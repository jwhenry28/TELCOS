class_name FileSystem extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("filesystem: loading")
	print("filesystem: done")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func initialize_filesystem(file_permissions:Dictionary, file_properties:Dictionary) -> void:
	var root_node = $"root"
	root_node.initialize("root", "dir", file_permissions, file_properties, true)


func get_root_node() -> iNode:
	return $"root"
