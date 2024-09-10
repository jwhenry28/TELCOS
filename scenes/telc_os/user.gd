class_name User extends Node

var username: String
var password: String
var home: String
var path: String

func initialize(new_username:String, new_password:String, new_home:String, new_path:String = ""):
	assert (new_username != "" and new_password != "", "New users require a username and password")

	self.name = new_username
	self.username = new_username
	self.password = new_password
	self.home = new_home
	self.path = new_path


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _to_string() -> String:
	return username + ":" + password + " " + home + " " + path
