class_name Cmd

var name: String
var help: String
var callback: Callable

func _init(new_name: String, new_help: String, new_callback: Callable):
	self.name = new_name
	self.help = new_help
	self.callback = new_callback

