extends CanvasLayer

@onready var progress: ProgressBar = $progress
@onready var randimg: TextureRect = $randimg
@onready var artcredit: Label = $artcredit
@onready var loadlabel: Label = $loadlabel

func _ready():
	visible = false

func show_screen():
	visible = true
	progress.value = 0
	loadlabel.text = tr("Loading...")
	
	if not Global.is_dedicated_server:
		choose_random_art()

func choose_random_art():
	var art = GameData.loading_screen_art.pick_random()
	
	randimg.texture = art["art"]
	artcredit.text = art["credits"]

func set_progress(val: float):
	progress.value = val

func hide_screen():
	visible = false
