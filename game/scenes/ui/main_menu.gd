## Main menu — entry point after boot.
extends Control


func _ready() -> void:
	GameManager.current_state = GameManager.GameState.MAIN_MENU


func _on_play_pressed() -> void:
	GameManager.transition_to_game()


func _on_quit_pressed() -> void:
	GameManager.quit_game()
