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

	$"Comms".play_cutscene("tutorial")
	print("main: done\n\n")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
