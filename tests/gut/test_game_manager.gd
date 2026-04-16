## Tests GameManager state machine, public API, and EventBus integration.
extends GutTest


var _original_state: GameManager.GameState
var _original_day: int
var _original_stores: Array[StringName]
var _original_ending_id: StringName


func before_each() -> void:
	_original_state = GameManager.current_state
	_original_day = GameManager.current_day
	_original_stores = GameManager.owned_stores.duplicate()
	_original_ending_id = GameManager.get_ending_id()
	GameManager.current_state = GameManager.GameState.MAIN_MENU


func after_each() -> void:
	GameManager.current_state = _original_state
	var time_system: TimeSystem = GameManager.get_time_system()
	if time_system != null:
		time_system.current_day = _original_day
	GameManager.owned_stores = _original_stores
	GameManager._ending_id = _original_ending_id


func test_initial_state_is_main_menu() -> void:
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.MAIN_MENU,
		"Initial state should be MAIN_MENU"
	)


func test_valid_transition_main_menu_to_loading() -> void:
	var result: bool = GameManager.change_state(
		GameManager.GameState.LOADING
	)
	assert_true(result, "MAIN_MENU -> LOADING should succeed")
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.LOADING
	)


func test_invalid_transition_main_menu_to_gameplay() -> void:
	var result: bool = GameManager.change_state(
		GameManager.GameState.GAMEPLAY
	)
	assert_false(result, "MAIN_MENU -> GAMEPLAY should fail")
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.MAIN_MENU
	)


func test_gameplay_to_paused() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	var result: bool = GameManager.change_state(
		GameManager.GameState.PAUSED
	)
	assert_true(result, "GAMEPLAY -> PAUSED should succeed")


func test_gameplay_to_game_over() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	var result: bool = GameManager.change_state(
		GameManager.GameState.GAME_OVER
	)
	assert_true(result, "GAMEPLAY -> GAME_OVER should succeed")


func test_game_over_to_main_menu() -> void:
	GameManager.current_state = GameManager.GameState.GAME_OVER
	var result: bool = GameManager.change_state(
		GameManager.GameState.MAIN_MENU
	)
	assert_true(result, "GAME_OVER -> MAIN_MENU should succeed")


func test_pause_game_from_gameplay() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager.pause_game()
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.PAUSED,
		"pause_game() should transition to PAUSED"
	)


func test_resume_game_from_paused() -> void:
	GameManager.current_state = GameManager.GameState.PAUSED
	GameManager.resume_game()
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAMEPLAY,
		"resume_game() should transition to GAMEPLAY"
	)


func test_trigger_game_over_from_gameplay() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager.trigger_game_over()
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"trigger_game_over() should transition to GAME_OVER"
	)


func test_start_new_game_resets_state() -> void:
	GameManager.start_new_game()
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAMEPLAY,
		"start_new_game() should end in GAMEPLAY"
	)
	assert_eq(
		GameManager.current_day, 1,
		"start_new_game() should reset day to 1"
	)
	assert_eq(
		GameManager.owned_stores.size(), 1,
		"start_new_game() should have exactly one owned store"
	)


func test_state_change_emits_signal() -> void:
	var received: Array[Dictionary] = []
	EventBus.game_state_changed.connect(
		func(old: int, new: int) -> void:
			received.append({"old": old, "new": new})
	)
	GameManager.change_state(GameManager.GameState.LOADING)
	assert_eq(received.size(), 1, "Should emit game_state_changed")
	assert_eq(
		received[0]["new"],
		GameManager.GameState.LOADING
	)


func test_current_day_reads_from_time_system() -> void:
	var time_system := TimeSystem.new()
	add_child_autofree(time_system)
	time_system.initialize()
	time_system.current_day = 6
	time_system.advance_to_next_day()
	assert_eq(
		GameManager.current_day, 7,
		"current_day should be read from TimeSystem"
	)


func test_game_over_triggered_signal_calls_trigger_game_over() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	EventBus.game_over_triggered.emit()
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"game_over_triggered signal should cause GAME_OVER state"
	)


func test_build_state_transitions() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	var to_build: bool = GameManager.change_state(
		GameManager.GameState.BUILD
	)
	assert_true(to_build, "GAMEPLAY -> BUILD should succeed")

	var to_gameplay: bool = GameManager.change_state(
		GameManager.GameState.GAMEPLAY
	)
	assert_true(to_gameplay, "BUILD -> GAMEPLAY should succeed")


func test_day_summary_transitions() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	var to_summary: bool = GameManager.change_state(
		GameManager.GameState.DAY_SUMMARY
	)
	assert_true(to_summary, "GAMEPLAY -> DAY_SUMMARY should succeed")

	var to_gameplay: bool = GameManager.change_state(
		GameManager.GameState.GAMEPLAY
	)
	assert_true(to_gameplay, "DAY_SUMMARY -> GAMEPLAY should succeed")


func test_always_can_transition_to_main_menu() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	var result: bool = GameManager.change_state(
		GameManager.GameState.MAIN_MENU
	)
	assert_true(
		result,
		"Should always be able to transition to MAIN_MENU"
	)


func test_pause_from_non_gameplay_state_does_nothing() -> void:
	GameManager.current_state = GameManager.GameState.MAIN_MENU
	GameManager.pause_game()
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.MAIN_MENU,
		"pause_game() from MAIN_MENU should not change state"
	)


func test_pause_from_game_over_does_nothing() -> void:
	GameManager.current_state = GameManager.GameState.GAME_OVER
	GameManager.pause_game()
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"pause_game() from GAME_OVER should not change state"
	)


func test_gameplay_ready_signal_emits_after_initialize() -> void:
	var received: Array[bool] = []
	var conn: Callable = func() -> void: received.append(true)
	EventBus.gameplay_ready.connect(conn)

	var mock_world: Node = Node.new()
	mock_world.set_script(GDScript.new())
	mock_world.get_script().source_code = (
		"extends Node\nfunc initialize_systems() -> void:\n\tpass\n"
	)
	mock_world.get_script().reload()
	add_child_autofree(mock_world)

	GameManager.initialize_game_systems(mock_world)

	assert_eq(
		received.size(), 1,
		"gameplay_ready should fire exactly once"
	)
	EventBus.gameplay_ready.disconnect(conn)


func test_current_day_proxy_updates_after_multiple_advances() -> void:
	var time_system := TimeSystem.new()
	add_child_autofree(time_system)
	time_system.initialize()
	for _i: int in range(4):
		time_system.advance_to_next_day()
	assert_eq(
		GameManager.current_day, 5,
		"current_day should equal TimeSystem day after advances"
	)


func test_current_day_not_set_directly() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://game/autoload/game_manager.gd"
	)
	assert_true(
		not source.contains("_current_day"),
		"GameManager should not define a writable _current_day shadow field"
	)
	assert_true(
		source.contains("return get_current_day()"),
		"current_day getter should delegate to TimeSystem-backed get_current_day()"
	)


func test_initialization_tier_order() -> void:
	var mock_world: Node = Node.new()
	var script: GDScript = GDScript.new()
	script.source_code = """extends Node

var call_log: Array[String] = []

func initialize_systems() -> void:
	call_log.append("initialize_systems")
"""
	script.reload()
	mock_world.set_script(script)
	add_child_autofree(mock_world)

	var ready_fired: Array[bool] = []
	var conn: Callable = func() -> void: ready_fired.append(true)
	EventBus.gameplay_ready.connect(conn)

	GameManager.initialize_game_systems(mock_world)

	assert_eq(
		mock_world.call_log.size(), 1,
		"initialize_systems should be called exactly once"
	)
	assert_eq(
		ready_fired.size(), 1,
		"gameplay_ready should fire after initialize_systems"
	)
	EventBus.gameplay_ready.disconnect(conn)


func test_initialize_game_systems_rejects_invalid_world() -> void:
	var mock_world: Node = Node.new()
	add_child_autofree(mock_world)

	var ready_fired: Array[bool] = []
	var conn: Callable = func() -> void: ready_fired.append(true)
	EventBus.gameplay_ready.connect(conn)

	GameManager.initialize_game_systems(mock_world)

	assert_eq(
		ready_fired.size(), 0,
		"gameplay_ready should not fire if world lacks initialize_systems"
	)
	EventBus.gameplay_ready.disconnect(conn)


func test_ending_triggered_transitions_to_game_over() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	EventBus.ending_triggered.emit(&"mall_tycoon", {})
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"ending_triggered should transition to GAME_OVER"
	)
	assert_eq(
		GameManager.get_ending_id(), &"mall_tycoon",
		"ending_id should be stored"
	)


func test_ending_triggered_ignored_during_game_over() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager._ending_id = &""
	EventBus.ending_triggered.emit(&"first_ending", {})
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER
	)
	EventBus.ending_triggered.emit(&"second_ending", {})
	assert_eq(
		GameManager.get_ending_id(), &"first_ending",
		"Duplicate ending_triggered should be ignored"
	)


func test_ending_triggered_ignored_during_main_menu() -> void:
	GameManager.current_state = GameManager.GameState.MAIN_MENU
	EventBus.ending_triggered.emit(&"some_ending", {})
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.MAIN_MENU,
		"ending_triggered should be ignored in MAIN_MENU"
	)


func test_ending_triggered_pauses_time() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	var speed_requests: Array[int] = []
	var conn: Callable = func(tier: int) -> void:
		speed_requests.append(tier)
	EventBus.time_speed_requested.connect(conn)
	EventBus.ending_triggered.emit(&"bankruptcy", {})
	assert_eq(
		speed_requests.size(), 1,
		"Should emit time_speed_requested"
	)
	assert_eq(
		speed_requests[0], TimeSystem.SpeedTier.PAUSED,
		"Should request PAUSED speed"
	)
	EventBus.time_speed_requested.disconnect(conn)


func test_player_bankrupt_emits_ending_requested() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	var requests: Array[String] = []
	var conn: Callable = func(trigger: String) -> void:
		requests.append(trigger)
	EventBus.ending_requested.connect(conn)
	EventBus.player_bankrupt.emit()
	assert_eq(requests.size(), 1, "Should emit ending_requested")
	assert_eq(
		requests[0], "bankruptcy",
		"Should request bankruptcy ending"
	)
	EventBus.ending_requested.disconnect(conn)


func test_player_bankrupt_ignored_outside_gameplay() -> void:
	GameManager.current_state = GameManager.GameState.PAUSED
	var requests: Array[String] = []
	var conn: Callable = func(trigger: String) -> void:
		requests.append(trigger)
	EventBus.ending_requested.connect(conn)
	EventBus.player_bankrupt.emit()
	assert_eq(
		requests.size(), 0,
		"player_bankrupt should be ignored outside GAMEPLAY"
	)
	EventBus.ending_requested.disconnect(conn)


func test_start_new_game_resets_ending_id() -> void:
	GameManager._ending_id = &"old_ending"
	GameManager.start_new_game()
	assert_eq(
		GameManager.get_ending_id(), &"",
		"start_new_game should reset ending_id"
	)
