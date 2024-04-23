extends InteractableObject

func on_used(action: int):
	if action == 1:
		var gameinfo: PopupPanel = c_game.get_local_player().hud.get_node("gameinfo")
		
		gameinfo.popup()
		
		gameinfo.get_node("tabs").current_tab = 0
		
		if not Global.is_mobile:
			gameinfo.get_node("tabs/Player/TabContainer/Skin/VBoxContainer/skinbuiltin/skins").get_children()[0].grab_focus()
