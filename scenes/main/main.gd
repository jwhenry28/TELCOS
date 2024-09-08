extends Node

var terminal
var telcOS

var telco_name

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("main: loading")
	terminal = $"Terminal"
	telcOS = $"OS"

	telco_name = 'telco1'
	telcOS.load_telco(telco_name)
	print("main: done")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_released("cmd_enter"):
		var cmd = terminal.consume_text()
		terminal.add_to_history("> " + cmd)
		var result = telcOS.run_cmd(cmd)
		terminal.add_to_history(result)
