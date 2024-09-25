class_name TelcOS extends Node


enum TelcoState {
	RUNNING,
	DIALING,
	DISCONNECTED
}


class Cmd:
	var name: String
	var help: String
	var callback: Callable

	func _init(new_name: String, new_help: String, new_callback: Callable):
		self.name = new_name
		self.help = new_help
		self.callback = new_callback


var telco_name: String
var users: UsersDirectory
var filesys: FileSystem
var session: Session
var shell: Shell
var signal_bus: Node
var telco_state: TelcoState


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("telcOS: loading")
	filesys = $"FileSystem"
	print("telcOS: done")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	match telco_state:
		TelcoState.DIALING:
			pass
		TelcoState.RUNNING:
			pass
		TelcoState.DISCONNECTED:
			pass


func initialize_telco(new_telco_name: String) -> void:
	telco_name = new_telco_name
	session = Session.new()
	shell = Shell.new()
	users = UsersDirectory.new()
	signal_bus = get_node("../../SignalBus")
	signal_bus.network_data.connect(receive_network_data)
	telco_state = TelcoState.RUNNING

	load_telco_xml(telco_name)


func initialize_session(username: String, cwd: String = "") -> void:
	var user_present = false
	for user in users.get_users():
		if user.username == username:
			user_present = true
			break
	
	assert(user_present, "User: " + username + " not found in " + telco_name)
	
	session.user = get_user_from_username(username)

	if cwd == "":
		session.cwd = session.user.home
	else:
		session.cwd = cwd


func load_telco_xml(new_telco_name: String) -> void:
	print("Loading: ", new_telco_name)
	var parser = XMLParser.new()
	parser.open("res://assets/telcos/" + new_telco_name + ".xml")
	
	var file_path = ''
	var current_inode = null

	while parser.read() != ERR_FILE_EOF:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var element_name = parser.get_node_name()
				var attributes_dict = {}
				for i in range(parser.get_attribute_count()):
					attributes_dict[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
			
				match element_name:
					'telco':
						self.telco_name = attributes_dict['name']
					'users':
						pass
					'user':
						var username = attributes_dict.get('name', '')
						var password = attributes_dict.get('password', '')
						var home = attributes_dict.get('home', '')
						var path = attributes_dict.get('path', '')
						users.register_user(username, password, home, path)
					'shell':
						print(shell == null)
						var builtins = attributes_dict.get('builtins', '').split(';')
						var guest = attributes_dict.get('guest', '').split(';')
						shell.assign_builtin_cmds(builtins)
						shell.assign_guest_cmds(guest)
					'filesys':
						pass
					'inode':
						var file_name = attributes_dict.get('name')
						var file_type = attributes_dict.get('type')
						var file_unparsed_permissions = attributes_dict.get('permissions', '')
						var file_unparsed_properties = attributes_dict.get('properties', '')

						assert (file_name != null and file_type != null, "iNode name and type cannot be empty")

						file_path += '/' + file_name
						file_path = file_path.replace("//", "/")

						var file_permissions = {}
						if file_name != "" and file_unparsed_permissions == '':
							var parent_path_array:PackedStringArray = file_path.split('/')
							parent_path_array.remove_at(parent_path_array.size() - 1)
							var parent_path:String = "/".join(parent_path_array)

							var parent_inode:iNode = get_inode_from_path(parent_path)
							assert(parent_inode != null, "Parent inode not found")

							file_permissions = parent_inode.permissions.duplicate()
						else:
							for unparsed_permission in file_unparsed_permissions.split(';'):
								if unparsed_permission == '':
									continue
								var parsed_permission = unparsed_permission.split(':')
								var username = parsed_permission[0]
								var permissions = parsed_permission[1]
								file_permissions[username] = permissions
						
						var file_properties = {}
						for property in file_unparsed_properties.split(';'):
							if property == '':
								continue

							var property_name = property
							var property_value = true

							if "=" in property:
								var property_split = property.split('=')
								property_name = property_split[0]
								property_value = property_split[1]

							file_properties[property_name] = property_value

						if file_path == "/":
							filesys.initialize_filesystem(file_permissions, file_properties)
							current_inode = filesys.get_root_node()
						else:
							var new_inode = iNode.new()
							new_inode.initialize(file_name, file_type, file_permissions, file_properties)
							add_to_filesystem(file_path, new_inode)

							current_inode = new_inode
			
			XMLParser.NODE_TEXT:
				var content = parser.get_node_data().strip_edges(true, true)
				if content != '':
					if current_inode.type == "executable":
						assert(BINARIES.has(content) or SERVICES.has(content), "(" + telco_name + ") o implementation for executable: " + content)

					current_inode.set_content(content)
			XMLParser.NODE_ELEMENT_END:
				var element_name = parser.get_node_name()
				match element_name:
					'inode':
						var parent_path_array:PackedStringArray = file_path.split('/')
						parent_path_array.remove_at(parent_path_array.size() - 1)
						file_path = "/".join(parent_path_array)

	users.register_user("guest", "", "", "")
	initialize_session("guest")


func add_to_filesystem(file_path:String, inode:iNode) -> bool:
	var file_path_array = file_path.split('/')
	var current_node = filesys.get_root_node()
	
	for dir in file_path_array.slice(1, file_path_array.size() - 1):
		var child_name = dir
		current_node = current_node.get_child_inode(child_name)

		if current_node == null:
			return false

	current_node.add_child_inode(inode)
	return true


func path_to_absolute(file_path:String):	
	var full_path = ""
	if file_path.begins_with('/'):
		full_path = file_path
	else:
		full_path = session.cwd + '/' + file_path

	full_path = full_path.strip_edges(true, true)
	while full_path.find("//") != -1:
		full_path = full_path.replace("//", "/")
	if full_path.length() > 1 and full_path.ends_with('/'):
		full_path = full_path.trim_suffix('/')
		
	var path_parts = full_path.split('/')
	var absolute_path_parts = []
	for part in path_parts:
		if part == "..":
			absolute_path_parts.pop_back()
		elif part == ".":
			continue
		else:
			absolute_path_parts.append(part)
	
	if absolute_path_parts.size() == 0:
		return "/"
	if absolute_path_parts.size() == 1:
		return "/" + absolute_path_parts[0]

	return "/".join(absolute_path_parts)


func get_inode_from_path(file_path:String):
	assert(filesys != null, "Filesystem not loaded")

	if file_path == "/":
		return filesys.get_root_node()

	var file_path_array = file_path.split('/')
	var current_node = filesys.get_root_node()
	for dir in file_path_array.slice(1):
		current_node = current_node.get_child_inode(dir)
		if current_node == null:
			return null

	return current_node


func get_user_from_username(username: String) -> User:
	return users.get_user(username)


func authenticate_user(username: String, password: String) -> bool:
	# if username == "guest": 
	# 	return false
	
	var user = get_user_from_username(username)
	if user == null:
		return false
	
	if user.password == password:
		initialize_session(username)
		return true
	return false


func get_user_executables(username: String) -> Array[iNode]:
	if username == "guest":
		return []
	
	var executables: Array[iNode] = []
	var path = session.user.path
	var path_array = path.split(':')
	for dir in path_array:
		var dir_inode = get_inode_from_path(dir)
		if dir_inode == null or !dir_inode.verify_permissions(username, "r"):
			continue
		for child in dir_inode.get_children():
			if child.type == "executable" and child.verify_permissions(username, "x"):
				executables.append(child)

	return executables


func get_user_commands(username: String) -> Array[String]:
	var commands = []
	if username == "guest":
		commands = shell.guest_commands
	else:
		commands = shell.builtin_commands
	
	return commands


func stdout(msg: String) -> void:
	signal_bus.terminal_stdout.emit(msg)


func stderr(msg: String) -> void:
	signal_bus.terminal_stderr.emit(msg)


func send_network_data(source: String, destination: String, data: String) -> void:
	signal_bus.network_data.emit(source, destination, data)


func receive_network_data(source: String, destination: String, data: String) -> void:
	print(telco_name + ": received network data from: ", source, " to: ", destination, " data: ", data)
	if destination != telco_name:
		return	

	run_service_cmd(data, source)


# TODO - clean up this logic? It's ugly and unwieldy, even though it works
func run_cmd(cmd_string: String) -> void:
	var cmd_args = cmd_string.split(' ')
	var cmd = cmd_args[0]
	var argv = cmd_args.slice(1)

	var user_commands = get_user_commands(session.get_username())
	var ret = false
	session.user.add_to_history(cmd, argv, ret)
	var current_cmd = session.user.terminal_history[-1]

	if user_commands.has(cmd):
		ret = BINARIES[cmd].callback.call(cmd, argv)
		current_cmd["success"] = ret
		return

	var executables = get_user_executables(session.get_username())
	for exe in executables:
		if exe.filename == cmd:
			cmd = exe.get_executable()
			ret = BINARIES[cmd].callback.call(cmd, argv)
			current_cmd["success"] = ret
			return

	var absolute_path = path_to_absolute(cmd)
	var executable_inode = get_inode_from_path(absolute_path)
	if executable_inode != null and BINARIES.has(executable_inode.get_executable()):
		if !executable_inode.verify_permissions(session.get_username(), "x"):
			stderr("permission denied")
			return

		cmd = executable_inode.get_executable()
		ret = BINARIES[cmd].callback.call(cmd, argv)
		current_cmd["success"] = ret
		return

	stdout(cmd + ": command not found")


func run_service_cmd(cmd_string: String, source: String) -> void:
	var cmd_args = cmd_string.split(' ')
	var cmd = cmd_args[0]
	var argv = cmd_args.slice(1)
	

	if SERVICES.has(cmd):
		var ret = SERVICES[cmd].callback.call(cmd, argv, source)
		signal_bus.telco_command.emit(source, cmd, argv, ret)
		return
	else:
		return


var BINARIES: Dictionary = {
	"help": Cmd.new("help", "Prints accessible commands to the console", help_cmd),
	"whoami": Cmd.new("whoami", "Displays the current user", whoami_cmd),
	"users": Cmd.new("users", "Lists system users", users_cmd),
	"pwd": Cmd.new("pwd", "Displays the current working directory", pwd_cmd),
	"ls": Cmd.new("ls", "Lists directory contents", ls_cmd),
	"cd": Cmd.new("cd", "Changes the current working directory", cd_cmd),
	"cat": Cmd.new("cat", "Prints the content of a file", cat_cmd),
	"auth": Cmd.new("auth", "Authenticates the user", auth_cmd),
	"dial_standard": Cmd.new("dial", "Dial a new telco", dial_executable),
	"decryptor_standard": Cmd.new("decryptor", "Decrypts a file", decryptor_executable),
}

var SERVICES: Dictionary = {
	"dial.service": Cmd.new("dial.service", "Handles incoming calls", dial_service),
	"msg.service": Cmd.new("msg.service", "Catches inbound messages", msg_service),
}

func help_cmd(_cmd: String, _argv: Array) -> bool:
	var msg = ""
	var commands = get_user_commands(session.get_username())
	var executables = get_user_executables(session.get_username())

	for cmd in commands:
		msg += BINARIES[cmd].name.to_upper() + ": " + BINARIES[cmd].help + "\n"
	
	for exe in executables:
		var executable_key = exe.get_executable()
		assert (executable_key != "", "Executable key not found")
		msg += exe.filename.to_upper() + ": " + BINARIES[executable_key].help + "\n"
	
	stdout(msg)
	return true


func whoami_cmd(_cmd: String, _argv: Array) -> bool:
	var msg = ""
	if session.get_username() == "guest":
		msg = "guest@" + telco_name + " (unauthenticated)"
	else:
		msg = session.get_username() + "@" + telco_name
	
	stdout(msg)
	return true


func users_cmd(_cmd: String, _argv: Array) -> bool:
	var msg = ""
	for user in users.get_users():
		msg += user.username + "\n"
	
	stdout(msg)
	return true


func pwd_cmd(_cmd: String, _argv: Array) -> bool:
	stdout(session.cwd)
	return true


func ls_cmd(_cmd: String, argv: Array) -> bool:
	var path = ""
	var verbose = false

	if argv.size() == 0:
		path = session.cwd
	elif argv.size() == 1:
		if argv[0].begins_with('-'):
			verbose = argv[0] == '-l'
			path = session.cwd
		else:
			path = argv[0]
	elif argv.size() == 2:
		verbose = argv[0] == '-l'
		path = argv[1]

	var absolute_path = path_to_absolute(path)

	var target_inode = get_inode_from_path(absolute_path)
	if target_inode == null:
		stdout("no such file or directory: " + path)
		return false

	if !target_inode.verify_permissions(session.get_username(), "r"):
		stderr("permission denied")
		return false

	if target_inode.type == "dir":
		for child in target_inode.get_children():
			if verbose:
				var user_permissions = child.get_user_permissions(session.get_username())
				stdout("-" + user_permissions + " " + child.filename)
			else:
				stdout(child.filename)
	else:
		if verbose:
			var user_permissions = target_inode.get_user_permissions(session.get_username())
			stdout("-" + user_permissions + " " + target_inode.filename)
		else:
			stdout(target_inode.filename)
	
	return true


func cd_cmd(_cmd: String, argv: Array) -> bool:
	var path = ""
	if argv.size() == 0:
		if session.user == null or session.user.home == "":
			stdout("no home dir set")
			return false
		path = session.user.home
	elif argv.size() == 1:
		path = argv[0]

	var absolute_path = path_to_absolute(path)

	var target_inode = get_inode_from_path(absolute_path)
	if target_inode == null:
		stdout("no such file or directory")
		return false

	if !target_inode.verify_permissions(session.get_username(), "r"):
		stderr("permission denied")
		return false

	if target_inode.type == "dir":
		session.cwd = absolute_path
		return true
	else:
		stdout("not a directory")
		return false


func cat_cmd(cmd: String, argv: Array) -> bool:
	if argv.size() != 1:
		stdout("usage: " + cmd + " <path>")
		return false
	
	var path = argv[0]
	var absolute_path = path_to_absolute(path)

	var target_inode = get_inode_from_path(absolute_path)
	if target_inode == null:
		stdout("no such file or directory")
		return false
	
	if !target_inode.verify_permissions(session.get_username(), "r"):
		stderr("permission denied")
		return false

	if target_inode.type == "file":
		stdout(target_inode.get_content())
		return true
	else:
		stdout("not a file")
		return false


func auth_cmd(cmd: String, argv: Array) -> bool:
	if argv.size() < 1 or argv[0].find(":") == -1:
		stdout("usage: " + cmd + " <username>:<password>")
		return false
	
	var auth_string = argv[0]
	var username = auth_string.split(':')[0]
	var password = auth_string.split(':')[1]

	if get_user_from_username(username) == null:
		stdout("user not found")
		return false

	if !authenticate_user(username, password):
		stderr("invalid credentials")
		return false
	
	initialize_session(username)
	stdout("welcome, " + session.get_username()+ "!")
	return true


func dial_executable(_cmd: String, argv: Array) -> bool:
	print("dial start")
	if argv.size() != 1:
		stdout("no telco name provided")
		return false
	
	var auth_string = argv[0]

	if auth_string.find(":") == -1 or auth_string.find("@") == -1:
		auth_string = session.get_username()+ ":" + session.user.password + "@" + argv[0]
	
	print(auth_string)
	var dst_telco = auth_string.split("@")[1]
	var data = "dial.service " + auth_string

	print("dialing telco: ", dst_telco)

	stdout("dialing...")
	signal_bus.terminal_change_state.emit("DIALING")
	send_network_data(telco_name, dst_telco, data)
	return true


func decryptor_executable(cmd: String, argv: Array) -> bool:
	if argv.size() != 1:
		stdout("usage: " + cmd + " <path>")
		return false
	
	var path = argv[0]
	var absolute_path = path_to_absolute(path)
	var target_inode = get_inode_from_path(absolute_path)

	if target_inode == null:
		stdout("no such file or directory")
		return false
	
	if !target_inode.verify_permissions(session.get_username(), "r"):
		stderr("permission denied")
		return false
	
	if target_inode.type != "file":
		stdout("not a file")
		return false
	
	if !target_inode.properties.has("encrypted"):
		stdout("file is not encrypted")
		return false
	
	target_inode.properties.erase("encrypted")
	stdout("successfully decrypted " + target_inode.filename)
	return true


func msg_service(_cmd: String, argv: Array, _source: String) -> bool:
	var msg = argv[0]
	stdout(msg)
	return true


func dial_service(_cmd: String, argv: Array, _source: String) -> bool:
	var auth_string = argv[0]
	var username = auth_string.split(":")[0]
	var tmp = auth_string.split(":")[1]
	var password = tmp.split("@")[0]
	var auth_telco_name = tmp.split("@")[1]

	print("dial.service: authenticating " + username)

	if authenticate_user(username, password):
		signal_bus.terminal_change_telco.emit(auth_telco_name, username)
		initialize_session(username)
		stdout("WELCOME TO " + auth_telco_name.to_upper() + ". TYPE 'HELP' TO BEGIN:")
		return true
	else:
		stderr("unauthorized")
		return false
