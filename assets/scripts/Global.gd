extends Node

var version = ProjectSettings.get_setting("application/config/version")

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

## Used to check whatever or not it's a dedicated server.
var is_dedicated_server = false

## Used to check if we are on a mobile device (Android or iOS)
var is_mobile = false
## This is used to trick the game into thinking this is a mobile device. (Useful for development)
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
	"idle2",
	"idle3"
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

var player_skins: Dictionary = GameData.player_skins

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

## The information that's used to send to the server when joining.
var client_info: Dictionary = {
	"username": "Player",
	"version": version,
	"skin": "Default",
	"hat": "None",
	"modded": false,
	"mods": [],
	"platform": "unknown",
	"uuid": ""
}

## This is used to check if we can use Lua API for our mods
var is_lua_enabled = false

var hide_menu = false

var server_config: ConfigFile

var user_config: ConfigFile = ConfigFile.new()

var maps_path: String = "user://maps"
var mods_path: String = "user://mods"

## Whatever or not this allows the game to save user's data
var can_save_config = false

## Disabled Mods in Mod Menu will show up here
var disabled_mods := []

## Used to check whatever or not we have mods enabled
var has_mods_enabled := false

# epic fail
const DISCORD_LINK = "https://discord.gg/BFgQM5Wn2n"

const uuid = preload("res://assets/scripts/uuid.gd")

func lua_fields():
	return [
		"load_user_config",
		"load_custom_skins",
		"load_custom_maps",
		"load_server_config"
	]

func _ready():
	is_emulating_mobile = ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false) 
	is_mobile = is_emulating_mobile or OS.has_feature("mobile")
	is_dedicated_server = OS.has_feature("dedicated_server") or ("--dediserver" in OS.get_cmdline_args() and OS.is_debug_build())
	
	client_info["platform"] = OS.get_name()
	
	if is_dedicated_server:
		maps_path = OS.get_executable_path().get_base_dir().path_join("maps")
		mods_path = OS.get_executable_path().get_base_dir().path_join("mods")
	
	#if ClassDB.class_exists("LuaAPI") and ClassDB.is_class_enabled("LuaAPI"):
	if not OS.has_feature("DisableLua"):
		#print("Lua API enabled.")
		is_lua_enabled = true
	
	DirAccess.make_dir_absolute(maps_path)
	DirAccess.make_dir_absolute("user://skins")
	DirAccess.make_dir_absolute(mods_path)
	
	

func load_user_config():
	var config = user_config
	
	var err = config.load("user://client.cfg")
	
	if err != OK:
		client_info["uuid"] = uuid.v4()
		return
	
	
	client_info["username"] = config.get_value("Player", "username", "Player")
	client_info["skin"] = config.get_value("Player", "skin", "Default")
	client_info["hat"] = config.get_value("Player", "hat", "None")
	client_info["uuid"] = config.get_value("Player", "uuid", uuid.v4())
	
	disabled_mods = config.get_value("Mods", "disabled_mods", [])

func save_user_config():
	user_config.set_value("Player", "username", client_info["username"])
	user_config.set_value("Player", "skin", client_info["skin"])
	user_config.set_value("Player", "hat", client_info["hat"])
	user_config.set_value("Player", "uuid", client_info["uuid"])
	
	user_config.set_value("Mods", "disabled_mods", disabled_mods)
	
	user_config.save("user://client.cfg")

func _exit_tree():
	print("===== Thank you for playing our game! =====")
	
	# Dedicated Servers cannot save user data (they're not the player themselves)
	if not is_dedicated_server and can_save_config:
		print("Saving User Data...")
		save_user_config()



func load_custom_skins(path: String):
	var dir = DirAccess.open(path)
	
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
	#else:
	#	print("Failed to load custom skins")

func load_custom_maps(path: String):
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()
		
		while filename != "":
			if filename.ends_with(".tscn"):
				var mapname = filename.split(".")[0]
				custom_maps[mapname] = maps_path.path_join(filename)
				
				print("Loaded custom map: " + mapname)
			
			filename = dir.get_next()
	#else:
	#	print("Failed to load custom maps")

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

func alert(msg: String, title: String = "Alert"):
	print(msg)
	
	if not Global.is_dedicated_server:
		var window = AcceptDialog.new()
		
		window.dialog_text = msg
		window.title = title
		
		window.connect("confirmed", window.queue_free)
		window.dialog_hide_on_ok = false
		
		add_child(window)
		
		window.popup_centered.call_deferred()


func load_server_config():
	var config := ConfigFile.new()
	
	var path = OS.get_executable_path().get_base_dir().path_join("server.cfg")
	
	var err = config.load(path)
	
	if err != OK:
		config.set_value("Game", "gamemode", 0)
		config.set_value("Game", "max_bots", 0)
		config.set_value("Game", "lobby_map", "default")
		config.set_value("Game", "use_custom_maps", [])
		
		config.set_value("Server", "port", Global.server_port)
		config.set_value("Server", "name", "Dedicated Server")
		config.set_value("Server", "allow_early_join", false)
		config.set_value("Server", "allow_custom_skins", true)
		config.set_value("Server", "allow_modded_clients", true)
		config.set_value("Server", "voice_chat", true)
		
		config.save(path)
	
	server_config = config
	
	server_port = config.get_value("Server", "port", server_port)

func _process(_delta):
	client_info["version"] = version
