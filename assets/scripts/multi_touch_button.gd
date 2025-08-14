extends TextureButton

@export var action: String

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var event_pos_adjusted: Vector2 = event.position + global_position
		var inside: bool = event_pos_adjusted.x > position.x and event_pos_adjusted.y > position.y and event_pos_adjusted.x < position.x + size.x and event_pos_adjusted.y < position.y + size.y
		if event.pressed and inside:
			if toggle_mode:
				toggled.emit()
				button_pressed = true
			else:
				pressed.emit()
				button_down.emit()
			if action: Input.action_press(action)
		elif inside or (not event.pressed and not inside):
			button_up.emit()
			button_pressed = false
			if action: Input.action_release(action)
