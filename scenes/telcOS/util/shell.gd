class_name Shell

var builtin_commands: Array[String]
var guest_commands: Array[String]

func _init(builtins: Array[String] = [], guest: Array[String] = []):
	self.builtin_commands = builtins
	self.guest_commands = guest


func assign_builtin_cmds(builtins: Array[String]):
	for cmd in builtins:
		if cmd != "":
			self.builtin_commands.append(cmd)


func assign_guest_cmds(guest: Array[String]):
	for cmd in guest:
		if cmd != "":
			self.guest_commands.append(cmd)