## Global game state manager. Handles scene transitions and top-level game flow.
extends Node

enum GameState { BOOT, MAIN_MENU, PLAYING, PAUSED }

var current_state: GameState = GameState.BOOT


func change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func transition_to_game() -> void:
	current_state = GameState.PLAYING
	change_scene("res://game/scenes/world/game_world.tscn")


func transition_to_menu() -> void:
	current_state = GameState.MAIN_MENU
	change_scene("res://game/scenes/ui/main_menu.tscn")


func quit_game() -> void:
	get_tree().quit()
