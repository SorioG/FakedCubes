extends Control


@onready var gameinfo = $gameinfo
var game: Game
@export var player: Player

@onready var bots_slider = $gameinfo/tabs/Game/btns/bots/HSlider
@onready var actions = $actions
@onready var gm_options: OptionButton = $gameinfo/tabs/Game/btns/gamemode/option
@onready var skin_viewport := $gameinfo/tabs/Player/HBoxContainer/skinview/viewport

func _ready():
	
	game = Global.get_game()
	
	setup_skins()
	setup_gamemodes()
	
	if game is Game:
		game.game_ended.connect(_reset_actions)
	
	bots_slider.connect("value_changed", _change_bots)
	gm_options.connect("item_selected", _change_gamemode)
	
	# Only the host can change the game information
	if Global.net_mode == Global.GAME_TYPE.MULTIPLAYER_CLIENT:
		bots_slider.editable = false
		gm_options.disabled = true
	
	gameinfo.connect("about_to_popup", _opened_window)
	
	if Global.is_mobile:
		actions.custom_minimum_size = Vector2(0, 200)
		actions.position.x -= 100
	
	actions.get_node("btn1").connect("pressed", _pressed_button.bind(1))
	actions.get_node("btn2").connect("pressed", _pressed_button.bind(2))
	actions.get_node("btn3").connect("pressed", _pressed_button.bind(3))
	actions.get_node("btn4").connect("pressed", _pressed_button.bind(4))
	
	$gameinfo/tabs/Player/skinlist/VBoxContainer/skincustom/openskins.connect("pressed", _skin_directory_open)

func setup_skins():
	var skins = Global.player_skins
	var custom_skins = Global.custom_skins
	# Built-in Skins
	for s in skins:
		var skin = skins[s]
		
		var btn = TextureButton.new()
		
		var skinlist = $gameinfo/tabs/Player/skinlist/VBoxContainer/skinbuiltin/skins
		
		btn.name = s
		#btn.text = s
		btn.tooltip_text = s
		btn.texture_normal = skin["icon"]
		
		
		btn.connect("pressed", _on_skin_press.bind(s))
		btn.connect("focus_entered", _on_skin_focus.bind(btn))
		btn.connect("focus_exited", _on_skin_defocus.bind(btn))
		
		skinlist.add_child(btn)
	
	var skincustom = $gameinfo/tabs/Player/skinlist/VBoxContainer/skincustom
	
	if Global.custom_skins.size() > 0:
		for s in custom_skins:
			var skin = custom_skins[s]
			
			var btn = TextureButton.new()
			
			var skinlist = $gameinfo/tabs/Player/skinlist/VBoxContainer/skincustom/skins
			
			btn.name = s
			#btn.text = s
			btn.tooltip_text = s
			btn.texture_normal = skin["icon"]
			
			
			btn.connect("pressed", _on_custom_skin.bind(s))
			btn.connect("focus_entered", _on_skin_focus.bind(btn))
			btn.connect("focus_exited", _on_skin_defocus.bind(btn))
			
			skinlist.add_child(btn)
	else:
		skincustom.get_node("Label").text += "\nYou don't have any custom skins."

func setup_gamemodes():
	var gamemodes = Global.game_modes
	
	gm_options.clear()
	
	for gm in gamemodes:
		gm_options.add_icon_item(gm["icon"], gm["name"])
	
	#gm_options.add_separator("Custom")

func _change_gamemode(index: int):
	game.current_gamemode = Global.game_modes[index]
	game.gamemode_idx = index
	
	game.net_change_gamemode.rpc(index)

func _on_skin_press(nam: String):
	game.local_player.net_set_skin.rpc(nam)
	
	$select2.play()

func _on_custom_skin(nam: String):
	if not Global.custom_skins.has(nam): return
	
	var skin: Texture2D = Global.custom_skins[nam]["skin"]
	
	var img = skin.get_image()
	
	var buff = img.save_png_to_buffer()
	
	player.net_load_custom_skin.rpc(Marshalls.raw_to_base64(buff))
	
	$select2.play()


func _on_skin_focus(btn: TextureButton):
	btn.self_modulate = Color.LIGHT_YELLOW

func _on_skin_defocus(btn: TextureButton):
	btn.self_modulate = Color.WHITE

func _change_bots(changed):
	if game:
		game.num_bots = changed

func _process(_delta):
	var is_starting: bool
	if game:
		is_starting = (game.game_state == game.STATE.INGAME)
	else:
		is_starting = false
	
	
	if not is_starting:
		actions.get_node("btn1").visible = true
		
		actions.get_node("btn2").visible = false
		actions.get_node("btn3").visible = false
		actions.get_node("btn4").visible = false
	else:
		#if gamemode["base"] ==  "impostor":
		#	actions.get_node("btn2").visible = (player.current_role == Global.PLAYER_ROLE.IMPOSTOR)
		game.gamemode_node.update_actions(actions.get_node("btn1"),actions.get_node("btn2"),actions.get_node("btn3"),actions.get_node("btn4"))

func _opened_window():
	pass

func _pressed_button(action: int):
	#print("Pressed Button " + str(action))
	player._do_action(action)

func _reset_actions():
	actions.get_node("btn1").texture_normal = load("res://assets/sprites/action_icons1.png")
	actions.get_node("btn2").texture_normal = load("res://assets/sprites/action_icons2.png")

func _skin_directory_open():
	OS.shell_open(ProjectSettings.globalize_path("user://skins"))
