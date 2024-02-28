extends "res://assets/scripts/BaseGamemode.gd"
class_name ArenaGamemode

var protection_timer: Dictionary = {}
var player_health: Dictionary = {}
var player_kills: Dictionary = {}

var kills: int = 0

var max_kills: int = 10

var max_health: int = 300

var winner: Player

func _init():
	can_reveal_role = true

func can_start_game() -> String:
	if game.get_players().size() <= 1:
		return "Not enough players to start"
	
	return "OK"

func update_actions(_btn1: TextureButton, _btn2: TextureButton, _btn3: TextureButton, _btn4: TextureButton):
	_btn2.visible = true

func game_start():
	kills = 0
	winner = null
	
	if not game.is_using_custom_map:
		change_map("arena")
	
	max_kills = 5
	
	super()
	
	var i = 0
	for player in game.get_players():
		protect_player(player)
		player_health[player] = max_health
		player_kills[player] = 0
		player.kill_cooldown = 50
		
		if i > 10:
			max_kills += 2
			i = 0
		
		i += 1
	
	if Global.is_dedicated_server:
		print("[Arena] Maximum Kills to end the game: " + str(max_kills))

func check_end_game() -> int:
	if winner is Player:
		return Global.PLAYER_ROLE.INNOCENT
	
	if game.get_players().size() <= 1:
		return Global.PLAYER_ROLE.INNOCENT
	
	return Global.PLAYER_ROLE.NONE

# Protect player from being killed
func protect_player(player: Player):
	var timer: Timer
	if not protection_timer.has(player):
		timer = Timer.new()
		protection_timer[player] = timer
	else:
		return
	
	timer.wait_time = 2
	timer.one_shot = true
	timer.connect("timeout", _protection_ended.bind(player, timer))
	player.add_child(timer)
	
	player.animation.play("appearing")
	
	timer.start()

func _protection_ended(player: Player, timer: Timer):
	player.remove_child(timer)
	protection_timer.erase(player)
	
	player.animation.play("RESET")

func player_do_action(_player: Player, _action: int):
	if _action == 2 and _player.kill_cooldown < 1:
		_player.animation.play("RESET")
		_player.animation.play("kill")
		
		_player.kill_cooldown = 20
		
		for plr in _player.get_players_nearby():
			if plr.is_killed: continue
			if protection_timer.has(plr): continue
			
			if Global.net_mode != Global.GAME_TYPE.MULTIPLAYER_CLIENT:
				player_health[plr] -= 10
				plr.kill_cooldown += 2
			
			_player.kill_cooldown = 10
			
			if player_health[plr] < 1:
				plr.kill_cooldown = 100
				
				plr.is_killed = true
				#plr.animation.play("death")
				
				game.custom_rpc.rpc({"type": "death", "name": plr.name})
				
				
				if player_kills[_player] + 1 >= max_kills:
					game.custom_rpc.rpc({"type": "winner", "name": _player.name})
				
				player_kills[_player] += 1
				
				#_player.animation.play("happy2")
			else:
				plr.get_node("Sounds/hit2").play()
				
				plr.animation.play("RESET")
				plr.animation.play("damage")
			
			

func game_tick():
	for player in game.get_dead_players():
		if player.kill_cooldown < 1:
			game.reset_player(player, false)
			player.kill_cooldown = 20
			player.position = game.get_random_spawn().position
			#player_health[player] = max_health
			
			#protect_player(player)
			game.custom_rpc.rpc({"type": "revive", "name": player.name})

func bot_tick(bot: Player):
	bot.bot_walk_rand()
	
	if (bot.get_players_nearby().size() > 0):
		bot.bot_try_kill()

func show_results(label: Label, player: Player):
	if is_instance_valid(winner):
		label.text = winner.player_name + " wins"
	
		player.set_skin(winner.get_skin())
		
		player.animation.play("RESET")
		player.animation.play("happy")
	else:
		label.text = "Tie"

func role_reveal(_label: Label, _player: Player):
	_label.text = "Get " + str(max_kills) + " kills before anyone else"
	
	_player.animation.play("RESET")
	_player.animation.play("evil")

func network_save() -> Dictionary:
	return {
		"kills": kills,
		"max_kills": max_kills
	}

func network_load(data: Dictionary):
	kills = data["kills"]
	max_kills = data["max_kills"]


func receive_custom_rpc(_data: Dictionary, _id: int):
	if _data["type"] == "revive" and _id == 1:
		var player = game.players_node.get_node_or_null(NodePath(_data["name"]))
		
		if player is Player:
			player_health[player] = max_health
			protect_player(player)
	
	if _data["type"] == "death" and _id == 1:
		var player = game.players_node.get_node_or_null(NodePath(_data["name"]))
		
		if player is Player:
			player.kill_cooldown = 100
			
			#player.is_killed = true
			player.animation.play("death")
	
	if _data["type"] == "winner" and _id == 1:
		var player = game.players_node.get_node_or_null(NodePath(_data["name"]))
		
		if player is Player:
			winner = player
