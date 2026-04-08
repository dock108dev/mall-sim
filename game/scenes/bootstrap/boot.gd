## Boot scene — loads settings, then transitions to main menu.
extends Node

func _ready() -> void:
	Settings.load_settings()
	# Small delay so the boot screen is visible during development.
	await get_tree().create_timer(0.2).timeout
	GameManager.transition_to_menu()
