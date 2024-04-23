extends Node

var player_skins: Dictionary = {
	"Default": {
		"skin": load("res://assets/sprites/player-default.png"),
		"icon": load("res://assets/sprites/skinicons/default.png")
	},
	"Robot": {
		"skin": load("res://assets/sprites/player-bot.png"),
		"icon": load("res://assets/sprites/skinicons/bot.png")
	},
	"Killer": {
		"skin": load("res://assets/sprites/player-killer.png"),
		"icon": load("res://assets/sprites/skinicons/killer.png")
	},
	"Squashed": {
		"skin": load("res://assets/sprites/player-squashed.png"),
		"icon": load("res://assets/sprites/skinicons/squashed.png")
	},
	"Reddy": {
		"skin": load("res://assets/sprites/player-blockscape.png"),
		"icon": load("res://assets/sprites/skinicons/blockscape.png")
	},
	"Cubette": {
		"skin": load("res://assets/sprites/player-female.png"),
		"icon": load("res://assets/sprites/skinicons/female.png")
	},
	"Deal With It": {
		"skin": load("res://assets/sprites/player-glasses.png"),
		"icon": load("res://assets/sprites/skinicons/glasses.png")
	},
	"Square Glasses": {
		"skin": load("res://assets/sprites/player-glasses2.png"),
		"icon": load("res://assets/sprites/skinicons/glasses2.png")
	},
	"Mini": {
		"skin": load("res://assets/sprites/player-mini.png"),
		"icon": load("res://assets/sprites/skinicons/mini.png")
	},
}

var player_hats: Dictionary = {
	"None": load("res://assets/sprites/hats/hat1.png"),
	"Top Hat": load("res://assets/sprites/hats/hat2.png"),
	"Googly Eyes": load("res://assets/sprites/hats/hat4.png"),
	"Inside of the Box": load("res://assets/sprites/hats/hat5.png"),
	"Doctor's Mask": load("res://assets/sprites/hats/hat6.png"),
	"Spiky Hat": load("res://assets/sprites/hats/hat7.png"),
	"Cube Clones": load("res://assets/sprites/hats/hat8.png"),
	"Headphones": load("res://assets/sprites/hats/hat9.png")
}
