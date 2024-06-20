extends Node2D

func _ready():
	$ui/backbtn.connect("pressed", _on_back)
	$ui/panel/box/hostbtn.connect("pressed", _on_host)
	
	if Global.cubenet_server_url.is_empty():
		$ui/panel/box/public.disabled = true
		$ui/panel/box/nettype/value.disabled = true
	
	if OS.get_name() == "Web":
		$ui/panel/box/nettype/value.select(1)
		$ui/panel/box/nettype/value.disabled = true

func _process(_delta):
	$ui/panel/box/servport/value.editable = ($ui/panel/box/nettype/value.selected == 0)

func _on_back():
	Global.change_scene_file("res://scenes/menu_screen.tscn")

func _on_host():
	print("[Game] Hosting the server")
	
	Global.net_mode = Global.GAME_TYPE.MULTIPLAYER_HOST
	Global.net_type = $ui/panel/box/nettype/value.get_selected_id()
	
	Global.cubenet_is_public = $ui/panel/box/public.button_pressed
	Global.server_port = $ui/panel/box/servport/value.value
	
	Global.change_scene_file("res://scenes/game.tscn")
