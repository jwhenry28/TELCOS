class_name Comms extends Panel

enum CommState {
	INACTIVE,
	READY,
	WORKING,
	WAITING,
}

const TYPE_STEP = 0.05
const WAIT = 0.5

const TERMINAL_GREEN: Color = Color8(57, 255, 20, 255)
const BG_TERMINAL_GREEN: Color = Color8(11, 50, 4, 255)
const FONT_SIZE: int = 12

var comm_history_container: ScrollContainer
var vbox_container: VBoxContainer
var comm_history_scrollbar: VScrollBar
var terminal
var signal_bus

var cutscene: Dictionary
var comm_state: CommState
var current_element

var old_max_scroll_height: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	comm_history_container = $"ScrollContainer"
	vbox_container = $"ScrollContainer/VBoxContainer"
	comm_history_scrollbar = $"ScrollContainer".get_v_scroll_bar()
	terminal = $"../Terminal"
	signal_bus = $"../SignalBus"

	comm_state = CommState.INACTIVE


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	adjust_scrollbar()

	match comm_state:
		CommState.INACTIVE:
			pass
		CommState.READY:
			comm_state = CommState.WORKING
			advance_cutscene()
		CommState.WORKING:
			pass
		CommState.WAITING:
			await handle_wait_for_state(current_element["query"])


func play_cutscene(cutscene_name: String) -> void:
	print("playing cutscene: ", cutscene_name)
	signal_bus.terminal_change_state.emit("INACTIVE")
	var file = "res://assets/cutscenes/" + cutscene_name + ".json"
	assert(FileAccess.file_exists(file), "Cutscene file not found: " + file)

	var json_string = FileAccess.get_file_as_string(file)
	cutscene = JSON.parse_string(json_string)

	get_tree().call_group("cutscene_labels", "queue_free")
	var new_label = Label.new()
	new_label.add_to_group("cutscene_labels")
	vbox_container.add_child(new_label)

	comm_state = CommState.READY


func advance_cutscene() -> void:
	current_element = cutscene["elements"].pop_front()
	if current_element == null:
		comm_state = CommState.INACTIVE
		signal_bus.terminal_change_state.emit("TYPING")
		return
	
	print("comms: processing ", current_element)

	match current_element["type"]:
		"dialogue":
			await handle_dialogue(current_element["speaker"], current_element["text"])
		"pause":
			await handle_pause(current_element["duration"])
		"action":
			await handle_action(current_element["callback"], current_element["args"])
		"wait_for_state":
			await handle_wait_for_state(current_element["query"])


func handle_dialogue(speaker: String, msg: String):
	var label = Label.new()
	label.text = speaker + "> "
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", TERMINAL_GREEN)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_to_group("cutscene_labels")
	vbox_container.add_child(label)
	await type_text(msg, label)
	signal_bus.play_sound.emit("enter")

	comm_state = CommState.READY


func handle_pause(duration: float):
	if Input.is_key_pressed(KEY_RIGHT):
		comm_state = CommState.READY
		return
	await get_tree().create_timer(duration).timeout

	comm_state = CommState.READY


func handle_action(action: String, args: Array):
	print("handling action: " + action)
	match action:
		"play_sound":
			signal_bus.play_sound.emit(args[0])
		"change_telco":
			print("comms: changing telco: " + args[0])
			signal_bus.terminal_change_telco.emit(args[0], "guest")
		"terminal_stdout":
			signal_bus.terminal_stdout.emit(args[0])

	comm_state = CommState.READY


func handle_wait_for_state(query: Dictionary):
	print("waiting for state: ", query)
	signal_bus.terminal_change_state.emit("TYPING")

	if $"/root/Main".handle_query(query):
		comm_state = CommState.READY
		return
	
	comm_state = CommState.WAITING


func type_text(text: String, label: Label) -> void:	
	for c in text:
		label.text += c
		signal_bus.play_sound.emit("key")
		var modifier: float = 1.0 
		if Input.is_key_pressed(KEY_RIGHT):
			modifier = 3.0
		await get_tree().create_timer(TYPE_STEP / modifier).timeout


func adjust_scrollbar() -> void:
	if comm_history_scrollbar != null and old_max_scroll_height < comm_history_scrollbar.max_value:
		comm_history_container.scroll_vertical = int(comm_history_scrollbar.max_value)
		old_max_scroll_height = comm_history_scrollbar.max_value
