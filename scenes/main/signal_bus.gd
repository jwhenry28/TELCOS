extends Node

# You can define any params to passthrough here if needed
signal network_data(source: String, destination: String, data: String)
signal terminal_state(state: String)
signal change_telco(new_telco_name: String, username: String)
signal terminal_stdout(msg: String)
signal terminal_stderr(msg: String)


func _ready() -> void:
	print("signal_bus: loading")
	print("signal_bus: done")
