extends Node

var music = {
	"title": load("res://assets/music/fakedcubes_theme_new.ogg"),
	"title_old": load("res://assets/music/fakedcubes_theme.ogg")
}

var music_player: AudioStreamPlayer

var current_music: String = ""

var is_stopped: bool = true

func _ready():
	music_player = AudioStreamPlayer.new()
	
	music_player.bus = "Music"
	
	add_child(music_player)

func play_music(m: String):
	if not music.has(m): 
		push_warning("Tried to play a music that does not exist (name: " + m + ")")
		return
	
	if current_music != m:
		music_player.stop()
		
		music_player.stream = music[m]
		
		current_music = m
		
		music_player.volume_db = 0
		
		music_player.play()
	is_stopped = false
	
	fade_in()

func stop_music():
	music_player.stop()
	
	is_stopped = true
	#current_music = ""

func fade_out():
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80, 1.0)
	
	tween.tween_callback(pause)
	

func fade_in():
	if is_paused():
		resume()
	elif not music_player.playing:
		music_player.play()
	
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", 0, 0.4)

func pause():
	music_player.stream_paused = true

func resume():
	music_player.stream_paused = false

func _process(_delta):
	# Make sure to properly loop the music (in case of the audio file not having loop enabled)
	if not is_stopped and not music_player.stream_paused:
		if not music_player.playing:
			music_player.play()

func is_paused() -> bool:
	return music_player.stream_paused

func replace_music(m: String, new: AudioStream):
	music[m] = new

func mod_add_music(m: String, asset: String):
	var res = ModLoader.get_mod_asset(asset)
	
	if res is AudioStream:
		replace_music(m, res)
	else:
		print("Cannot add/replace music " + m + ": Asset must be a valid audio")
