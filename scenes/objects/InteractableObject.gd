extends Node2D
class_name InteractableObject

var player_is_touching = false
@onready var touch_area = $touch_area

@export var show_hint: bool = true

var c_game: Game

func _ready():
	$touch_hint.visible = false
	
	c_game = get_game()
	
	if c_game is Game:
		c_game.connect("local_player_used_action", _process_used)

func _physics_process(_delta):
	var bodies = touch_area.get_overlapping_bodies()
	
	
	player_is_touching = false
	
	if not c_game: return
	
	for player in bodies:
		if player is Player and player.is_local_player:
			player_is_touching = true
	
	$touch_hint.visible = player_is_touching and show_hint
	
	

func _process_used(action: int):
	if player_is_touching:
		$used.play()
		on_used(action)

func on_used(_action: int):
	pass

func get_game() -> Game:
	return get_node("../../../")
