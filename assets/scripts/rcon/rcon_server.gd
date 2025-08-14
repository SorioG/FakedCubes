extends Node

var tcp_server: TCPServer
var port: int = 27015
var password: String = ""
var clients: Dictionary = {}
var running: bool = false
var next_client_id: int = 1

class ClientInfo:
	var stream: StreamPeerTCP
	var authenticated: bool
	var buffer: PackedByteArray = PackedByteArray()
	var id: int
	var ip: String
	var last_request_id: int = 0

signal command_received(command: String, client_id: int)

func start() -> Error:
	tcp_server = TCPServer.new()
	var err = tcp_server.listen(port)
	if err == OK:
		running = true
		set_process(true)
	return err

func stop():
	running = false
	set_process(false)
	
	if tcp_server:
		tcp_server.stop()
	
	for client_id in clients:
		var client_info = clients[client_id]
		if client_info.stream:
			client_info.stream.disconnect_from_host()
	clients.clear()

func _process(_delta: float):
	if not running or not tcp_server: return
	
	if tcp_server.is_connection_available():
		var stream = tcp_server.take_connection()
		if stream:
			_handle_new_client(stream)
	
	var clients_to_remove = []
	for client_id in clients:
		var client_info: ClientInfo = clients[client_id]
		
		var status = client_info.stream.get_status()
		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			clients_to_remove.append(client_id)
			continue
		
		if status == StreamPeerTCP.STATUS_CONNECTED:
			var available = client_info.stream.get_available_bytes()
			if available > 0:
				var data = client_info.stream.get_data(available)
				if data[0] == OK:
					client_info.buffer.append_array(data[1])
					_process_client_buffer(client_id)
	
	for client_id in clients_to_remove:
		_remove_client(client_id)

func _handle_new_client(stream: StreamPeerTCP):
	var client_id = next_client_id
	next_client_id += 1
	
	var client_info = ClientInfo.new()
	client_info.stream = stream
	client_info.id = client_id
	client_info.ip = stream.get_connected_host()
	
	clients[client_id] = client_info
	print("[RCON] Client {0} connected".format([stream.get_connected_host()]))

func _remove_client(client_id: int):
	if client_id in clients:
		print("[RCON] Client {0} disconnected".format([clients[client_id].ip]))
		clients[client_id].stream.disconnect_from_host()
		clients.erase(client_id)

func _process_client_buffer(client_id: int):
	var client_info: ClientInfo = clients[client_id]
	
	while client_info.buffer.size() >= 14:
		var packet = RCONProtocol.parse_packet(client_info.buffer)
		if packet.is_empty(): break
		
		var packet_total_size = packet["size"] + 4
		if client_info.buffer.size() >= packet_total_size:
			client_info.buffer = client_info.buffer.slice(packet_total_size)
			_handle_packet(client_id, packet)
		else:
			break

func _handle_packet(client_id: int, packet: Dictionary):
	var client_info: ClientInfo = clients[client_id]
	
	match packet["type"]:
		RCONProtocol.PacketType.AUTH:
			_handle_auth(client_id, packet)
		RCONProtocol.PacketType.EXEC_COMMAND:
			if client_info.authenticated:
				client_info.last_request_id = packet["request_id"]
				var command = packet["body"]
				
				print("[RCON] Client {0} sent a command: {1}".format([client_info.ip, command]))
				command_received.emit(command, client_id)
			else:
				send_response(client_id, "Not authenticated!")

func _handle_auth(client_id: int, packet: Dictionary):
	var client_info: ClientInfo = clients[client_id]
	
	if packet["body"] == password:
		client_info.authenticated = true
		var response = RCONProtocol.create_packet(
			packet["request_id"],
			RCONProtocol.PacketType.AUTH_RESPONSE,
			""
		)
		_send_packet(client_id, response)
		print("[RCON] Client {0} successfully authenticated".format([client_info.ip]))
	else:
		var response = RCONProtocol.create_packet(
			-1,
			RCONProtocol.PacketType.AUTH_RESPONSE,
			""
		)
		_send_packet(client_id, response)
		print("[RCON] Client {0} failed to authenticate".format([client_info.ip]))

func send_response(client_id: int, response_text: String):
	if client_id not in clients: return
	
	var client_info: ClientInfo = clients[client_id]
	if not client_info.authenticated: return
	
	var response = RCONProtocol.create_packet(
		client_info.last_request_id,
		RCONProtocol.PacketType.RESPONSE_VALUE,
		response_text
	)
	_send_packet(client_id, response)

func _send_packet(client_id: int, packet_data: PackedByteArray):
	if client_id not in clients: return
	
	var client_info: ClientInfo = clients[client_id]
	if client_info.stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		client_info.stream.put_data(packet_data)
