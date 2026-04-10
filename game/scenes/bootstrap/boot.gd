## Boot scene — loads settings and game content, then transitions to main menu.
extends Node


func _ready() -> void:
	Settings.load_settings()
	_load_content()
	_transition_after_delay()


func _transition_after_delay() -> void:
	await get_tree().create_timer(0.2).timeout
	GameManager.transition_to_menu()


func _load_content() -> void:
	var loader := DataLoader.new()
	loader.load_all_content()
	GameManager.data_loader = loader
	EventBus.content_loaded.emit()
