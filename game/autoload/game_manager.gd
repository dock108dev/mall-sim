## Global game state manager. Handles state transitions and session lifecycle.
extends Node

enum GameState {
	MAIN_MENU, GAMEPLAY, PAUSED, GAME_OVER,
	LOADING, DAY_SUMMARY, BUILD,
}

const DEFAULT_STARTING_STORE: StringName = &"sports"

const _VALID_TRANSITIONS: Dictionary = {
	GameState.MAIN_MENU: [GameState.LOADING],
	GameState.LOADING: [GameState.GAMEPLAY],
	GameState.GAMEPLAY: [
		GameState.PAUSED, GameState.DAY_SUMMARY,
		GameState.MAIN_MENU, GameState.BUILD, GameState.GAME_OVER,
	],
	GameState.PAUSED: [
		GameState.GAMEPLAY, GameState.MAIN_MENU, GameState.BUILD,
	],
	GameState.DAY_SUMMARY: [
		GameState.GAMEPLAY, GameState.MAIN_MENU, GameState.GAME_OVER,
	],
	GameState.BUILD: [GameState.GAMEPLAY],
	GameState.GAME_OVER: [GameState.MAIN_MENU],
}

var current_state: GameState = GameState.MAIN_MENU
var current_day: int:
	get:
		return _current_day
var current_store_id: StringName = &""
var is_tutorial_active: bool = false
var data_loader: DataLoader
var owned_stores: Array[StringName] = []
## Set by main menu before transitioning; GameWorld consumes and resets it.
var pending_load_slot: int = -1
var _scene_transition: SceneTransition
var _current_day: int = 1
var _boot_completed: bool = false
var _ending_id: StringName = &""


func _ready() -> void:
	_scene_transition = SceneTransition.new()
	add_child(_scene_transition)
	EventBus.day_started.connect(_on_day_started)
	EventBus.game_over_triggered.connect(trigger_game_over)
	EventBus.ending_triggered.connect(_on_ending_triggered)
	EventBus.player_bankrupt.connect(_on_player_bankrupt)


func change_state(new_state: GameState) -> bool:
	if new_state == GameState.MAIN_MENU:
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
	_current_day = 1
	current_store_id = ""
	is_tutorial_active = false
	_ending_id = &""
	owned_stores = [DEFAULT_STARTING_STORE]
	change_state(GameState.LOADING)
	change_state(GameState.GAMEPLAY)


## Loads a save slot and transitions to gameplay.
func load_game(slot: int) -> void:
	pending_load_slot = slot
	start_new_game()
	change_scene("res://game/scenes/world/game_world.tscn")


## Toggles current_state to PAUSED from GAMEPLAY.
func pause_game() -> void:
	change_state(GameState.PAUSED)


## Toggles current_state back to GAMEPLAY from PAUSED.
func resume_game() -> void:
	change_state(GameState.GAMEPLAY)


## Unloads the GameWorld scene and loads the main menu scene.
func go_to_main_menu() -> void:
	transition_to_menu()


## Transitions to the GAME_OVER state.
func trigger_game_over() -> void:
	change_state(GameState.GAME_OVER)


## Returns the ending_id that triggered the current game_over state.
func get_ending_id() -> StringName:
	return _ending_id


func _on_ending_triggered(
	ending_id: StringName, _final_stats: Dictionary
) -> void:
	if current_state == GameState.GAME_OVER:
		return
	if current_state == GameState.MAIN_MENU:
		return
	_ending_id = ending_id
	change_state(GameState.GAME_OVER)
	EventBus.time_speed_requested.emit(TimeSystem.SpeedTier.PAUSED)


func _on_player_bankrupt() -> void:
	if current_state != GameState.GAMEPLAY:
		return
	EventBus.ending_requested.emit("bankruptcy")


## Returns true if the player owns the given store.
func is_store_owned(store_id: String) -> bool:
	var canonical: StringName = ContentRegistry.resolve(store_id)
	if canonical.is_empty():
		return false
	return canonical in owned_stores


## Adds a store to the player's owned stores list.
func own_store(store_id: String) -> void:
	var canonical: StringName = ContentRegistry.resolve(store_id)
	if canonical.is_empty():
		return
	if canonical in owned_stores:
		return
	owned_stores.append(canonical)


func change_scene(scene_path: String) -> void:
	await _scene_transition.transition_to_scene(scene_path)


func change_scene_packed(scene: PackedScene) -> void:
	await _scene_transition.transition_to_packed(scene)


## Orchestrates tiered system initialization after DataLoader completes.
## Called by GameWorld._ready() once all system nodes are in the tree.
func initialize_game_systems(game_world: Node) -> void:
	if not game_world.has_method("initialize_systems"):
		push_error("GameManager: game_world missing initialize_systems()")
		return
	game_world.initialize_systems()
	EventBus.gameplay_ready.emit()


func transition_to_game() -> void:
	start_new_game()
	await change_scene("res://game/scenes/world/game_world.tscn")


func transition_to_menu() -> void:
	change_state(GameState.MAIN_MENU)
	await change_scene("res://game/scenes/ui/main_menu.tscn")


## Returns true after the boot sequence has completed successfully.
func is_boot_completed() -> bool:
	return _boot_completed


## Called by boot.gd after all boot steps succeed.
func mark_boot_completed() -> void:
	_boot_completed = true


func quit_game() -> void:
	get_tree().quit()


## Syncs current_day after a save file is loaded. TimeSystem owns the day;
## this keeps the read-only proxy accurate without emitting day_started.
func notify_day_loaded(day: int) -> void:
	_current_day = day


func _on_day_started(day: int) -> void:
	_current_day = day
