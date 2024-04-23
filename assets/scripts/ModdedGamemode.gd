extends "res://assets/scripts/BaseGamemode.gd"

# Gamemode Class intended to be easy to mod (with lua hooks)

func game_tick():
	ModLoader.call_hook("gamemode_tick", [])

func check_end_game():
	var res = ModLoader.call_hook("gamemode_check_end", [])
	
	if res:
		return res
	
	return Global.PLAYER_ROLE.NONE

func game_start():
	super()
	
	var reveal = ModLoader.call_hook("gamemode_try_reveal", [])
	
	if reveal:
		can_reveal_role = true
	else:
		can_reveal_role = false
	
	ModLoader.call_hook("gamemode_started", [])

func choose_role_for_player(_player: Player) -> int:
	var res = ModLoader.call_hook("gamemode_choose_role", [_player])
	
	if res:
		return res
	
	return Global.PLAYER_ROLE.INNOCENT

func player_join_early(_player: Player):
	ModLoader.call_hook("gamemode_joined_early", [_player])

func game_end():
	ModLoader.call_hook("gamemode_ended", [])

func bot_tick(bot: Player):
	if ModLoader.call_hook("gamemode_bot_tick", [bot]): return
	
	super(bot)

func can_start_game() -> String:
	var res = ModLoader.call_hook("gamemode_try_start", [])
	
	if res:
		return res
	
	return "OK"

func update_player(_player: Player):
	ModLoader.call_hook("gamemode_update_player", [_player])

func show_results(_label: Label, _player: Player):
	ModLoader.call_hook("gamemode_show_results", [_label, _player])

func role_reveal(_label: Label, _player: Player):
	ModLoader.call_hook("gamemode_role_reveal", [_label, _player])

func receive_custom_rpc(_data: Dictionary, _id: int):
	ModLoader.call_hook("receive_custom_rpc", [_data, _id])

func player_do_action(_player: Player, _action: int):
	ModLoader.call_hook("gamemode_player_action", [_player, _action])

func update_actions(_btn1: TextureButton, _btn2: TextureButton, _btn3: TextureButton, _btn4: TextureButton):
	ModLoader.call_hook("gamemode_update_actions", [_btn1, _btn2, _btn3, _btn4])
