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

enum NET_TYPE {
	DIRECT = 0,
	WEBRTC
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
var net_type: NET_TYPE = NET_TYPE.DIRECT

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
	"appearing",
	"reported",
	"scared"
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
	"username": "Player", # Client Username
	"version": version, # Version of the game used
	"skin": "Default", # Skin used by the client, custom skins start with "custom:"
	"hat": "None", # Hat used by the client
	"modded": false, # Whatever or not the client is modded
	"mods": [], # List of mods loaded by the client (does not show client-side mods)
	"platform": "unknown", # Platform used by the client (Linux, Windows, Android, etc.)
	"uuid": "", # Client UUID for identity purposes (server bans and more)
	"discord_id": 0 # Discord User ID automatically set by Rich Presence
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

var is_april_fools := false

var cubenet_server_url := ""
var cubenet_headers = ["User-Agent: FakedCubes/" + version]

var cubenet_is_public := false

var is_exiting := false

# epic fail
const DISCORD_LINK = "https://discord.gg/BFgQM5Wn2n"

const uuid = preload("res://assets/scripts/uuid.gd")

var uuid_regex = RegEx.create_from_string("^[0-9a-fA-F]{8}\\b-[0-9a-fA-F]{4}\\b-[0-9a-fA-F]{4}\\b-[0-9a-fA-F]{4}\\b-[0-9a-fA-F]{12}$")

const MAX_PLAYERS := 16

const CUBENET_SERVER_DEV := "http://localhost:7400"

const WEBRTC_ICE_SERVERS := [
	{
		"urls": [
			"stun:stun.l.google.com:19302",
			"stun:stunserver.stunprotocol.org:3478"
		]
	}
]

var server_thread: Thread = Thread.new()

signal discord_join_request(user)

func lua_fields():
	return [
		"load_user_config",
		"load_custom_skins",
		"load_custom_maps",
		"load_server_config"
	]

func _ready():
	is_emulating_mobile = ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false) 
	is_mobile = is_emulating_mobile or DisplayServer.is_touchscreen_available()
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
	
	is_april_fools = ("--force-april-fools" in OS.get_cmdline_args()) and OS.is_debug_build()
	
	var date = Time.get_datetime_dict_from_system()
	
	# Right time to fool players.
	if date.month == Time.MONTH_APRIL and date.day == 1:
		is_april_fools = true
	
	if not uuid_regex.is_valid():
		if OS.is_debug_build():
			print("[Debug] UUID Regex is invalid, the game won't check for invalid UUIDs")

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
	
	# Empty UUID for the player is worse ngl
	if client_info["uuid"].is_empty() or not is_uuid_valid(client_info["uuid"]):
		print("[WARN] Player UUID is empty or invalid, regenerating one..")
		client_info["uuid"] = uuid.v4()
	
	disabled_mods = config.get_value("Mods", "disabled_mods", [])
	
	var cubenet_server_default = ""
	if OS.is_debug_build():
		cubenet_server_default = CUBENET_SERVER_DEV
	
	cubenet_server_url = config.get_value("CubeNet", "server_url", cubenet_server_default)

func save_user_config():
	user_config.set_value("Player", "username", client_info["username"])
	user_config.set_value("Player", "skin", client_info["skin"])
	user_config.set_value("Player", "hat", client_info["hat"])
	user_config.set_value("Player", "uuid", client_info["uuid"])
	
	user_config.set_value("Mods", "disabled_mods", disabled_mods)
	
	user_config.set_value("CubeNet", "server_url", cubenet_server_url)
	
	user_config.save("user://client.cfg")

func _exit_tree():
	is_exiting = true
	
	if is_april_fools:
		print("===== You thank for game playing our! =====")
	else:
		print("===== Thank you for playing our game! =====")
	
	# Dedicated Servers cannot save user data (they're not the player themselves)
	if not is_dedicated_server and can_save_config:
		print("Saving User Data...")
		save_user_config()
	
	if server_thread.is_alive():
		server_thread.wait_to_finish()



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
						
						print("Loaded icon for custom skin: " + skinname)
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
		# Game Configuration
		config.set_value("Game", "gamemode", 0)
		config.set_value("Game", "max_bots", 0)
		config.set_value("Game", "lobby_map", "default")
		config.set_value("Game", "use_custom_maps", [])
		
		# Server Configuration
		config.set_value("Server", "port", Global.server_port)
		config.set_value("Server", "name", "Dedicated Server")
		config.set_value("Server", "allow_early_join", false)
		config.set_value("Server", "allow_custom_skins", true)
		config.set_value("Server", "allow_modded_clients", true)
		config.set_value("Server", "voice_chat", true)
		
		# Discord-related Configuration
		config.set_value("Discord", "allow_invites", true)
		config.set_value("Discord", "show_server_name", true)
		
		config.save(path)
	
	server_config = config
	
	server_port = config.get_value("Server", "port", server_port)

func _process(_delta):
	client_info["version"] = version
	
	is_mobile = DisplayServer.is_touchscreen_available()

func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_F11 and event.is_pressed():
			# Toggle Fullscreen when pressing F11
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func is_uuid_valid(uid: String) -> bool:
	if not uuid_regex.is_valid(): return true
	
	# Try to search for the valid UUID
	var res = uuid_regex.search(uid)
	
	if res is RegExMatch:
		return true
	
	return false

func start_server_thread():
	if not Global.is_dedicated_server: return
	
	if not ("--no-input" in OS.get_cmdline_args()):
		print("Type 'help' for the list of commands")
		server_thread.start(_server_console_thread)

func _server_console_thread():
	var text = ""
	while text != "quit":
		text = OS.read_string_from_stdin().strip_edges()
		_handle_console_command.call_deferred(text, _on_server_cmd)
	
	get_tree().quit()

func _handle_console_command(cmd: String, callback: Callable):
	var args = cmd.split(" ")
	var game: Game = get_game()
	
	if game:
		game._handle_command(args, callback)
	else:
		callback.call("You cannot use the commands while the server is starting")

func _on_server_cmd(res: String):
	print(res)


func get_skin_still_image(skin: Texture2D) -> Image:
	# This might be almost complex, but this will get a image with character parts included.
	var body_img = skin.get_image()
	
	var img = Image.create(64, 64, false, body_img.get_format())
	
	#var rect = Rect2i(0, 0, 64, 64)
	var dest = Vector2i(0, 0)
	
	img.blit_rect(body_img, Rect2i(0, 0, 64, 64), dest)
	img.blend_rect(body_img, Rect2i(0, 64, 64, 64), dest)
	img.blend_rect(body_img, Rect2i(0, 128, 64, 64), dest)
	
	return img

func get_skin_by_name(nam: String) -> Texture2D:
	if nam.begins_with("custom:"):
		# Trying to load a custom skin
		nam = nam.split(":")[1]
		if custom_skins.has(nam):
			return custom_skins[nam]["skin"]
		else:
			push_error("Cannot find custom skin with name ", nam)
			return player_skins["Default"]["skin"]
	else:
		# Bulit-in Skin
		if player_skins.has(nam):
			return player_skins[nam]["skin"]
		else:
			push_error("Cannot find skin with name ", nam)
			return player_skins["Default"]["skin"]

func cubenet_get_websocket() -> String:
	var url = Global.cubenet_server_url
	url = url.replace("http", "ws")
	url = url.replace("https", "wss")
	
	return url
