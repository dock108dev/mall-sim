## Build/place mode for arranging fixtures and props in the store.
class_name BuildMode
extends Node

# Stub — will handle fixture placement, rotation, snapping, and validation.

var is_active: bool = false


func enter_build_mode() -> void:
	is_active = true


func exit_build_mode() -> void:
	is_active = false
