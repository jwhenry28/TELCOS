extends Panel

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
var signal_bus

var connected_telco: String
var terminal_history: Array[String] = [
	"> whoami",
	"root"
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("terminal: loading")
	terminal_history_container = $"TerminalHistory"
	vbox_container = $"TerminalHistory/VBoxContainer"
	cmd_prompt_textedit = $"TerminalHistory/VBoxContainer/HBoxContainer/CmdPrompt"
	terminal_history_scrollbar = $"TerminalHistory".get_v_scroll_bar()
	telco_network = $"../TelcoNetwork"

	signal_bus = $"../SignalBus"
	signal_bus.telco_stdout.connect(add_to_history)
	signal_bus.change_telco.connect(_on_change_telco)

	last_sibling_index = vbox_container.get_child_count() - 2
	connected_telco = "telco1"

	for item in terminal_history:
		add_to_history(item)

	print("terminal: done")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if old_max_scroll_height < terminal_history_scrollbar.max_value:
		adjust_scrollbar()
		old_max_scroll_height = terminal_history_scrollbar.max_value

	if Input.is_action_just_released("cmd_enter"):
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


func add_to_history(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_color_override("font_color", TERMINAL_GREEN)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	
	var last_sibling = vbox_container.get_child(last_sibling_index)
	last_sibling_index += 1
	last_sibling.add_sibling(label)


func _on_change_telco(new_telco_name: String, username: String) -> void:
	print("main: changing telco to ", username, "@", new_telco_name)
	connected_telco = new_telco_name

	var telcOS = telco_network.get_telco(connected_telco)
	telcOS.initialize_session(username)
