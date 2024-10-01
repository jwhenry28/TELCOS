extends Node

# You can define any params to passthrough here if needed
signal network_data(source: String, destination: String, data: String)
signal terminal_change_state(state: String)
signal terminal_change_telco(new_telco_name: String, username: String)
signal terminal_stdout(msg: String)
signal terminal_stderr(msg: String)
signal play_sound(sound_name: String)
signal stats_add(stat_name: String, value: String)


func _ready() -> void:
	print("signal_bus: loading")
	print("signal_bus: done")
