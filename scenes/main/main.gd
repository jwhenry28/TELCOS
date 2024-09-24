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

	# print(get_tree_string_pretty())
	# $"Comms".play_cutscene("test")
	print("main: done\n\n")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func handle_query(query: Dictionary) -> bool:
	var telco_name = query["telco"]
	var telco = telco_network.get_telco(telco_name)
	var state_event = query["state_event"]
	var args = query["args"]

	var ret = false

	match state_event:
		"last_cmd":
			var cmd = ""
			var argv = []
			var success = true

			if "cmd" in args:
				cmd = args["cmd"]
			if "argv" in args:
				argv = args["argv"]
			if "success" in args:
				success = args["success"]
			
			if telco.session.user.terminal_history.size() < 1:
				return false
			
			var last_cmd = telco.session.user.terminal_history[-1]

			print("last_cmd: ", last_cmd)

			ret = last_cmd["cmd"] == cmd and last_cmd["success"] == success
			# TODO - check argv
		"current_user":
			var username = ""

			if "username" in args:
				username = args["username"]
			
			print("comparing ", username, " to ", telco.session.user.username)
			ret = username == telco.session.user.username
			
	return ret
			
