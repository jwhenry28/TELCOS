extends Control

var TERMINAL_GREEN = Color8(57, 255, 20, 255)
var BG_TERMINAL_GREEN = Color8(11, 50, 4, 255)
var FONT_SIZE = 12

var last_sibling_index

var terminal_history_container
var vbox_container
var cmd_prompt_textedit
var terminal_history_scrollbar

var old_max_scroll_height = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	terminal_history_container = $"Terminal/TerminalHistory"
	vbox_container = $"Terminal/TerminalHistory/VBoxContainer"
	cmd_prompt_textedit = $"Terminal/TerminalHistory/VBoxContainer/HBoxContainer/CmdPrompt"
	terminal_history_scrollbar = $"Terminal/TerminalHistory".get_v_scroll_bar()
	
	last_sibling_index = vbox_container.get_child_count() - 2


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if old_max_scroll_height < terminal_history_scrollbar.max_value:
		adjust_scrollbar()
		old_max_scroll_height = terminal_history_scrollbar.max_value
	
	if Input.is_action_just_released("cmd_enter"):
		var cmd = cmd_prompt_textedit.text
		cmd_prompt_textedit.text = ''
		add_to_history("> " + cmd)
		run_cmd(cmd)
		adjust_scrollbar()


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


func run_cmd(cmd) -> void:
	var output = "(cmd output)"
	add_to_history(output)
