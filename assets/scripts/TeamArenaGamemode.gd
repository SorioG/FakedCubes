extends "res://assets/scripts/ArenaGamemode.gd"

var player_team: Dictionary = {}

func game_start():
	super()
	
	for player in game.get_players():
		player_team[player] = randi_range(1,2)
