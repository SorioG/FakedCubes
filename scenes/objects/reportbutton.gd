extends InteractableObject

func on_used(action: int):
	if action != 1: return
	
	if c_game.gamemode_node is ImpostorGamemode:
		if c_game.local_player.is_killed:
			Global.alert("You cannot accuse players while you're dead.", "Error")
			return
		
		if c_game.gamemode_node.get("vote_in_session"):
			Global.alert("You cannot accuse players while the vote is in session.", "Error")
			return
		
		c_game.local_player.ask_to_pick_player("Accuse a player", true, true, "report")
