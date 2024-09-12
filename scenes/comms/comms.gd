class_name Comms extends Panel

enum CommState {
	INACTIVE,
	CUTSCENE,
}

const TYPE_STEP = 0.05
const WAIT = 0.5

const TERMINAL_GREEN: Color = Color8(57, 255, 20, 255)
const BG_TERMINAL_GREEN: Color = Color8(11, 50, 4, 255)
const FONT_SIZE: int = 12

var terminal_history_container: ScrollContainer
var vbox_container: VBoxContainer
var terminal_history_scrollbar: VScrollBar
var signal_bus

var cutscene: Dictionary
var comm_state: CommState

var old_max_scroll_height: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	terminal_history_container = $"ScrollContainer"
	vbox_container = $"ScrollContainer/VBoxContainer"
	terminal_history_scrollbar = $"ScrollContainer".get_v_scroll_bar()
	signal_bus = $"../SignalBus"

	comm_state = CommState.INACTIVE


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	adjust_scrollbar()
			
	

func play_cutscene(cutscene_name: String) -> void:
	print("playing cutscene: ", cutscene_name)
	var file = "res://assets/cutscenes/" + cutscene_name + ".json"
	assert(FileAccess.file_exists(file), "Cutscene file not found: " + file)

	var json_string = FileAccess.get_file_as_string(file)
	print("json_string: ", json_string)
	cutscene = JSON.parse_string(json_string)

	get_tree().call_group("cutscene_labels", "queue_free")
	var new_label = Label.new()
	new_label.add_to_group("cutscene_labels")
	vbox_container.add_child(new_label)

	comm_state = CommState.CUTSCENE
	advance_cutscene()



func advance_cutscene() -> void:
	var current_dialogue = cutscene["dialogue"].pop_front()
	if current_dialogue == null:
		comm_state = CommState.INACTIVE
		return

	print("current_dialogue: ", current_dialogue)
	match current_dialogue["type"]:
		"dialogue":
			var label = Label.new()
			label.text = current_dialogue["speaker"] + "> "
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
			label.add_theme_color_override("font_color", TERMINAL_GREEN)
			label.add_theme_font_size_override("font_size", FONT_SIZE)
			label.add_to_group("cutscene_labels")
			vbox_container.add_child(label)
			await type_text(current_dialogue["text"], label)
			signal_bus.play_sound.emit("enter")
		"pause":
			print("pause:", current_dialogue["duration"])
			await get_tree().create_timer(current_dialogue["duration"]).timeout
		"action":
			match current_dialogue["callback"]:
				"play_sound":
					signal_bus.play_sound.emit(current_dialogue["args"][0])
	
	advance_cutscene()


func type_text(text: String, label: Label) -> void:	
	for c in text:
		label.text += c
		signal_bus.play_sound.emit("key")
		await get_tree().create_timer(TYPE_STEP).timeout
	


func adjust_scrollbar() -> void:
	if terminal_history_scrollbar != null and old_max_scroll_height < terminal_history_scrollbar.max_value:
		terminal_history_container.scroll_vertical = int(terminal_history_scrollbar.max_value)
		old_max_scroll_height = terminal_history_scrollbar.max_value
