extends "res://assets/scripts/BaseGamemode.gd"

#var seeker: Player

var local_player_warning := false
var found_seeker := false
var bot_found_player: Player

func _init():
	can_reveal_role = false

func check_end_game() -> int:
	var alive_innos = game.get_alive_players_by_role(Global.PLAYER_ROLE.INNOCENT).size()
	var alive_impos = game.get_alive_players_by_role(Global.PLAYER_ROLE.IMPOSTOR).size()
	
	if alive_innos < 1:
		return Global.PLAYER_ROLE.IMPOSTOR

	if alive_impos < 1:
		return Global.PLAYER_ROLE.INNOCENT
	
	return Global.PLAYER_ROLE.NONE

func can_start_game() -> String:
	if game.get_players().size() <= 1:
		return "Not enough players to start"
	
	return "OK"

func game_start():
	if not game.is_using_custom_map:
		change_map("arena")
	
	if Global.net_mode != Global.GAME_TYPE.MULTIPLAYER_CLIENT:
		var num_seekers = randi_range(1, 3)
		
		if game.get_players().size() <= 2:
			num_seekers = 1
		elif game.get_players().size() <= 4:
			num_seekers = randi_range(1, 2)
		
		while num_seekers > 0:
			for hider in game.get_players():
				if hider.current_role == Global.PLAYER_ROLE.IMPOSTOR: continue
				
				if randi_range(0, 80) > 70:
					hider.current_role = Global.PLAYER_ROLE.IMPOSTOR
					num_seekers -= 1
					hider.kill_cooldown = 800
				else:
					hider.current_role = Global.PLAYER_ROLE.INNOCENT

func game_tick():
	for seeker in game.get_alive_players_by_role(Global.PLAYER_ROLE.IMPOSTOR):
		seeker.set_face(Global.FACE_TYPE.EYES, Global.MOOD_TYPE.KILL)
		seeker.set_face(Global.FACE_TYPE.BODY, Global.MOOD_TYPE.KILL)
	
	for hider in game.get_alive_players_by_role(Global.PLAYER_ROLE.INNOCENT):
		for plr in hider.get_players_in_view():
			if plr.current_role == Global.PLAYER_ROLE.IMPOSTOR:
				hider.set_face(Global.FACE_TYPE.EYES, Global.MOOD_TYPE.REPORT)
				if not plr.is_running:
					hider.set_face(Global.FACE_TYPE.MOUTH, Global.MOOD_TYPE.BORED)
	
	if game.local_player:
		var player = game.local_player
		var alive_innocents = game.get_alive_players_by_role(Global.PLAYER_ROLE.INNOCENT)
		if alive_innocents.size() >= 2:
			if player.current_role == Global.PLAYER_ROLE.INNOCENT:
				found_seeker = false
				
				if not player.is_killed:
					for plr in player.get_players_in_view():
						if plr.current_role == Global.PLAYER_ROLE.IMPOSTOR and not plr.is_killed:
							found_seeker = true
							if not local_player_warning:
								if MusicManager.current_music != "once_more_metal":
									MusicManager.play_music("once_more_metal")
								else:
									MusicManager.music_player.volume_db = 0
								local_player_warning = true
							break
				
				if not found_seeker:
					if local_player_warning:
						local_player_warning = false
						MusicManager.music_player.volume_db = -80
			elif player.current_role == Global.PLAYER_ROLE.IMPOSTOR:
				found_seeker = false
				
				if not player.is_killed:
					for plr in player.get_players_in_view():
						if plr.current_role == Global.PLAYER_ROLE.INNOCENT and not plr.is_killed:
							found_seeker = true
							if not local_player_warning:
								if MusicManager.current_music != "once_more_metal":
									MusicManager.play_music("once_more_metal")
								else:
									MusicManager.music_player.volume_db = 0
								local_player_warning = true
							break
				
				if not found_seeker:
					if local_player_warning:
						local_player_warning = false
						MusicManager.music_player.volume_db = -80
		elif alive_innocents.size() == 1:
			if MusicManager.current_music != "outworld":
				MusicManager.play_music("outworld")

func update_actions(_btn1: TextureButton, _btn2: TextureButton, _btn3: TextureButton, _btn4: TextureButton):
	if Global.is_dedicated_server: return
	_btn2.visible = (game.local_player.current_role == Global.PLAYER_ROLE.IMPOSTOR)

func player_do_action(_player: Player, _action: int):
	if _action == 2 and _player.current_role == Global.PLAYER_ROLE.IMPOSTOR:
		if _player.kill_cooldown > 0: return
		if _player.is_ghost: return
		elif _player.is_killed: return
		
		_player.animation.play("kill")
		
		for plr in _player.get_players_nearby():
			if plr.is_killed: continue
			if plr.current_role == Global.PLAYER_ROLE.IMPOSTOR: continue
			
			plr.kill_player()
			
			_player.kill_cooldown = 300
			break

func bot_tick(bot: Player):
	if bot.current_role == Global.PLAYER_ROLE.INNOCENT:
		var found_player: Player
		
		for plr in bot.get_players_in_view():
			if plr.current_role == Global.PLAYER_ROLE.IMPOSTOR:
				found_player = plr
				break
		
		if not found_player:
			bot.bot_walk_rand()
			bot.is_running = false
		else:
			if randf_range(1, 100) >= 99:
				bot.is_running = not bot.is_running
			if not bot.is_running:
				bot.bot_walk_rand()
			else:
				if bot.position.x < found_player.position.x:
					bot.bot_move_x = -1
				elif bot.position.x > found_player.position.x:
					bot.bot_move_x = 1
				
				if bot.position.y < found_player.position.y:
					bot.bot_move_y = -1
				elif bot.position.y > found_player.position.y:
					bot.bot_move_y = 1
	elif bot.current_role == Global.PLAYER_ROLE.IMPOSTOR:
		#var found_player: Player
		
		for plr in bot.get_players_in_view():
			if plr.current_role == Global.PLAYER_ROLE.INNOCENT and not plr.is_killed:
				bot_found_player = plr
				break
		
		if not bot.bot_found_player and randf_range(1, 10) >= 9:
			var alive_innos := game.get_alive_players_by_role(Global.PLAYER_ROLE.INNOCENT)
			if alive_innos.size() >= 1:
				bot.bot_found_player = alive_innos.pick_random()
		
		if bot.bot_found_player:
			if bot.bot_found_player.is_killed:
				bot.bot_found_player = null
			
			if not (bot.bot_found_player in bot.get_players_in_view()):
				if randf_range(1, 100) >= 100:
					bot.bot_found_player = null
		
		if not bot.bot_found_player:
			bot.bot_walk_rand()
			bot.is_running = false
		elif bot.kill_cooldown < 1:
			if randf_range(1, 100) >= 99:
				bot.is_running = not bot.is_running
			bot.bot_try_kill()
			
			if not bot.is_running:
				bot.bot_walk_rand()
			else:
				if bot.position.x < bot.bot_found_player.position.x:
					bot.bot_move_x = 1
				elif bot.position.x > bot.bot_found_player.position.x:
					bot.bot_move_x = -1
				
				if bot.position.y < bot.bot_found_player.position.y:
					bot.bot_move_y = 1
				elif bot.position.y > bot.bot_found_player.position.y:
					bot.bot_move_y = -1

func game_end():
	MusicManager.stop_music()
	MusicManager.music_player.volume_db = 0

#func role_reveal(label: Label, player: Player):
#	var role = game.local_player.current_role
