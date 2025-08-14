extends "res://assets/scripts/BaseGamemode.gd"
class_name ImpostorGamemode

var vote_in_session = false
var accused_player: Player

const MAX_VOTE_TIMER = 200

# Bot Messages used during the accused voting

# Messages used when the bot has witnessed the killer while the suspect is visible.
var bot_witness_messages = [
	"It's {0}! I saw them killing {1}!",
	"Do you not see what {0} did? They killed {1}!",
	"I was minding my own business, when i saw {0} has killed {1}, this shocked me.",
	"{0} is sus, who let them unalive {1}?",
	"I know who killed {1}! It's... {0}, yeah."
]

# Messages used when the bot doesn't know who killed them
var bot_unknown_report_messages = [
	"I don't know, is it {0}?",
	"I was wandering around, and suddenly there is a dead body appearing in front of me, surely it's {0}.",
	"If {0} is not a faker, I'm going to crash out >:(",
	"Ahem, is it correct if {0} has killed someone?"
]

# Messages used when the accused bot has randomly said something
var bot_accused_mercy_messages = [
	"Why :(",
	"VOTE NO ANYONE",
	"You're accusing a innocent?? D:",
	"Nah, they're self reporting. lol",
	"Me vs anyone, am i getting voted out?",
	"I'm just a dumb bot, beep boop",
	"I'm accepting defeat, just vote yes.",
	":)",
	"D:"
]

# Messages when the bot knows the killer while the other bot doesn't know something during the accused voting
# Also used for when players accuse the known killer.
var bot_unknown_reply_messages = [
	"Yep, that's the killer we're looking for, vote yes anyone!",
	"Congrats, you found the faker >:)",
	"If you dont know it, im going to use a application jumpscare on you, so yes, that's the killer",
	"Time to say goodbye, the 'trying to be normal' player",
	"CLICK YES, GO FOR IT!",
	"Ahem, you are correct for that player",
	"You are genius, another bot, or player!"
]

var vote_timer = MAX_VOTE_TIMER
var vote_points = 0
var every_vote = 0

var tasks_completed = 0
var max_tasks = 0

# Singleplayer Only
var sp_has_voted := false

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
	
	# Game Ends when all of the tasks have completed (innocent wins)
	if tasks_completed >= max_tasks:
		return Global.PLAYER_ROLE.INNOCENT
	
	return Global.PLAYER_ROLE.NONE

func player_join_early(player: Player):
	player.current_role = Global.PLAYER_ROLE.INNOCENT
	player.is_ghost = true
	player.is_killed = true

func game_start():
	vote_in_session = false
	accused_player = null
	tasks_completed = 0
	
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
	
	max_tasks = get_tree().get_nodes_in_group("TaskComputer").size()
	
	#if impostor_used > 0:
	#	print("not enough impostors used")

func game_end():
	for player in game.get_players():
		player.animation.play("RESET")
		player.bot_witness_killer = null
		if player.is_bot:
			player.is_paused = false
	
	if game.local_player:
		var fatepanel = game.local_player.hud.get_node("accused_voting")
		fatepanel.visible = false

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
	
	if bot.current_role == Global.PLAYER_ROLE.IMPOSTOR and not bot.bot_mimic_innocent:
		var viewers = 0
		var victim: Player
		var saw_dead_player: Player
		
		for p in bot.get_players_in_view():
			if p.is_killed:
				saw_dead_player = p
				continue
			if p.current_role == bot.current_role: continue
			if p.is_paused: continue
			viewers += 1
			victim = p
		
		if viewers <= 1 and victim:
			if not bot.is_ghost:
				if bot.kill_cooldown < 1:
					bot.is_running = true
					bot.bot_is_pathfinding = false
					bot.bot_walk_to(victim.position)
					
					bot.bot_try_kill()
				else:
					bot.is_running = false
					bot.bot_walk_rand()
		elif viewers >= 2 and saw_dead_player:
			bot.bot_mimic_innocent = true
		else:
			bot.is_running = false
			bot.bot_walk_rand()
	else:
		bot.is_running = (not is_fine)
		var is_impostor = (bot.current_role == Global.PLAYER_ROLE.IMPOSTOR)
		
		if is_fine:
			# We're fine, as long as there is no faker killing in front of me.
			var found_dead: Player
			var need_sos = false
			var viewers = 0
			
			for p in bot.get_players_in_view():
				if p.is_killed: continue
				if is_impostor:
					if p.current_role == bot.current_role: continue
				viewers += 1
			
			for p in bot.get_players_in_view():
				if p.is_ghost: continue
				if not p.is_killed:
					if p.animation.current_animation == "kill":
						# The faker somehow missed their attack or saw them killing them, this player needs to be accused
						bot.bot_witness_killer = p
						bot.bot_random_accuse = true
						break
				if p.is_killed:
					found_dead = p
					break
			
			if found_dead:
				bot.bot_saw_dead_player = found_dead
				for f in found_dead.get_players_nearby():
					if f.is_killed: continue
					if f.animation.current_animation == "kill":
						need_sos = true
						bot.bot_witness_killer = f
						break
					elif randi_range(1, 100) > 30:
						need_sos = true
						bot.bot_witness_killer = f
						bot.bot_random_accuse = true
						break
				
				if not need_sos:
					bot.bot_witness_killer = bot
			elif is_impostor and viewers <= 1:
				bot.bot_mimic_innocent = false
			else:
				if bot.bot_target_interactable_object:
					var task_is_completed = bot.bot_target_interactable_object.get("already_completed")
					if task_is_completed:
						bot.is_paused = false
						bot.bot_target_interactable_object = null
						return
					
					if not bot.bot_is_using_forced_pathfinding:
						bot.bot_force_pathfind(bot.bot_target_interactable_object.position)
					
					var is_near = (bot.position.distance_to(bot.bot_target_interactable_object.position) < 42)
					
					if is_near:
						if not bot.is_paused:
							bot.is_paused = true
							bot.bot_move_x = 0
							bot.bot_move_y = 0
							bot.bot_timer = randi_range(10, 1000)
						else:
							if bot.bot_timer < 1:
								if is_impostor:
									bot.is_paused = false
									bot.bot_target_interactable_object = null
								else:
									var success = randi_range(1, 1000) < 800
									var task_type = bot.bot_target_interactable_object.get("task_type")
									if task_type == 1:
										var num1 = randi_range(1, 10)
										var num2 = randi_range(1, 10)
										var res = randi_range(0, num1 + num2)
										if res == (num1 + num2):
											success = true
										else:
											success = false
									if success:
										#bot.animation.play("happy")
										#tasks_completed += 1
										game.custom_rpc.rpc({
											"type": "bot_task_success",
											"bot_path": str(bot.get_path()),
											"node_path": str(bot.bot_target_interactable_object.get_path())
										})
										bot.is_paused = false
										bot.bot_target_interactable_object = null
									else:
										#bot.animation.play("sad")
										game.custom_rpc.rpc({
											"type": "bot_task_fail",
											"bot_path": str(bot.get_path()),
										})
										if randi_range(1, 10) < 6:
											bot.is_paused = false
											bot.bot_target_interactable_object = null
							else:
								bot.bot_timer -= 1
					else:
						bot.bot_walk_rand()
						bot.is_paused = false
				else:
					bot.is_paused = false
					bot.bot_walk_rand()
				
				if randi_range(1, 90) < 80:
					if not bot.bot_target_interactable_object:
						bot.bot_target_interactable_object = get_random_task_computer()
		else:
			# Panic, and rush to the report button if they're closely near one.
			var target_btn = get_first_report_button()
			
			bot.is_paused = false
			
			has_found_button = (bot.position.distance_to(target_btn.position) < 42)
			
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
				if not bot.bot_is_using_forced_pathfinding:
					bot.bot_force_pathfind(target_btn.position)
				
				bot.bot_walk_rand()

func get_first_report_button() -> InteractableObject:
	for obj in game.current_map.get_children():
		if obj.is_in_group("ReportButton"):
			return obj
	
	return null

func get_random_task_computer() -> InteractableObject:
	return get_tree().get_nodes_in_group("TaskComputer").pick_random()

func hud_picked_player(plr: Player, tag: String, picker: Player):
	if tag != "report": return
	if plr.is_killed: return
	if vote_in_session: return
	
	# Make every dead player a ghost before voting for the fate.
	for p in game.get_players():
		if p.is_ghost: continue
		if p.is_killed or p.is_frozen:
			p.is_killed = true
			p.is_ghost = true
			p.is_frozen = false
			p.camera.offset = Vector2.ZERO
			p.animation.play("RESET")
	
	for f in game.get_players():
		if not f.is_killed:
			if plr == f: continue
			if picker == f: continue
			f.position = game.get_random_spawn().position
			f.visible = false
			f.animation.play("appearing")
	
	for f in game.get_players():
		if not f.is_killed:
			if plr == f: continue
			if picker == f: continue
			f.position = plr.position
	
	for f in game.get_players():
		# Interrupt what they're doing
		f.hud.get_node("TaskMath").hide()
		f.hud.get_node("FakeTask").hide()
		f.hud.get_node("pickplayer").hide()
	
	vote_in_session = true
	vote_timer = MAX_VOTE_TIMER
	vote_points = 1
	accused_player = plr
	every_vote = 1
	
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
		
		if Global.net_mode == Global.GAME_TYPE.SINGLEPLAYER:
			if plr == game.local_player:
				sp_has_voted = true
			if game.local_player.is_killed:
				sp_has_voted = true
			if picker == game.local_player:
				sp_has_voted = true
	
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
		elif bot.current_role == Global.PLAYER_ROLE.IMPOSTOR:
			# Be evil and vote yes or no depending on which player got accused
			if plr.current_role == Global.PLAYER_ROLE.IMPOSTOR:
				# This accused player is one of us, so vote no
				vote_points -= 1
			else:
				# Always vote yes on all innocents
				vote_points += 1
		else:
			# The bot doesn't know or witness the murderer yet, vote either yes or no
			if randf_range(1, 9000) > 9900:
				vote_points += 1
			elif randf_range(1, 10) > 9:
				vote_points -= 1
	
	if Global.net_mode != Global.GAME_TYPE.MULTIPLAYER_CLIENT:
		if picker.is_bot:
			if picker.bot_random_accuse or picker.bot_witness_killer == picker:
				picker.fake_say.rpc(bot_unknown_report_messages.pick_random().format([plr.player_name]))
				
				for another_bot in game.get_bots():
					if another_bot == picker: continue
					if another_bot == plr: continue
					if another_bot.bot_random_accuse: continue
					if another_bot.bot_witness_killer == plr:
						another_bot.fake_say.rpc(bot_unknown_reply_messages.pick_random())
						break
			else:
				picker.fake_say.rpc(bot_witness_messages.pick_random().format([picker.bot_witness_killer.player_name, picker.bot_saw_dead_player.player_name]))
		else:
			for another_bot in game.get_bots():
				if another_bot == plr: continue
				if another_bot.bot_random_accuse: continue
				if another_bot.bot_witness_killer == plr:
					another_bot.fake_say.rpc(bot_unknown_reply_messages.pick_random())
					break
		
		if plr.is_bot and randf_range(1, 8) > 6:
			plr.fake_say.rpc(bot_accused_mercy_messages.pick_random())
	
	# Forget about what you witness, bots.
	for bot in game.get_bots():
		bot.bot_witness_killer = null
		bot.bot_saw_dead_player = null
		bot.bot_random_accuse = false
		bot.bot_is_pathfinding = false
		bot.bot_mimic_innocent = false
		bot.is_paused = false
	
	# Let the clients know about votes set by bots, so the vote points are in sync.
	if Global.net_mode != Global.GAME_TYPE.MULTIPLAYER_CLIENT:
		game.custom_rpc.rpc({
			"type": "set_vote_points",
			"points": vote_points,
			"every_vote": every_vote
		})
	
	picker.is_running = false
	picker.bot_move_x = 0
	picker.bot_move_y = 0
	await get_tree().physics_frame
	picker.position = plr.position + Vector2(randf_range(-100, 100),randf_range(-100, 100))
	picker.animation.play("reported")

func receive_custom_rpc(_data: Dictionary, _id: int):
	if _data["type"] == "vote":
		if _data["is_yes"]:
			vote_points += 1
		else:
			vote_points -= 1
		every_vote += 1
		if Global.net_mode == Global.GAME_TYPE.SINGLEPLAYER:
			sp_has_voted = true
	if _data["type"] == "vote_timer" and Global.net_mode == Global.GAME_TYPE.MULTIPLAYER_CLIENT:
		vote_timer = _data["timer"]
	if _data["type"] == "set_vote_points":
		# This is neccesary in order to keep in sync with bots in multiplayer.
		vote_points = _data["points"]
		every_vote = _data["every_vote"]
	if _data["type"] == "vote_finished":
		vote_points = _data["points"]
		_vote_finished()
	
	# Task-specific RPCs
	if _data["type"] == "task_success":
		var player = game.get_player_by_id(_id)
		var obj = get_tree().root.get_node(NodePath(_data["node_path"]))
		if player:
			if not player.is_killed or player.is_killed and player.is_ghost:
				if not player.is_ghost:
					player.animation.play("happy2")
				player.get_node("Sounds/task_complete").play()
				tasks_completed += 1
		if obj:
			obj.already_completed = true
			obj.get_node("sprite").texture = load("res://assets/sprites/task_computer_done.png")
	if _data["type"] == "task_fail":
		var player = game.get_player_by_id(_id)
		if player:
			if not player.is_killed or player.is_killed and player.is_ghost:
				if not player.is_ghost:
					player.animation.play("sad")
				#tasks_completed += 1
				player.get_node("Sounds/task_fail").play()
	if _data["type"] == "bot_task_success":
		var player = game.get_node_or_null(NodePath(_data["bot_path"]))
		var obj = get_tree().root.get_node(NodePath(_data["node_path"]))
		if player:
			if not player.is_killed or player.is_killed and player.is_ghost:
				if not player.is_ghost:
					player.animation.play("happy2")
				tasks_completed += 1
				player.get_node("Sounds/task_complete").play()
		if obj:
			obj.already_completed = true
			obj.get_node("sprite").texture = load("res://assets/sprites/task_computer_done.png")
	if _data["type"] == "bot_task_fail":
		var player = game.get_node_or_null(NodePath(_data["bot_path"]))
		if player:
			if not player.is_killed or player.is_killed and player.is_ghost:
				if not player.is_ghost:
					player.animation.play("sad")
				#tasks_completed += 1
				player.get_node("Sounds/task_fail").play()

func game_tick():
	for p in game.get_players():
		if p.is_frozen:
			if not p.animation.is_playing():
				p.is_killed = true
				p.is_ghost = true
				p.is_frozen = false
				p.camera.zoom = Vector2(1.2, 1.2)
				p.camera.position = Vector2(0, 0)
				p.animation.play("RESET")
	
	if vote_in_session:
		# Don't stay dead while there is the vote going on
		for p in game.get_dead_players():
			p.is_ghost = true
			p.camera.offset = Vector2.ZERO
		
		if sp_has_voted:
			vote_timer -= 300 * game.time_delta
		else:
			vote_timer -= (5 * every_vote) * game.time_delta
		
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
	sp_has_voted = false
	every_vote = 0
	
	if fate_success:
		accused_player.is_frozen = true
		if accused_player.current_role == Global.PLAYER_ROLE.IMPOSTOR:
			accused_player.animation.play("thrown_away_fake")
		else:
			accused_player.animation.play("thrown_away")
		
		#if Global.net_mode != Global.GAME_TYPE.MULTIPLAYER_CLIENT:
		#	accused_player.is_ghost = true
	
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
	
	vote_in_session = false
	
	for p in game.get_alive_players():
		p.kill_cooldown = 800
		p.visible = true
		if not p.is_frozen:
			p.animation.play("RESET")
		
		if p.is_bot:
			p.is_running = false
		
		p.position = game.get_random_spawn().position
	
	accused_player = null
