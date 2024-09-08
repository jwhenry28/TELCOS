extends Node

var telco_name: String
var users: Array[User]
var filesys: iNode
var session: Session

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("telcOS: loading")
	print("telcOS: done")
	session = Session.new()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func initialize_telco(new_telco_name: String, username: String = "", cwd: String = "/") -> void:
	telco_name = new_telco_name
	load_telco_xml(telco_name)
	print('\n\n\nTELCO LOADED. Sanity check:')
	print("name: ", telco_name)
	print("users: ", users)
	print("FILESYSTEM:")
	filesys.print_inode(true)
	filesys.print_inode_details(true)

	var user_present = false
	for user in users:
		if user.username == username:
			user_present = true
			break
	assert(user_present, "User: " + username + " not found")

	session.username = username
	session.cwd = cwd
	session.user = get_user_from_username(username)


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
	var full_path = ""
	if file_path.begins_with('/'):
		full_path = file_path
	else:
		full_path = session.cwd + '/' + file_path
	
	var path_parts = full_path.split('/')
	print("path_parts: ", path_parts)
	var absolute_path_parts = []
	for part in path_parts:
		if part == "..":
			absolute_path_parts.pop_back()
		else:
			absolute_path_parts.append(part)
	
	print("absolute_path_parts: ", absolute_path_parts)
	var size = absolute_path_parts.size()
	if size > 2 and absolute_path_parts[size - 1] == "":
		# trailing slash
		absolute_path_parts.pop_back()
	
	return "/".join(absolute_path_parts)


func get_inode_from_path(file_path:String):
	assert(filesys != null, "Filesystem not loaded")

	print("retrieving inode: ", file_path)
	var file_path_array = file_path.split('/')
	file_path_array.remove_at(0)

	print(file_path_array)
	if file_path_array.size() == 1 and file_path_array[0] == "":
		return filesys

	var current_node = filesys
	for dir in file_path_array:
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


func run_cmd(cmd_string: String) -> CmdIO:
	print("running command: ", cmd_string)
	var cmd_args = cmd_string.split(' ')
	print("cmd_args: ", cmd_args)
	var cmd = cmd_args[0]
	print("cmd: ", cmd)
	var argv = cmd_args.slice(1)
	print("argv: ", argv)


	var io = CmdIO.new()

	if COMMANDS.has(cmd):
		COMMANDS[cmd].callback.call(cmd, argv, io)
	else:
		io.set_return_code(1)
		io.log(cmd + ": command not found")

	return io


func authenticate_user(username: String, password: String) -> bool:
	var user = get_user_from_username(username)
	if user == null:
		return false
	
	if user.password == password:
		session.username = username
		return true
	return false


var COMMANDS: Dictionary = {
	"help": Cmd.new("help", "Prints this message to the console", help_cmd),
	"whoami": Cmd.new("whoami", "Displays the current user", whoami_cmd),
	"users": Cmd.new("users", "Lists system users", users_cmd),
	"pwd": Cmd.new("pwd", "Displays the current working directory", pwd_cmd),
	"ls": Cmd.new("ls", "Lists directory contents", ls_cmd),
	"cd": Cmd.new("cd", "Changes the current working directory", cd_cmd),
	"cat": Cmd.new("cat", "Prints the content of a file", cat_cmd),
	"auth": Cmd.new("auth", "Authenticates the user", auth_cmd),
	"dial": Cmd.new("dial", "Dial a new telco", dial_cmd),
}


func help_cmd(_cmd: String, _args: Array, io: CmdIO):
	var msg = ""
	for cmd in COMMANDS:
		msg += COMMANDS[cmd].name.to_upper() + ": " + COMMANDS[cmd].help + "\n"
	io.log(msg)


func whoami_cmd(_cmd: String, _args: Array, io: CmdIO):
	var msg = ""
	if session.username == "":
		msg = "guest@" + telco_name + " (unauthenticated)"
	else:
		msg = session.username + "@" + telco_name
	io.log(msg)


func users_cmd(_cmd: String, _args: Array, io: CmdIO):
	var msg = ""
	for user in users:
		msg += user.username + "\n"
	io.log(msg, "")


func pwd_cmd(_cmd: String, _args: Array, io: CmdIO):
	io.log(session.cwd)


func ls_cmd(_cmd: String, args: Array, io: CmdIO):
	var path = ""
	var verbose = false

	if args.size() == 0:
		print("no args, using cwd")
		path = session.cwd
	elif args.size() == 1:
		if args[0].begins_with('-'):
			print("no args, using cwd with flag")
			verbose = args[0] == '-l'
			path = session.cwd
		else:
			print("path arg: ", args[0])
			path = args[0]
	elif args.size() == 2:
		print("path and flag: ", args[0], args[1])
		verbose = args[0] == '-l'
		path = args[1]
	print("path: ", path)
	
	var absolute_path = path_to_absolute(path)
	print("absolute_path: ", absolute_path)

	var target_inode = get_inode_from_path(absolute_path)
	if target_inode == null:
		io.set_return_code(1)
		io.log("no such file or directory: " + path)
		return

	var user_permissions = target_inode.get_user_permissions(session.username)
	var permissions = user_permissions.split("")

	if permissions[0] != "r":
		io.set_return_code(1)
		io.log("permission denied: " + path)
		return

	if target_inode.type == "dir":
		for child in target_inode.children:
			if verbose:
				user_permissions = child.get_user_permissions(session.username)
				io.log("-" + user_permissions + " " + child.name)
			else:
				io.log(child.name)
	else:
		if verbose:
			io.log("-" + user_permissions + " " + target_inode.name)
		else:
			io.log(target_inode.name)


func cd_cmd(_cmd: String, args: Array, io: CmdIO):
	var path = ""
	if args.size() == 0:
		path = session.user.home
	elif args.size() == 1:
		path = args[0]

	var absolute_path = path_to_absolute(path)
	print("absolute_path: ", absolute_path)

	var target_inode = get_inode_from_path(absolute_path)
	if target_inode == null:
		io.set_return_code(1)
		io.log("no such file or directory")
		return

	var user_permissions = target_inode.get_user_permissions(session.username)
	var permissions = user_permissions.split("")
	
	if permissions[0] != "r":
		io.set_return_code(1)
		io.log("permission denied")
		return

	if target_inode.type == "dir":
		session.cwd = absolute_path
	else:
		io.set_return_code(1)
		io.log("not a directory")


func cat_cmd(cmd: String, args: Array, io: CmdIO):
	if args.size() != 1:
		io.set_return_code(1)
		io.log("usage: " + cmd + " <path>")
		return
	
	var path = args[0]
	var absolute_path = path_to_absolute(path)
	print("absolute_path: ", absolute_path)

	var target_inode = get_inode_from_path(absolute_path)
	if target_inode == null:
		io.set_return_code(1)
		io.log("no such file or directory")
		return

	var user_permissions = target_inode.get_user_permissions(session.username)
	var permissions = user_permissions.split("")
	
	if permissions[0] != "r":
		io.set_return_code(1)
		io.log("permission denied")
		return

	if target_inode.type == "file":
		io.log(target_inode.content)
	else:
		io.set_return_code(1)
		io.log("not a file")


func auth_cmd(cmd: String, args: Array, io: CmdIO):
	if args.size() < 1 or args[0].find(":") == -1:
		io.set_return_code(1)
		io.log("usage: " + cmd + " <username>:<password>")
		return
	
	var auth_string = args[0]
	var username = auth_string.split(':')[0]
	var password = auth_string.split(':')[1]

	if !authenticate_user(username, password):
		io.set_return_code(1)
		io.log("invalid credentials")
		return
	
	io.log("welcome, " + session.username + "!")
	session.username = username
	session.user = get_user_from_username(username)
	session.cwd = session.user.home


func dial_cmd(cmd: String, args: Array, io: CmdIO):
	pass
