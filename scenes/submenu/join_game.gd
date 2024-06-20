extends Node2D

func _ready():
	$ui/backbtn.connect("pressed", _on_back)
	
	$ui/userinfo/vert/username.text = Global.client_info["username"]
	$ui/userinfo/vert/uuid.text = Global.client_info["uuid"]
	
	var avatar: Image = Global.get_skin_still_image(Global.get_skin_by_name(Global.client_info["skin"]))
	
	$ui/userinfo/avatar.texture = ImageTexture.create_from_image(avatar)
	$ui/userinfo/avatar.tooltip_text = Global.client_info["skin"]

func _on_back():
	Global.change_scene_file("res://scenes/menu_screen.tscn")
