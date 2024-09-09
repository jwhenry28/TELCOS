extends Node

var terminal
var telco_network
var signal_bus


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("main: loading")
	terminal = $"Terminal"
	telco_network = $"TelcoNetwork"
	signal_bus = $"SignalBus"
	print("main: done")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_released("cmd_enter"):
		var cmd = terminal.consume_text().strip_edges(true, true)
		terminal.add_to_history("> " + cmd)
		
		var result:CmdIO = telco_network.run_cmd(cmd)
		# if result.stdout != "":
		# 	terminal.add_to_history(result.stdout)
