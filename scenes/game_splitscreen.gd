extends Node

@onready var viewport1 = $BG/players/PlayerScreen1/SubViewport
@onready var viewport2 = $BG/players/PlayerScreen2/SubViewport

var game1: Game
var game2: Game

var p2_mapi: MultiplayerAPI = MultiplayerAPI.create_default_interface()

var player2_joined: bool = false


func _ready():
	game1 = Global.GAME_NODE.instantiate()
	
	#game1.num_bots = 0
	game1.is_split_screen = true
	#game1.net_mode = Global.GAME_TYPE.MULTIPLAYER_HOST
	viewport1.add_child(game1)
	#$BG/players/PlayerScreen2.visible = false
	
	#get_tree().set_multiplayer(p2_mapi, ^"/root/SplitScreen/BG/players/PlayerScreen2/SubViewport")
	
	handle_player2_join()

#func _process(delta):
#	if Input.is_action_just_pressed("p2_join"):
#		handle_player2_join()

func handle_player2_join():
	if player2_joined: return
	
	#game2 = Global.GAME_NODE.instantiate()
	
	#game2.num_bots = 0
	#game2.is_split_screen = true
	#game2.split_screen_player = 2
	#game2.net_mode = Global.GAME_TYPE.MULTIPLAYER_CLIENT
	
	$BG/players/PlayerScreen2.visible = true
	$BG/players/PlayerScreen2/SubViewport.audio_listener_enable_2d = true
	
	viewport2.world_2d = viewport1.world_2d
	
	
	var player2 = game1.spawn_player(true, "Player2")
	player2.action_prefix = "p2_"
	player2.ui.custom_viewport = viewport2
	player2.camera.custom_viewport = viewport2
	player2.camera.make_current()
	
	game1.local_player2 = player2
	#player2.set_skin(Global.player_skins["Cubette"])
	player2.get_node("username").visible = true
	game1.local_player.get_node("username").visible = true
	#viewport2.add_child(game2)
