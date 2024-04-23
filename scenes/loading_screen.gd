extends CanvasLayer

@onready var progress: ProgressBar = $progress
@onready var randimg: TextureRect = $randimg
@onready var loadlabel: Label = $loadlabel

func _ready():
	visible = false

func show_screen():
	visible = true
	progress.value = 0
	loadlabel.text = "Loading..."

func set_progress(val: float):
	progress.value = val

func hide_screen():
	visible = false
