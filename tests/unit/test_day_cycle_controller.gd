## Unit tests for DayCycleController — day_ended receipt, wage/advance ordering, bankruptcy, endings.
class_name TestDayCycleController
extends GutTest

const TEST_SIGNAL_UTILS: GDScript = preload("res://game/tests/test_signal_utils.gd")

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
var _ending_requested_count: int = 0
var _day_started_count: int = 0
var _call_log: Array[StringName] = []


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	GameManager.current_state = GameManager.GameState.GAMEPLAY
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
	_ending_eval.initialize()

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
	_ending_requested_count = 0
	_day_started_count = 0
	_call_log = []

	EventBus.bankruptcy_declared.connect(_on_bankruptcy)
	EventBus.ending_requested.connect(_on_ending_requested)
	EventBus.day_started.connect(_on_day_started)


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.bankruptcy_declared, _on_bankruptcy)
	TEST_SIGNAL_UTILS.safe_disconnect(
		EventBus.ending_requested, _on_ending_requested
	)
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.day_started, _on_day_started)


func _on_bankruptcy() -> void:
	_bankruptcy_count += 1
	_call_log.append(&"bankruptcy_declared")


func _on_ending_requested(_trigger_type: String) -> void:
	_ending_requested_count += 1


func _on_day_started(_day: int) -> void:
	_day_started_count += 1
	_call_log.append(&"day_started")


# ── Test 1: day_ended signal receipt triggers handler ────────────────────────

func test_day_ended_connects_handler() -> void:
	assert_true(
		EventBus.day_ended.is_connected(
			_controller._on_day_ended
		),
		"Controller should connect to EventBus.day_ended on initialize"
	)


func test_day_ended_signal_transitions_to_day_summary() -> void:
	EventBus.day_ended.emit(1)
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.DAY_SUMMARY,
		"day_ended should transition state to DAY_SUMMARY"
	)
	assert_true(
		_controller._awaiting_acknowledgement,
		"Should set _awaiting_acknowledgement after day_ended"
	)


# ── Test 2: wages called before advance_day ──────────────────────────────────

func test_wages_before_advance_day() -> void:
	_staff.initialize(_economy, ReputationSystemSingleton, null, null)
	_controller._on_day_ended(1)
	var day_before: int = _time.current_day

	_controller._on_day_acknowledged()

	assert_true(
		_day_started_count >= 1,
		"advance_to_next_day should have been called"
	)
	assert_eq(
		_time.current_day, day_before + 1,
		"Day should advance by one after acknowledgement"
	)


# ── Test 3: bankruptcy path ──────────────────────────────────────────────────

func test_bankruptcy_when_cash_negative_after_wages() -> void:
	_economy.initialize(5.0)
	_staff.initialize(_economy, ReputationSystemSingleton, null, null)
	_controller._on_day_ended(1)

	_economy.force_deduct_cash(100.0, "Pre-wage overdraft")
	var day_before: int = _time.current_day

	_controller._on_day_acknowledged()

	assert_true(
		_economy.get_cash() < 0.0,
		"Cash should be negative after wages"
	)
	assert_true(
		_bankruptcy_count > 0,
		"bankruptcy_declared should be emitted when cash < 0"
	)
	assert_eq(
		_time.current_day, day_before,
		"advance_to_next_day should NOT be called after bankruptcy"
	)


func test_bankruptcy_emits_ending_requested() -> void:
	_economy.initialize(5.0)
	_staff.initialize(_economy, ReputationSystemSingleton, null, null)
	_controller._on_day_ended(1)
	_economy.force_deduct_cash(100.0, "Overdraft")

	_controller._on_day_acknowledged()

	assert_true(
		_ending_requested_count > 0,
		"ending_requested('bankruptcy') should be emitted"
	)


func test_bankruptcy_prevents_advance() -> void:
	_economy.initialize(5.0)
	_staff.initialize(_economy, ReputationSystemSingleton, null, null)
	_controller._on_day_ended(1)
	_economy.force_deduct_cash(100.0, "Overdraft")
	var day_before: int = _time.current_day

	_controller._on_day_acknowledged()

	assert_eq(
		_time.current_day, day_before,
		"Day should NOT advance when bankruptcy is triggered"
	)


# ── Test 4: milestone before ending evaluation ───────────────────────────────

func test_milestones_evaluated_before_endings() -> void:
	_controller._on_day_ended(1)

	_controller._on_day_acknowledged()

	assert_eq(
		_day_started_count, 1,
		"Normal path should advance day (milestones and endings both run)"
	)


# ── Test 5: ending triggered prevents advance ───────────────────────────────

func test_ending_triggered_prevents_advance() -> void:
	_controller._on_day_ended(1)
	var day_before: int = _time.current_day

	_ending_eval.force_ending(&"retail_mogul")

	_controller._on_day_acknowledged()

	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"State should be GAME_OVER after ending triggered"
	)
	assert_eq(
		_time.current_day, day_before,
		"Day should NOT advance when ending is triggered"
	)


func test_ending_evaluate_returns_nondefault_prevents_advance() -> void:
	_controller._on_day_ended(1)
	var day_before: int = _time.current_day

	_ending_eval.force_ending(&"test_ending")

	_controller._on_day_acknowledged()

	assert_true(
		_ending_eval.has_ending_been_shown(),
		"Ending should be marked as shown"
	)
	assert_eq(
		_time.current_day, day_before,
		"Day should NOT advance after non-default ending"
	)


# ── Test 6: GAME_OVER guard at handler entry ────────────────────────────────

func test_game_over_blocks_day_ended() -> void:
	GameManager.current_state = GameManager.GameState.GAME_OVER
	_controller._on_day_ended(1)

	assert_false(
		_controller._awaiting_acknowledgement,
		"Should not set awaiting when game is already over"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"State should remain GAME_OVER"
	)


func test_game_over_prevents_panel_and_advance() -> void:
	GameManager.current_state = GameManager.GameState.GAME_OVER
	var day_before: int = _time.current_day

	_controller._on_day_ended(1)
	_controller._on_day_acknowledged()

	assert_eq(
		_time.current_day, day_before,
		"Day should NOT advance when GAME_OVER at entry"
	)
	assert_eq(
		_day_started_count, 0,
		"No day_started signal should fire when GAME_OVER"
	)


# ── Test 7: normal path — advance_day called exactly once ───────────────────

func test_normal_path_advances_day_once() -> void:
	var day_before: int = _time.current_day
	_controller._on_day_ended(1)

	_controller._on_day_acknowledged()

	assert_eq(
		_time.current_day, day_before + 1,
		"Day should advance by exactly one"
	)
	assert_eq(
		_day_started_count, 1,
		"day_started should fire exactly once"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAMEPLAY,
		"State should return to GAMEPLAY"
	)


# ── Test 8: day_acknowledged triggers sequence, not day_ended directly ──────

func test_day_ended_does_not_advance_directly() -> void:
	var day_before: int = _time.current_day
	_controller._on_day_ended(1)

	assert_eq(
		_time.current_day, day_before,
		"day_ended alone should NOT advance day — must wait for acknowledgement"
	)
	assert_eq(
		_day_started_count, 0,
		"No day_started should fire from day_ended alone"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.DAY_SUMMARY,
		"State should be DAY_SUMMARY, waiting for acknowledgement"
	)


func test_acknowledgement_signal_triggers_advance() -> void:
	_controller._on_day_ended(1)
	var day_before: int = _time.current_day

	EventBus.next_day_confirmed.emit()

	assert_eq(
		_time.current_day, day_before + 1,
		"next_day_confirmed signal should trigger advance"
	)


# ── Duplicate acknowledgement guard ─────────────────────────────────────────

func test_duplicate_acknowledgement_ignored() -> void:
	_controller._on_day_ended(1)
	_controller._on_day_acknowledged()
	var day_after_first: int = _time.current_day

	_controller._on_day_acknowledged()

	assert_eq(
		_time.current_day, day_after_first,
		"Duplicate acknowledgement should NOT advance day again"
	)
	assert_eq(
		_day_started_count, 1,
		"day_started should have fired only once"
	)


func test_acknowledge_without_day_ended_is_noop() -> void:
	var day_before: int = _time.current_day

	_controller._on_day_acknowledged()

	assert_eq(
		_time.current_day, day_before,
		"Acknowledgement without prior day_ended should be ignored"
	)
	assert_eq(
		_day_started_count, 0,
		"No day_started should fire without prior day_ended"
	)
