extends Control

var listener_peer: PacketPeerUDP

var servers: Dictionary = {}

var public_servers: Dictionary = {}

@onready var lan_list = $tabs/LAN
@onready var public_list = $tabs/Public

func _ready():
	listener_peer = PacketPeerUDP.new()
	
	var err = listener_peer.bind(9887)
	
	if err != OK:
		print("[LAN] Failed to listen for servers (another instance already open?)")
		
		lan_list.set_item_text(0, "Failed to listen for LAN Servers")
	else:
		$listener_timer.connect("timeout", _on_listen)
		$listener_timer.start()
	
	lan_list.connect("item_activated", _on_server)
	public_list.connect("item_activated", _on_public_server)
	
	$tabs/Direct/connectbtn.connect("pressed", _on_direct)
	
	$PublicListRequest.connect("request_completed", _on_public_list_response)
	
	if Global.cubenet_server_url.is_empty():
		public_list.set_item_text(0, "CubeNet Instance not set, you won't have the public servers")
	else:
		var err2 = $PublicListRequest.request(
			Global.cubenet_server_url + "/servers?version=" + Global.version.uri_encode() + "&platform=" + OS.get_name().uri_encode()
		)
		if err2 != OK:
			public_list.set_item_text(0, "Invalid CubeNet Instance URL, did you include the slash after the url?")

func _on_listen():
	var num_packets: int = listener_peer.get_available_packet_count()
	
	for i in num_packets:
		var packet: String = listener_peer.get_packet().get_string_from_utf8()
		var ip = listener_peer.get_packet_ip()
		
		# That way we know the packet comes from Faked Cubes Server
		if packet.begins_with("FC|"):
			var data = packet.split("|")[1]
			var decoded_data = Marshalls.base64_to_utf8(data)
			var info = JSON.parse_string(decoded_data)
			
			if info is Dictionary:
				if not servers.has(ip):
					info["idx"] = _add_server_info(info, lan_list)
					servers[ip] = info
				else:
					var server = servers[ip]
					
					for x in info:
						if server.has(x) and info[x] == server[x]: continue
						server[x] = info[x]
					
					#lan_list.set_item_text(server["idx"], sname)
					

func _on_server(idx: int):
	for serv in servers:
		var info = servers[serv]
		
		if info["idx"] == idx:
			Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_CLIENT
			
			Global.server_ip = serv
			Global.server_port = info["port"]
			
			Global.change_scene_file("res://scenes/game.tscn")
			break

func _on_public_server(idx: int):
	for serv in public_servers:
		var info = public_servers[serv]
		
		if info["idx"] == idx:
			Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_CLIENT
			
			Global.server_ip = info["ip"]
			
			if Global.server_ip.begins_with("webrtc:"):
				Global.net_type = Global.NET_TYPE.WEBRTC
				Global.server_ip = Global.server_ip.split(":")[1]
			else:
				Global.net_type = Global.NET_TYPE.DIRECT
			
			Global.server_port = info["port"]
			
			Global.change_scene_file("res://scenes/game.tscn")
			break

func _on_direct():
	var ip = $tabs/Direct/ip/value.text
	var port = int($tabs/Direct/port/value.value)
	
	Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_CLIENT
	
	Global.server_ip = ip
	Global.server_port = port
	
	Global.change_scene_file("res://scenes/game.tscn")

func _exit_tree():
	if listener_peer.is_bound():
		listener_peer.close()

func _add_server_info(info: Dictionary, list: ItemList) -> int:
	var outdated = false
	
	var sname = info["name"]
	
	if info["version"] != Global.version:
		outdated = true
	
		sname += " (Version Mismatch: " + info["version"] + ")"
	else:
		sname += " | Gamemode: " + info["gamemode"]
		
		sname += " | Players: " + str(info["players"])
		
		if info["bots"] > 0:
			sname += " (" + str(info["bots"]) + " bots)"
		
		if info["dedicated"]:
			sname += " (dedicated)"
	
	var idx = list.add_item(sname, null, (not outdated))
	info["idx"] = idx
	
	return idx

func _on_public_list_response(_res: int, res_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if res_code == 200:
		var json: Array = JSON.parse_string(body.get_string_from_utf8())
		
		if json.size() > 0:
			public_list.clear()
		else:
			public_list.set_item_text(0, "There are no public servers online right now.")
		
		for info in json:
			_add_server_info(info, public_list)
			
			public_servers[info["uuid"]] = info
		
	else:
		public_list.set_item_text(0, "Failed to request the server list, check your internet and try again")
