extends "res://assets/scripts/BaseGamemode.gd"
class_name ImpostorGamemode

func _init():
	can_reveal_role = true

func check_end_game() -> int:
	var alive_innos = game.get_alive_players_by_role(Global.PLAYER_ROLE.INNOCENT).size()
	var alive_impos = game.get_alive_players_by_role(Global.PLAYER_ROLE.IMPOSTOR).size()
	
	# Game Ends when there are less innocent alive (impostor wins)
	if alive_innos < 3:
		return Global.PLAYER_ROLE.IMPOSTOR
	
	# Game Ends when there is no alive impostors (innocent wins)
	if alive_impos < 1:
		return Global.PLAYER_ROLE.INNOCENT
	
	return Global.PLAYER_ROLE.NONE

func player_join_early(player: Player):
	player.current_role = Global.PLAYER_ROLE.INNOCENT

func game_start():
	if not game.is_using_custom_map:
		change_map("impostor1")
	
	var impostor_used: int = 3
	if game.get_players().size() < 8:
		impostor_used = 1
	elif game.get_players().size() < 10:
		impostor_used = 2
	
	#print("Impostor Used: " + str(impostor_used))
	
	#var attempted_players: Array[Player] = []
	
	while impostor_used > 0:
		#if attempted_players.size() >= get_players().size(): break
		if Global.net_mode == Global.GAME_TYPE.MULTIPLAYER_CLIENT: break
		
		for player in game.get_players():
			if player.current_role == Global.PLAYER_ROLE.IMPOSTOR: continue
			#if attempted_players.has(player): continue
			if impostor_used > 0 and (randi_range(1, 80-player.impostor_chance) >= 70-player.impostor_chance):
				player.current_role = Global.PLAYER_ROLE.IMPOSTOR
				impostor_used -= 1
				#print("Chosen as impostor: " + player.player_name)
				
				player.kill_cooldown = 500
			
			#attempted_players.append(player)
	
	for player in game.get_players():
		if player.current_role == Global.PLAYER_ROLE.IMPOSTOR: continue
		player.current_role = choose_role_for_player(player)
	
	#if impostor_used > 0:
	#	print("not enough impostors used")

func role_reveal(label: Label, player: Player):
	var role = game.local_player.current_role
	
	if role == Global.PLAYER_ROLE.IMPOSTOR:
		label.text = "Impostor"
		
		player.animation.play("evil")
	elif role == Global.PLAYER_ROLE.INNOCENT:
		label.text = "Innocent"
	else:
		role_reveal_shared(label, player)

func role_reveal_shared(_label: Label, _player: Player):
	pass

func show_results(label: Label, player: Player):
	var role = game.winning_role
	
	if role == Global.PLAYER_ROLE.IMPOSTOR:
		label.text = "Impostor Wins"
		
		player.animation.play("RESET")
		player.animation.play("evil")
	elif role == Global.PLAYER_ROLE.INNOCENT:
		label.text = "Innocent Wins"
		
		player.animation.play("RESET")
		player.animation.play("happy")
	else:
		show_results_shared(label, player)

func show_results_shared(_label: Label, _player: Player):
	pass

func update_player(player: Player):
	if player.current_role == Global.PLAYER_ROLE.IMPOSTOR:
		player.get_node("impostor_icon").visible = (game.local_player.current_role == Global.PLAYER_ROLE.IMPOSTOR)
		player.get_node("impostor_icon").modulate = Color.RED
	else:
		player.get_node("impostor_icon").visible = false

func can_start_game() -> String:
	if game.get_players().size() < 5:
		return "Not enough players to start"
	
	return "OK"

func update_actions(_btn1: TextureButton, _btn2: TextureButton, _btn3: TextureButton, _btn4: TextureButton):
	_btn2.visible = (game.local_player.current_role == Global.PLAYER_ROLE.IMPOSTOR)

func player_do_action(_player: Player, _action: int):
	if _action == 2 and _player.current_role == Global.PLAYER_ROLE.IMPOSTOR:
		if _player.kill_cooldown > 0: return
		
		_player.animation.play("kill")
		
		for plr in _player.get_players_nearby():
			
			if plr.is_killed: continue
			if plr.current_role == Global.PLAYER_ROLE.IMPOSTOR: continue
			
			plr.kill_player()
			
			_player.kill_cooldown = 500
			break

func bot_tick(bot: Player):
	bot.bot_walk_rand()
	
	if bot.current_role == Global.PLAYER_ROLE.IMPOSTOR:
		bot.bot_try_kill()
