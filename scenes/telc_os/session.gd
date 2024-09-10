class_name Session extends Node

var cwd: String
var username: String
var user: User

func _init():
	self.cwd = ""
	self.user = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func get_username() -> String:
	if user == null:
		return ""
	return user.username

func password() -> String:
	if user == null:
		return ""
	return user.password

func home() -> String:
	if user == null:
		return ""
	return user.home

func path() -> String:
	if user == null:
		return ""
	return user.path
