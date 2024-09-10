class_name UsersDirectory extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func register_user(username: String, password: String, home_dir: String, path: String) -> void:
	var user = User.new()
	user.initialize(username, password, home_dir, path)
	add_child(user)


func get_users():
	return get_children()


func get_user(username: String) -> User:
	return get_node(username)
