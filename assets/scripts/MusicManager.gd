extends Node

var music = {
	"title": load("res://assets/music/fakedcubes_theme_new.ogg")
}

var music_player: AudioStreamPlayer

var current_music: String = ""

func _ready():
	music_player = AudioStreamPlayer.new()
	
	music_player.bus = "Music"
	
	add_child(music_player)

func play_music(m: String):
	if not music.has(m): return
	
	if current_music != m:
		music_player.stop()
		
		music_player.stream = music[m]
		
		current_music = m
		
		music_player.volume_db = 0
		
	
	fade_in()

func stop_music():
	music_player.stop()
	
	current_music = ""

func fade_out():
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80, 2.0)
	
	tween.tween_callback(music_player.stop)
	

func fade_in():
	if not music_player.playing:
		music_player.play()
	
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", 0, 0.2)

func _process(_delta):
	pass

func replace_music(m: String, new: AudioStream):
	music[m] = new

func mod_add_music(m: String, asset: String):
	var res = ModLoader.get_mod_asset(asset)
	
	if res is AudioStream:
		replace_music(m, res)
	else:
		print("Cannot add/replace music " + m + ": Asset must be a valid audio")
