extends HBoxContainer

func _ready():
	update()

func update():
	$vert/username.text = Global.client_info["username"]
	$vert/uuid.text = Global.client_info["uuid"]
	
	var avatar: Image = Global.get_skin_still_image(Global.get_skin_by_name(Global.client_info["skin"]))
	
	$avatar.texture = ImageTexture.create_from_image(avatar)
	$avatar.tooltip_text = Global.client_info["skin"]
