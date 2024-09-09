extends Node

var current_telco_name: String
var signal_bus

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var dir = DirAccess.open("res://assets/telcos")
	assert(dir != null, "Failed to open telcos directory")

	signal_bus = $"../SignalBus"
	signal_bus.change_telco.connect(_on_change_telco)

	current_telco_name = "telco1"

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".xml"):
				print("loading telco: " + file_name)
				var new_telco = TelcOS.new()
				var telco_name = file_name.replace(".xml", "")
				print("telco name: " + telco_name)
				new_telco.name = telco_name
				self.add_child(new_telco)
				new_telco.initialize_telco(telco_name)
				print("telco added")
			file_name = dir.get_next()


func get_telco(telco_name: String) -> TelcOS:
	for telco in self.get_children():
		if telco.name == telco_name:
			return telco
	return null


func run_cmd(cmd: String) -> CmdIO:
	var telcOS = get_telco(current_telco_name)
	return telcOS.run_cmd(cmd)


func _on_change_telco(new_telco_name: String, username: String) -> void:
	print("main: changing telco to ", username, "@", new_telco_name)
	current_telco_name = new_telco_name

	var telcOS = get_telco(current_telco_name)
	telcOS.initialize_session(username)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
