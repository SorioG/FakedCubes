extends Node2D
class_name Game

@onready var players_node = $players
@onready var bottominfo = $hud/lobby_ui/BottomInfo
@onready var multi_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var bot_mp_spawner: MultiplayerSpawner = $BotSpawner

@onready var chat_window = $hud/ChatWindow

@onready var pause_bg = $hud/PauseBG
@onready var pause_win = $hud/PauseWindow

var lan_announcer: PacketPeerUDP

var current_map: Node2D

var current_gamemode = {"name": "Unknown", "base": BaseGamemode}:
	set(val):
		current_gamemode = val
		
		if is_instance_valid(gamemode_node):
			gamemode_node.free()
		
		gamemode_node = val["base"].new()
		gamemode_node.game = self

var gamemode_node: BaseGamemode

signal player_spawned(player: Player)

var players: Array[Player] = []

var local_player: Player

enum STATE {
	LOBBY = 1,
	INGAME = 2
}

@export var game_state = STATE.LOBBY
@export var net_mode: int = Global.net_mode

@export var num_bots: int = 0

@export var spawn_local_player = true

@export var autoplay = false

@export var bot_change_skin = true

var max_impostors: int = 3

var bot_players: Array[Player] = []

var winning_role: int

var gamemode_idx: int

var name_generator: NameGenerator = NameGenerator.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var is_split_screen: bool = false
var split_screen_player: int = 1
var local_player2: Player

var server_info: Dictionary = {
	"name": "My Server", 
	"port": Global.server_port,
	"version": Global.version,
	"gamemode": "Classic",
	"players": 0,
	"bots": 0
}

var dediserver_confirmed = false

# Custom Maps
var is_using_custom_map = false
var custom_map_path: String = ""

var current_map_path: String = ""

var custom_lobby_path: String = ""

@export var can_change_map = true

@export var is_voice_chat_allowed = true
@export var is_custom_skins_allowed = true

signal local_player_used_action(action: int)
signal game_ended


func spawn_player(is_local: bool, plr_name: String = "Player", is_new: bool = true, is_bot: bool = false) -> Player:
	var plr = Global.PLAYER_NODE.instantiate()
	plr.is_local_player = is_local
	plr.player_name = plr_name
	plr.name = plr_name
	plr.is_bot = is_bot
	
	emit_signal("player_spawned", plr)
	
	players_node.add_child(plr)
	
	if is_new:
		plr.animation.play("appear")
	
	if is_local and is_split_screen:
		plr.action_prefix = "p{0}_".format([split_screen_player])
	
	# Handle Early Player Spawns (count them as innocent)
	if game_state == STATE.INGAME:
		#if current_gamemode["base"] == "impostor":
		#	plr.current_role = Global.PLAYER_ROLE.INNOCENT
		gamemode_node.player_join_early(plr)
	
	plr.position = get_random_spawn().position
	
	return plr

func _ready():
	rng.randomize()
	
	$hud/role_reveal.visible = false
	$hud/role_reveal/hide_timer.connect("timeout", _impostor_timer_end)
	
	multi_spawner.spawn_function = net_spawn_player
	bot_mp_spawner.spawn_function = net_bot_spawn
	
	multiplayer.peer_connected.connect(_on_peer_joined)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	multiplayer.server_disconnected.connect(_on_disconnect)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	current_gamemode = Global.game_modes[0]
	gamemode_idx = 0
	
	$hud/vc_enable.connect("pressed", _enable_microphone)
	$hud/chat.connect("pressed", _show_chat_window)
	
	$hud/vc_enable.visible = is_voice_chat_allowed
	
	if net_mode == Global.GAME_TYPE.SINGLEPLAYER:
		change_to_lobby()
		
		if spawn_local_player:
			local_player = spawn_player(true, "Player1")
		
		$bot_spawn_timer.connect("timeout", bot_spawn)
		$bot_spawn_timer.start()
		
		# Voice Chat is not needed in singleplayer
		$hud/vc_enable.visible = false
		is_voice_chat_allowed = false
	
	elif net_mode == Global.GAME_TYPE.MULTIPLAYER_HOST:
		var peer = ENetMultiplayerPeer.new()
		var err = peer.create_server(Global.server_port)
		
		if err != OK:
			Global.alert("Failed to start the server, is the port open?", "Server Error")
			
			if Global.is_dedicated_server:
				# Automatically stop the dedicated server in case of the error
				get_tree().quit(1)
			
			_leave_game()
			return
		
		multiplayer.multiplayer_peer = peer
		
		change_to_lobby()
		
		#net_spawn_player.rpc(multiplayer.get_unique_id())
		
		# Spawn a local player unless we are hosting a dedicated server
		if not Global.is_dedicated_server:
			multi_spawner.spawn(1)
			
			server_info["name"] = Global.client_info["username"] + "'s server"
		
		$bot_spawn_timer.connect("timeout", bot_spawn)
		$bot_spawn_timer.start()
		
		# Announce the server to LAN
		lan_announcer = PacketPeerUDP.new()
		lan_announcer.set_broadcast_enabled(true)
		# Should we keep the destination address with that one?
		lan_announcer.set_dest_address("255.255.255.255", 9887)
		
		$announce_timer.connect("timeout", _lan_announce)
		$announce_timer.start()
		
		handle_arguments()
	
	elif net_mode == Global.GAME_TYPE.MULTIPLAYER_CLIENT:
		$hud/lobby_ui/StartButton.visible = false
		
		print("Connecting to " + Global.server_ip + ":" + str(Global.server_port))
		
		#LoadingScreen.music.play()
		LoadingScreen.show_screen()
		LoadingScreen.loadlabel.text = tr("Connecting to the server...")
		
		var peer = ENetMultiplayerPeer.new()
		peer.create_client(Global.server_ip, Global.server_port)
		multiplayer.multiplayer_peer = peer
	
	$hud/lobby_ui/StartButton.connect("pressed", _on_start_pressed)
	
	chat_window.visible = false
	
	#chat_window.add_message("User", "Test Message")
	chat_window.connect("type_message", _typed_message)
	chat_window.connect("new_message", _new_message)
	
	$dediserver_timer.connect("timeout", dediserver_autostart)
	
	if Global.is_dedicated_server:
		parse_server_config()
		
		$dediserver_timer.start()
	
	pause_bg.visible = false
	pause_win.visible = false
	
	$hud/menu.connect("pressed", _pause_pressed)
	$hud/PauseWindow/btns/resume.connect("pressed", _resume_pressed)
	$hud/PauseWindow/btns/quit.connect("pressed", _leave_game)

func _pause_pressed():
	pause_bg.visible = true
	pause_bg.modulate = Color.TRANSPARENT
	pause_win.visible = true
	#pause_win.position = Vector2(376, 80)
	
	pause_win.get_node("paused").play()
	
	var tween = create_tween()
	#tween.tween_property(pause_win, "position", Vector2(376, 55), 0.2)
	tween.tween_property(pause_bg, "modulate", Color.WHITE, 0.2)
	
	pause_win.get_node("btns/resume").grab_focus()
	
	if Global.net_mode == Global.GAME_TYPE.SINGLEPLAYER:
		get_tree().paused = true

func _resume_pressed():
	pause_bg.visible = false
	pause_win.visible = false
	#pause_bg.color = Color.from_string("#00000093", Color.BLACK)
	
	
	pause_win.get_node("resumed").play()
	
	if Global.net_mode == Global.GAME_TYPE.SINGLEPLAYER:
		get_tree().paused = false

func _leave_game():
	get_tree().set_deferred("paused", false)
	
	Global.net_mode = Global.GAME_TYPE.SINGLEPLAYER
	
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Global.change_scene_file("res://scenes/menu_screen.tscn")

func parse_server_config():
	var config: ConfigFile = Global.server_config
	
	if not config: return
	
	server_info["name"] = config.get_value("Server", "name", "Dedicated Server")
	is_custom_skins_allowed = config.get_value("Server", "allow_custom_skins", true)
	is_voice_chat_allowed = config.get_value("Server", "voice_chat", true)
	
	var lobby_map = config.get_value("Game", "lobby_map", "default")
	
	if lobby_map != "default":
		custom_lobby_path = Global.maps_path.path_join(lobby_map + ".tscn")
		
		change_to_lobby()

func change_to_lobby():
	if custom_lobby_path.is_empty():
		_change_map("lobby")
	else:
		load_custom_map(custom_lobby_path)

## Automatically start the game on a dedicated server
func dediserver_autostart():
	if game_state == STATE.INGAME: return
	if can_start_game() == "OK":
		if not dediserver_confirmed:
			dediserver_confirmed = true
			#print("[Game] Automatically starting the game")
			net_server_message.rpc("The game will now start after a few seconds")
		else:
			dediserver_confirmed = false
			_on_start_pressed.call_deferred()
			$dediserver_timer.stop()
	else:
		if dediserver_confirmed:
			net_server_message.rpc("Stopped the timer because the gamemode cannot be started")
		dediserver_confirmed = false

func _typed_message(msg: String):
	net_user_message.rpc(msg)

func _new_message(_user: String, _msg: String):
	if not chat_window.visible:
		$hud/chat.modulate = Color.WHITE
		$chat_new.play()

@rpc("any_peer", "call_local", "reliable")
func net_user_message(msg: String):
	var id = multiplayer.get_remote_sender_id()
	var player: Player = players_node.get_node_or_null("Player" + str(id))
	if player:
		chat_window.add_message(player.player_name, msg)
		
		print("[Chat] " + player.player_name + ": " + msg)
	else:
		push_warning("Someone typed a message, but player does not exist")

@rpc("authority", "call_local", "reliable")
func net_server_message(msg: String):
	chat_window.add_message("Server", msg, load("res://assets/sprites/computer.png"))
	print("[Chat] Server: " + msg)

func _on_peer_joined(id: int):
	print("[Server] Player " + str(id) + " has connected")
	if multiplayer.is_server():
		if not current_map_path.is_empty():
			var file = FileAccess.open(current_map_path, FileAccess.READ)
			
			var netdata = Marshalls.raw_to_base64(file.get_buffer(file.get_length()))
			
			net_download_map.rpc_id(id, netdata)
			
			file.close()
		else:
			change_map.rpc_id(id, current_map.name)
		
		net_change_gamemode.rpc_id(id, gamemode_idx)
		
		# TODO: Automatically download required mods used from the server before spawning
	
	# Send the correct skin to a player (whatever or not it's a custom skin)
	if local_player:
		if local_player.skin_name == "Custom":
			local_player.net_load_custom_skin.rpc_id(id, local_player.custom_skin_data)
		else:
			local_player.net_set_skin.rpc_id(id, local_player.skin_name)
		
		local_player.net_set_hat.rpc_id(id, local_player.hat_name)
	



func _on_peer_left(id: int):
	var player = players_node.get_node_or_null("Player" + str(id))
	
	if player:
		print("[Game] " + player.player_name + " left the game")
		player.disappear()

		if Global.is_dedicated_server and ("--close-on-empty" in OS.get_cmdline_args()):
			if multiplayer.get_peers().size() < 1:
				print("Closing automatically due to the server being empty")
				get_tree().quit.call_deferred()
	else:
		print("[Server] Player " + str(id) + " disconnected")

func bot_spawn():
	var size = bot_players.size()
	var bnam = name_generator.new_name()
	if size < num_bots:
		if Global.net_mode == Global.GAME_TYPE.SINGLEPLAYER:
			var bot = spawn_player(false, bnam[1], true, true)
		
			bot_players.push_back(bot)
		elif Global.net_mode == Global.GAME_TYPE.MULTIPLAYER_HOST:
			bot_mp_spawner.spawn(bnam[1])
	
	elif size > num_bots:
		var bot = bot_players.pop_back()
		
		bot.disappear()
		

func net_bot_spawn(nam: String):
	var player := Global.PLAYER_NODE.instantiate()
	
	player.name = "Bot" + nam.md5_text()
	player.player_name = nam
	player.is_bot = true
	player.is_local_player = false
	player.can_have_authority = false
	
	player.has_spawned = true
	
	emit_signal("player_spawned", player)
	
	bot_players.push_back(player)
	
	return player

func get_local_ip():
	var addr = IP.get_local_addresses()
	
	for ip in addr:
		var addr2 = ip.split(":")[0]
		
		if addr2.begins_with("192.168."):
			return addr2
	
	return "127.0.0.1"

func _process(_delta):
	bottominfo.text = "Gamemode: " + current_gamemode["name"]
	bottominfo.text += " | "
	
	if Global.net_mode == Global.GAME_TYPE.SINGLEPLAYER:
		bottominfo.text += "Singleplayer"
	elif Global.net_mode == Global.GAME_TYPE.MULTIPLAYER_HOST:
		bottominfo.text += get_local_ip() + ":" + str(Global.server_port)
	elif Global.net_mode == Global.GAME_TYPE.MULTIPLAYER_CLIENT:
		bottominfo.text += Global.server_ip + ":" + str(Global.server_port)
	
	if local_player:
		update_players()
		
		if Input.is_action_just_pressed("menu") and not pause_win.visible:
			_pause_pressed()
	
	if game_state == STATE.INGAME:
		gamemode_node.game_tick()
		
		if multiplayer.is_server():
			winning_role = check_end_game()
			
			if winning_role != Global.PLAYER_ROLE.NONE:
				end_game()
				
				net_end_game.rpc(winning_role)
	
	if autoplay:
		if bot_players.size() >= num_bots and game_state == STATE.LOBBY:
			_on_start_pressed()
			autoplay = false
	
	$hud/vc_enable.visible = is_voice_chat_allowed

@rpc("authority", "call_local", "reliable")
func change_map(m: String):
	if not Global.maps[m]:
		return
	
	if is_instance_valid(current_map):
		current_map.free()
	
	current_map_path = ""
	is_using_custom_map = false
	
	current_map = Global.maps[m].instantiate()
	
	current_map.name = m
	
	current_map.get_node("spawns").visible = false
	
	$map.add_child(current_map)
	
	move_players()

func get_random_spawn():
	return current_map.get_node("spawns").get_children().pick_random()

func move_players():
	var plrs = players_node.get_children()
	
	for plr in plrs:
		if plr is Player:
			plr.position = get_random_spawn().position

func get_local_player() -> Player:
	if net_mode != Global.GAME_TYPE.SINGLEPLAYER:
		return players_node.get_node("Player"+str(multiplayer.get_unique_id()))
	
	return local_player

func get_local_player2() -> Player:
	return local_player2


func net_spawn_player(id):
	var player := Global.PLAYER_NODE.instantiate()
	
	player.net_id = id
	player.has_spawned = true
	player.name = "Player" + str(id)
	player.is_local_player = false
	
	player.set_multiplayer_authority(id)
	
	player.get_node("ServerSyncer").set_multiplayer_authority(1)
	
	emit_signal("player_spawned", player)
	
	if multiplayer.is_server():
		player.position = get_random_spawn().position
	
	return player

@rpc("authority", "call_remote", "reliable")
func net_load_scripts(_scr: Array[String]):
	pass

func _change_map(map: String):
	if Global.net_mode == Global.GAME_TYPE.SINGLEPLAYER:
		change_map(map)
	if Global.net_mode == Global.GAME_TYPE.MULTIPLAYER_HOST:
		change_map.rpc(map)

func can_start_game() -> String:
	return gamemode_node.can_start_game()

func _on_start_pressed():
	var err = can_start_game()
	
	if err != "OK":
		print("Failed to start game: " + err)
		
		if not Global.is_dedicated_server:
			var diag: AcceptDialog = $hud/FailDialog
			
			diag.dialog_text = "Failed to start game: " + err
			diag.popup()
		return
	
	$hud/lobby_ui.visible = false
	
	print("[Game] Successfully started the game")
	
	game_state = STATE.INGAME
	
	
	if Global.net_mode == Global.GAME_TYPE.MULTIPLAYER_HOST and multiplayer.is_server():
		multiplayer.multiplayer_peer.refuse_new_connections = true
		
		print("[Server] This server is now refusing connections.")
	
	if is_using_custom_map and can_change_map:
		load_custom_map(custom_map_path)
	
	gamemode_node.game_start()
	
	if gamemode_node.can_reveal_role:
		show_role_reveal()
	
	net_start_game.rpc()

@rpc("authority", "call_remote", "reliable")
func net_start_game():
	$hud/lobby_ui.visible = false
	
	gamemode_node.game_start()
	
	if gamemode_node.can_reveal_role:
		show_role_reveal()

func get_players(exclude_bots: bool = false) -> Array[Player]:
	var res: Array[Player] = []
	for plr in players_node.get_children():
		if plr is Player:
			if plr.is_bot and exclude_bots: continue
			if plr.c_game != self: continue
			res.append(plr)
	
	return res



func get_players_by_role(role: int) -> Array[Player]:
	var res: Array[Player] = []
	
	for plr in get_players():
		if plr.current_role == role:
			res.append(plr)
	
	return res

func show_role_reveal():
	
	# Make the reveal visible even without the player (to stop the bots from moving)
	$hud/role_reveal.visible = true
	
	if local_player:
		$hud/role_reveal/role_player.set_skin(local_player.get_skin()) # Try to match player's skin
		$hud/role_reveal/role_player.animation.play("idle2")
		
		if not multiplayer.is_server():
			$hud/role_reveal/role_text.text = "Waiting for server..."
			
			await local_player.get_node("ServerSyncer").synchronized
		
		gamemode_node.role_reveal($hud/role_reveal/role_text, $hud/role_reveal/role_player)
	
	$hud/role_reveal/hide_timer.start()

func end_game():
	change_to_lobby()
	
	print("[Game] The game has now ended. (Winning Role: " + str(winning_role) + ")")
	
	game_state = STATE.LOBBY
	$hud/lobby_ui.visible = true
	
	if Global.is_dedicated_server:
		$dediserver_timer.start()
	
	show_results()
	
	reset_players()
	
	if multiplayer.is_server():
		net_end_game.rpc(winning_role)
		multiplayer.multiplayer_peer.refuse_new_connections = false
		
		print("[Server] This server is now accepting connections.")
	
	emit_signal("game_ended")

func check_end_game() -> int:
	return gamemode_node.check_end_game()

func show_results():
	if not local_player: return
	$hud/role_reveal.visible = true
	$hud/role_reveal/role_player.set_skin(get_players_by_role(winning_role).pick_random().get_skin()) # Try to match player's skin
	$hud/role_reveal/role_player.animation.play("idle")
	
	gamemode_node.show_results($hud/role_reveal/role_text, $hud/role_reveal/role_player)
	
	$hud/role_reveal/hide_timer.start()

func get_alive_players() -> Array[Player]:
	var res: Array[Player] = []
	
	for plr in get_players():
		if plr.is_killed: continue
		
		res.append(plr)
	
	return res

func get_alive_players_by_role(role: int) -> Array[Player]:
	var res: Array[Player] = []
	
	for plr in get_players():
		if plr.is_killed: continue
		if plr.current_role != role: continue
		
		res.append(plr)
	
	return res

func get_dead_players() -> Array[Player]:
	var res: Array[Player] = []
	
	for plr in get_players():
		if not plr.is_killed: continue
		
		res.append(plr)
	
	return res

func reset_players():
	for plr in get_players():
		reset_player(plr)

func reset_player(plr: Player, reset_role: bool = true):
	plr.is_killed = false
	plr.camera.offset = Vector2()
	if reset_role:
		plr.current_role = Global.PLAYER_ROLE.NONE
	
	plr.animation.play("RESET")
	plr.is_idle = false
	
	if multiplayer.is_server():
		plr.net_reset_player.rpc(reset_role)

func _impostor_timer_end():
	$hud/role_reveal.visible = false

func update_players():
	for player in get_players():
		if player == local_player: continue
		if game_state == STATE.INGAME:
			gamemode_node.update_player(player)
		else:
			player.get_node("impostor_icon").visible = false

@rpc("authority", "call_remote", "reliable")
func net_change_gamemode(id: int):
	current_gamemode = Global.game_modes[id]

func _enable_microphone():
	if Global.is_mobile and not Global.is_emulating_mobile:
		if not OS.request_permission("RECORD_AUDIO"): return
	
	if local_player.vc_input.playing:
		local_player.vc_input.stop()
	else:
		local_player.vc_input.play()

func _show_chat_window():
	$hud/chat.modulate = Color.from_string("#ffffff80", Color.WHITE)
	
	chat_window.visible = not chat_window.visible

func _lan_announce():
	server_info["gamemode"] = current_gamemode["name"]
	server_info["players"] = get_players(true).size()
	server_info["bots"] = bot_players.size()
	
	var packet = "FC@" + JSON.stringify(server_info)
	var err = lan_announcer.put_packet(packet.to_utf8_buffer())
	
	if err != OK:
		print("Failed to announce server to LAN")
		$announce_timer.stop()

@rpc("any_peer", "reliable", "call_local")
func send_client_info(_info: Dictionary):
	pass

@rpc("any_peer", "reliable", "call_local")
func custom_rpc(data: Dictionary):
	var id = multiplayer.get_remote_sender_id()
	
	gamemode_node.receive_custom_rpc(data, id)

func get_player_by_id(id: int) -> Player:
	return get_node_or_null("players/Player" + str(id))

func _on_disconnect():
	Global.net_mode = Global.GAME_TYPE.SINGLEPLAYER
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Global.alert("You have been disconnected from the server")
	
	Global.change_scene_file("res://scenes/menu_screen.tscn")

func _on_connection_failed():
	Global.net_mode = Global.GAME_TYPE.SINGLEPLAYER
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Global.alert("Failed to connect to the server")
	
	Global.change_scene_file("res://scenes/menu_screen.tscn")

func _on_connected():
	LoadingScreen.loadlabel.text = "Sending client information..."
	
	net_client_info.rpc_id(1, Global.client_info)

@rpc("call_remote", "reliable")
func net_end_game(winner: int):
	winning_role = winner
	end_game()

# This should be useful for handling arguments in a dedicated server (also works on listen server)
func handle_arguments():
	var i = 0
	var args = OS.get_cmdline_args()
	for line in args:
		if line == "--max-bots":
			num_bots = int(args[i+1])
			
			print("Adding " + str(num_bots) + " bots")
		
		if line == "--gamemode":
			var nam = int(args[i+1])
			
			if nam > Global.game_modes.size() or nam < 0:
				print("Invalid Gamemode, ignoring..")
			else:
				current_gamemode = Global.game_modes[nam]
				gamemode_idx = nam
				
				print("Changed gamemode to " + current_gamemode["name"])
		
		i += 1


func load_custom_map(path: String):
	var map = ResourceLoader.load(path, "PackedScene")
	
	if map is PackedScene:
		if is_instance_valid(current_map):
			current_map.free()
		
		var cmap = map.instantiate()
		
		current_map = cmap
		
		current_map_path = path
		
		$map.add_child(cmap)
		
		move_players()
		
		if multiplayer.is_server():
			var file = FileAccess.open(path, FileAccess.READ)
			
			var netdata = Marshalls.raw_to_base64(file.get_buffer(file.get_length()))
			
			net_download_map.rpc(netdata)
			
			file.close()
	else:
		print("Failed to load custom map")

@rpc("call_remote", "reliable")
func net_download_map(file: String):
	var data = Marshalls.base64_to_raw(file)
	
	DirAccess.make_dir_absolute("user://net_downloads")
	
	var path = "user://net_downloads/" + file.md5_text() + ".tscn"
	
	var map = FileAccess.open(path, FileAccess.WRITE)
	
	map.store_buffer(data)
	
	map.close()
	
	load_custom_map.call_deferred(path)

@rpc("any_peer", "reliable", "call_local")
func net_client_info(info: Dictionary):
	assert(multiplayer.is_server(), "Server Only RPC Function")
	
	var id = multiplayer.get_remote_sender_id()
	
	var can_join: bool = true
	var err_msg: String = "You are not allowed to join this server"
	
	var modded: bool = info["modded"]
	var mods: Array = info["mods"]
	var username: String = info["username"]
	var version: String = info["version"]
	var platform: String = info["platform"]
	
	# Remind that client to use the version that the server is currently using
	if version != Global.version:
		err_msg = "Outdated Version! This server is using " + Global.version
		can_join = false
	
	# Empty Usernames are kind of cheating.
	if username.is_empty() and can_join:
		err_msg = "The username must not be empty"
		can_join = false
	
	# If this server is modded, we can check whatever or not this client has some mods enabled.
	if ModLoader.required_mods.size() > 0 and can_join:
		var max_mods = ModLoader.required_mods.size()
		
		if not modded:
			err_msg = "You're connecting to a modded server, but you don't have any mods enabled. (" + str(max_mods) + " required mods used)"
			can_join = false
		else:
			var mod_count = 0
			for mod_id in mods:
				if ModLoader.required_mods.has(mod_id):
					mod_count += 1
			
			# This client does not have the server's required mods.
			if mod_count != max_mods:
				err_msg = "You do not have the " + str(max_mods-mod_count) + " required mods for this server."
				can_join = false
	
	# Let the mods handle it as well.
	ModLoader.call_hook("handle_client_info", [info, err_msg, can_join])
	
	if can_join:
		print(username + " has joined the game (platform: " + platform + ", modded: " + str(modded) + ")")
		multi_spawner.spawn(id)
	else:
		if username:
			print(username + " failed to join the game (" + err_msg + ")")
		else:
			print("Player " + id + " failed to join the game (" + err_msg + ")")
		
		net_info_fail.rpc_id(id, err_msg)

@rpc("any_peer", "reliable", "call_local")
func net_info_fail(msg: String):
	assert(multiplayer.get_remote_sender_id() == 1)
	
	Global.alert(msg, "Connection Failed")
	
	_leave_game()

# Something that's useful for mods
func get_gamemode_name() -> String:
	return current_gamemode["name"]

func load_custom_map_by_name(n: String):
	if Global.custom_maps.has(n):
		load_custom_map(Global.custom_maps[n])
	else:
		print("Custom map named '" + n + "' does not exist")

func send_server_message(msg: String):
	net_server_message.rpc(msg)

func send_server_message_to_id(id: int, msg: String):
	net_server_message.rpc_id(id, msg)

func send_player_message(msg: String):
	if Global.is_dedicated_server:
		print("[WARN] The host is not a player, please use send_server_message instead")
		net_server_message.rpc(msg)
	else:
		net_user_message.rpc(msg)
