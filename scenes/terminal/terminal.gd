class_name Terminal extends Panel

enum TerminalState {
	TYPING,
	DIALING,
	INACTIVE,
}

const DIAL_DURATION: float = 2.5

@export var _font: Font
@export var _font_size: int
@export var _font_color: Color
@export var _text_border_size_x: int # TODO: get_num_rows_in_buffer() doesn't work when this value is 2, for some reason.
@export var _text_border_size_y: int

var _CHAR_WIDTH: float
var _CHAR_HEIGHT: float
const _CURSOR: String = "█"

var _buffer: Array
var _caps_lock_enabled: bool
var _echo_timer: float
var _echo_duration_exceeded: bool
const ECHO_TIMER_DURATION: float = 0.5
const ECHO_REPEAT_TIMER_DURATION: float = 0.1

var _cursor_right_limit: int
var _cursor_idx: int
var _start_line_idx: int

var _cmd_string
var _terminal_history: Array
var _last_cmd_idx: int

var _buffered_writes: Array

const TERMINAL_NAME: String = "user_terminal"

var telco_network
var terminal_noises: Node

var num_typing_noises: int
var _animation_timing: float
var _dialing_pos: int
var _data_ack: bool

var signal_bus

var connected_telco: String
var terminal_state: TerminalState


func get_num_window_rows() -> float:
	return floor(get_window_y() / _CHAR_HEIGHT) - 1


func get_window_x() -> float:
	return size.x - (_text_border_size_x * 2.0) - _CHAR_WIDTH


func get_window_y() -> float:
	return size.y - (_text_border_size_y * 2.0) - _CHAR_HEIGHT


func get_num_rows_in_buffer() -> int:
	var line_string = ""
	var num_rows = 0
	for key in _buffer:
		if key == "\n" or key == null:
			num_rows += 1
			num_rows += floor((line_string.length() * _CHAR_WIDTH) / get_window_x())
			line_string = ""
		else:
			line_string += key
	
	return num_rows


func get_num_rows_in_buffer_old() -> int:
	var num_rows_in_buffer = 0
	var buffer_string = "".join(PackedStringArray(_buffer.slice(0, _buffer.size()-1)))
	for item in buffer_string.split("\n"):
		var tmp_rows = ceil((item.length() * _CHAR_WIDTH) / get_window_x())
		num_rows_in_buffer += tmp_rows
	print("get_rows: ret=", num_rows_in_buffer)
	return num_rows_in_buffer


func _init() -> void:
	_buffer = [ null ]
	_cmd_string = null
	_terminal_history = [ "" ]
	_buffered_writes = []
		
	_CHAR_HEIGHT = 16.0 # TODO: MOVE THIS
	_CHAR_WIDTH = 8.0 # TODO: MOVE THIS
	_caps_lock_enabled = false
	_echo_timer = -1.0
	_echo_duration_exceeded = false
	
	_cursor_idx = 0
	_cursor_right_limit = 0
	_last_cmd_idx = 0
	_start_line_idx = 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("terminal: loading")
	telco_network = $"../TelcoNetwork"
	terminal_noises = $"../SoundPlayer"

	signal_bus = $"../SignalBus"
	signal_bus.terminal_stdout.connect(_on_stdout)
	signal_bus.terminal_stderr.connect(_on_stderr)
	signal_bus.terminal_change_telco.connect(_on_change_telco)
	signal_bus.terminal_change_state.connect(_on_terminal_state_change)
	signal_bus.network_data.connect(_on_data_recv)

	terminal_state = TerminalState.TYPING

	grab_focus()
	
	print("terminal: done")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:	
	match terminal_state:
		TerminalState.TYPING:
			if _echo_timer >= 0:
				_echo_timer += delta
		TerminalState.DIALING:
			var fps: float = 3.0
			var num_frames: int = 4
			_animation_timing += delta

			var num_dots = int(_animation_timing / (1.0 / fps)) % num_frames
			for i in range(num_frames - 1):
				if i < num_dots:
					_buffer[_dialing_pos + i] = "."
				else:
					_buffer[_dialing_pos + i] = ""
			queue_redraw()

			if _animation_timing > DIAL_DURATION:
				if !_data_ack:
					write("no answer\n", true)
				print("terminal: exceeded duration")
				_on_terminal_state_change("TYPING")
		TerminalState.INACTIVE:
			pass


func _draw():
	var x_limit = get_window_x() + _text_border_size_x
	var _y_limit = get_window_y() + _text_border_size_y
	
	var x_start = _text_border_size_x
	var y_start = _CHAR_HEIGHT + _text_border_size_y
	var char_pos = Vector2(x_start, y_start)
	
	var idx = 0
		
	var line_idx = 0
	var start_line_index = _start_line_idx
	var end_line_index = _start_line_idx + min(get_num_window_rows(), get_num_rows_in_buffer())

	# print("\ndraw: _start_line_idx=", _start_line_idx)
	# print("draw: size.y=", size.y)
	# print("draw: CHAR_HEIGTH=", _CHAR_HEIGHT)
	# print("draw: _text_border_size_y=", _text_border_size_y)
	# print("draw: get_window_y()=", get_window_y())
	# print("draw: get_num_window_rows=", get_num_window_rows())
	# print("draw: get_num_rows_in_buffer=", get_num_rows_in_buffer())
	# print("draw: end_line_index=", end_line_index)
	
	for key in _buffer:
		var idx_in_range = start_line_index <= line_idx and line_idx <= end_line_index
		
		if key != null:
			var draw_key = key
			
			if key == "\n":
				draw_key = " "
				
			if idx_in_range:
				draw_char(_font, char_pos, draw_key, _font_size, _font_color)
			char_pos.x += _CHAR_WIDTH
				
			if key == "\n" or char_pos.x >= x_limit:
				if idx_in_range:
					char_pos.y += _CHAR_HEIGHT
				char_pos.x = _text_border_size_x
				line_idx += 1
			
		if idx_in_range and idx == _cursor_idx and terminal_state == TerminalState.TYPING:
			draw_char(_font, char_pos, _CURSOR, _font_size, _font_color)
		
		idx += 1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if get_num_rows_in_buffer() > get_num_window_rows():
					_start_line_idx = min(_start_line_idx + 1, get_num_rows_in_buffer() - get_num_window_rows())
				else:
					_start_line_idx = 0
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_start_line_idx = max(0, _start_line_idx - 1)
			queue_redraw()
			
	if event is InputEventKey:		
		if event.is_echo() and _echo_timer == -1.0:
			_echo_timer = 0.0
		elif !event.is_echo():
			_echo_timer = -1.0
			_echo_duration_exceeded = false
		
		var repeat = false
		if _echo_timer > ECHO_TIMER_DURATION:
			print("gui: timer exceeded")
			_echo_duration_exceeded = true
			_echo_timer = 0.0
		elif _echo_duration_exceeded and _echo_timer > ECHO_REPEAT_TIMER_DURATION:
			print("gui: repeat")
			_echo_timer = 0.0
			repeat = true			

		if event.pressed and (!event.is_echo() or repeat):
			var c = event_to_char(event)
			if c != "":
				add_to_buffer(c, c=="\n")
				_cursor_idx = _buffer.size() - 1
			
			if _cmd_string != null:
				run_command(_cmd_string)
				_cmd_string = null
			queue_redraw()


func _on_change_telco(new_telco_name: String, username: String) -> void:
	print("terminal: changing telco to ", username, "@", new_telco_name)
	connected_telco = new_telco_name


func _on_terminal_state_change(state: String) -> void:
	terminal_state = TerminalState.get(state)
	print("terminal: terminal_state is now: ", terminal_state)

	match terminal_state:
		TerminalState.TYPING:
			grab_focus()
			while _buffered_writes.size() > 0:
				var msg = _buffered_writes.pop_front()
				write(msg.text, msg.is_stderr)
		TerminalState.DIALING:
			_data_ack = false
			_animation_timing = 0.0
			_dialing_pos = _buffer.size() - 5
			release_focus()
			signal_bus.play_sound.emit("dial")
		TerminalState.INACTIVE:
			release_focus()


func _on_stdout(msg: String) -> void:
	write(msg)
	queue_redraw()


func _on_stderr(msg: String) -> void:
	write(msg, true)
	queue_redraw()


func _on_data_recv(_source: String, destination: String, data: String) -> void:
	if destination != TERMINAL_NAME:
		return
	
	match data:
		"ACK":
			_data_ack = true


func clear_current_line() -> void:
	while _cursor_idx > _cursor_right_limit:
		_buffer.remove_at(_cursor_right_limit)
		_cursor_idx -= 1
		


func add_to_buffer(text: String, append_to_buffer: bool = false) -> void:
	assert(text.length() == 1, "add_to_buffer: should only add char (input text len=" + str(text.length()) + ")")
	
	if append_to_buffer:
		_buffer.insert(_buffer.size() - 1, text)
	else:
		_buffer.insert(_cursor_idx, text)
	
	if _buffer[-1] != null:
		_buffer.append(null)
	_cursor_idx += 1


func write(text: String, is_stderr: bool = false, buffer_override: bool = false) -> void:
	if terminal_state == TerminalState.TYPING or terminal_state == TerminalState.INACTIVE or buffer_override:
		for c in text:
			add_to_buffer(c)
		_cursor_right_limit = _cursor_idx
		_start_line_idx = max(0, get_num_rows_in_buffer() - get_num_window_rows())
		# print("write: _start_line_idx=", _start_line_idx)
		# print("write: size.y=", size.y)
		# print("write: CHAR_HEIGTH=", _CHAR_HEIGHT)
		# print("write: _text_border_size_y=", _text_border_size_y)
		# print("write: get_window_y()=", get_window_y())
		# print("write: get_num_window_rows=", get_num_window_rows())
		# print("write: get_num_rows_in_buffer=", get_num_rows_in_buffer())
		# queue_redraw()

		if is_stderr:
			terminal_noises.get_node("stderr").play()
	else:
		var msg = {"text": text, "is_stderr": is_stderr}
		_buffered_writes.append(msg)


func run_command(cmd_string: String) -> void:
	telco_network.run_cmd(connected_telco, cmd_string)
	match telco_network.get_telco(connected_telco).shell.state:
		0: # LOCAL
			write("> ")
		_: 
			pass


func get_cmd_string() -> String:
	return "".join(PackedStringArray(_buffer.slice(_cursor_right_limit, _buffer.size()-1)))


func terminal_dial(telco_name: String, username: String = "guest", password: String = "") -> void:
	write("dialing...\n")
	_on_terminal_state_change("DIALING")
	var data = "dial.service " + username + ":" + password + "@" + telco_name
	_data_ack = false
	signal_bus.network_data.emit(TERMINAL_NAME, telco_name, data)
	write("> ")


func event_to_char(event: InputEventKey) -> String:
	var keycode_string = OS.get_keycode_string(event.get_keycode_with_modifiers())
	var c = ""
		
	match keycode_string:
		"A" when _caps_lock_enabled:
			c = "A"
		"A":
			c = "a"
		"Shift+A":
			c = "A"
		"B" when _caps_lock_enabled:
			c = "B"
		"B":
			c = "b"
		"Shift+B":
			c = "B"
		"C" when _caps_lock_enabled:
			c = "C"
		"C":
			c = "c"
		"Shift+C":
			c = "C"
		"D" when _caps_lock_enabled:
			c = "D"
		"D":
			c = "d"
		"Shift+D":
			c = "D"
		"E" when _caps_lock_enabled:
			c = "E"
		"E":
			c = "e"
		"Shift+E":
			c = "E"
		"F" when _caps_lock_enabled:
			c = "F"
		"F":
			c = "f"
		"Shift+F":
			c = "F"
		"G" when _caps_lock_enabled:
			c = "G"
		"G":
			c = "g"
		"Shift+G":
			c = "G"
		"H" when _caps_lock_enabled:
			c = "H"
		"H":
			c = "h"
		"Shift+H":
			c = "H"
		"I" when _caps_lock_enabled:
			c = "I"
		"I":
			c = "i"
		"Shift+I":
			c = "I"
		"J" when _caps_lock_enabled:
			c = "J"
		"J":
			c = "j"
		"Shift+J":
			c = "J"
		"K" when _caps_lock_enabled:
			c = "K"
		"K":
			c = "k"
		"Shift+K":
			c = "K"
		"L" when _caps_lock_enabled:
			c = "L"
		"L":
			c = "l"
		"Shift+L":
			c = "L"
		"M" when _caps_lock_enabled:
			c = "M"
		"M":
			c = "m"
		"Shift+M":
			c = "M"
		"N" when _caps_lock_enabled:
			c = "N"
		"N":
			c = "n"
		"Shift+N":
			c = "N"
		"O" when _caps_lock_enabled:
			c = "O"
		"O":
			c = "o"
		"Shift+O":
			c = "O"
		"P" when _caps_lock_enabled:
			c = "P"
		"P":
			c = "p"
		"Shift+P":
			c = "P"
		"Q" when _caps_lock_enabled:
			c = "Q"
		"Q":
			c = "q"
		"Shift+Q":
			c = "Q"
		"R" when _caps_lock_enabled:
			c = "R"
		"R":
			c = "r"
		"Shift+R":
			c = "R"
		"S" when _caps_lock_enabled:
			c = "S"
		"S":
			c = "s"
		"Shift+S":
			c = "S"
		"T" when _caps_lock_enabled:
			c = "T"
		"T":
			c = "t"
		"Shift+T":
			c = "T"
		"U" when _caps_lock_enabled:
			c = "U"
		"U":
			c = "u"
		"Shift+U":
			c = "U"
		"V" when _caps_lock_enabled:
			c = "V"
		"V":
			c = "v"
		"Shift+V":
			c = "V"
		"W" when _caps_lock_enabled:
			c = "W"
		"W":
			c = "w"
		"Shift+W":
			c = "W"
		"X" when _caps_lock_enabled:
			c = "X"
		"X":
			c = "x"
		"Shift+X":
			c = "X"
		"Y" when _caps_lock_enabled:
			c = "Y"
		"Y":
			c = "y"
		"Shift+Y":
			c = "Y"
		"Z" when _caps_lock_enabled:
			c = "Z"
		"Z":
			c = "z"
		"Shift+Z":
			c = "Z"
		"0":
			c = "0"
		"Shift+0":
			c = ")"
		"1":
			c = "1"
		"Shift+1":
			c = "!"
		"2":
			c = "2"
		"Shift+2":
			c = "@"
		"3":
			c = "3"
		"Shift+3":
			c = "#"
		"4":
			c = "4"
		"Shift+4":
			c = "$"
		"5":
			c = "5"
		"Shift+5":
			c = "%"
		"6":
			c = "6"
		"Shift+6":
			c = "^"
		"7":
			c = "7"
		"Shift+7":
			c = "&"
		"8":
			c = "8"
		"Shift+8":
			c = "*"
		"9":
			c = "9"
		"Shift+9":
			c = "("
		"QuoteLeft":
			c = "`"
		"Shift+QuoteLeft":
			c = "~"
		"Minus":
			c = "-"
		"Shift+Minus":
			c = "_"
		"Equal":
			c = "="
		"Shift+Equal":
			c = "+"
		"BracketLeft":
			c = "["
		"Shift+BracketLeft":
			c = "{"
		"BracketRight":
			c = "]"
		"Shift+BracketRight":
			c = "}"
		"BackSlash":
			c = "\\"
		"Shift+BackSlash":
			c = "|"
		"Semicolon":
			c = ";"
		"Shift+Semicolon":
			c = ":"
		"Apostrophe":
			c = "'"
		"Shift+Apostrophe":
			c = '"'
		"Comma":
			c = ","
		"Shift+Comma":
			c = "<"
		"Period":
			c = "."
		"Shift+Period":
			c = ">"
		"Slash":
			c = "/"
		"Shift+Slash":
			c = "?"
		"Space":
			c = " "
		"CapsLock":
			_caps_lock_enabled = !_caps_lock_enabled
		"Enter":
			_cmd_string = get_cmd_string()
			if _cmd_string != _terminal_history[_terminal_history.size() - 2]:
				_terminal_history[-1] = _cmd_string
				_terminal_history.append("")
			_last_cmd_idx = _terminal_history.size() - 1
			c = "\n"
		"Left": 
			_cursor_idx = max(_cursor_right_limit, _cursor_idx - 1)
			while _cursor_idx > _cursor_right_limit and _buffer[_cursor_idx] == "\n":
				_cursor_idx = _cursor_idx - 1
		"Right": 
			_cursor_idx = min(_cursor_idx + 1, _buffer.size() - 1)
			while _cursor_idx < _buffer.size() and _buffer[_cursor_idx] == "\n":
				_cursor_idx = _cursor_idx + 1
		"Up": 
			if _terminal_history.size() > 0 and _last_cmd_idx > -1:
				clear_current_line()
				_last_cmd_idx = max(0, _last_cmd_idx - 1)
				var last_cmd = _terminal_history[_last_cmd_idx]
				for _c in last_cmd:
					add_to_buffer(_c)
		"Down": 
			if _terminal_history.size() > 0 and _last_cmd_idx < _terminal_history.size()-1:
				clear_current_line()
				_last_cmd_idx = min(_last_cmd_idx + 1, _terminal_history.size() - 1)
				var last_cmd = _terminal_history[_last_cmd_idx]
				for _c in last_cmd:
					add_to_buffer(_c)
		"Backspace":
			if _cursor_idx > _cursor_right_limit:
				_buffer.remove_at(_cursor_idx - 1)
				_cursor_idx -= 1
		_:
			c = ""
	
	_start_line_idx = max(0, get_num_rows_in_buffer() - get_num_window_rows())
	
	return c
