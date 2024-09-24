class_name MusicPlayer extends Node

const BREAK_MEAN: float = 30.0
const BREAK_DEVIATION: float = 5.0

var num_songs: int
var song_timer: float
var random: RandomNumberGenerator

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var dir = DirAccess.open("res://assets/music")
	assert(dir != null, "Failed to open music directory")

	num_songs = 0

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".mp3"):
				var new_song = AudioStreamPlayer.new()
				var song_name = file_name.substr(0, file_name.length() - 4)
				print("using: " + song_name)
				new_song.name = song_name
				new_song.stream = load("res://assets/music/" + file_name)
				add_child(new_song)
				num_songs += 1
			file_name = dir.get_next()
			
	song_timer = 0.0
	random = RandomNumberGenerator.new()
	random.randomize()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	song_timer -= delta
	
	if song_timer <= 0.0:
		var audio_stream_player = get_child(randi() % num_songs)
		audio_stream_player.play()
		song_timer = audio_stream_player.stream.get_length() + random.randfn(BREAK_MEAN, BREAK_DEVIATION)
