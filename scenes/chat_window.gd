extends Control

@onready var input = $panel/box/input
@onready var messages = $panel/box/scroll/messages
@onready var scroll = $panel/box/scroll

@onready var msg_node = preload("res://scenes/chat_message.tscn")

signal type_message(msg: String)
signal new_message(user: String, message: String)

func _ready():
	input.connect("text_submitted", _on_type_message)

func add_message(user: String, message: String, avatar: Texture2D = null):
	var clone = msg_node.instantiate()
	if avatar != null:
		clone.get_node("panel/box/avatar").texture = avatar
	
	clone.get_node("panel/box/info/username").text = user
	clone.get_node("panel/box/info/message").text = message
	
	clone.visible = true
	clone.custom_minimum_size = Vector2(0, 100)
	messages.add_child(clone)
	
	await get_tree().process_frame
	
	scroll.ensure_control_visible(clone)
	
	emit_signal("new_message", user, message)

func _on_type_message(text: String):
	emit_signal("type_message", text)
	input.text = ""
