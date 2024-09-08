extends Node

var telco_name: String
var users: Array
var filesys: iNode

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("telcOS: loading")
	print("telcOS: done")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func load_telco(new_telco_name: String) -> void:
	telco_name = new_telco_name
	load_telco_xml(telco_name)
	print('\n\n\nTELCO LOADED. Sanity check:')
	print("name: ", telco_name)
	print("users: ", users)
	print("FILESYSTEM:")
	filesys.print_inode(true)
	filesys.print_inode_details(true)


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
						
						var file_properties:Array[String] = []
						for property in file_unparsed_properties.split(';'):
							if property == '':
								continue
							print("parsing: ", property)
							file_properties.append(property)

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


func get_inode_from_path(file_path:String):
	assert(filesys != null, "Filesystem not loaded")

	print("retrieving inode: ", file_path)
	var file_path_array = file_path.split('/')
	file_path_array.remove_at(0)

	print(file_path_array)
	var current_node = filesys
	for dir in file_path_array:
		print("looking for: ", dir)
		current_node = current_node.get_child(dir)
		
		if current_node == null:
			return null

	return current_node


func run_cmd(cmd: String) -> String:
	return 'TelcOS ran command'


### INNER CLASSES ###
class User:
	var username: String
	var password: String
	var home: String
	var path: String


	func _init(new_username:String, new_password:String, new_home:String, new_path:String = ""):
		assert (new_username != '' and new_password != '', "New users require a username and password")

		self.username = new_username
		self.password = new_password
		self.home = new_home
		self.path = new_path
	

	func _to_string() -> String:
		return username + ":" + password + " " + home + " " + path


class iNode:
	var name: String
	var type: String
	var permissions: Dictionary
	var content: String
	var children: Array[iNode]
	var properties: Array[String]


	func _init(new_name:String, new_type:String, new_permissions:Dictionary = {}, new_properties:Array[String] = []):
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
	

	func set_content(new_content:String) -> void:
		# TODO: use return type instead if this becomes irritating
		assert(type == 'file', "Only files can have content")
		self.content = new_content
	

	func get_user_permissions(username:String):
		return self.permissions[username]
	

	func print_inode(recursive:bool = false, spacing:String = "") -> void:
		print(spacing + self.name + " (" + self.type + ")")
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
			inode_string += property + ";"
		inode_string += "\n"

		inode_string += "content: " + self.content + "\n"
		
		inode_string += "children:\n"
		for child in self.children:
			inode_string += " - " + child.name + " (" + child.type + ")" + "\n"

		return inode_string
