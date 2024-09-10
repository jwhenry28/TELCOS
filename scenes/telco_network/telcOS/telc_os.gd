class_name TelcOS extends Node

enum TelcoState {
	RUNNING,
	CONNECTING,
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


class iNode:
	var name: String
	var type: String
	var permissions: Dictionary
	var content: String
	var children: Array[iNode]
	var properties: Dictionary


	func _init(new_name:String, new_type:String, new_permissions:Dictionary = {}, new_properties:Dictionary = {}):
		self.name = new_name
		self.type = new_type

		if new_permissions.is_empty():
			new_permissions = {'*': 'rwx'}

		self.permissions = new_permissions
		self.children = []
		self.properties = new_properties


	func add_child(new_child:iNode) -> void:
		# TODO: use return type instead if this becomes irritating
		assert(type == 'dir', "Only directories can have children") 
		self.children.append(new_child)


	func get_child(child_name:String):
		for child in self.children:
			print("checking child: ", child.name)
			if child.name == child_name:
				return child
		return null


	func get_content() -> String:
		if type == 'file':
			return self.content
		
		return ""


	func get_executable() -> String:
		if type == 'executable':
			return self.content

		return ""


	func set_content(new_content:String) -> void:
		# TODO: use return type instead if this becomes irritating
		assert(type == 'file' or type == 'executable', "Only files can have content")

		# hack - this will prevent me from having tabs in the file contents.
		# I'll figure out how to strip leading tabs from the XML file if this 
		# becomes a problem.
		new_content = new_content.replace("\t", "")
		self.content = new_content


	func get_user_permissions(username:String):
		if permissions.has("*"):
			return permissions["*"]
		elif permissions.has(username):
			return permissions[username]

		return "---"


	func verify_permissions(username:String, permission:String):
		assert(permission == "r" or permission == "w" or permission == "x", "Invalid permission: " + permission)
		
		print("verifying permission '" + permission + "' for " + username + " on " + self.name)

		var user_permissions = get_user_permissions(username)
		var permission_bit = ""
		match permission:
			"r":
				permission_bit = user_permissions[0]
			"w":
				permission_bit = user_permissions[1]
			"x":
				permission_bit = user_permissions[2]

		return permission_bit == permission


	func print_inode(recursive:bool = false, spacing:String = "") -> void:
		print(spacing + "/" + self.name + " (" + self.type + ")")
		for child in self.children:
			child.print_inode(recursive, spacing + "    ")


	func print_inode_details(recursive:bool = false) -> void:
		print(self._to_string())
		if recursive:
			for child in self.children:
				child.print_inode_details(recursive)


	func _to_string() -> String:
		var inode_string = self.name + " (" + self.type + ")\n"
		inode_string += "permissions:\n"
		for permission in self.permissions:
			inode_string += " - " + permission + ": " + self.permissions[permission] + "\n"

		inode_string += "properties: "
		for property in self.properties:
			inode_string += property + "=" + str(self.properties[property]) + ";"
		inode_string += "\n"

		inode_string += "content: " + self.content + "\n"
		
		inode_string += "children:\n"
		for child in self.children:
			inode_string += " - " + child.name + " (" + child.type + ")" + "\n"

		return inode_string


class Session:
	var cwd: String
	var username: String
	var user: User

	func _init():
		self.cwd = ""
		self.user = null

	func get_username() -> String:
		if user == null:
			return ""
		return user.username

	func password() -> String:
		if user == null:
			return ""
		return user.password

	func home() -> String:
		if user == null:
			return ""
		return user.home

	func path() -> String:
		if user == null:
			return ""
		return user.path


class Shell:
	var builtin_commands: Array[String]
	var guest_commands: Array[String]

	func _init(builtins: Array[String] = [], guest: Array[String] = []):
		self.builtin_commands = builtins
		self.guest_commands = guest


	func assign_builtin_cmds(builtins: Array[String]):
		for cmd in builtins:
			if cmd != "":
				self.builtin_commands.append(cmd)


	func assign_guest_cmds(guest: Array[String]):
		for cmd in guest:
			if cmd != "":
				self.guest_commands.append(cmd)


class User:
	var username: String
	var password: String
	var home: String
	var path: String

	func _init(new_username:String, new_password:String, new_home:String, new_path:String = ""):
		assert (new_username != "" and new_password != "", "New users require a username and password")

		self.username = new_username
		self.password = new_password
		self.home = new_home
		self.path = new_path


	func _to_string() -> String:
		return username + ":" + password + " " + home + " " + path


var telco_name: String
var users: Array[User]
var filesys: iNode
var session: Session
var shell: Shell
var signal_bus: Node
var telco_state: TelcoState

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("telcOS: loading")
	print("telcOS: done")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	match telco_state:
		TelcoState.CONNECTING:
			pass
		TelcoState.RUNNING:
			pass
		TelcoState.DISCONNECTED:
			pass


func initialize_telco(new_telco_name: String) -> void:
	telco_name = new_telco_name
	session = Session.new()
	shell = Shell.new()
	signal_bus = get_node("../../SignalBus")
	signal_bus.network_data.connect(receive_network_data)
	telco_state = TelcoState.RUNNING

	load_telco_xml(telco_name)
	print("\n\n\n" + telco_name.to_upper() + " LOADED. Sanity check:")
	print("name: ", telco_name)
	print("users: ", users)
	print("shell: ", shell)
	print("- builtins: ", shell.builtin_commands)
	print("- guest: ", shell.guest_commands)
	print(telco_name + " FILESYSTEM:")
	filesys.print_inode(true)
	filesys.print_inode_details(true)


func initialize_session(username: String, cwd: String = "") -> void:
	var user_present = false
	for user in users:
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
				print("NODE_ELEMENT")
				var element_name = parser.get_node_name()
				var attributes_dict = {}
				for i in range(parser.get_attribute_count()):
					attributes_dict[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
			
				match element_name:
					'telco':
						self.telco_name = attributes_dict['name']
						print("setting telco name: ", self.telco_name)
					'users':
						pass
					'user':
						print("adding user: ", attributes_dict.get('name', ''))
						users.append(User.new(
							attributes_dict.get('name', ''), 
							attributes_dict.get('password', ''), 
							attributes_dict.get('home', ''), 
							attributes_dict.get('path', '')
						))
					'shell':
						print(shell == null)
						var builtins = attributes_dict.get('builtins', '').split(';')
						var guest = attributes_dict.get('guest', '').split(';')
						print("builtins: ", builtins)
						print("guest: ", guest)
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

						if file_name != "":
							file_path += '/' + file_name

						print("file path: ", file_path)
						var file_permissions = {}
						if file_name != "" and file_unparsed_permissions == '':
							print("inherting parent permissions")
							var parent_path_array:PackedStringArray = file_path.split('/')
							parent_path_array.remove_at(parent_path_array.size() - 1)
							var parent_path:String = "/".join(parent_path_array)

							print("parent_path: ", parent_path)
							var parent_inode:iNode = get_inode_from_path(parent_path)
							assert(parent_inode != null, "Parent inode not found")

							print("parent_inode: ", parent_inode.name)
							file_permissions = parent_inode.permissions.duplicate()
						else:
							print("setting permissions")
							for unparsed_permission in file_unparsed_permissions.split(';'):
								if unparsed_permission == '':
									continue
								print("parsing: ", unparsed_permission)
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

							print("parsing: ", property)
							file_properties[property_name] = property_value

						var new_inode = iNode.new(file_name, file_type, file_permissions, file_properties)
						print("adding inode: " + file_name)
						var res = add_to_filesystem(file_path, new_inode)
						assert (res, "Failed to add inode to filesystem")

						current_inode = new_inode
			
			XMLParser.NODE_TEXT:
				var content = parser.get_node_data().strip_edges(true, true)
				if content != '':
					print("NODE_TEXT")
					print(current_inode.name, ': ', content)
					current_inode.set_content(content)
			XMLParser.NODE_ELEMENT_END:
				print("NODE_ELEMENT_END")
				var element_name = parser.get_node_name()
				match element_name:
					'inode':
						print("inode end. updating file path")
						var parent_path_array:PackedStringArray = file_path.split('/')
						parent_path_array.remove_at(parent_path_array.size() - 1)
						file_path = "/".join(parent_path_array)

						print("new file path: ", file_path)


func add_to_filesystem(file_path:String, inode:iNode) -> bool:
	if filesys == null:
		print("adding root")
		filesys = inode
		return true

	var file_path_array = file_path.split('/')
	file_path_array = file_path_array.slice(1, file_path_array.size() - 1)
	var current_node = filesys
	for dir in file_path_array:
		print("looking for: ", dir)
		var child_name = dir
		current_node = current_node.get_child(child_name)
		
		if current_node == null:
			return false
	
	current_node.add_child(inode)
	return true


func path_to_absolute(file_path:String):
	print("path_to_absolute: ", file_path)
	
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
	
	print("cleaned file path: ", full_path)
	
	print("full path: ", full_path)
	var path_parts = full_path.split('/')
	print("path_parts: ", path_parts)
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
	print("absolute_path_parts: ", absolute_path_parts)
	return "/".join(absolute_path_parts)


func get_inode_from_path(file_path:String):
	print("get_inode_from_path: ", file_path)
	assert(filesys != null, "Filesystem not loaded")

	if file_path == "/":
		print("returning root")
		return filesys

	var file_path_array = file_path.split('/')
	print("file_path_array: ", 	file_path_array)

	var current_node = filesys
	for dir in file_path_array.slice(1):
		print("looking for: ", dir)
		current_node = current_node.get_child(dir)
		
		if current_node == null:
			return null

	return current_node


func get_user_from_username(username: String) -> User:
	for user in users:
		if user.username == username:
			return user
	return null


func run_cmd(cmd_string: String) -> void:
	print("running command: ", cmd_string)
	var cmd_args = cmd_string.split(' ')
	print("cmd_args: ", cmd_args)
	var cmd = cmd_args[0]
	print("cmd: ", cmd)
	var argv = cmd_args.slice(1)
	print("argv: ", argv)

	var user_commands = get_user_commands(session.get_username())
	if user_commands.has(cmd):
		BINARIES[cmd].callback.call(cmd, argv)
		return

	var executables = get_user_executables(session.get_username())
	for exe in executables:
		if exe.name == cmd:
			cmd = exe.get_executable()
			BINARIES[cmd].callback.call(cmd, argv)
			return

	var absolute_path = path_to_absolute(cmd)
	var executable_inode = get_inode_from_path(absolute_path)
	if executable_inode != null:
		cmd = executable_inode.get_executable()
		BINARIES[cmd].callback.call(cmd, argv)
		return

	stdout(cmd + ": command not found")


func authenticate_user(username: String, password: String) -> bool:
	var user = get_user_from_username(username)
	if user == null:
		return false
	
	if user.password == password:
		initialize_session(username)
		return true
	return false


func get_user_executables(username: String) -> Array[iNode]:
	print("getting user executables for " + username)
	if username == "":
		print("user is guest")
		return []
	
	var executables: Array[iNode] = []
	var path = session.user.path
	var path_array = path.split(':')
	for dir in path_array:
		var dir_inode = get_inode_from_path(dir)
		if dir_inode == null or !dir_inode.verify_permissions(username, "r"):
			continue
		for child in dir_inode.children:
			print("child: ", child.name)
			if child.type == "executable" and child.verify_permissions(username, "x"):
				executables.append(child)

	return executables


func get_user_commands(username: String) -> Array[String]:
	var commands = []
	if username == "":
		commands = shell.guest_commands
	else:
		commands = shell.builtin_commands
	
	return commands


func stdout(msg: String) -> void:
	signal_bus.telco_stdout.emit(msg)


func send_network_data(source: String, destination: String, data: String) -> void:
	signal_bus.network_data.emit(source, destination, data)


func receive_network_data(source: String, destination: String, data: String) -> void:
	print(telco_name + ": received network data from: ", source, " to: ", destination, " data: ", data)
	if destination != telco_name:
		return	

	if data.begins_with("dial "):
		print("received dial")
		var dial_data = data.split(" ")
		var auth_string = dial_data[1]
		var username = auth_string.split(":")[0]
		var tmp = auth_string.split(":")[1]
		var password = tmp.split("@")[0]
		var telco_name = tmp.split("@")[1]

		if authenticate_user(username, password):
			print("authenticated user: ", username)
			signal_bus.change_telco.emit(telco_name, username)
			signal_bus.telco_stdout.emit(telco_name + ": welcome " + username + "!")
		else:
			print("failed to authenticate user: ", username)
	


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
}


func help_cmd(_cmd: String, _argv: Array):
	var msg = ""
	var commands = get_user_commands(session.get_username())
	var executables = get_user_executables(session.get_username())

	for cmd in commands:
		msg += BINARIES[cmd].name.to_upper() + ": " + BINARIES[cmd].help + "\n"
	
	for exe in executables:
		var executable_key = exe.get_executable()
		assert (executable_key != "", "Executable key not found")
		msg += exe.name.to_upper() + ": " + BINARIES[executable_key].help + "\n"
	

	stdout(msg)


func whoami_cmd(_cmd: String, _argv: Array):
	var msg = ""
	if session.get_username() == "":
		msg = "guest@" + telco_name + " (unauthenticated)"
	else:
		msg = session.get_username() + "@" + telco_name
	stdout(msg)


func users_cmd(_cmd: String, _argv: Array):
	var msg = ""
	for user in users:
		msg += user.username + "\n"
	stdout(msg)


func pwd_cmd(_cmd: String, _argv: Array):
	stdout(session.cwd)


func ls_cmd(_cmd: String, argv: Array):
	var path = ""
	var verbose = false

	if argv.size() == 0:
		print("no args, using cwd")
		path = session.cwd
	elif argv.size() == 1:
		if argv[0].begins_with('-'):
			print("no args, using cwd with flag")
			verbose = argv[0] == '-l'
			path = session.cwd
		else:
			print("path arg: ", argv[0])
			path = argv[0]
	elif argv.size() == 2:
		print("path and flag: ", argv[0], argv[1])
		verbose = argv[0] == '-l'
		path = argv[1]
	print("path: ", path)
	
	var absolute_path = path_to_absolute(path)
	print("absolute_path: ", absolute_path)

	var target_inode = get_inode_from_path(absolute_path)
	if target_inode == null:
		
		stdout("no such file or directory: " + path)
		return

	if !target_inode.verify_permissions(session.get_username(), "r"):
		
		stdout("permission denied: " + path)
		return

	if target_inode.type == "dir":
		for child in target_inode.children:
			if verbose:
				var user_permissions = child.get_user_permissions(session.get_username())
				stdout("-" + user_permissions + " " + child.name)
			else:
				stdout(child.name)
	else:
		if verbose:
			var user_permissions = target_inode.get_user_permissions(session.get_username())
			stdout("-" + user_permissions + " " + target_inode.name)
		else:
			stdout(target_inode.name)


func cd_cmd(_cmd: String, argv: Array):
	var path = ""
	if argv.size() == 0:
		if session.user == null or session.user.home == "":
			
			stdout("no home dir set")
			return
		path = session.user.home
	elif argv.size() == 1:
		path = argv[0]

	var absolute_path = path_to_absolute(path)
	print("absolute_path: ", absolute_path)

	var target_inode = get_inode_from_path(absolute_path)
	if target_inode == null:
		
		stdout("no such file or directory")
		return

	if !target_inode.verify_permissions(session.get_username(), "r"):
		
		stdout("permission denied")
		return

	if target_inode.type == "dir":
		session.cwd = absolute_path
	else:
		
		stdout("not a directory")


func cat_cmd(cmd: String, argv: Array):
	if argv.size() != 1:
		
		stdout("usage: " + cmd + " <path>")
		return
	
	var path = argv[0]
	var absolute_path = path_to_absolute(path)
	print("absolute_path: ", absolute_path)

	var target_inode = get_inode_from_path(absolute_path)
	if target_inode == null:
		
		stdout("no such file or directory")
		return
	
	if !target_inode.verify_permissions(session.get_username(), "r"):
		
		stdout("permission denied")
		return

	if target_inode.type == "file":
		stdout(target_inode.get_content())
	else:
		
		stdout("not a file")


func auth_cmd(cmd: String, argv: Array):
	if argv.size() < 1 or argv[0].find(":") == -1:
		
		stdout("usage: " + cmd + " <username>:<password>")
		return
	
	var auth_string = argv[0]
	var username = auth_string.split(':')[0]
	var password = auth_string.split(':')[1]

	if !authenticate_user(username, password):
		
		stdout("invalid credentials")
		return
	
	initialize_session(username)
	stdout("welcome, " + session.get_username()+ "!")


func dial_executable(_cmd: String, argv: Array):
	print("dial start")
	if argv.size() != 1:
		
		stdout("no telco name provided")
		return
	
	var auth_string = argv[0]

	if auth_string.find(":") == -1 or auth_string.find("@") == -1:
		auth_string = session.get_username()+ ":" + session.user.password + "@" + argv[0]
	
	print(auth_string)
	var dst_telco = auth_string.split("@")[1]
	var data = "dial " + auth_string

	print("dialing telco: ", dst_telco)

	send_network_data(telco_name, dst_telco, data)
	telco_state = TelcoState.CONNECTING
	stdout("dialing...")
