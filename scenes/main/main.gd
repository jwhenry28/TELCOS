extends Node

var terminal
var telcOS

var telco_name

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("main: loading")
	terminal = $"Terminal"
	telcOS = $"OS"

	telco_name = "telco1"
	var username = "telco1"
	var starting_dir = "/home/telco1"
	telcOS.initialize_telco(telco_name, username, starting_dir)
	print("main: done")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_released("cmd_enter"):
		var cmd = terminal.consume_text().strip_edges(true, true)
		terminal.add_to_history("> " + cmd)
		var result:CmdIO = telcOS.run_cmd(cmd)
		if result.stdout != "":
			terminal.add_to_history(result.stdout)
