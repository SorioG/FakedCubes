extends Node2D

func _ready():
	LoadingScreen.show_screen()
	
	LoadingScreen.loadlabel.text = tr("Loading Custom Maps")
	print(tr("Loading Custom Maps"))
	Global.load_custom_maps(Global.maps_path)
	
	await get_tree().process_frame
	
	if not OS.has_feature("dedicated_server"):
		LoadingScreen.loadlabel.text = tr("Loading Custom Skins")
		print(tr("Loading Custom Skins"))
		Global.load_custom_skins("user://skins")
		
		await get_tree().process_frame
		
		LoadingScreen.loadlabel.text = tr("Loading Data")
		print(tr("Loading Data"))
		Global.load_user_config()
		
		Global.can_save_config = true
		
		await get_tree().process_frame
	
	if Global.is_lua_enabled:
		# However, even disabling the mods, quitting the game will freeze for a second and then closes
		# Not sure why, but i will try to work around this if i can.
		LoadingScreen.loadlabel.text = tr("Loading Mods")
		print(tr("Loading Mods"))
		ModLoader.load_mods()
	
		await get_tree().process_frame
	
	LoadingScreen.hide_screen()
	
	if OS.has_feature("dedicated_server") or ("--dediserver" in OS.get_cmdline_args() and OS.is_debug_build()):
		# If launched through dedicated server, it will automatically host a server.
		# This will be also used if "--dediserver" was included as a argument (only works on debug build)
		print(" ")
		print("---- Faked Cubes Dedicated Server ----")
		print("Server Version: " + Global.version)
		print("Hosting on port " + str(Global.server_port))
		print("--------------------------------------")
		print(" ")
		Global.is_dedicated_server = true
		Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_HOST
		
		Global.load_server_config()
		
		Global.change_scene_file.call_deferred("res://scenes/game.tscn")
		
	elif "--server" in OS.get_cmdline_args():
		Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_HOST
		
		Global.change_scene_file.call_deferred("res://scenes/game.tscn")
	
	elif "--singleplayer" in OS.get_cmdline_args():
		Global.net_mode = Global.GAME_TYPE.SINGLEPLAYER
		
		Global.change_scene_file.call_deferred("res://scenes/game.tscn")
	
	elif "--connect" in OS.get_cmdline_args():
		Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_CLIENT
		
		Global.change_scene_file.call_deferred("res://scenes/game.tscn")
	
	else:
		print("Faked Cubes - " + Global.version)
		if not handle_arguments():
			Global.change_scene_file.call_deferred("res://scenes/menu_screen.tscn")

func handle_arguments() -> bool:
	var _i = 0
	var args = OS.get_cmdline_args()
	var handled = false
	for arg in args:
		if arg == "--map-editor":
			handled = true
			Global.change_scene_file.call_deferred("res://scenes/map_editor.tscn")
		
		if arg == "--record-mode":
			#print("Record Mode enabled - Recommended to use godot's built-in recorder or any other recording software")
			Global.hide_menu = true
		
		_i += 1
	
	return handled
