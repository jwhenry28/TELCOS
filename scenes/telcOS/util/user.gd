class_name User

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