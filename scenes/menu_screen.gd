extends Node2D

#@onready var menu_player: Player = $menu_player
@onready var camera: Camera2D = $screen2/camera
@onready var game: Game = $screen2/game
@onready var menu = $UI/menu
@onready var serverbrowser = $UI/ServerBrowser

var following_player: Player

var waiting_input: bool = true

var is_changing = false

var spectate_timer: Timer = Timer.new()

var easter_egg = false

func _ready():
	LoadingScreen.hide_screen()
	$UI/VersionLabel.text = Global.version
	
	$UI/menu/mbtns/singleplayer.connect("pressed", _singleplayer_pressed)
	$UI/menu/mbtns/hostgame.connect("pressed", _host_pressed)
	$UI/menu/mbtns/joingame.connect("pressed", _join_pressed)
	
	$UI/menu/mbtns/quitbtn.connect("pressed", get_tree().quit)
	
	if Global.is_mobile:
		$UI/menu/mbtns/quitbtn.visible = false
	
	$UI/ToolsMenu.connect("id_pressed", handle_tool_menu)
	
	
	
	
	#$skin_timer.connect("timeout", _player_timer)
	
	#menu_player.set_skin(Global.player_skins.values().pick_random())
	
	# Hide Mods Menu if Lua API is unavailable
	if not Global.is_lua_enabled:
		$UI/menu/mbtns/mods.visible = false
	
	
	
	$screen2/game/hud.visible = false
	
	game.current_gamemode = Global.game_modes.pick_random()
	
	spectate_timer.one_shot = false
	spectate_timer.wait_time = 5
	
	spectate_timer.autostart = true
	$screen2.add_child(spectate_timer)
	spectate_timer.connect("timeout", _spectate_player)
	
	easter_egg = false
	
	game.bot_change_skin = false
	
	game.connect("player_spawned", _bot_spawned)
	game.connect("game_ended", _game_ended)
	
	animate_menu(false, .1)
	
	menu.visible = false
	$UI/ColorRect.visible = false
	
	$screen1/menu_player/ui.visible = false
	
	$music.play()

func _input(event):
	if event.is_pressed() and waiting_input:
		waiting_input = false
		animate_menu()
		$UI/StartLabel.visible = false
		$UI/StartLogo.visible = false
		
		menu.visible = true
		$UI/ColorRect.visible = true
		
		#$screen2/camera.enabled = false
		#$screen1.process_mode = Node.PROCESS_MODE_INHERIT
		#$screen1.visible = true
		#$screen1/Camera2D.enabled = true
		#$screen1/Camera2D.make_current()
		
		$select.play()
		
		$UI/menu/mbtns/singleplayer.grab_focus()

func _spectate_player():
	var bots: Array[Player] = game.get_alive_players()
	
	var bot = bots.pick_random()
	
	following_player = bot
	camera.position = bot.position
	
	if game.game_state == game.STATE.LOBBY:
		game.current_gamemode = Global.game_modes.pick_random()
		
		game.autoplay = true


func _process(_delta):
	
	if Input.is_action_just_pressed("devtools"):
		$UI/ToolsMenu.popup_centered()
	
	if not waiting_input:
		if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
			$select2.play()
	
	if following_player and not following_player.is_killed:
		camera.position = following_player.position
		#camera.position -= Vector2(200, 0)
	else:
		camera.position += Vector2(.2, .2)

func _bot_spawned(plr: Player):
	plr.player_name = ""
	
	if easter_egg:
		var skin = Global.player_skins.values().pick_random()
		plr.set_skin(skin["skin"])

func _game_ended():
	game.num_bots += randi_range(1, 4)

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
		$UI/menu/mbtns/singleplayer.visible = false
		$UI/menu/mbtns/hostgame.visible = false
		$UI/menu/mbtns/mods.visible = false
		$UI/menu/mbtns/joingame.text = "Back"
	else:
		$UI/menu/mbtns/singleplayer.visible = true
		$UI/menu/mbtns/hostgame.visible = true
		$UI/menu/mbtns/mods.visible = true
		$UI/menu/mbtns/joingame.text = "Join Game"

func handle_tool_menu(id: int):
	if id == 0:
		Global.change_scene_file("res://scenes/skin_previewer.tscn")
	if id == 1:
		Global.change_scene_file("res://scenes/map_editor.tscn")

func animate_menu(cshow=true, delay=.5):
	var tween = create_tween()
	var sx = 0
	var cl: Color = Color.WHITE
	if not cshow:
		sx = -400
		cl = Color.TRANSPARENT
	
	tween.tween_property(menu, "position", Vector2(sx, 304), delay)
	tween.tween_property($UI/ColorRect, "modulate", cl, delay)
	
