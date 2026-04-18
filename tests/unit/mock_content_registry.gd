## Test double for ContentRegistry that records errors without writing to the engine log.
class_name MockContentRegistry
extends "res://game/autoload/content_registry.gd"


var error_messages: Array[String] = []
var warning_messages: Array[String] = []


func _emit_error(message: String) -> void:
	error_messages.append(message)


func _emit_warning(message: String) -> void:
	warning_messages.append(message)
