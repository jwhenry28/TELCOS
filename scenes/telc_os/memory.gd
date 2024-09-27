class_name Memory extends Node

var memory: Dictionary


func _init() -> void:
	memory = {}


func store_data(service_name: String, data_name: String, data) -> void:
	if !memory.has(service_name):
		memory[service_name] = {}
	
	memory[service_name][data_name] = data


func get_data(service_name: String, data_name: String):
	if !memory.has(service_name):
		return null
	
	return memory[service_name][data_name]
