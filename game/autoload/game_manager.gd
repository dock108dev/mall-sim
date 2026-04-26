# gdlint:disable=max-public-methods
## Global game state manager. Handles state transitions and session lifecycle.
extends Node

enum State {
	MAIN_MENU, GAMEPLAY, PAUSED, GAME_OVER,
	LOADING, DAY_SUMMARY, BUILD,
	MALL_OVERVIEW, STORE_VIEW,
}

const DEFAULT_STARTING_STORE: StringName = &"retro_games"
const MAIN_MENU_SCENE_PATH := "res://game/scenes/ui/main_menu.tscn"
const GAMEPLAY_SCENE_PATH := "res://game/scenes/mall/mall_hub.tscn"

const _VALID_TRANSITIONS: Dictionary = {
	State.MAIN_MENU: [State.LOADING],
	State.LOADING: [State.GAMEPLAY, State.MALL_OVERVIEW],
	State.GAMEPLAY: [
		State.PAUSED, State.DAY_SUMMARY,
		State.MAIN_MENU, State.BUILD, State.GAME_OVER,
		State.MALL_OVERVIEW,
	],
	State.PAUSED: [
		State.GAMEPLAY, State.MAIN_MENU, State.BUILD,
		State.MALL_OVERVIEW, State.STORE_VIEW,
	],
	State.DAY_SUMMARY: [
		State.GAMEPLAY, State.MAIN_MENU, State.GAME_OVER,
		State.MALL_OVERVIEW,
	],
	State.BUILD: [State.GAMEPLAY, State.MALL_OVERVIEW],
	State.GAME_OVER: [State.MAIN_MENU],
	State.MALL_OVERVIEW: [
		State.STORE_VIEW, State.PAUSED, State.DAY_SUMMARY,
		State.MAIN_MENU, State.BUILD, State.GAME_OVER,
	],
	State.STORE_VIEW: [
		State.MALL_OVERVIEW, State.PAUSED, State.DAY_SUMMARY,
		State.MAIN_MENU, State.BUILD, State.GAME_OVER,
	],
}

var current_state: State = State.MAIN_MENU
var current_day: int:
	get:
		return get_current_day()
	set(value):
		set_current_day(value)
var current_store_id: StringName = &""
var is_tutorial_active: bool = false
var data_loader: DataLoader
var owned_stores: Array[StringName] = []
## Set by main menu before transitioning; GameWorld consumes and resets it.
var pending_load_slot: int = -1
var _scene_transition: SceneTransition
var _time_system_ref: WeakRef
var _store_state_manager_ref: WeakRef
var _inventory_system_ref: WeakRef
var _customer_system_ref: WeakRef
var _economy_system_ref: WeakRef
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


func change_state(new_state: State) -> bool:
	var previous_state: State = current_state
	if new_state == State.MAIN_MENU:
		current_state = new_state
		EventBus.game_state_changed.emit(previous_state, new_state)
		return true

	var allowed: Array = _VALID_TRANSITIONS.get(current_state, [])
	if new_state not in allowed:
		push_warning(
			"GameManager: Invalid transition %s → %s"
			% [
				State.keys()[int(current_state)],
				State.keys()[int(new_state)],
			]
		)
		return false

	previous_state = current_state
	current_state = new_state
	EventBus.game_state_changed.emit(previous_state, new_state)
	return true


func start_new_game() -> void:
	if not _run_data_loader():
		return
	begin_new_run()
	change_state(State.LOADING)
	change_state(State.GAMEPLAY)
	change_scene(GAMEPLAY_SCENE_PATH)


## Initializes a fresh run: clears session state, resets day to 1, and emits
## the `new_game_clicked` audit checkpoint. Called by `start_new_game()` before
## the mall_hub scene swap so day/money are set before MallHub._ready() runs.
func begin_new_run() -> void:
	pending_load_slot = -1
	_reset_session_state()
	set_current_day(1)
	if AuditLog != null:
		AuditLog.pass_check(
			&"new_game_clicked",
			"day=1 store=%s" % DEFAULT_STARTING_STORE
		)


## Loads a save slot and transitions to gameplay.
func load_game(slot: int) -> void:
	if not _run_data_loader():
		return
	pending_load_slot = slot
	_reset_session_state()
	change_state(State.LOADING)
	change_state(State.GAMEPLAY)
	change_scene(GAMEPLAY_SCENE_PATH)


## Toggles current_state to PAUSED from GAMEPLAY.
func pause_game() -> void:
	change_state(State.PAUSED)


## Toggles current_state back to GAMEPLAY from PAUSED.
func resume_game() -> void:
	change_state(State.GAMEPLAY)


## Unloads the GameWorld scene and loads the main menu scene.
func go_to_main_menu() -> void:
	pending_load_slot = -1
	transition_to_menu()


## Transitions to the GAME_OVER state.
func trigger_game_over() -> void:
	change_state(State.GAME_OVER)


## Returns the ending_id that triggered the current game_over state.
func get_ending_id() -> StringName:
	return _ending_id


func _on_ending_triggered(
	ending_id: StringName, _final_stats: Dictionary
) -> void:
	if current_state == State.GAME_OVER:
		return
	if current_state == State.MAIN_MENU:
		return
	_ending_id = ending_id
	change_state(State.GAME_OVER)
	EventBus.time_speed_requested.emit(TimeSystem.SpeedTier.PAUSED)


func _on_player_bankrupt() -> void:
	if current_state != State.GAMEPLAY:
		return
	EventBus.ending_requested.emit("bankruptcy")


## Returns true if the player owns the given store.
func is_store_owned(store_id: String) -> bool:
	var canonical: StringName = ContentRegistry.resolve(store_id)
	if canonical.is_empty():
		return false
	return canonical in get_owned_store_ids()


## Returns the authoritative active store from StoreStateManager when available.
func get_active_store_id() -> StringName:
	var store_state_manager: StoreStateManager = get_store_state_manager()
	if store_state_manager != null:
		return store_state_manager.active_store_id
	return current_store_id


## Returns owned store IDs ordered by storefront slot when StoreStateManager is active.
func get_owned_store_ids() -> Array[StringName]:
	var store_state_manager: StoreStateManager = get_store_state_manager()
	if store_state_manager != null:
		return store_state_manager.get_owned_store_ids()
	return owned_stores.duplicate()


func change_scene(scene_path: String) -> void:
	_scene_transition.transition_to_scene(scene_path)


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
	match state:
		State.MAIN_MENU:
			transition_to_menu()
		State.GAMEPLAY:
			transition_to_game()
		_:
			change_state(state)


func transition_to_menu() -> void:
	change_state(State.MAIN_MENU)
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


## Keeps legacy tests and systems able to override the current day without a
## live TimeSystem, while still forwarding to TimeSystem when present.
func set_current_day(day: int) -> void:
	var normalized_day: int = max(day, 1)
	_current_day_shadow = normalized_day
	var time_system: TimeSystem = get_time_system()
	if time_system != null:
		time_system.current_day = normalized_day


## Returns the active TimeSystem from the current scene tree when available.
func get_time_system() -> TimeSystem:
	_time_system_ref = _resolve_system_ref(_time_system_ref, "TimeSystem")
	if _time_system_ref == null:
		return null
	return _time_system_ref.get_ref() as TimeSystem


## Returns the active InventorySystem from the current scene tree when available.
func get_inventory_system() -> InventorySystem:
	_inventory_system_ref = _resolve_system_ref(
		_inventory_system_ref, "InventorySystem"
	)
	if _inventory_system_ref == null:
		return null
	return _inventory_system_ref.get_ref() as InventorySystem


## Returns the active CustomerSystem from the current scene tree when available.
func get_customer_system() -> CustomerSystem:
	_customer_system_ref = _resolve_system_ref(
		_customer_system_ref, "CustomerSystem"
	)
	if _customer_system_ref == null:
		return null
	return _customer_system_ref.get_ref() as CustomerSystem


## Returns the active EconomySystem from the current scene tree when available.
func get_economy_system() -> EconomySystem:
	_economy_system_ref = _resolve_system_ref(
		_economy_system_ref, "EconomySystem"
	)
	if _economy_system_ref == null:
		return null
	return _economy_system_ref.get_ref() as EconomySystem


## Returns the active StoreStateManager from the current scene tree when available.
func get_store_state_manager() -> StoreStateManager:
	_store_state_manager_ref = _resolve_system_ref(
		_store_state_manager_ref, "StoreStateManager"
	)
	if _store_state_manager_ref == null:
		return null
	return _store_state_manager_ref.get_ref() as StoreStateManager


## Returns a WeakRef to a system node by class name, reusing the supplied cached
## ref when it still points into the current scene tree. Returns null when the
## tree is not yet ready or no matching node exists.
##
## Silent null is intentional: HUD `_seed_counters_from_systems()` and other
## early callers run during Tier-5 UI ready (before world systems may have
## attached) and during headless tests. Logging here would create push_warning
## spam that breaks CI's error audit. Callers that need to assert presence
## must do so themselves. See docs/audits/error-handling-report.md §J1.
func _resolve_system_ref(cached_ref: WeakRef, class_name_filter: String) -> WeakRef:
	if cached_ref != null:
		var cached: Node = cached_ref.get_ref() as Node
		if cached != null and cached.is_inside_tree():
			return cached_ref
	if not is_inside_tree():
		return null
	var root: Window = get_tree().root
	if root == null:
		return null
	var matches: Array[Node] = root.find_children(
		"*", class_name_filter, true, false
	)
	if matches.is_empty():
		return null
	return weakref(matches[0])


func quit_game() -> void:
	_flush_save_before_quit()
	get_tree().quit()


func _flush_save_before_quit() -> void:
	if current_state != State.GAMEPLAY and current_state != State.PAUSED:
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var matches: Array[Node] = tree.current_scene.find_children(
		"*", "SaveManager", true, false
	)
	if matches.is_empty():
		return
	var save_manager: SaveManager = matches[0] as SaveManager
	if save_manager == null:
		return
	save_manager.save_game(SaveManager.AUTO_SAVE_SLOT)


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
		push_warning("GameManager: cannot start session without DataLoader")
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
