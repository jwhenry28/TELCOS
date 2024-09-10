class_name iNode extends Node


var filename: String
var type: String
var permissions: Dictionary
var content: String
# var children: Array[iNode]
var properties: Dictionary


func initialize(new_filename:String, new_type:String, new_permissions:Dictionary = {}, new_properties:Dictionary = {}, is_root_node:bool = false):
	if !is_root_node:
		self.name = new_filename.md5_text()
	else:
		self.name = new_filename
	self.filename = new_filename
	self.type = new_type

	if new_permissions.is_empty():
		new_permissions = {'*': 'rwx'}

	self.permissions = new_permissions
	# self.children = []
	self.properties = new_properties


func _ready() -> void:
	print("iNode: ready")


func _process(_delta: float) -> void:
	pass


func add_child_inode(new_child:iNode) -> void:
	# TODO: use return type instead if this becomes irritating
	assert(type == 'dir', "Only directories can have children") 
	add_child(new_child)


func get_child_inode(child_name:String):
	return get_node(child_name.md5_text())


func get_content() -> String:
	if type == 'file':
		if properties.has("encrypted"):
			seed(self.content.hash())
			randomize()

			var encryption_block = "----- BEGIN PGP MESSAGE -----\nVersion: 2.6.2\n\n"
			var encrypted_content = ""
			var padding = 4
			var line_size = 32
			var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
			
			for i in range(self.content.length() * 2):
				encrypted_content += alphabet[randi() % alphabet.length()]
			while encrypted_content.length() % padding != 0:
				encrypted_content += "="
			while encrypted_content.length() > 0:
				encryption_block += encrypted_content.substr(0, line_size) + "\n"
				encrypted_content = encrypted_content.substr(line_size)

			encryption_block += "-----  END PGP MESSAGE  -----\n"
			return encryption_block
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
	
	print("verifying permission '" + permission + "' for " + username + " on " + self.filename)

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
	print(spacing + "/" + self.filename + " (" + self.type + ")")
	for child in get_children():
		child.print_inode(recursive, spacing + "    ")


func print_inode_details(recursive:bool = false) -> void:
	print(self._to_string())
	if recursive:
		for child in get_children():
			child.print_inode_details(recursive)


func _to_string() -> String:
	var inode_string = self.filename + " (" + self.type + ")\n"
	inode_string += "permissions:\n"
	for permission in self.permissions:
		inode_string += " - " + permission + ": " + self.permissions[permission] + "\n"

	inode_string += "properties: "
	for property in self.properties:
		inode_string += property + "=" + str(self.properties[property]) + ";"
	inode_string += "\n"

	inode_string += "content: " + self.content + "\n"
	
	inode_string += "children:\n"
	for child in get_children():
		inode_string += " - " + child.filename + " (" + child.type + ")" + "\n"

	return inode_string
