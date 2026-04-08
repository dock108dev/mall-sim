## Handles saving and loading game state. Not yet implemented.
class_name SaveManager
extends RefCounted

const SAVE_PATH := "user://save_data.json"


static func save_game(_data: Dictionary) -> void:
	push_warning("SaveManager.save_game() — not yet implemented")


static func load_game() -> Dictionary:
	push_warning("SaveManager.load_game() — not yet implemented")
	return {}


static func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
