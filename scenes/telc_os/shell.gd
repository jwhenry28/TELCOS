class_name Shell extends Node


var builtin_commands: Array[String]
var guest_commands: Array[String]

func _init(builtins: Array[String] = [], guest: Array[String] = []):
	self.builtin_commands = builtins
	self.guest_commands = guest

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func assign_builtin_cmds(builtins: Array[String]):
	for cmd in builtins:
		if cmd != "":
			self.builtin_commands.append(cmd)


func assign_guest_cmds(guest: Array[String]):
	for cmd in guest:
		if cmd != "":
			self.guest_commands.append(cmd)
