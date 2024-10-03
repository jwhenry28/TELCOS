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
var cmd_history_index: int = 0

var terminal_history_container: ScrollContainer
var vbox_container: VBoxContainer
var cmd_prompt_textedit: TextEdit
var terminal_history_scrollbar: VScrollBar
var telco_network
var terminal_noises: Node
var cursor: Node
var num_typing_noises: int
var animation_timing: float
var msg_buffer: Array[Dictionary]
var data_ack: bool

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
	cursor = $"TerminalHistory/VBoxContainer/HBoxContainer/Cursor"

	cursor.text = "> "
	cmd_prompt_textedit.placeholder_text = "..."

	signal_bus = $"../SignalBus"
	signal_bus.terminal_stdout.connect(add_to_history)
	signal_bus.terminal_stderr.connect(_on_stderr)
	signal_bus.terminal_change_telco.connect(_on_change_telco)
	signal_bus.terminal_change_state.connect(_on_terminal_state_change)
	signal_bus.network_data.connect(_on_data_recv)

	next_msg_index = vbox_container.get_child_count() - 1
	print("terminal: next_msg_index: ", next_msg_index)
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
			var fps: float = 3.0
			var num_frames: int = 4
			animation_timing += delta
			var num_dots = int(animation_timing / (1.0 / fps)) % num_frames
			var dialing_msg = "dialing" + ".".repeat(num_dots)
			var animation_label = vbox_container.get_child(next_msg_index-2)
			animation_label.text = dialing_msg

			if animation_timing > DIAL_DURATION:
				animation_label.text = "dialing..."
				if !data_ack:
					add_to_history("no answer\n", true)
				print("terminal: exceeded duration")
				_on_terminal_state_change("TYPING")
		TerminalState.INACTIVE:
			pass
	
	
func _input(event):
	if event is InputEventKey and event.is_pressed() and !event.is_echo():
		match event.keycode:
			KEY_ENTER:
				signal_bus.play_sound.emit("enter")
			KEY_BACKSPACE:
				signal_bus.play_sound.emit("backspace")
			KEY_UP:
				var terminal_history = telco_network.get_telco(connected_telco).session.user.terminal_history
				if terminal_history.size() > 0 and cmd_history_index > 0:
					cmd_history_index -= 1
					var last_cmd = terminal_history[cmd_history_index]
					var last_cmd_text = last_cmd["cmd"]
					if last_cmd["argv"].size() > 0:
						last_cmd_text += " " + " ".join(last_cmd["argv"])
					cmd_prompt_textedit.set_line(0, last_cmd_text)
			KEY_DOWN:
				var terminal_history = telco_network.get_telco(connected_telco).session.user.terminal_history
				if terminal_history.size() > 0 and cmd_history_index < terminal_history.size() - 1:
					cmd_history_index += 1
					var last_cmd = terminal_history[cmd_history_index]
					var last_cmd_text = last_cmd["cmd"]
					if last_cmd["argv"].size() > 0:
						last_cmd_text += " " + " ".join(last_cmd["argv"])
					cmd_prompt_textedit.set_line(0, last_cmd_text)
			_:
				signal_bus.play_sound.emit("key")

	if Input.is_action_just_released("cmd_enter"): # for whatever reason, Godot renders the cursor in the wrong location if we use just_pressed for enter
		var cmd = consume_text().strip_edges(true, true)

		add_to_history(cursor.text + cmd + "\n")
		
		telco_network.run_cmd(connected_telco, cmd)
		match telco_network.get_telco(connected_telco).shell.state:
			0: # LOCAL
				cursor.text = "> "
				cmd_prompt_textedit.placeholder_text = "..."
			1: # REMOTE
				cursor.text = ""
				cmd_prompt_textedit.placeholder_text = ""
			_:
				cursor.text = "@"
		
		cmd_history_index = telco_network.get_telco(connected_telco).session.user.terminal_history.size()


func consume_text() -> String:
	var cmd = cmd_prompt_textedit.text
	cmd_prompt_textedit.text = ""
	
	return cmd


func adjust_scrollbar() -> void:
	if terminal_history_scrollbar != null:
		terminal_history_container.scroll_vertical = int(terminal_history_scrollbar.max_value)


func add_to_history(text: String, is_stderr: bool = false, buffer_override = false) -> void:
	print("terminal: adding to history: [", text.replace("\n", "\\n") + "]")
	if terminal_state == TerminalState.TYPING or terminal_state == TerminalState.INACTIVE or buffer_override:
		for char in text:
			if char == "\n" or vbox_container.get_child_count() == 1:
				print("terminal: creating new label")
				var label = Label.new()
				label.text = ""
				label.visible = false
				label.autowrap_mode = TextServer.AUTOWRAP_WORD
				label.add_theme_color_override("font_color", TERMINAL_GREEN)
				label.add_theme_font_size_override("font_size", FONT_SIZE)
				
				var previous_label = vbox_container.get_child(next_msg_index - 1)
				previous_label.visible = true

				vbox_container.add_child(label)
				vbox_container.move_child(label, next_msg_index)
				next_msg_index += 1
			
			if char != "\n":
				var current_label = vbox_container.get_child(next_msg_index - 1)
				current_label.visible = true
				current_label.text += char

		if is_stderr:
			terminal_noises.get_node("stderr").play()
	else:
		var msg = {"text": text, "is_stderr": is_stderr}
		print("terminal: adding to buffer.")
		msg_buffer.append(msg)
	
	print("terminal: message logged.")


func terminal_dial(telco_name: String, username: String = "guest", password: String = "") -> void:
	add_to_history("dialing...\n")
	_on_terminal_state_change("DIALING")
	var data = "dial.service " + username + ":" + password + "@" + telco_name
	data_ack = false
	signal_bus.network_data.emit("user_terminal", telco_name, data)


func _on_stderr(msg: String) -> void:
	add_to_history(msg, true)


func _on_change_telco(new_telco_name: String, username: String) -> void:
	print("terminal: changing telco to ", username, "@", new_telco_name)
	connected_telco = new_telco_name


func _on_terminal_state_change(state: String) -> void:
	terminal_state = TerminalState.get(state)
	print("terminal: terminal_state is now: ", terminal_state)

	match terminal_state:
		TerminalState.TYPING:
			cmd_prompt_textedit.focus_mode = Control.FOCUS_ALL
			cmd_prompt_textedit.grab_focus()
			while msg_buffer.size() > 0:
				var msg = msg_buffer.pop_front()
				add_to_history(msg.text, msg.is_stderr)
		TerminalState.DIALING:
			data_ack = false
			animation_timing = 0.0
			cmd_prompt_textedit.release_focus()
			signal_bus.play_sound.emit("dial")
		TerminalState.INACTIVE:
			cmd_prompt_textedit.focus_mode = Control.FOCUS_NONE
			cmd_prompt_textedit.release_focus()


func _on_data_recv(source: String, destination: String, data: String) -> void:
	if destination != "user_terminal":
		return
	
	match data:
		"ACK":
			data_ack = true
