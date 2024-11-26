extends Node2D

func _ready():
	$ui/backbtn.connect("pressed", _on_back)

func _on_back():
	Global.change_scene_file("res://scenes/menu_screen.tscn")
