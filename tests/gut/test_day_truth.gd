## Tests that current_day has a single source of truth in TimeSystem.
extends GutTest


var _time_system: TimeSystem


func before_each() -> void:
	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()


func test_game_manager_syncs_via_day_started() -> void:
	_time_system.advance_to_next_day()
	assert_eq(
		GameManager.current_day, 2,
		"GameManager should sync to day 2 after first advance"
	)

	_time_system.advance_to_next_day()
	assert_eq(
		GameManager.current_day, 3,
		"GameManager should sync to day 3 after second advance"
	)

	_time_system.advance_to_next_day()
	assert_eq(
		GameManager.current_day, 4,
		"GameManager should sync to day 4 after third advance"
	)


func test_game_manager_matches_time_system_after_three_advances() -> void:
	for i: int in range(3):
		_time_system.advance_to_next_day()

	assert_eq(
		GameManager.current_day, _time_system.current_day,
		"GameManager.current_day must equal TimeSystem.current_day"
	)


func test_game_manager_current_day_is_read_only_proxy() -> void:
	EventBus.day_started.emit(42)
	assert_eq(
		GameManager.current_day, 42,
		"GameManager.current_day should reflect signal payload"
	)


func test_notify_day_loaded_syncs_without_signal() -> void:
	GameManager.notify_day_loaded(15)
	assert_eq(
		GameManager.current_day, 15,
		"notify_day_loaded should update the proxy directly"
	)


func test_start_new_game_resets_day_to_one() -> void:
	EventBus.day_started.emit(99)
	GameManager.start_new_game()
	assert_eq(
		GameManager.current_day, 1,
		"start_new_game should reset current_day to 1"
	)
