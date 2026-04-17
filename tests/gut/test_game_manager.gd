## Tests GameManager session boot, state changes, and gameplay readiness flow.
extends GutTest


class FakeDataLoader:
	extends DataLoader

	var run_calls: int = 0
	var load_errors: Array[String] = []

	func run() -> void:
		run_calls += 1

	func get_load_errors() -> Array[String]:
		return load_errors.duplicate()


class FakeSceneTransition:
	extends SceneTransition

	var requested_paths: Array[String] = []

	func transition_to_scene(scene_path: String) -> void:
		requested_paths.append(scene_path)

	func transition_to_packed(_scene: PackedScene) -> void:
		return


class FakeGameWorld:
	extends Node

	var calls: Array[String] = []

	func initialize_tier_1_data() -> void:
		calls.append("initialize_tier_1_data")

	func initialize_tier_2_state() -> void:
		calls.append("initialize_tier_2_state")

	func initialize_tier_3_operational() -> void:
		calls.append("initialize_tier_3_operational")

	func initialize_tier_4_world() -> void:
		calls.append("initialize_tier_4_world")

	func initialize_tier_5_meta() -> void:
		calls.append("initialize_tier_5_meta")

	func finalize_system_wiring() -> void:
		calls.append("finalize_system_wiring")

	func initialize_systems() -> void:
		calls.append("initialize_systems")

	func bootstrap_new_game_state(store_id: StringName) -> void:
		calls.append("bootstrap_new_game_state:%s" % store_id)

	func apply_pending_session_state() -> void:
		calls.append("apply_pending_session_state")


var _original_state: int
var _original_pending_load_slot: int
var _original_current_store_id: StringName
var _original_owned_stores: Array[StringName]
var _original_ending_id: StringName
var _original_data_loader: DataLoader
var _original_scene_transition: SceneTransition
var _original_day_shadow: int

var _fake_loader: FakeDataLoader
var _fake_transition: FakeSceneTransition


func before_each() -> void:
	_original_state = GameManager.current_state
	_original_pending_load_slot = GameManager.pending_load_slot
	_original_current_store_id = GameManager.current_store_id
	_original_owned_stores = GameManager.owned_stores.duplicate()
	_original_ending_id = GameManager.get_ending_id()
	_original_data_loader = GameManager.data_loader
	_original_scene_transition = GameManager._scene_transition
	_original_day_shadow = GameManager._current_day_shadow

	_fake_loader = FakeDataLoader.new()
	_fake_transition = FakeSceneTransition.new()
	GameManager.data_loader = _fake_loader
	GameManager._scene_transition = _fake_transition
	GameManager.current_state = GameManager.GameState.MAIN_MENU
	GameManager.pending_load_slot = -1
	GameManager.current_store_id = &"retro_games"
	GameManager.owned_stores = [&"retro_games"]
	GameManager._ending_id = &"old_ending"
	GameManager._current_day_shadow = 1


func after_each() -> void:
	GameManager.current_state = _original_state
	GameManager.pending_load_slot = _original_pending_load_slot
	GameManager.current_store_id = _original_current_store_id
	GameManager.owned_stores = _original_owned_stores
	GameManager._ending_id = _original_ending_id
	GameManager.data_loader = _original_data_loader
	GameManager._scene_transition = _original_scene_transition
	GameManager._current_day_shadow = _original_day_shadow
	if is_instance_valid(_fake_loader):
		_fake_loader.free()
	if is_instance_valid(_fake_transition):
		_fake_transition.free()


func test_start_new_game_runs_data_loader_and_queues_gameplay_scene() -> void:
	GameManager.start_new_game()

	assert_eq(_fake_loader.run_calls, 1, "start_new_game should run DataLoader")
	assert_eq(GameManager.pending_load_slot, -1)
	assert_eq(GameManager.current_state, GameManager.GameState.GAMEPLAY)
	assert_eq(GameManager.current_store_id, &"")
	assert_eq(GameManager.owned_stores, [])
	assert_eq(GameManager.get_ending_id(), &"")
	assert_eq(
		_fake_transition.requested_paths,
		[GameManager.GAMEPLAY_SCENE_PATH],
		"start_new_game should transition to the gameplay scene"
	)


func test_load_game_preserves_requested_slot_and_queues_gameplay_scene() -> void:
	GameManager.load_game(2)

	assert_eq(_fake_loader.run_calls, 1, "load_game should run DataLoader")
	assert_eq(GameManager.pending_load_slot, 2)
	assert_eq(GameManager.current_state, GameManager.GameState.GAMEPLAY)
	assert_eq(
		_fake_transition.requested_paths,
		[GameManager.GAMEPLAY_SCENE_PATH],
		"load_game should transition to the gameplay scene"
	)


func test_pause_and_resume_emit_state_changes() -> void:
	var received: Array[Dictionary] = []
	var conn: Callable = func(old_state: int, new_state: int) -> void:
		received.append({"old": old_state, "new": new_state})
	EventBus.game_state_changed.connect(conn)

	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager.pause_game()
	GameManager.resume_game()

	EventBus.game_state_changed.disconnect(conn)
	assert_eq(GameManager.current_state, GameManager.GameState.GAMEPLAY)
	assert_eq(received.size(), 2, "pause/resume should emit two state changes")
	assert_eq(received[0]["new"], GameManager.GameState.PAUSED)
	assert_eq(received[1]["new"], GameManager.GameState.GAMEPLAY)


func test_game_over_trigger_signal_transitions_state() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY

	EventBus.game_over_triggered.emit()

	assert_eq(GameManager.current_state, GameManager.GameState.GAME_OVER)


func test_go_to_main_menu_resets_pending_slot_and_queues_menu_scene() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager.pending_load_slot = 1

	GameManager.go_to_main_menu()

	assert_eq(GameManager.pending_load_slot, -1)
	assert_eq(GameManager.current_state, GameManager.GameState.MAIN_MENU)
	assert_eq(
		_fake_transition.requested_paths,
		[GameManager.MAIN_MENU_SCENE_PATH],
		"go_to_main_menu should transition back to the main menu scene"
	)


func test_current_day_shadow_updates_from_day_started_signal() -> void:
	EventBus.day_started.emit(6)

	assert_eq(GameManager.current_day, 6)


func test_current_day_prefers_time_system_when_available() -> void:
	var time_system := TimeSystem.new()
	add_child_autofree(time_system)
	time_system.initialize()
	time_system.current_day = 9
	EventBus.day_started.emit(3)

	assert_eq(
		GameManager.current_day, 9,
		"TimeSystem remains the day source of truth when present"
	)


func test_initialize_game_systems_bootstraps_new_game_before_ready_signal() -> void:
	var world := FakeGameWorld.new()
	add_child_autofree(world)
	var ready_count: int = 0
	var conn: Callable = func() -> void:
		ready_count += 1
	EventBus.gameplay_ready.connect(conn)

	GameManager.initialize_game_systems(world)

	EventBus.gameplay_ready.disconnect(conn)
	assert_eq(
		world.calls,
		[
			"initialize_tier_1_data",
			"initialize_tier_2_state",
			"initialize_tier_3_operational",
			"initialize_tier_4_world",
			"initialize_tier_5_meta",
			"finalize_system_wiring",
			"bootstrap_new_game_state:sports",
		],
		"New game flow should initialize GameWorld tiers before bootstrapping default state"
	)
	assert_eq(ready_count, 0, "gameplay_ready should wait for session-state application")


func test_finalize_gameplay_start_applies_session_state_then_emits_ready() -> void:
	var world := FakeGameWorld.new()
	add_child_autofree(world)
	watch_signals(EventBus)

	GameManager.finalize_gameplay_start(world)

	assert_eq(world.calls, ["apply_pending_session_state"])
	assert_signal_emitted(
		EventBus,
		"gameplay_ready",
		"gameplay_ready should fire after session state is applied"
	)


func test_initialize_game_systems_load_path_skips_new_game_bootstrap() -> void:
	var world := FakeGameWorld.new()
	add_child_autofree(world)
	GameManager.pending_load_slot = 3

	GameManager.initialize_game_systems(world)

	assert_eq(
		world.calls,
		[
			"initialize_tier_1_data",
			"initialize_tier_2_state",
			"initialize_tier_3_operational",
			"initialize_tier_4_world",
			"initialize_tier_5_meta",
			"finalize_system_wiring",
		],
		"Load path should reuse tier initialization without seeding a new game state"
	)
