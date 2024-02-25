extends Node2D

@onready var player: Player = $Player

var anim_list: PackedStringArray

var skinimage: Image
var skintexture: Texture2D

var about_to_take_screenshot = false

func _ready():
	$ui/SkinDialog.connect("file_selected", on_load_skin)
	$ui/SaveDialog.connect("file_selected", on_save_icon)
	
	$ui/panel/Skin/loadskin.connect("pressed", press_load_skin)
	$ui/panel/Skin/randomface.connect("pressed", on_random_face)
	$ui/panel/Skin/flipplayer.connect("pressed", flip_player)
	$ui/panel/Skin/screenshot.connect("pressed", screenshot)
	$ui/panel/Skin/saveicon.connect("pressed", press_save_icon)
	
	$ui/quitbtn.connect("pressed", on_quit)
	
	anim_list = player.animation.get_animation_list()
	
	for anim in anim_list:
		var btn = Button.new()
		btn.text = anim
		btn.name = anim
		
		btn.connect("pressed", on_animation.bind(anim))
		
		$ui/panel/Animations/btns.add_child(btn)
	
	$lobby/spawns.visible = false

func press_load_skin():
	$ui/SkinDialog.popup_centered()

func press_save_icon():
	$ui/SaveDialog.popup()

func drop_file():
	pass

func on_save_icon(path: String):
	print(path)
	
	var err = skinimage.save_png(path)
	
	if err != OK:
		print("failed to save icon")

func on_load_skin(path: String):
	print(path)
	
	var res: Texture2D = ResourceLoader.load(path, "Image")
	
	if not res is Texture2D:
		return
	
	#print(res.get_width(), res.get_height())
	
	if res.get_width() != 576 or res.get_height() != 192:
		OS.alert("The image size does not match the skin's required size", "Invalid Skin")
		return
	
	$ui/panel/Skin/skininfo.text = "[center]Filename: "
	$ui/panel/Skin/skininfo.text += path
	
	
	var sname: String
	
	
	if OS.get_name() == "Windows":
		var split = path.split("\\")
		sname = split[split.size()-1]
	else:
		var split = path.split("/")
		sname = split[split.size()-1]
	
	var sp2 = sname.split(".")[1]
	
	sname = sname.replace("." + sp2, "")
	
	
	
	print(sname)
	
	player.set_skin(res)
	#player.player_name = sname
	skintexture = res
	#about_to_take_screenshot = true

func _physics_process(_delta):
	if about_to_take_screenshot:
		screenshot()
		about_to_take_screenshot = false

func on_animation(anim: String):
	player.animation.play(anim)

func on_quit():
	Global.change_scene_file("res://scenes/menu_screen.tscn")

func on_random_face():
	player.set_face(Global.FACE_TYPE.BODY, randi_range(0,8))
	player.set_face(Global.FACE_TYPE.EYES, randi_range(0,8))
	player.set_face(Global.FACE_TYPE.MOUTH, randi_range(0,8))

func flip_player():
	if player.character.scale.x == 1:
		player.character.scale.x = -1
	else:
		player.character.scale.x = 1

func screenshot():
	var offset = -48
	#var region = Rect2(Vector2(player.position.x+offset, player.position.y+offset), Vector2(100, 100))
	$thumbcam.enabled = true
	$ui.visible = false
	
	var old_mode = DisplayServer.window_get_mode()
	
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	await get_tree().create_timer(0.5).timeout
	
	var center = $thumbcam.get_screen_center_position()
	
	var view_rect = get_viewport_rect()
	
	var region = Rect2(view_rect.get_center() + Vector2(offset, offset), Vector2(100, 100))
	
	
	player.nametag.visible = false
	
	
	
	
	await get_tree().create_timer(0.5).timeout
	
	var image = get_viewport().get_texture().get_image().get_region(region)
	
	var tex = ImageTexture.create_from_image(image)
	
	
	#$scrtest.texture = tex
	$ui/panel/Skin/skinimage/TextureRect.texture = tex
	
	skinimage = image
	
	$thumbcam.enabled = false
	$ui.visible = true
	
	DisplayServer.window_set_mode(old_mode)
	#await get_tree().create_timer(1.0).timeout
	
	player.nametag.visible = true
