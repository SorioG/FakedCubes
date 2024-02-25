extends CharacterBody2D
class_name Player

@export var is_local_player = true
@export var is_bot = false
@export var player_name = "Player"
@export var start_flipped = false

@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var hud = $ui/HUD
@onready var ui: CanvasLayer = $ui
@onready var camera = $camera
@onready var nametag: Label = $username

@export var manual_move_x = 0.0
@export var manual_move_y = 0.0

@export var can_animate = true
@export var can_have_authority = true

@export var current_role: int = Global.PLAYER_ROLE.NONE

@export var skin_name: String = "Default"

@export var has_spawned = false
@export var net_id = 1

@export var is_killed: bool = false

@export var action_prefix: String = ""

@onready var character: Node2D = $Character

@onready var vc_output: AudioStreamPlayer2D = $Sounds/voice
@onready var vc_input: AudioStreamPlayer = $Sounds/voiceinput

var vc_out_playback: AudioStreamGeneratorPlayback

@export var c_game: Game

@export var is_idle: bool = false

var is_disappearing = false

@export var is_voicing: bool = false

const MAX_VELOCITY = 300

var bot_move_x = 0.0
var bot_move_y = 0.0

var impostor_chance = 0.0

@export var kill_cooldown: int = 0

var vc_max_buffer: int = 512

var vc_idx: int
var vc_effect: AudioEffectCapture

@export var custom_skin_data: String


func set_skin(tex: Texture2D) -> bool:
	if not tex is Texture2D: return false
	
	$Character/Body.texture = tex
	$Character/Body/Eyes.texture = tex
	$Character/Body/Mouth.texture = tex
	
	if is_local_player:
		var viewport = $ui/HUD/gameinfo/tabs/Player/HBoxContainer/skinview/viewport
		
		viewport.get_node("Body").texture = tex
		viewport.get_node("Eyes").texture = tex
		viewport.get_node("Mouth").texture = tex
	
	return true

func get_skin() -> Texture2D:
	
	return $Character/Body.texture

@rpc("any_peer","call_local","reliable")
func net_set_skin(nam: String):
	
	if not Global.player_skins.has(nam): 
		print("[WARN] " + player_name + " attempted to set a skin that does not exist (name: " + nam + ")")
		return
	
	var skin = Global.player_skins[nam]["skin"]
	
	set_skin(skin)
	skin_name = nam

func set_face(face: Global.FACE_TYPE, mood: int):
	var sprite: Sprite2D
	
	if face == Global.FACE_TYPE.BODY:
		sprite = $Character/Body
	elif face == Global.FACE_TYPE.EYES:
		sprite = $Character/Body/Eyes
	elif face == Global.FACE_TYPE.MOUTH:
		sprite = $Character/Body/Mouth
	else:
		return
	
	sprite.frame_coords.x = mood

func _ready():
	if not c_game:
		c_game = get_game()
	
	
	if can_have_authority:
		if c_game.net_mode != Global.GAME_TYPE.SINGLEPLAYER:
			if is_multiplayer_authority():
				is_local_player = true
				c_game.local_player = self
				
				LoadingScreen.hide_screen()
				
				vc_input.stream = AudioStreamMicrophone.new()
				#vc_input.play()
				
				vc_idx = AudioServer.get_bus_index("Voice")
				vc_effect = AudioServer.get_bus_effect(vc_idx, 0)
		
		vc_out_playback = vc_output.get_stream_playback()
	
	
	
	$camera.enabled = is_local_player
	$AudioListener2D.current = is_local_player
	if can_animate:
		$username.visible = not is_local_player
	$ui.visible = is_local_player
	
	$username.text = player_name
	
	if start_flipped:
		$Character.scale.x = -1
	
	if is_bot and c_game.bot_change_skin:
		#set_skin(Global.player_skins.values().pick_random())
		set_skin(Global.BOT_SKIN)
	
	if has_spawned:
		animation.play("appear")
		has_spawned = false
	
	


func _physics_process(_delta):
	if is_disappearing:
		if not animation.is_playing():
			queue_free()
		return
	
	if Global.stop_animations.has(animation.current_animation): 
		is_idle = false
		return
	
	
	if multiplayer.is_server():
		if kill_cooldown > 0:
			kill_cooldown -= 1
	
	var move_x = 0.0
	var move_y = 0.0
	
	$username.text = player_name
	
	
	
	if is_local_player:
		# Local Player (player is controlling the character)
		if not get_node("ui/HUD/gameinfo").visible:
			
			move_x = Input.get_action_strength(action_prefix+"move_right") - Input.get_action_strength(action_prefix+"move_left")
			move_y = Input.get_action_strength(action_prefix+"move_down") - Input.get_action_strength(action_prefix+"move_up")
			
			if Input.is_action_just_pressed(action_prefix+"use"):
				_do_action(1)
			elif Input.is_action_just_pressed(action_prefix+"action1"):
				_do_action(2)
			elif Input.is_action_just_pressed(action_prefix+"action2"):
				_do_action(3)
			elif Input.is_action_just_pressed(action_prefix+"action3"):
				_do_action(4)
			
			if is_instance_valid(c_game):
				if c_game.net_mode != Global.GAME_TYPE.SINGLEPLAYER:
					manual_move_x = move_x
					manual_move_y = move_y
		
		#$username.visible = false
	else:
		# Remote Player (player is networked or a bot)
		
		if is_bot and is_multiplayer_authority():
			# Only the host can control the bots
			var data = bot_tick()
			
			move_x = data[0]
			move_y = data[1]
			
			manual_move_x = move_x
			manual_move_y = move_y
		else:
			move_x = manual_move_x
			move_y = manual_move_y
		
		if can_animate:
			$username.visible = not is_killed
	
	if is_killed:
		$camera.offset += Vector2(move_x, move_y) * 30
		
		move_x = 0
		move_y = 0
		
		#animation.play("death")
		
		# Fix a bug where the player is still dead in the lobby
		if c_game.game_state == c_game.STATE.LOBBY:
			is_killed = false
	
	velocity = Vector2(move_x, move_y) * MAX_VELOCITY
	
	
	move_and_slide()
	
	if can_animate and not is_killed:
		set_animation()

func set_animation():
	
	if velocity.x < 0:
		$Character.scale.x = 1
	elif velocity.x > 0:
		$Character.scale.x = -1
	
	if animation.is_playing():
		if Global.freeze_animations.has(animation.current_animation): 
			is_idle = false
			return
	
	if velocity == Vector2.ZERO:
		if not is_idle:
			animation.play(Global.idle_animations.pick_random())
			is_idle = true
	else:
		is_idle = false
		animation.play("walk")
	

func get_game() -> Game:
	return get_node("../../")


@rpc("call_local", "reliable")
func do_action(num: int):
	if is_local_player:
		c_game.emit_signal("local_player_used_action", num)
	
	if not is_killed:
		c_game.gamemode_node.player_do_action(self, num)

func _do_action(num: int):
	if Global.net_mode != Global.GAME_TYPE.SINGLEPLAYER:
		do_action.rpc(num)
	else:
		do_action(num)

func bot_tick() -> Array[int]:
	var move_x = 0
	var move_y = 0
	
	
	
	var game: Game = c_game
	
	if game.game_state == game.STATE.LOBBY:
		# In Lobby: Just wander around, nothing else to do.
		bot_walk_rand()
		
	elif game.game_state == game.STATE.INGAME:
		if game.get_node("hud/role_reveal").visible:
			bot_move_x = 0
			bot_move_y = 0
		else:
			game.gamemode_node.bot_tick(self)
	
	move_x = bot_move_x
	move_y = bot_move_y
	
	return [move_x, move_y]

func bot_walk_rand():
	if Global.rand_chance(0.9):
		bot_move_x = c_game.rng.randi_range(-1, 1)
		bot_move_y = c_game.rng.randi_range(-1, 1)

func bot_try_kill():
	var plrs = get_players_nearby()
	
	var plr_view = get_players_in_view()
	
	var viewers = 0
	for viewer in plr_view:
		if c_game.gamemode_node is ArenaGamemode: break
		if viewer.is_killed: continue
		if viewer.current_role == Global.PLAYER_ROLE.IMPOSTOR: continue
		
		viewers += 1
		
		if viewers >= 2: return
	
	if plrs.size() > 0 and Global.rand_chance(0.8):
		for plr in plrs:
			if plr.is_killed: continue
			if plr.current_role == Global.PLAYER_ROLE.IMPOSTOR: continue
			
			_do_action(2)
			break


func disappear():
	animation.play("disappear")
	
	is_disappearing = true

func get_players_nearby() -> Array[Player]:
	var res: Array[Player] = []
	
	for obj in $use_area.get_overlapping_bodies():
		if obj == self: continue
		if obj is Player:
			res.append(obj)
	
	return res

func get_players_in_view() -> Array[Player]:
	var res: Array[Player] = []
	
	for obj in $view_area.get_overlapping_bodies():
		if obj == self: continue
		if obj is Player:
			res.append(obj)
	
	return res

@rpc("any_peer", "call_remote", "reliable")
func send_voice_data(buffer: PackedVector2Array):
	if not vc_output.playing:
		vc_output.play()
	
	for i in range(0, vc_max_buffer):
		vc_out_playback.push_frame(buffer[i])

func _process(_delta):
	if is_multiplayer_authority() and not is_bot:
		if vc_effect is AudioEffectCapture:
			#vc_max_buffer = vc_effect.get_frames_available()
			if (vc_effect.can_get_buffer(vc_max_buffer)):
				send_voice_data.rpc(vc_effect.get_buffer(vc_max_buffer))
			
			vc_effect.clear_buffer()
			
		
		if c_game is Game:
			is_voicing = vc_input.playing
			
			if vc_input.playing:
				c_game.get_node("hud/vc_enable").texture_normal = load("res://assets/sprites/chaticons1.png")
			else:
				c_game.get_node("hud/vc_enable").texture_normal = load("res://assets/sprites/chaticons2.png")
	else:
		$voice_icon.visible = is_voicing

@rpc("any_peer", "reliable", "call_remote")
func net_reset_player(reset_role: bool):
	c_game.reset_player(self, reset_role)

@rpc("any_peer", "reliable", "call_local")
func net_load_custom_skin(_skin: String):
	var data = Marshalls.base64_to_raw(_skin)
	
	var img = Image.new()
	var err = img.load_png_from_buffer(data)
	
	if err != OK:
		print("[WARN] "+player_name+" attempted to load a invalid custom skin, using default skin instead")
		
		if is_local_player:
			Global.alert("The custom skin you have selected is invalid, using default skin instead.")
		
		net_set_skin("Default")
		return
	
	var tex = ImageTexture.create_from_image(img)
	
	set_skin(tex)
	
	skin_name = "Custom"
	custom_skin_data = _skin
