extends Panel

enum TerminalState {
	TYPING,
	DIALING,
}

var TERMINAL_GREEN: Color = Color8(57, 255, 20, 255)
var BG_TERMINAL_GREEN: Color = Color8(11, 50, 4, 255)
var FONT_SIZE: int = 12

var last_sibling_index: int
var old_max_scroll_height: float = 0.0

var terminal_history_container: ScrollContainer
var vbox_container: VBoxContainer
var cmd_prompt_textedit: TextEdit
var terminal_history_scrollbar: VScrollBar
var telco_network
var terminal_noises: Node
var num_typing_noises: int
var animation_timing: float
var animation_label: Label
var msg_buffer: Array[Dictionary]

var signal_bus

var connected_telco: String
var terminal_state: TerminalState

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("terminal: loading")
	terminal_history_container = $"TerminalHistory"
	vbox_container = $"TerminalHistory/VBoxContainer"
	cmd_prompt_textedit = $"TerminalHistory/VBoxContainer/HBoxContainer/CmdPrompt"
	terminal_history_scrollbar = $"TerminalHistory".get_v_scroll_bar()
	telco_network = $"../TelcoNetwork"
	terminal_noises = $"TerminalNoises"

	var dir = DirAccess.open("res://assets/sounds/typing")
	assert(dir != null, "Failed to open telcos directory")

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var type_count = 1
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".wav"):
				print("loading typing noise: ", file_name)
				var new_typing_noise = AudioStreamPlayer.new()
				new_typing_noise.name = "type" + str(type_count)
				new_typing_noise.stream = load("res://assets/sounds/typing/" + file_name)
				terminal_noises.add_child(new_typing_noise)
				type_count += 1
			file_name = dir.get_next()
		num_typing_noises = type_count - 1

	signal_bus = $"../SignalBus"
	signal_bus.terminal_stdout.connect(add_to_history)
	signal_bus.terminal_stderr.connect(_on_stderr)
	signal_bus.change_telco.connect(_on_change_telco)
	signal_bus.terminal_state.connect(_on_terminal_state)

	last_sibling_index = vbox_container.get_child_count() - 2
	connected_telco = "telco1"
	terminal_state = TerminalState.TYPING
	msg_buffer = []

	cmd_prompt_textedit.grab_focus()
	print(vbox_container.get_tree_string_pretty())
	print("terminal: done")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if old_max_scroll_height < terminal_history_scrollbar.max_value:
		adjust_scrollbar()
		old_max_scroll_height = terminal_history_scrollbar.max_value
	
	match terminal_state:
		TerminalState.TYPING:
			pass
		TerminalState.DIALING:
			var fps: float = 3.0
			var num_frames: int = 3
			var duration: int = 3
			animation_timing += delta
			var dialing_msg = "dialing" + ".".repeat(int(animation_timing / (1.0 / fps)) % num_frames)
			animation_label.text = dialing_msg

			if animation_timing > duration:
				signal_bus.terminal_state.emit("TYPING")
	
	
func _input(event):
	if event is InputEventKey and event.is_pressed() and !event.is_echo():
		if event.keycode == KEY_ENTER:
			terminal_noises.get_node("enter").play()
		elif event.keycode == KEY_BACKSPACE:
			terminal_noises.get_node("backspace").play()
		else:
			var type_sound_name = "type" + str(randi() % num_typing_noises + 1)
			terminal_noises.get_node(type_sound_name).play()

	if Input.is_action_just_released("cmd_enter"):
		print("consuming textedit")
		var cmd = consume_text().strip_edges(true, true)
		add_to_history("> " + cmd)
		
		telco_network.run_cmd(connected_telco, cmd)


func consume_text() -> String:
		var cmd = cmd_prompt_textedit.text
		cmd_prompt_textedit.text = ''
		
		return cmd


func adjust_scrollbar() -> void:
	if terminal_history_scrollbar != null:
		terminal_history_container.scroll_vertical = terminal_history_scrollbar.max_value

func add_to_history(text: String, is_stderr: bool = false) -> void:
	print("adding to history: ", text)
	print("terminal state: ", TerminalState.keys()[terminal_state])
	if terminal_state == TerminalState.TYPING:
		var label = Label.new()
		label.name = text
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_color_override("font_color", TERMINAL_GREEN)
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		
		var last_sibling = vbox_container.get_child(last_sibling_index)
		last_sibling_index += 1
		last_sibling.add_sibling(label)

		if is_stderr:
			terminal_noises.get_node("stderr").play()
	else:
		var msg = {"text": text, "is_stderr": is_stderr}
		msg_buffer.append(msg)


func _on_stderr(msg: String) -> void:
	add_to_history(msg, true)


func _on_change_telco(new_telco_name: String, username: String) -> void:
	print("main: changing telco to ", username, "@", new_telco_name)
	connected_telco = new_telco_name

	var telcOS = telco_network.get_telco(connected_telco)
	telcOS.initialize_session(username)


func _on_terminal_state(state: String) -> void:
	terminal_state = TerminalState.get(state)

	match terminal_state:
		TerminalState.TYPING:
			cmd_prompt_textedit.grab_focus()
			while msg_buffer.size() > 0:
				var msg = msg_buffer.pop_front()
				add_to_history(msg.text, msg.is_stderr)
		TerminalState.DIALING:
			animation_timing = 0.0
			animation_label = vbox_container.get_child(last_sibling_index)
			cmd_prompt_textedit.release_focus()
			terminal_noises.get_node("dial").play()
