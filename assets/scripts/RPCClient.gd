extends Node

var in_game := false

var discord_user_init := false
var discord_working := false

func _ready():
	# Discord Rich Presence does not work on dedicated servers and on mobile devices
	if Global.is_dedicated_server: return
	if Global.is_mobile: return
	
	# Don't run the code below if "--no-rpc" was included as a command line argument.
	if ("--no-rpc" in OS.get_cmdline_args()): return
	
	DiscordRPC.app_id = 1248427738855903294 # App ID is required for rich presence to work
	DiscordRPC.large_image = "icon"
	DiscordRPC.large_image_text = "v" + Global.version
	DiscordRPC.details = "Idle"
	
	if OS.is_debug_build():
		DiscordRPC.large_image_text += " (In Development)"
	
	DiscordRPC.connect("activity_join", _on_activity_join)
	DiscordRPC.connect("activity_join_request", _on_activity_join_request)
	
	DiscordRPC.refresh()
	
	if DiscordRPC.get_is_discord_working():
		#print("[Discord] App is working")
		discord_working = true

func _process(_delta):
	if Global.is_dedicated_server: return
	if Global.is_mobile: return
	
	if not discord_working: return
	
	if DiscordRPC.get_current_user()["id"] != 0 and not discord_user_init:
		discord_user_init = true
		var username = DiscordRPC.get_current_user().get("username", "IAmError")
		var disid = DiscordRPC.get_current_user().get("id", 0)
		print("[Discord] Logged in as " + username + " (" + str(disid) + ")")
		
		Global.client_info["username"] = username
		Global.client_info["discord_id"] = disid
	
	var game: Game = Global.get_game()
	
	if game:
		if not in_game:
			in_game = true
			DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())
			
		if Global.net_mode == Global.GAME_TYPE.SINGLEPLAYER:
			DiscordRPC.details = "Playing Singleplayer"
		else:
			if game.has_connected:
				if game.server_info["discord_show_name"]:
					DiscordRPC.details = "In Server: " + game.server_info["name"]
				else:
					DiscordRPC.details = "In Server: <Server Name Hidden>"
				
				DiscordRPC.party_id = game.server_info["uuid"]
				DiscordRPC.current_party_size = game.get_players(true).size()
				DiscordRPC.max_party_size = Global.MAX_PLAYERS
				DiscordRPC.is_public_party = game.server_info["discord_public"]
				
				# Generate a secret, so the player can send invites or ask to join their game.
				# If the server does not allow invites, don't generate a secret.
				if DiscordRPC.join_secret.is_empty() and game.server_info["allow_discord_invites"]:
					var encoded = Marshalls.utf8_to_base64(get_join_secret())
					
					DiscordRPC.join_secret = encoded
				
				# Make the join secret empty if the server has disabled invites for now.
				if not game.server_info["allow_discord_invites"]:
					if not DiscordRPC.join_secret.is_empty():
						DiscordRPC.join_secret = ""
			else:
				DiscordRPC.details = "Connecting to the server"
		
		if game.has_connected:
			if game.game_state == game.STATE.LOBBY:
				DiscordRPC.state = "Lobby"
			else:
				DiscordRPC.state = game.current_gamemode["name"]
			
			# Show the bot count when playing singleplayer
			if Global.net_mode == Global.GAME_TYPE.SINGLEPLAYER:
				DiscordRPC.state += " (" + str(game.num_bots) + " bots)"
		else:
			DiscordRPC.state = ""
		
		DiscordRPC.refresh()
	elif in_game:
		in_game = false
		DiscordRPC.state = ""
		DiscordRPC.details = "Idle"
		DiscordRPC.party_id = ""
		DiscordRPC.current_party_size = 0
		DiscordRPC.max_party_size = 0
		DiscordRPC.join_secret = ""
		DiscordRPC.start_timestamp = 0
		
		DiscordRPC.refresh()

# Player wants to join other player's game, connect to it automatically
func _on_activity_join(secret):
	DisplayServer.window_request_attention()
	
	var decoded = Marshalls.base64_to_utf8(secret)
	
	# Something is not right here.. invalid base64?
	if not decoded or decoded.is_empty():
		Global.alert("Failed to join the activity (invalid secret)", "RPC Error")
		return
	
	var code_split = decoded.split("|")
	
	var net_type = code_split[0]
	
	if net_type == "direct":
		print("[Discord] Connecting to the server by invite (direct mode)")
		Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_CLIENT
		
		Global.server_ip = code_split[1]
		Global.server_port = int(code_split[2])
		
		Global.change_scene_file.call_deferred("res://scenes/game.tscn")
	else:
		# This shouldn't happen, maybe modified client?
		Global.alert("Failed to join the activity (invalid network type)", "RPC Error")

# We got a request from someone, emit a signal.
func _on_activity_join_request(user):
	print("[Discord] Received join request from " + user["username"] + " (" + str(user["id"]) + ")")
	
	Global.emit_signal("discord_join_request", user)

func get_join_secret() -> String:
	var join_code = ""
	var game: Game = Global.get_game()
	
	join_code += "direct"
	if Global.net_mode == Global.GAME_TYPE.MULTIPLAYER_CLIENT:
		join_code += "|" + Global.server_ip
	else:
		join_code += "|" + game.get_local_ip()
		join_code += "|" + str(Global.server_port)
	
	return join_code

func _exit_tree():
	# Make sure that the activity is cleared before exiting
	DiscordRPC.clear(true)
