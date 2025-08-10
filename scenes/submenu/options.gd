extends Node2D

var is_discord_loaded = GDExtensionManager.is_extension_loaded("res://addons/discord-rpc-gd/bin/discord-rpc-gd.gdextension")

func _ready() -> void:
	$ui/tabs/Game/Settings/Username/Value.text = Global.client_info["username"]
	
	if not is_discord_loaded:
		$ui/tabs/Game/Settings/AutoChangeName.visible = false

func _process(_delta: float) -> void:
	$ui/tabs/Game/Settings/Username/Value.editable = not $ui/tabs/Game/Settings/AutoChangeName.button_pressed
