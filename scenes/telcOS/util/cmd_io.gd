class_name CmdIO

var stdout: String
var return_code: int

func _init():
	self.stdout = ""
	self.return_code = 0

func log(output: String, end: String = "\n") -> void:
	self.stdout += output + end

func set_return_code(code: int) -> void:
	self.return_code = code