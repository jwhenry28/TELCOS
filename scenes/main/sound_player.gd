class_name SoundPlayer extends Node

var signal_bus

var num_typing_noises: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	signal_bus = $"../SignalBus"
	signal_bus.play_sound.connect(_on_sound_play)

	var dir = DirAccess.open("res://assets/sounds/typing")
	assert(dir != null, "Failed to open telcos directory")

	num_typing_noises = 0

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var type_count = 1
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".wav"):
				var new_typing_noise = AudioStreamPlayer.new()
				new_typing_noise.name = "type" + str(type_count)
				new_typing_noise.stream = load("res://assets/sounds/typing/" + file_name)
				add_child(new_typing_noise)
				type_count += 1
			file_name = dir.get_next()
		num_typing_noises = type_count - 1


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_sound_play(sound_name: String) -> void:
	match sound_name:
		"enter":
			var sound = get_node("enter")
			sound.play()
		"backspace":
			var sound = get_node("backspace")
			sound.play()
		"key":
			var sound = get_node("type" + str(randi() % num_typing_noises + 1))
			sound.play()
		"dial":
			var sound = get_node("dial")
			sound.play()
