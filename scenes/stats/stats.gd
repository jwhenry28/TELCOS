extends Panel

const TERMINAL_GREEN: Color = Color8(57, 255, 20, 255)
const BG_TERMINAL_GREEN: Color = Color8(11, 50, 4, 255)
const FONT_SIZE: int = 12

var credentials: VBoxContainer
var files: VBoxContainer
var services: VBoxContainer
var title: Label

var signal_bus

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	title = $"Label"
	credentials = $"CredentialsContainer/ScrollContainer/VBoxContainer"
	files = $"FilesContainer/ScrollContainer/VBoxContainer"
	services = $"ServicesContainer/ScrollContainer/VBoxContainer"

	signal_bus = $"../SignalBus"
	signal_bus.stats_add.connect(_on_stats_add)
	signal_bus.terminal_change_telco.connect(_on_terminal_change_telco)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_terminal_change_telco(new_telco: String, _username: String):
	print("stats: freeing all lists")
	for node in [credentials, files, services]:
		for child in node.get_children():
			print("stats: freeing " + child.name)
			remove_child(child)
			child.free()
	
	print(credentials.get_tree_string_pretty())
	
	title.text = new_telco.to_upper()
	
	var telco_network = $"../TelcoNetwork"
	var new_telco_node = telco_network.get_telco(new_telco)
	var new_stats = new_telco_node.stats
	
	for type in ["credentials", "files", "services"]:
		for stat in new_stats[type]:
			print("stats: adding ", type, ":", stat, " to ", new_telco)
			_on_stats_add(type, stat)


func _on_stats_add(stat_name: String, value: String):
	print("stats: _on_stats_add for ", stat_name, ":", value)
	var stat_node = null
	match stat_name:
		'credentials':
			stat_node = credentials
		'files':
			stat_node = files
		'services':
			stat_node = services
	
	assert(stat_node != null, "stats: unknown stat_name: " + stat_name)
	
	var node_name = value.md5_text()
	if stat_node.get_node(node_name) != null:
		print("stats: duplicate")
		print(stat_node.get_tree_string_pretty())
		return
	
	var label = Label.new()
	label.name = node_name
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", TERMINAL_GREEN)
	label.add_theme_font_size_override("font_size", FONT_SIZE)

	stat_node.add_child(label)
