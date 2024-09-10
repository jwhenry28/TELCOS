extends Node

@export var telcos_scene: PackedScene

var signal_bus

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var dir = DirAccess.open("res://assets/telcos")
	assert(dir != null, "Failed to open telcos directory")

	signal_bus = $"../SignalBus"

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".xml"):
				print("loading telco: " + file_name)
				var new_telco = telcos_scene.instantiate()
				var telco_name = file_name.replace(".xml", "")
				print("telco name: " + telco_name)
				new_telco.name = telco_name
				self.add_child(new_telco)
				new_telco.initialize_telco(telco_name)
				print("telco added")
			file_name = dir.get_next()


func get_telco(telco_name: String):
	for telco in self.get_children():
		if telco.name == telco_name:
			return telco
	return null


func run_cmd(telco_name: String, cmd: String) -> void:
	var telcOS = get_telco(telco_name)
	telcOS.run_cmd(cmd)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
