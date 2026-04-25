## Tests that PerformanceReportSystem patches store_revenue from day_closed.
extends GutTest


var _system: PerformanceReportSystem
var _saved_state: GameManager.State
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	GameManager.current_state = GameManager.State.GAMEPLAY
	GameManager.current_store_id = &""
	GameManager.owned_stores = []

	_system = PerformanceReportSystem.new()
	add_child_autofree(_system)
	_system.initialize()


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores


func test_store_revenue_empty_before_day_closed() -> void:
	EventBus.day_ended.emit(1)
	var history: Array[PerformanceReport] = _system.get_history()
	assert_eq(history.size(), 1, "One report after day_ended")
	assert_eq(
		history[0].store_revenue.size(), 0,
		"store_revenue must be empty before day_closed fires"
	)


func test_store_revenue_patched_after_day_closed() -> void:
	EventBus.day_ended.emit(1)
	var payload: Dictionary = {
		"store_revenue": {"retro_games": 120.0, "electronics": 80.0},
	}
	EventBus.day_closed.emit(1, payload)
	var history: Array[PerformanceReport] = _system.get_history()
	assert_eq(history.size(), 1, "Still one report after day_closed")
	assert_eq(
		history[0].store_revenue.get("retro_games", 0.0),
		120.0,
		"retro_games revenue must be 120.0"
	)
	assert_eq(
		history[0].store_revenue.get("electronics", 0.0),
		80.0,
		"electronics revenue must be 80.0"
	)


func test_day_closed_for_wrong_day_does_not_patch() -> void:
	EventBus.day_ended.emit(1)
	var payload: Dictionary = {
		"store_revenue": {"retro_games": 200.0},
	}
	EventBus.day_closed.emit(2, payload)
	var history: Array[PerformanceReport] = _system.get_history()
	assert_eq(
		history[0].store_revenue.size(), 0,
		"Mismatched day must not patch store_revenue"
	)


func test_get_best_day_report_returns_highest_revenue() -> void:
	EventBus.day_ended.emit(1)
	EventBus.day_started.emit(2)
	EventBus.day_ended.emit(2)
	var history: Array[PerformanceReport] = _system.get_history()
	assert_eq(history.size(), 2, "Two reports must be in history")
	var best: PerformanceReport = _system.get_best_day_report()
	assert_not_null(best, "get_best_day_report must not return null")


func test_get_best_day_report_null_on_empty_history() -> void:
	var best: PerformanceReport = _system.get_best_day_report()
	assert_null(
		best, "get_best_day_report must return null when history is empty"
	)


func test_get_recent_history_caps_at_count() -> void:
	for d: int in range(1, 10):
		EventBus.day_ended.emit(d)
		EventBus.day_started.emit(d + 1)
	EventBus.day_ended.emit(10)
	var recent: Array[PerformanceReport] = _system.get_recent_history(7)
	assert_eq(recent.size(), 7, "get_recent_history must return at most 7")


func test_get_recent_history_returns_all_when_fewer_than_count() -> void:
	EventBus.day_ended.emit(1)
	var recent: Array[PerformanceReport] = _system.get_recent_history(7)
	assert_eq(recent.size(), 1, "Returns all when fewer than requested")


func test_store_revenue_serialized_and_deserialized() -> void:
	EventBus.day_ended.emit(1)
	EventBus.day_closed.emit(1, {
		"store_revenue": {"video_rental": 55.0}
	})
	var save_data: Dictionary = _system.get_save_data()
	var new_system: PerformanceReportSystem = PerformanceReportSystem.new()
	add_child_autofree(new_system)
	new_system.initialize()
	new_system.load_save_data(save_data)
	var loaded: Array[PerformanceReport] = new_system.get_history()
	assert_eq(loaded.size(), 1, "Loaded history must have one report")
	assert_eq(
		loaded[0].store_revenue.get("video_rental", 0.0),
		55.0,
		"store_revenue must survive save/load round-trip"
	)
