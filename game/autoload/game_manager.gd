## Global game state manager. Handles state transitions and session lifecycle.
extends Node

enum GameState { MENU, LOADING, PLAYING, PAUSED, DAY_SUMMARY, BUILD }

const DEFAULT_STARTING_STORE: String = "sports_memorabilia"

const _VALID_TRANSITIONS: Dictionary = {
	GameState.MENU: [GameState.LOADING],
	GameState.LOADING: [GameState.PLAYING],
	GameState.PLAYING: [
		GameState.PAUSED, GameState.DAY_SUMMARY,
		GameState.MENU, GameState.BUILD,
	],
	GameState.PAUSED: [GameState.PLAYING, GameState.MENU, GameState.BUILD],
	GameState.DAY_SUMMARY: [GameState.PLAYING, GameState.MENU],
	GameState.BUILD: [GameState.PLAYING],
}

var current_state: GameState = GameState.MENU
var current_day: int = 0
var current_store_id: String = ""
var is_tutorial_active: bool = false
var data_loader: DataLoader
var owned_stores: Array[String] = []
## Set by main menu before transitioning; GameWorld consumes and resets it.
var pending_load_slot: int = -1
var _scene_transition: SceneTransition


func _ready() -> void:
	_scene_transition = SceneTransition.new()
	add_child(_scene_transition)


func change_state(new_state: GameState) -> bool:
	if new_state == GameState.MENU:
		var old_state: GameState = current_state
		current_state = new_state
		EventBus.game_state_changed.emit(old_state, new_state)
		return true

	var allowed: Array = _VALID_TRANSITIONS.get(current_state, [])
	if new_state not in allowed:
		push_warning(
			"GameManager: Invalid transition %s → %s"
			% [GameState.keys()[current_state], GameState.keys()[new_state]]
		)
		return false

	var old_state: GameState = current_state
	current_state = new_state
	EventBus.game_state_changed.emit(old_state, new_state)
	return true


func start_new_game() -> void:
	current_day = 1
	current_store_id = ""
	is_tutorial_active = false
	owned_stores = [DEFAULT_STARTING_STORE]
	change_state(GameState.LOADING)
	change_state(GameState.PLAYING)


## Returns true if the player owns the given store.
func is_store_owned(store_id: String) -> bool:
	return store_id in owned_stores


## Adds a store to the player's owned stores list.
func own_store(store_id: String) -> void:
	if store_id in owned_stores:
		return
	owned_stores.append(store_id)


func change_scene(scene_path: String) -> void:
	await _scene_transition.transition_to_scene(scene_path)


func change_scene_packed(scene: PackedScene) -> void:
	await _scene_transition.transition_to_packed(scene)


func transition_to_game() -> void:
	start_new_game()
	await change_scene("res://game/scenes/world/game_world.tscn")


func transition_to_menu() -> void:
	change_state(GameState.MENU)
	await change_scene("res://game/scenes/ui/main_menu.tscn")


func quit_game() -> void:
	get_tree().quit()
