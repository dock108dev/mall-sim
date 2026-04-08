## Base class for any object the player can interact with.
class_name Interactable
extends Area3D

@export var display_name: String = "Item"
@export var interaction_prompt: String = "Inspect"


func interact() -> void:
	# Override in subclasses.
	print("[Interactable] %s interacted" % display_name)
