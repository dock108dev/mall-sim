## Global game state manager. Handles state transitions and session lifecycle.
extends Node

enum GameState {
	MAIN_MENU, GAMEPLAY, PAUSED, GAME_OVER,
	LOADING, DAY_SUMMARY, BUILD,
}

enum State {
	MAIN_MENU, GAMEPLAY, PAUSED, GAME_OVER,
	LOADING, DAY_SUMMARY, BUILD,
}

const DEFAULT_STARTING_STORE: StringName = &"sports"
const MAIN_MENU_SCENE_PATH := "res://game/scenes/ui/main_menu.tscn"
const GAMEPLAY_SCENE_PATH := "res://game/scenes/world/game_world.tscn"

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
		return get_current_day()
var current_store_id: StringName = &""
var is_tutorial_active: bool = false
var data_loader: DataLoader
var owned_stores: Array[StringName] = []
## Set by main menu before transitioning; GameWorld consumes and resets it.
var pending_load_slot: int = -1
var _scene_transition: SceneTransition
var _time_system_ref: WeakRef
var _boot_completed: bool = false
var _ending_id: StringName = &""
var _content_load_errors: Array[String] = []
var _current_day_shadow: int = 1


func _ready() -> void:
	_scene_transition = SceneTransition.new()
	add_child(_scene_transition)
	EventBus.content_load_failed.connect(_on_content_load_failed)
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
	if not _run_data_loader():
		return
	pending_load_slot = -1
	_reset_session_state()
	change_state(GameState.LOADING)
	change_state(GameState.GAMEPLAY)
	change_scene(GAMEPLAY_SCENE_PATH)


## Loads a save slot and transitions to gameplay.
func load_game(slot: int) -> void:
	if not _run_data_loader():
		return
	pending_load_slot = slot
	_reset_session_state()
	change_state(GameState.LOADING)
	change_state(GameState.GAMEPLAY)
	change_scene(GAMEPLAY_SCENE_PATH)


## Toggles current_state to PAUSED from GAMEPLAY.
func pause_game() -> void:
	change_state(GameState.PAUSED)


## Toggles current_state back to GAMEPLAY from PAUSED.
func resume_game() -> void:
	change_state(GameState.GAMEPLAY)


## Unloads the GameWorld scene and loads the main menu scene.
func go_to_main_menu() -> void:
	pending_load_slot = -1
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
	_scene_transition.transition_to_scene(scene_path)


func change_scene_packed(scene: PackedScene) -> void:
	_scene_transition.transition_to_packed(scene)


## Orchestrates tiered system initialization after DataLoader completes.
## Called by GameWorld._ready() once all system nodes are in the tree.
func initialize_game_systems(game_world: Node) -> void:
	if not _initialize_game_world_tiers(game_world):
		return
	if pending_load_slot >= 0:
		return
	_start_new_game(game_world)


## Applies pending new-game or load-game session state once GameWorld UI is ready.
func finalize_gameplay_start(game_world: Node) -> void:
	if not game_world.has_method("apply_pending_session_state"):
		push_error(
			"GameManager: game_world missing apply_pending_session_state()"
		)
		return
	game_world.apply_pending_session_state()
	EventBus.gameplay_ready.emit()


func transition_to_game() -> void:
	start_new_game()


## Public state transition entry point used by boot sequence and UI flows.
func transition_to(state: State) -> void:
	var target: GameState = state as int
	match target:
		GameState.MAIN_MENU:
			transition_to_menu()
		GameState.GAMEPLAY:
			transition_to_game()
		_:
			change_state(target)


func transition_to_menu() -> void:
	change_state(GameState.MAIN_MENU)
	change_scene(MAIN_MENU_SCENE_PATH)


## Returns true after the boot sequence has completed successfully.
func is_boot_completed() -> bool:
	return _boot_completed


## Called by boot.gd after all boot steps succeed.
func mark_boot_completed() -> void:
	_boot_completed = true


## Returns the most recent content loading errors captured during boot.
func get_content_load_errors() -> Array[String]:
	return _content_load_errors.duplicate()


## Returns the active TimeSystem-owned current day, or day 1 when absent.
func get_current_day() -> int:
	var time_system: TimeSystem = get_time_system()
	if time_system == null:
		return _current_day_shadow
	return time_system.current_day


## Returns the active TimeSystem from the current scene tree when available.
func get_time_system() -> TimeSystem:
	if _time_system_ref != null:
		var cached: TimeSystem = _time_system_ref.get_ref() as TimeSystem
		if cached != null and cached.is_inside_tree():
			return cached
	if not is_inside_tree():
		return null
	var root: Window = get_tree().root
	if root == null:
		return null
	var matches: Array[Node] = root.find_children(
		"*", "TimeSystem", true, false
	)
	if matches.is_empty():
		return null
	var time_system: TimeSystem = matches[0] as TimeSystem
	_time_system_ref = weakref(time_system)
	return time_system


func quit_game() -> void:
	get_tree().quit()


## Legacy no-op kept for compatibility. TimeSystem is the day source of truth.
func notify_day_loaded(_day: int) -> void:
	return


func _on_content_load_failed(errors: Array[String]) -> void:
	_content_load_errors = errors.duplicate()


func _on_day_started(day: int) -> void:
	_current_day_shadow = max(day, 1)


## Initializes GameWorld tiers in dependency order once content is ready.
func _initialize_game_world_tiers(game_world: Node) -> bool:
	if game_world.has_method("initialize_tier_1_data"):
		game_world.initialize_tier_1_data()
		game_world.initialize_tier_2_state()
		game_world.initialize_tier_3_operational()
		game_world.initialize_tier_4_world()
		game_world.initialize_tier_5_meta()
		game_world.finalize_system_wiring()
		return true
	if game_world.has_method("initialize_systems"):
		game_world.initialize_systems()
		return true
	push_error("GameManager: game_world missing tier initialization methods")
	return false


## Boots a new session after GameWorld has completed tier initialization.
func _start_new_game(game_world: Node) -> void:
	if data_loader == null:
		push_error("GameManager: cannot start new game without DataLoader")
		return
	if not game_world.has_method("bootstrap_new_game_state"):
		push_error("GameManager: game_world missing bootstrap_new_game_state()")
		return
	current_store_id = &""
	owned_stores = []
	game_world.bootstrap_new_game_state(DEFAULT_STARTING_STORE)


func _run_data_loader() -> bool:
	if data_loader == null:
		push_error("GameManager: cannot start session without DataLoader")
		return false
	_content_load_errors = []
	data_loader.run()
	_content_load_errors = data_loader.get_load_errors()
	if not _content_load_errors.is_empty():
		push_error(
			"GameManager: content load failed with %d errors"
			% _content_load_errors.size()
		)
		return false
	return true


func _reset_session_state() -> void:
	current_store_id = &""
	is_tutorial_active = false
	_ending_id = &""
	owned_stores = []
