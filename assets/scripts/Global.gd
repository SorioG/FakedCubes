extends Node

var version_state = "Alpha"
var version = version_state + " " + ProjectSettings.get_setting("application/config/version")



enum FACE_TYPE {
	BODY,
	EYES,
	MOUTH
}

enum MOOD_TYPE {
	NORMAL = 0,
	SCARED = 1,
	HAPPY = 2,
	BORED = 3,
	KILL = 4,
	DEAD = 5,
	EXCITED = 6,
	REPORT = 7
}

enum GAME_TYPE {
	SINGLEPLAYER = 1,
	MULTIPLAYER_HOST = 2,
	MULTIPLAYER_CLIENT = 3
}



var maps = {
	"lobby": load("res://scenes/maps/lobby.tscn"),
	"impostor1": load("res://scenes/maps/default_map.tscn"),
	"arena": load("res://scenes/maps/arena_map1.tscn")
}

const PLAYER_NODE = preload("res://scenes/player/player.tscn")
const GAME_NODE = preload("res://scenes/game.tscn")

const EMULATE_MOBILE = false

const BOT_SKIN = preload("res://assets/sprites/player-bot.png")

var net_mode: GAME_TYPE = GAME_TYPE.SINGLEPLAYER

var server_ip = "127.0.0.1"
var server_port = 7230

var is_dedicated_server = false

var is_mobile = false
var is_emulating_mobile = false

var device_id = OS.get_unique_id()

var freeze_animations: Array[String] = [
	"appear",
	"kill",
	"damage",
	"happy",
	"happy2"
]

var stop_animations: Array[String] = [
	"appearing"
]

var idle_animations: Array[String] = [
	"idle",
	"idle2"
]

var game_modes: Array[Dictionary] = [
	{
		"name": "Classic",
		"icon": load("res://assets/sprites/action_icons2.png"),
		"base": ImpostorGamemode
	},
	{
		"name": "Deathmatch",
		"icon": load("res://assets/sprites/action_icons7.png"),
		"base": ArenaGamemode
	},
	{
		"name": "Detective & Sherrif",
		"icon": load("res://assets/sprites/action_icons9.png"),
		"base": ImpostorGamemode
	}
]

var player_skins: Dictionary = {
	"Default": {
		"skin": load("res://assets/sprites/player-default.png"),
		"icon": load("res://assets/sprites/skinicons/default.png")
	},
	"Robot": {
		"skin": BOT_SKIN,
		"icon": load("res://assets/sprites/skinicons/bot.png")
	},
	"Killer": {
		"skin": load("res://assets/sprites/player-killer.png"),
		"icon": load("res://assets/sprites/skinicons/killer.png")
	},
	"Squashed": {
		"skin": load("res://assets/sprites/player-squashed.png"),
		"icon": load("res://assets/sprites/skinicons/squashed.png")
	},
	"Reddy": {
		"skin": load("res://assets/sprites/player-blockscape.png"),
		"icon": load("res://assets/sprites/skinicons/blockscape.png")
	},
	"Cubette": {
		"skin": load("res://assets/sprites/player-female.png"),
		"icon": load("res://assets/sprites/skinicons/female.png")
	},
	"Deal With It": {
		"skin": load("res://assets/sprites/player-glasses.png"),
		"icon": load("res://assets/sprites/skinicons/glasses.png")
	},
	"Square Glasses": {
		"skin": load("res://assets/sprites/player-glasses2.png"),
		"icon": load("res://assets/sprites/skinicons/glasses2.png")
	},
	"Mini": {
		"skin": load("res://assets/sprites/player-mini.png"),
		"icon": load("res://assets/sprites/skinicons/mini.png")
	}
}

var custom_skins: Dictionary = {}
var custom_maps: Dictionary = {}

enum PLAYER_ROLE {
	NONE = -1,
	INNOCENT = 0,
	IMPOSTOR = 1,
	CUSTOM1 = 2,
	CUSTOM2 = 3,
	CUSTOM3 = 4,
}

enum PLATFORM_TYPE {
	PC_STEAM,
	PC,
	MOBILE
}

var client_info: Dictionary = {
	"username": "Player",
	"version": version
}

var is_lua_enabled = false # This is used to check if we can use Lua API for our mods (in case if mobile does not work with mods)

var hide_menu = false

var server_config: ConfigFile

var maps_path: String = "user://maps"

func _ready():
	is_emulating_mobile = ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false) 
	is_mobile = is_emulating_mobile or OS.has_feature("mobile")
	is_dedicated_server = OS.has_feature("dedicated_server")
	
	if is_dedicated_server:
		maps_path = OS.get_executable_path().get_base_dir().path_join("maps")
	
	#if ClassDB.class_exists("LuaAPI") and ClassDB.is_class_enabled("LuaAPI"):
	if not OS.has_feature("DisableLua"):
		print("Lua API enabled.")
		is_lua_enabled = true
	
	DirAccess.make_dir_absolute(maps_path)
	DirAccess.make_dir_absolute("user://skins")
	
	load_custom_maps()
	
	if not OS.has_feature("dedicated_server"):
		load_custom_skins()

func load_custom_skins():
	var dir = DirAccess.open("user://skins")
	
	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()
		while filename != "":
			if not dir.current_is_dir():
				if filename.ends_with(".png"):
					var is_icon = filename.ends_with("_icon.png")
					var skinname = filename.split(".")[0]
					if is_icon:
						skinname = skinname.split("_")[0]
					if not custom_skins.has(skinname):
						custom_skins[skinname] = {}
						
						# Load the default skin icon, in case the icon does not exist
						custom_skins[skinname]["icon"] = load("res://assets/sprites/skin-defaulticon.png")
					
					var image = Image.load_from_file("user://skins/" + filename)
					
					var tex = ImageTexture.create_from_image(image)
					
					if is_icon:
						custom_skins[skinname]["icon"] = tex
					else:
						custom_skins[skinname]["skin"] = tex
					
						print("Loaded custom skin: " + skinname)
			
			filename = dir.get_next()
	else:
		print("Failed to load custom skins")

func load_custom_maps():
	var dir = DirAccess.open(maps_path)
	
	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()
		
		while filename != "":
			if filename.ends_with(".tscn"):
				var mapname = filename.split(".")[0]
				custom_maps[mapname] = maps_path.path_join(filename)
				
				print("Loaded custom map: " + mapname)
			
			filename = dir.get_next()
	else:
		print("Failed to load custom maps")

func change_scene(scene: PackedScene):
	var err = get_tree().change_scene_to_packed(scene)
	
	if err != OK:
		print("Failed to change scene!")
	

func change_scene_file(scene: String):
	var err = get_tree().change_scene_to_file(scene)
	
	if err != OK:
		print("Failed to change scene!")
	

func get_game() -> Game:
	if has_node("../SplitScreen"):
		return get_node_or_null("../SplitScreen/BG/players/PlayerScreen1/SubViewport/game")
	else:
		return get_node_or_null("../game")

func rand_chance(chanc: float) -> bool:
	return (randf() > chanc)

func alert(msg: String):
	print(msg)
	
	if not Global.is_dedicated_server:
		var window = AcceptDialog.new()
		
		window.dialog_text = msg
		
		window.connect("confirmed", window.queue_free)
		window.dialog_hide_on_ok = false
		
		add_child(window)
		
		window.popup_centered.call_deferred()


func load_server_config():
	var config := ConfigFile.new()
	
	var err = config.load(OS.get_executable_path().get_base_dir().path_join("server.cfg"))
	
	if err != OK:
		config.set_value("Game", "gamemode", 0)
		config.set_value("Game", "max_bots", 0)
		config.set_value("Game", "lobby_map", "default")
		config.set_value("Game", "use_custom_maps", [])
		
		config.set_value("Server", "port", Global.server_port)
		config.set_value("Server", "allow_early_join", false)
		config.set_value("Server", "allow_custom_skins", true)
		config.set_value("Server", "voice_chat", true)
		
		config.save(OS.get_executable_path().get_base_dir().path_join("server.cfg"))
	
	server_config = config
