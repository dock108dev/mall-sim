## A single StoreRegistry entry — pure data, no scene loading.
##
## Returned by `StoreRegistry.resolve(store_id)`. `controller_script` may be
## null while a store's real controller is still being authored; the scene
## itself is the canonical source of the controller in that case.
class_name StoreRegistryEntry
extends RefCounted

var store_id: StringName = &""
var scene_path: String = ""
var controller_script: Script = null
var display_name: String = ""
var metadata: Dictionary = {}


func _init(
	p_store_id: StringName = &"",
	p_scene_path: String = "",
	p_controller_script: Script = null,
	p_display_name: String = "",
	p_metadata: Dictionary = {}
) -> void:
	store_id = p_store_id
	scene_path = p_scene_path
	controller_script = p_controller_script
	display_name = p_display_name
	metadata = p_metadata.duplicate(true)
