extends Panel

enum TerminalState {
	TYPING,
	DIALING,
	INACTIVE,
}

const TERMINAL_GREEN: Color = Color8(57, 255, 20, 255)
const BG_TERMINAL_GREEN: Color = Color8(11, 50, 4, 255)
const FONT_SIZE: int = 12
const DIAL_DURATION: float = 2.5

var next_msg_index: int
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
	terminal_noises = $"../SoundPlayer"

	signal_bus = $"../SignalBus"
	signal_bus.terminal_stdout.connect(add_to_history)
	signal_bus.terminal_stderr.connect(_on_stderr)
	signal_bus.terminal_change_telco.connect(_on_change_telco)
	signal_bus.terminal_change_state.connect(_on_terminal_state_change)

	next_msg_index = vbox_container.get_child_count() - 1
	print("next_msg_index: ", next_msg_index)
	connected_telco = "telco1"
	terminal_state = TerminalState.TYPING
	msg_buffer = []
	mouse_default_cursor_shape = Control.CURSOR_ARROW

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
			print("dialing")
			print("animation_timing: ", animation_timing)
			var fps: float = 3.0
			var num_frames: int = 3
			var duration: int = 3
			animation_timing += delta
			var num_dots = int(animation_timing / (1.0 / fps)) % num_frames
			var dialing_msg = "dialing" + ".".repeat(num_dots)
			animation_label.text = dialing_msg

			if animation_timing > DIAL_DURATION:
				print("exceeded duration")
				_on_terminal_state_change("TYPING")
		TerminalState.INACTIVE:
			pass
	
	
func _input(event):
	if event is InputEventKey and event.is_pressed() and !event.is_echo():
		if event.keycode == KEY_ENTER:
			signal_bus.play_sound.emit("enter")
		elif event.keycode == KEY_BACKSPACE:
			signal_bus.play_sound.emit("backspace")
		else:
			signal_bus.play_sound.emit("key")

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
		terminal_history_container.scroll_vertical = int(terminal_history_scrollbar.max_value)


func add_to_history(text: String, is_stderr: bool = false) -> void:
	print("adding to history: ", text)
	print("terminal state: ", TerminalState.keys()[terminal_state])
	if terminal_state == TerminalState.TYPING or terminal_state == TerminalState.INACTIVE:
		var label = Label.new()
		label.name = text
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_color_override("font_color", TERMINAL_GREEN)
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		
		print("next_msg_index: ", next_msg_index)
		# var last_sibling = vbox_container.get_child(next_msg_index)
		# print("adding sibling to: ", last_sibling.name)
		# next_msg_index += 1
		# last_sibling.add_sibling(label)
		vbox_container.add_child(label)
		vbox_container.move_child(label, next_msg_index)
		next_msg_index += 1

		if is_stderr:
			terminal_noises.get_node("stderr").play()
	else:
		var msg = {"text": text, "is_stderr": is_stderr}
		print("adding to buffer: ", msg)
		msg_buffer.append(msg)


func terminal_dial(telco_name: String, username: String = "guest", password: String = "") -> void:
	add_to_history("dialing...")
	_on_terminal_state_change("DIALING")
	var data = "dial.service " + username + ":" + password + "@" + telco_name
	signal_bus.network_data.emit("terminal", telco_name, data)


func _on_stderr(msg: String) -> void:
	add_to_history(msg, true)


func _on_change_telco(new_telco_name: String, username: String) -> void:
	print("terminal: changing telco to ", username, "@", new_telco_name)
	connected_telco = new_telco_name

	# var telcOS = telco_network.get_telco(connected_telco)
	# telcOS.initialize_session(username)


func _on_terminal_state_change(state: String) -> void:
	terminal_state = TerminalState.get(state)
	print("terminal_state is now: ", terminal_state)

	match terminal_state:
		TerminalState.TYPING:
			cmd_prompt_textedit.focus_mode = Control.FOCUS_ALL
			cmd_prompt_textedit.grab_focus()
			while msg_buffer.size() > 0:
				var msg = msg_buffer.pop_front()
				add_to_history(msg.text, msg.is_stderr)
		TerminalState.DIALING:
			animation_timing = 0.0
			print("animation_label: ", vbox_container.get_child(next_msg_index-1).name)
			animation_label = vbox_container.get_child(next_msg_index-1)
			cmd_prompt_textedit.release_focus()
			signal_bus.play_sound.emit("dial")
		TerminalState.INACTIVE:
			cmd_prompt_textedit.focus_mode = Control.FOCUS_NONE
			cmd_prompt_textedit.release_focus()
