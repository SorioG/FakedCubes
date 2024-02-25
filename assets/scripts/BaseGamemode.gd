extends Node
class_name BaseGamemode

# Base Class for all of the gamemodes

var game: Game
@export var can_reveal_role: bool = false

func choose_role_for_player(_player: Player) -> int:
	return Global.PLAYER_ROLE.INNOCENT

func check_end_game() -> int:
	return Global.PLAYER_ROLE.NONE

func player_join_early(_player: Player):
	pass

func game_start():
	for player in game.get_players():
		player.current_role = choose_role_for_player(player)
		#player.kill_cooldown = 500

func game_tick():
	pass

func game_end():
	pass

func show_results(_label: Label, _player: Player):
	pass

func role_reveal(_label: Label, _player: Player):
	pass

func change_map(map: String):
	game._change_map(map)

func update_player(_player: Player):
	pass

func can_start_game() -> String:
	return "OK"

func update_actions(_btn1: TextureButton, _btn2: TextureButton, _btn3: TextureButton, _btn4: TextureButton):
	pass

func player_do_action(_player: Player, _action: int):
	pass

func bot_tick(bot: Player):
	bot.bot_walk_rand()

# Network functions to make the gamemode be synced properly
func network_save() -> Dictionary:
	return {}

func network_load(_data: Dictionary):
	pass

func receive_custom_rpc(_data: Dictionary, _id: int):
	pass
