extends Node2D

#@onready var menu_player: Player = $menu_player
@onready var camera: Camera2D = $screen2/camera
#@onready var game: Game = $screen2/game
@onready var menu = $UI/menu
@onready var serverbrowser = $UI/ServerBrowser
@onready var modlist = $UI/ModList

var map: Node2D

var following_player: Player

var waiting_input: bool = true

var is_changing = false

var spectate_timer: Timer = Timer.new()

var easter_egg = false

@onready var spbtn = $UI/menu/mbtns/singleplayer
@onready var hostbtn = $UI/menu/mbtns/hostgame
@onready var joinbtn = $UI/menu/mbtns/joingame
@onready var modsbtn = $UI/menu/mbtns/mods

func _ready():
	LoadingScreen.hide_screen()
	$UI/VersionLabel.text = Global.version
	
	#if Global.is_mobile:
	#	spbtn = $UI/menu/mobilebtns/spbtn
	#	hostbtn = $UI/menu/mobilebtns/hostgame
	#	joinbtn = $UI/menu/mobilebtns/joingame
	
	spbtn.connect("pressed", _singleplayer_pressed)
	hostbtn.connect("pressed", _host_pressed)
	joinbtn.connect("pressed", _join_pressed)
	modsbtn.connect("pressed", _mods_pressed)
	
	$UI/menu/mbtns/quitbtn.connect("pressed", get_tree().quit)
	
	if Global.is_mobile:
		$UI/menu/mbtns/quitbtn.visible = false
	
	$UI/ToolsMenu.connect("id_pressed", handle_tool_menu)
	
	
	$UI/descardbutton.connect("pressed", OS.shell_open.bind(Global.DISCORD_LINK))
	
	
	#$skin_timer.connect("timeout", _player_timer)
	
	#menu_player.set_skin(Global.player_skins.values().pick_random())
	
	# Hide Mods Menu if Lua API is unavailable
	if not Global.is_lua_enabled:
		$UI/menu/mbtns/mods.visible = false
	
	
	
	#$screen2/game/hud.visible = false
	
	#game.current_gamemode = Global.game_modes.pick_random()
	
	spectate_timer.one_shot = false
	spectate_timer.wait_time = 20
	
	spectate_timer.autostart = true
	$screen2.add_child(spectate_timer)
	spectate_timer.connect("timeout", _spectate_player)
	
	easter_egg = false
	
	#game.bot_change_skin = false
	
	#game.connect("player_spawned", _bot_spawned)
	#game.connect("game_ended", _game_ended)
	
	animate_menu(false, .1)
	
	menu.visible = false
	$UI/ColorRect.visible = false
	
	#$screen1/Control/menu_player/ui.visible = false
	
	#if Global.is_mobile:
	#	$UI/menu/mbtns.visible = false
	#	
	#	$UI/menu/mobilebtns.visible = true
	#	
	#	$UI/StartLabel.text = tr("Touch Screen")
	#else:
	#	$UI/menu/mobilebtns.visible = false
	
	if not Global.hide_menu:
		MusicManager.play_music("title")
	else:
		$UI.hide()
		
		#game.handle_arguments()
	
	#$screen1/Control/other_player.set_face(Global.FACE_TYPE.EYES, 4)
	#$screen1/Control/other_player.set_face(Global.FACE_TYPE.BODY, 4)
	#$screen1/Control/other_player.set_face(Global.FACE_TYPE.MOUTH, 6)
	
	$screen1/Control/menu_player.set_face(Global.FACE_TYPE.EYES, randi_range(0,8))
	$screen1/Control/menu_player.set_face(Global.FACE_TYPE.MOUTH, randi_range(0,8))
	
	var sk = Global.player_skins[Global.client_info["skin"]]["skin"]
	var hattex = GameData.player_hats[Global.client_info["hat"]]
	$screen1/Control/menu_player.set_skin(sk)
	$screen1/Control/other_player.set_skin(sk)
	
	$screen1/Control/menu_player.set_hat(hattex)
	$screen1/Control/other_player.set_hat(hattex)
	
	$screen1/Control/menu_player.player_name = Global.client_info["username"]
	
	_spectate_player()

func _input(event):
	if Global.hide_menu: return
	if event.is_pressed() and waiting_input:
		waiting_input = false
		animate_menu()
		$UI/StartLabel.visible = false
		
		
		menu.visible = true
		
		#if not Global.is_mobile:
		$UI/ColorRect.visible = true
		$UI/StartLogo.visible = false
		#else:
		#	$UI/menu/Logo.visible = false
		
		#$screen2/camera.enabled = false
		#$screen1.process_mode = Node.PROCESS_MODE_INHERIT
		$screen1.visible = true
		#$screen1/Camera2D.enabled = true
		#$screen1/Camera2D.make_current()
		
		#$select.play()
		
		$UI/menu/mbtns/singleplayer.grab_focus()

func _spectate_player():
	choose_rand_map()
	
	camera.position = map.get_node("spawns").get_children().pick_random().position
#	var bots: Array[Player] = game.get_alive_players()
#	
#	var bot = bots.pick_random()
#	
#	following_player = bot
#	camera.position = bot.position
#	
#	if game.game_state == game.STATE.LOBBY:
#		game.current_gamemode = Global.game_modes.pick_random()
#		
#		game.autoplay = true

func choose_rand_map():
	if is_instance_valid(map):
		map.free()
	
	map = Global.maps.values().pick_random().instantiate()
	
	map.get_node("spawns").visible = false
	
	$screen2.add_child(map)


func _process(_delta):
	
	if Input.is_action_just_pressed("devtools"):
		$UI/ToolsMenu.popup_centered()
	
	if not waiting_input:
		if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
			$select2.play()
	
	#if following_player and not following_player.is_killed:
	#	camera.position = following_player.position
		#camera.position -= Vector2(200, 0)
	#else:
	camera.position += Vector2(.1, .1)

func _bot_spawned(plr: Player):
	plr.player_name = ""
	
	if easter_egg:
		var skin = Global.player_skins.values().pick_random()
		plr.set_skin(skin["skin"])

func _game_ended():
	if Global.hide_menu:
		get_tree().quit()
	#game.num_bots += randi_range(1, 4)

func _singleplayer_pressed():
	print("playing singleplayer")
	
	Global.net_mode = Global.GAME_TYPE.SINGLEPLAYER
	
	Global.change_scene_file("res://scenes/game.tscn")

func _host_pressed():
	Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_HOST
	
	Global.change_scene_file("res://scenes/game.tscn")

func _join_pressed():
	#Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_CLIENT
	
	#Global.change_scene_file("res://scenes/game.tscn")
	serverbrowser.visible = not serverbrowser.visible
	
	if serverbrowser.visible:
		spbtn.visible = false
		hostbtn.visible = false
		if Global.is_lua_enabled:
			modsbtn.visible = false
		joinbtn.text = tr("Back")
		
		#if Global.is_mobile:
		#	$UI/menu/mobilebtns.alignment = $UI/menu/mobilebtns.ALIGNMENT_BEGIN
		#	$UI/StartLogo.visible = false
	else:
		spbtn.visible = true
		hostbtn.visible = true
		if Global.is_lua_enabled:
			modsbtn.visible = true
		joinbtn.text = tr("Join Game")
		
		#if Global.is_mobile:
		#	$UI/menu/mobilebtns.alignment = $UI/menu/mobilebtns.ALIGNMENT_CENTER
		#	$UI/StartLogo.visible = true

func _mods_pressed():
	modlist.visible = not modlist.visible
	
	if modlist.visible:
		spbtn.visible = false
		hostbtn.visible = false
		joinbtn.visible = false
		modsbtn.text = tr("Back")
	else:
		spbtn.visible = true
		hostbtn.visible = true
		joinbtn.visible = true
		modsbtn.text = tr("Mods")
		
		if modlist.has_changed_mods:
			modlist.has_changed_mods = false
			Global.alert(tr("You must restart the game for changes to take effect"))

func handle_tool_menu(id: int):
	if id == 0:
		Global.change_scene_file("res://scenes/skin_previewer.tscn")
	if id == 1:
		Global.change_scene_file("res://scenes/map_editor.tscn")

func animate_menu(cshow=true, delay=.3):
	var tween = create_tween()
	#var sx = 0
	var cl: Color = Color.WHITE
	if not cshow:
		#sx = -400
		cl = Color.TRANSPARENT
	
	#tween.tween_property(menu, "position", Vector2(sx, 304), delay)
	tween.tween_property($UI/ColorRect, "modulate", cl, delay)
	
