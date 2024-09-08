class_name iNode


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


func set_content(new_content:String) -> void:
	# TODO: use return type instead if this becomes irritating
	assert(type == 'file', "Only files can have content")

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
		inode_string += property + "=" + self.properties[property] + ";"
	inode_string += "\n"

	inode_string += "content: " + self.content + "\n"
	
	inode_string += "children:\n"
	for child in self.children:
		inode_string += " - " + child.name + " (" + child.type + ")" + "\n"

	return inode_string
