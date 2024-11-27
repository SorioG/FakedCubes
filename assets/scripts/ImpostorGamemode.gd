extends "res://assets/scripts/BaseGamemode.gd"
class_name ImpostorGamemode

var vote_in_session = false
var accused_player: Player

const MAX_VOTE_TIMER = 200

var vote_timer = MAX_VOTE_TIMER
var vote_points = 0

#var fate_kill_sound = AudioStreamPlayer.new()

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
	player.is_ghost = true
	player.is_killed = true

func game_start():
	vote_in_session = false
	accused_player = null
	
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
		if Global.net_mode == Global.GAME_TYPE.MULTIPLAYER_CLIENT: break
		if player.current_role == Global.PLAYER_ROLE.IMPOSTOR: continue
		player.current_role = choose_role_for_player(player)
	
	#if impostor_used > 0:
	#	print("not enough impostors used")

func role_reveal(label: Label, player: Player):
	var role = game.local_player.current_role
	
	if role == Global.PLAYER_ROLE.IMPOSTOR:
		label.text = "Your role is impostor"
		
		player.animation.play("evil")
	elif role == Global.PLAYER_ROLE.INNOCENT:
		label.text = "Your role is innocent"
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
	if Global.is_dedicated_server: return
	_btn2.visible = (game.local_player.current_role == Global.PLAYER_ROLE.IMPOSTOR)

func player_do_action(_player: Player, _action: int):
	if _action == 2 and _player.current_role == Global.PLAYER_ROLE.IMPOSTOR:
		if _player.kill_cooldown > 0: return
		if _player.is_ghost: return
		elif _player.is_killed: return
		
		if vote_in_session: return
		
		_player.animation.play("kill")
		
		for plr in _player.get_players_nearby():
			if plr.is_killed: continue
			if plr.current_role == Global.PLAYER_ROLE.IMPOSTOR: continue
			
			plr.kill_player()
			
			_player.kill_cooldown = 500
			break

func bot_tick(bot: Player):
	var is_fine = (bot.bot_witness_killer == null)
	var has_found_button = false
	
	# No need to rush to report, you're already dead.
	if bot.is_killed: is_fine = true
	
	if vote_in_session:
		bot.is_running = false
		bot.bot_move_x = 0
		bot.bot_move_y = 0
		return
	
	if bot.current_role == Global.PLAYER_ROLE.IMPOSTOR:
		bot.is_running = false
		
		bot.bot_walk_rand()
		
		bot.bot_try_kill()
	else:
		bot.is_running = (not is_fine)
		bot.bot_walk_rand()
		
		if is_fine:
			# We're fine, as long as there is no faker killing in front of me.
			var found_dead: Player
			var need_sos = false
			
			for p in bot.get_players_in_view():
				if p.is_ghost: continue
				if p.is_killed:
					found_dead = p
					break
			
			if found_dead:
				for f in found_dead.get_players_nearby():
					if f.is_killed: continue
					if f.animation.current_animation == "kill":
						need_sos = true
						bot.bot_witness_killer = f
						break
					elif Global.rand_chance(0.2):
						need_sos = true
						bot.bot_witness_killer = f
						break
				
				if not need_sos:
					bot.bot_witness_killer = bot
			
		else:
			# Panic, and rush to the report button if they're closely near one.
			var target_btn = get_first_report_button()
			
			has_found_button = (bot.position.distance_to(target_btn.position) < 9)
			
			if has_found_button:
				if bot.bot_witness_killer != bot:
					# This must be a impostor we have seen yet, pick the already seen one.
					bot.bot_force_pick_player(bot.bot_witness_killer, "report")
				else:
					# In case we do not know who killed them yet, pick a random player.
					bot.bot_pick_player(true, "report")
				
				#if OS.is_debug_build():
				#	print_debug("[Debug] Bot " + bot.player_name + " tried to accuse a player")
				
				bot.bot_witness_killer = null
			else:
				if (bot.position.distance_to(target_btn.position) > 30):
					if bot.position.x < target_btn.position.x:
						bot.bot_move_x = 1
					elif bot.position.x > target_btn.position.x:
						bot.bot_move_x = -1
					
					if bot.position.y < target_btn.position.y:
						bot.bot_move_y = 1
					elif bot.position.y > target_btn.position.y:
						bot.bot_move_y = -1

func get_first_report_button() -> InteractableObject:
	for obj in game.current_map.get_children():
		if obj.is_in_group("ReportButton"):
			return obj
	
	return null

func hud_picked_player(plr: Player, tag: String, picker: Player):
	if tag != "report": return
	if plr.is_killed: return
	if vote_in_session: return
	
	# Make every dead player a ghost before voting for the fate.
	for p in game.get_players():
		if not p.is_killed: continue
		if not p.is_ghost: continue
		p.is_ghost = true
		p.camera.offset = Vector2.ZERO
	
	for f in game.get_players():
		f.position = game.get_random_spawn().position
		if not f.is_killed:
			if plr == f: continue
			if picker == f: continue
			f.visible = false
			f.animation.play("appearing")
	
	for f in game.get_players():
		if not f.is_killed:
			if plr == f: continue
			if picker == f: continue
			f.position = plr.position
	
	vote_in_session = true
	vote_timer = MAX_VOTE_TIMER
	vote_points = 1
	accused_player = plr
	
	if game.local_player:
		var fatepanel = game.local_player.hud.get_node("accused_voting")
		fatepanel.visible = true
		fatepanel.get_node("box/label").text = picker.player_name + " has accused " + plr.player_name + " for bad actions, do you think that this is the impostor?"
		fatepanel.get_node("box/btns").visible = (plr != game.local_player)
		fatepanel.get_node("TimeBar").max_value = MAX_VOTE_TIMER
		
		if game.local_player.is_killed:
			fatepanel.get_node("box/btns").visible = false
		
		if picker == game.local_player:
			fatepanel.get_node("box/btns").visible = false
		
	
	print("[Impostor] " + picker.player_name + " has accused " + plr.player_name + " for bad actions")
	
	plr.animation.play("scared")
	
	
	# Makes the bot vote depending on what they know about.
	for bot in game.get_players():
		if Global.net_mode == Global.GAME_TYPE.MULTIPLAYER_CLIENT: break # Let the server handle automatic votes by bots
		if not bot.is_bot: continue
		if picker == bot: continue
		if bot.is_killed: continue
		if bot.bot_witness_killer == plr:
			# Always vote yes!
			vote_points += 1
		else:
			# The bot doesn't know or witness the murderer yet, vote either yes or no
			if Global.rand_chance(0.2):
				vote_points += 1
			elif Global.rand_chance(0.5):
				vote_points -= 1
	
	# Forget about what you witness, bots.
	for bot in game.get_players():
		if not bot.is_bot: continue
		bot.bot_witness_killer = null
	
	# Let the clients know about votes set by bots, so the vote points are in sync.
	if Global.net_mode != Global.GAME_TYPE.MULTIPLAYER_CLIENT:
		game.custom_rpc.rpc({
			"type": "set_vote_points",
			"points": vote_points
		})
	
	# FIXME: The reported animation doesn't seem to play for some reason (maybe bot?)
	picker.is_running = false
	picker.bot_move_x = 0
	picker.bot_move_y = 0
	picker.animation.play("reported")

func receive_custom_rpc(_data: Dictionary, _id: int):
	if _data["type"] == "vote":
		if _data["is_yes"]:
			vote_points += 1
		else:
			vote_points -= 1
	if _data["type"] == "vote_timer" and Global.net_mode == Global.GAME_TYPE.MULTIPLAYER_CLIENT:
		vote_timer = _data["timer"]
	if _data["type"] == "set_vote_points":
		# This is neccesary in order to keep in sync with bots in multiplayer.
		vote_points = _data["points"]
	if _data["type"] == "vote_finished":
		vote_points = _data["points"]
		_vote_finished()

func game_tick():
	if vote_in_session:
		# Don't stay dead while there is the vote going on
		for p in game.get_dead_players():
			p.is_ghost = true
			p.camera.offset = Vector2.ZERO
		
		vote_timer -= 10 * game.time_delta
		
		if Global.net_mode != Global.GAME_TYPE.MULTIPLAYER_CLIENT:
			game.custom_rpc.rpc({
				"type": "vote_timer",
				"timer": vote_timer
			})
		
		if vote_timer < 1 and Global.net_mode != Global.GAME_TYPE.MULTIPLAYER_CLIENT:
			game.custom_rpc.rpc({
				"type": "vote_finished",
				"points": vote_points
			})
		
		if game.local_player:
			var fatepanel = game.local_player.hud.get_node("accused_voting")
			fatepanel.get_node("TimeBar").value = vote_timer

func _vote_finished():
	var fate_success = (vote_points > 0)
	
	if fate_success and Global.net_mode != Global.GAME_TYPE.MULTIPLAYER_CLIENT:
		accused_player.kill_player()
		accused_player.is_ghost = true
	
	if game.local_player:
		var fatepanel = game.local_player.hud.get_node("accused_voting")
		fatepanel.visible = false
	
	var smsg = ""
	var sicon = load("res://assets/sprites/action_icons1.png")
		
	if fate_success:
		smsg = "Anyone has chosen to kill " + accused_player.player_name
	else:
		smsg = "Anyone has chosen to trust " + accused_player.player_name
		sicon = load("res://assets/sprites/action_icons8.png")
	
	if fate_success:
		smsg += " with " + str(vote_points) + " votes"
		if accused_player.current_role == Global.PLAYER_ROLE.IMPOSTOR:
			smsg += " (it's a impostor)"
		else:
			smsg += " (it's a innocent)"
	#else:
	#	smsg += " with " + str(vote_points).erase(0) + " votes"
	
	game.chat_window.add_message("Game", smsg, sicon)
		
	print("[Impostor] " + smsg)
	
	accused_player = null
	vote_in_session = false
	
	for p in game.get_alive_players():
		p.kill_cooldown = 800
		p.visible = true
		p.animation.play("RESET")
		p.position = game.get_random_spawn().position
