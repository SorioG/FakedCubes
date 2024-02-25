extends Control

var listener_peer: PacketPeerUDP

var servers: Dictionary = {}

@onready var lan_list = $tabs/LAN

func _ready():
	listener_peer = PacketPeerUDP.new()
	
	var err = listener_peer.bind(9887)
	
	if err != OK:
		print("Failed to listen for servers")
	else:
		$listener_timer.connect("timeout", _on_listen)
		$listener_timer.start()
	
	lan_list.connect("item_activated", _on_server)
	
	$tabs/Direct/connectbtn.connect("pressed", _on_direct)

func _on_listen():
	var num_packets: int = listener_peer.get_available_packet_count()
	
	for i in num_packets:
		var packet: String = listener_peer.get_packet().get_string_from_utf8()
		var ip = listener_peer.get_packet_ip()
		
		# That way we know the packet comes from Faked Cubes Server
		if packet.begins_with("FC@"):
			var data = packet.split("@")[1]
			var info = JSON.parse_string(data)
			var outdated = false
			
			var sname = info["name"]
			
			if info["version"] != Global.version:
				outdated = true
				
				sname += " (Version Mismatch: " + Global.version + ")"
			else:
				sname += " | Gamemode: " + info["gamemode"]
				
				sname += " | Players: " + str(info["players"])
				
				if info["bots"] > 0:
					sname += " (" + str(info["bots"]) + " bots)"
			
			
			
			if info is Dictionary:
				if not servers.has(ip):
					info["idx"] = lan_list.add_item(sname, null, (not outdated))
					servers[ip] = info
				else:
					var server = servers[ip]
					
					for x in info:
						if server.has(x) and info[x] == server[x]: continue
						server[x] = info[x]
					
					lan_list.set_item_text(server["idx"], sname)
					

func _on_server(idx: int):
	for serv in servers:
		var info = servers[serv]
		
		if info["idx"] == idx:
			Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_CLIENT
			
			Global.server_ip = serv
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
