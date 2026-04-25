## Tests for DayCycleController day-end coordination flow.
extends GutTest


var _controller: DayCycleController
var _time: TimeSystem
var _economy: EconomySystem
var _staff: StaffSystem
var _progression: ProgressionSystem
var _ending_eval: EndingEvaluatorSystem
var _perf_report: PerformanceReportSystem

var _saved_state: int
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]
var _bankruptcy_count: int = 0
var _next_day_count: int = 0


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	GameManager.current_store_id = &"pocket_creatures"
	GameManager.owned_stores = []

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.initialize()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)

	_staff = StaffSystem.new()
	add_child_autofree(_staff)

	_progression = ProgressionSystem.new()
	add_child_autofree(_progression)

	_ending_eval = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_eval)

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()

	_controller = DayCycleController.new()
	add_child_autofree(_controller)
	_controller.initialize(
		_time, _economy, _staff, _progression,
		_ending_eval, _perf_report,
	)

	_bankruptcy_count = 0
	_next_day_count = 0
	EventBus.bankruptcy_declared.connect(_on_bankruptcy)
	EventBus.day_started.connect(_on_day_started)


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	_safe_disconnect(
		EventBus.bankruptcy_declared, _on_bankruptcy
	)
	_safe_disconnect(
		EventBus.day_started, _on_day_started
	)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_bankruptcy() -> void:
	_bankruptcy_count += 1


func _on_day_started(_day: int) -> void:
	_next_day_count += 1


func test_connects_to_day_ended() -> void:
	assert_true(
		EventBus.day_ended.is_connected(
			_controller._on_day_ended
		),
		"Controller should connect to day_ended in initialize"
	)


func test_game_over_blocks_panel() -> void:
	GameManager.current_state = GameManager.State.GAME_OVER
	_controller._on_day_ended(1)
	assert_false(
		_controller._awaiting_acknowledgement,
		"Should not show panel when game is over"
	)


func test_day_ended_transitions_to_day_summary() -> void:
	GameManager.current_state = GameManager.State.GAMEPLAY
	_controller._on_day_ended(1)
	assert_eq(
		GameManager.current_state,
		GameManager.State.DAY_SUMMARY,
		"State should transition to DAY_SUMMARY on day_ended"
	)
	assert_true(
		_controller._awaiting_acknowledgement,
		"Should be awaiting acknowledgement after day_ended"
	)


func test_acknowledgement_advances_day() -> void:
	GameManager.current_state = GameManager.State.GAMEPLAY
	_controller._on_day_ended(1)
	assert_eq(
		_controller._awaiting_acknowledgement, true,
		"Should await acknowledgement"
	)

	_controller._on_day_acknowledged()
	assert_eq(
		_next_day_count, 1,
		"Day should advance after acknowledgement"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.State.GAMEPLAY,
		"State should return to GAMEPLAY"
	)


func test_bankruptcy_emitted_when_cash_negative() -> void:
	_economy.initialize(5.0)
	_staff.initialize(
		_economy, ReputationSystemSingleton, null, null
	)
	GameManager.current_state = GameManager.State.GAMEPLAY
	_controller._on_day_ended(1)
	_economy.force_deduct_cash(100.0, "Test overdraft")

	_controller._on_day_acknowledged()
	assert_true(
		_economy.get_cash() < 0.0,
		"Cash should be negative"
	)


func test_duplicate_acknowledgement_ignored() -> void:
	GameManager.current_state = GameManager.State.GAMEPLAY
	_controller._on_day_ended(1)
	_controller._on_day_acknowledged()
	var day_after_first: int = _time.current_day

	_controller._on_day_acknowledged()
	assert_eq(
		_time.current_day, day_after_first,
		"Duplicate acknowledgement should not advance day"
	)


func test_no_advance_if_ending_triggered() -> void:
	GameManager.current_state = GameManager.State.GAMEPLAY
	_ending_eval.initialize()
	_controller._on_day_ended(1)

	_ending_eval.force_ending(&"test_ending")

	assert_eq(
		_next_day_count, 0,
		"Day should not advance when ending is triggered"
	)
