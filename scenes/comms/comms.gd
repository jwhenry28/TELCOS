class_name Comms extends Panel

const TYPE_STEP = 0.05
const WAIT = 0.5

const TERMINAL_GREEN: Color = Color8(57, 255, 20, 255)
const BG_TERMINAL_GREEN: Color = Color8(11, 50, 4, 255)
const FONT_SIZE: int = 12

var terminal_history_container: ScrollContainer
var vbox_container: VBoxContainer
var terminal_history_scrollbar: VScrollBar
var signal_bus

var dialogue: Dictionary
var dialogue_timer: float
var dialogue_index: int
var old_max_scroll_height: float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var file = "res://assets/cutscenes/tutorial.json"
	var json_string = FileAccess.get_file_as_string(file)
	dialogue = JSON.parse_string(json_string)

	terminal_history_container = $"ScrollContainer"
	vbox_container = $"ScrollContainer/VBoxContainer"
	terminal_history_scrollbar = $"ScrollContainer".get_v_scroll_bar()
	signal_bus = $"../SignalBus"
	
	dialogue_timer = 0.0
	dialogue_index = 0
	old_max_scroll_height = 0.0

	var new_label = Label.new()
	vbox_container.add_child(new_label)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if old_max_scroll_height < terminal_history_scrollbar.max_value:
		adjust_scrollbar()
		old_max_scroll_height = terminal_history_scrollbar.max_value
	
	dialogue_timer += delta

	if dialogue["dialogue"][dialogue_index] == "":
		if dialogue_timer > WAIT:
			dialogue_timer = 0.0
			var label = Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
			label.add_theme_color_override("font_color", TERMINAL_GREEN)
			label.add_theme_font_size_override("font_size", FONT_SIZE)
			vbox_container.add_child(label)
			signal_bus.play_sound.emit("enter")
			dialogue_index += 1
	else:
		if dialogue_timer > TYPE_STEP:
			dialogue_timer = 0.0
			var num_children = vbox_container.get_child_count()
			var current_label = vbox_container.get_child(num_children - 1)
			current_label.text += dialogue["dialogue"][dialogue_index][0]
			dialogue["dialogue"][dialogue_index] = dialogue["dialogue"][dialogue_index].substr(1)
			signal_bus.play_sound.emit("key")
	

func adjust_scrollbar() -> void:
	if terminal_history_scrollbar != null:
		terminal_history_container.scroll_vertical = int(terminal_history_scrollbar.max_value)
