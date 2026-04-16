## Tests that current_day has a single source of truth in TimeSystem.
extends GutTest


var _time_system: TimeSystem


func before_each() -> void:
	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()


func test_game_manager_proxy_tracks_time_system_advances() -> void:
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
	for _i: int in range(3):
		_time_system.advance_to_next_day()

	assert_eq(
		GameManager.current_day, _time_system.current_day,
		"GameManager.current_day must equal TimeSystem.current_day"
	)


func test_game_manager_current_day_is_read_only_proxy() -> void:
	_time_system.current_day = 12
	EventBus.day_started.emit(42)
	assert_eq(
		GameManager.current_day, 12,
		"GameManager.current_day must ignore signal payloads and read TimeSystem directly"
	)


func test_notify_day_loaded_does_not_override_time_system() -> void:
	_time_system.current_day = 15
	GameManager.notify_day_loaded(2)
	assert_eq(
		GameManager.current_day, 15,
		"notify_day_loaded should not diverge from TimeSystem-owned day"
	)


func test_start_new_game_keeps_time_system_as_day_owner() -> void:
	_time_system.current_day = 99
	GameManager.start_new_game()
	assert_eq(
		GameManager.current_day, 99,
		"start_new_game should not shadow TimeSystem.current_day"
	)
