extends Panel

const TERMINAL_GREEN: Color = Color8(57, 255, 20, 255)
const BG_TERMINAL_GREEN: Color = Color8(11, 50, 4, 255)
const FONT_SIZE: int = 12

var credentials: VBoxContainer
var files: VBoxContainer
var services: VBoxContainer

var signal_bus

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	credentials = $"CredentialsContainer/ScrollContainer/VBoxContainer"
	files = $"FilesContainer/ScrollContainer/VBoxContainer"
	services = $"ServicesContainer/ScrollContainer/VBoxContainer"

	signal_bus = $"../SignalBus"
	signal_bus.stats_add.connect(_on_stats_add)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_stats_add(stat_name: String, value: String):
	var label = Label.new()
	label.name = value
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", TERMINAL_GREEN)
	label.add_theme_font_size_override("font_size", FONT_SIZE)

	match stat_name:
		'credentials':
			credentials.add_child(label)
		'files':
			files.add_child(label)
		'services':
			services.add_child(label)
