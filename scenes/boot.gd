extends Node2D

func _ready():
	if OS.has_feature("dedicated_server") or ("--dediserver" in OS.get_cmdline_args()):
		print(" ")
		print("---- Faked Cubes Dedicated Server ----")
		print("Server Version: " + Global.version)
		print("Hosting on port " + str(Global.server_port))
		print("--------------------------------------")
		print(" ")
		Global.is_dedicated_server = true
		Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_HOST
		
		Global.change_scene_file.call_deferred("res://scenes/game.tscn")
		
	elif "--server" in OS.get_cmdline_args():
		Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_HOST
		
		Global.change_scene_file.call_deferred("res://scenes/game.tscn")
	
	elif "--connect" in OS.get_cmdline_args():
		Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_CLIENT
		
		Global.change_scene_file.call_deferred("res://scenes/game.tscn")
	
	else:
		print("Faked Cubes - " + Global.version)
		if not handle_arguments():
			Global.change_scene_file.call_deferred("res://scenes/menu_screen.tscn")

func handle_arguments() -> bool:
	var i = 0
	var args = OS.get_cmdline_args()
	var handled = false
	for arg in args:
		if arg == "--map-editor":
			handled = true
			Global.change_scene_file.call_deferred("res://scenes/map_editor.tscn")
		
		i += 1
	
	return handled
