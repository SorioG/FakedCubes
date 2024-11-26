extends Node

var lua: LuaAPI

var mods_dir: Dictionary = {}
var mods_info: Dictionary = {}
var mod_error: Dictionary = {}

var mod_assets: Dictionary = {}

var loaded_mod_dirs: Dictionary = {}
var loaded_mod_info: Dictionary = {}

var required_mods: Array[String] = []

const API_VERSION = "1.0"

const REQUIRED_KEYS = [
	"name",
	"id",
	"api-version",
	"required"
]

var mod_hooks := {}

# Make sure that Lua can only be setup when lua-scripted mods are loaded
var is_lua_loaded := false

func lua_fields():
	return ["load_mods","load_mod_info","init_mods","print_error"]

func load_mods():
	var dir = DirAccess.open(Global.mods_path)
	
	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()
		
		while filename != "":
			if dir.current_is_dir():
				
				mods_dir[filename] = Global.mods_path.path_join(filename)
			
			filename = dir.get_next()
		
		load_mod_info()
		init_mods()
		
		print_error()
	else:
		print("[ModLoader] Cannot load mods (directory does not exist)")

func setup_lua():
	lua = LuaAPI.new()
	lua.bind_libraries(["base", "table", "string", "math"])
	lua_push_vars()
	
	is_lua_loaded = true

func lua_push_vars():
	lua.push_variant("print", _lua_print)
	
	lua.push_variant("global", Global)
	lua.push_variant("music", MusicManager)
	
	lua.push_variant("fc", self)
	
	lua.push_variant("NET_SINGLEPLAYER", Global.GAME_TYPE.SINGLEPLAYER)
	lua.push_variant("NET_HOST", Global.GAME_TYPE.MULTIPLAYER_HOST)
	lua.push_variant("NET_CLIENT", Global.GAME_TYPE.MULTIPLAYER_CLIENT)

func load_mod_info():
	for dir in mods_dir:
		var path = mods_dir[dir].path_join("fcmod.json")
		
		if not FileAccess.file_exists(path): continue
		
		var file = FileAccess.open(path, FileAccess.READ)
		
		var info = file.get_as_text()
		
		file.close()
		
		var parsed = JSON.parse_string(info)
		
		mods_info[dir] = parsed

func init_mods():
	var count = 0
	var mod_size = mods_dir.keys().size()
	
	for dir in mods_dir:
		LoadingScreen.loadlabel.text = tr("Loading Mods {0}").format(["(" + str(count) + "/" + str(mod_size) + ")"])
		
		# Mods are required to have information, so the game can easily handle all of it.
		if not mods_info.has(dir): 
			mod_error[dir] = "'fcmod.json' file does not exist"
			continue
		
		if mods_info[dir] == null:
			mod_error[dir] = "Failed to parse json file"
			continue
		
		var info: Dictionary = mods_info[dir]
		
		var used_keys = []
		for k in info.keys():
			if REQUIRED_KEYS.has(k):
				used_keys.push_back(k)
		
		if used_keys.size() != REQUIRED_KEYS.size():
			mod_error[dir] = "'fcmod.json' does not have the required keys"
			continue
		
		if loaded_mod_info.has(info["id"]):
			mod_error[dir] = "A Another Mod with the same ID already exists"
			continue
		
		if info["api-version"] != API_VERSION:
			mod_error[dir] = "API Version Mismatch (version: " + info["api-version"] + ", recent: " + API_VERSION + ")"
			continue
		
		print("[ModLoader] Loaded mod " + info["name"])
		loaded_mod_dirs[info["id"]] = mods_dir[dir]
		
		info["dir"] = mods_dir[dir]
		
		loaded_mod_info[info["id"]] = info
		
		if info.has("icon") and not Global.is_dedicated_server:
			var img = Image.new()
			
			var err = img.load(info["dir"].path_join(info["icon"]))
			if err != OK:
				print("[ModLoader] Failed to load icon for mod: " + info["name"])
			else:
				info["icon"] = ImageTexture.create_from_image(img)
		
		if not info.has("description"):
			info["description"] = tr("No Description Provided")
		
		# Don't do anything below if this mod is disabled
		if not Global.disabled_mods.has(info["id"]):
			#if not Global.has_mods_enabled:
			#	DisplayServer.window_set_title("Faked Cubes (Modded)")
			
			Global.has_mods_enabled = true
			Global.client_info["modded"] = true
			
			# Only change the version if the mods used here require other players to have it.
			if info["required"]:
				if required_mods.size() < 1:
					Global.version += "-modded"
				
				required_mods.push_back(info["id"])
				
				Global.client_info["mods"].push_back(info["id"])
			
			# Mods can have assets, so lua scripts can use them.
			if DirAccess.dir_exists_absolute(mods_dir[dir].path_join("assets")):
				var assets = load_assets(mods_dir[dir].path_join("assets"), info["id"])
				mod_assets.merge(assets)
			
			# Mods can also have custom skins and maps, not just for the user.
			# This will make it possible for modders to make skin and/or map packs.
			if DirAccess.dir_exists_absolute(mods_dir[dir].path_join("skins")):
				Global.load_custom_skins(mods_dir[dir].path_join("skins"))
			
			if DirAccess.dir_exists_absolute(mods_dir[dir].path_join("maps")):
				Global.load_custom_maps(mods_dir[dir].path_join("maps"))
			
			# Let the mods add music or replace the existing ones
			if DirAccess.dir_exists_absolute(mods_dir[dir].path_join("music")):
				add_music(mods_dir[dir].path_join("music"))
			
			if info.has("main"):
				if not is_lua_loaded:
					setup_lua()
				
				var err = lua.do_file(mods_dir[dir].path_join(info["main"]))
				
				if err is LuaError:
					mod_error[dir] = "Lua Error: " + err.message
		
		count += 1
		
		await get_tree().process_frame

func add_music(path: String):
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		
		while file != "":
			if not dir.current_is_dir():
				var nam = file.split(".")[0]
				var type = file.split(".")[1]
				var file2 = FileAccess.open(path.path_join(file), FileAccess.READ)
				var bytes := file2.get_buffer(file2.get_length())
				
				var musi: AudioStream = null
				
				if type == "ogg":
					musi = AudioStreamOggVorbis.new()
					musi.loop = true
					musi.data = bytes
				elif type == "mp3":
					musi = AudioStreamMP3.new()
					musi.loop = true
					musi.data = bytes
				else:
					print("[ModLoader] Unsupported audio type for music file " + nam + "." + type)
				
				if musi is AudioStream:
					print("[ModLoader] Added music '" + nam + "'")
					MusicManager.replace_music(nam, musi)
				
			file = dir.get_next()

func load_assets(dir: String, nam: String) -> Dictionary:
	var dac = DirAccess.open(dir)
	var res := {}
	
	if dac:
		dac.list_dir_begin()
		var file = dac.get_next()
		
		while file != "":
			if not dac.current_is_dir():
				res[nam + "/" + file] = Image.load_from_file(dir.path_join(file))
			
			file = dac.get_next()
	else:
		print("[Lua] Cannot load assets from directory " + dir)
	
	return res

func print_error():
	var msgs = ""
	for mod in mod_error:
		var msg = mod_error[mod]
		var err = "[Lua] Cannot load mod " + mod + ": " + msg
		
		print(err)
		msgs += "[" + mod + "] " + msg + "\n"
	
	if not Global.is_dedicated_server and not msgs.is_empty():
		Global.alert(tr("Failed to load mods, check the console (or a log file) for more information"), tr("Error"))

func get_mod_path(n: String) -> String:
	if loaded_mod_dirs.has(n):
		return loaded_mod_dirs[n]
	
	return ""

func get_mod_asset(nam: String) -> Resource:
	if mod_assets.has(nam):
		return mod_assets[nam]
	
	return null

func add_hook(hook: String, f: String):
	# TODO: Allow adding a hook with a lua function instead of a string
	if not mod_hooks.has(hook):
		mod_hooks[hook] = []
	
	if lua.function_exists(f):
		if mod_hooks[hook].has(f):
			return LuaError.new_error("A Function with the hook '" + hook + "' was already added")
		else:
			mod_hooks[hook].push_back(f)
			
			print("[Lua] Added function '" + f + "' to hook '" + hook + "'")
	else:
		return LuaError.new_error("Tried to add a hook with a function that does not exist")

func call_hook(hook: String, args: Array):
	if not mod_hooks.has(hook): return null
	
	for f in mod_hooks[hook]:
		var res = lua.call_function(f, args)
		
		if res is LuaError:
			print("[Lua] Lua Error: " + res.message)
			print("[Lua] Disabling '" + f + "' on hook '" + hook + "' to prevent further errors")
			
			var game: Game = Global.get_game()
			
			if game:
				game.chat_window.add_message("Lua Error", res.message, load("res://assets/sprites/action_icons2.png"))
			
			mod_hooks[hook].erase(f)
			continue
		
		if res:
			return res
	
	return null

func add_custom_gamemode(nam: String, asset: String):
	var img = get_mod_asset(asset)
	if img is Texture2D:
		Global.game_modes.push_back({
			"name": nam,
			"icon": img,
			"base": load("res://assets/scripts/ModdedGamemode.gd")
		})
	else:
		Global.game_modes.push_back({
			"name": nam,
			"icon": load("res://assets/sprites/action_icons3.png"),
			"base": load("res://assets/scripts/ModdedGamemode.gd")
		})
	
	print("[Lua] Added Custom Gamemode: " + nam)

func _lua_print(msg: String):
	print("[Lua] " + msg)

func send_custom_rpc(data: Dictionary):
	var game = Global.get_game()
	
	if game:
		game.custom_rpc.rpc(data)
