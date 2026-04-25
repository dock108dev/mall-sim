## Integration test: full day cycle — day_ended → wages → progression → ending evaluation → advance.
extends GutTest

const STARTING_CASH: float = 200.0
const STAFF_WAGE: float = 50.0
const STORE_ID: String = "test_store"
const TEST_REVENUE: float = 500.0
const TEST_CUSTOMERS: int = 3
const FLOAT_EPSILON: float = 0.01
const CLOSE_WAIT_SECS: float = 0.5

var _time: TimeSystem
var _economy: EconomySystem
var _perf_report: PerformanceReportSystem
var _staff: StaffSystem
var _data_loader: DataLoader
var _day_cycle: DayCycleController
var _summary_panel: DaySummary
var _ending_evaluator: EndingEvaluatorSystem
var _progression: ProgressionSystem
var _reputation: ReputationSystem

var _saved_state: GameManager.State
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()

	GameManager.current_state = GameManager.State.GAMEPLAY
	GameManager.current_store_id = &"test_store"
	GameManager.owned_stores = [&"test_store"]

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.current_day = 1

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_test_staff()

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_ID)
	_reputation.add_reputation(STORE_ID, 50.0)

	_staff = StaffSystem.new()
	add_child_autofree(_staff)
	_staff.initialize(_economy, _reputation, null, _data_loader)

	_ending_evaluator = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_evaluator)
	_ending_evaluator.initialize()

	_progression = ProgressionSystem.new()
	add_child_autofree(_progression)
	_progression.initialize(_economy, _reputation)

	var panel_scene: PackedScene = load("res://game/scenes/ui/day_summary.tscn")
	_summary_panel = panel_scene.instantiate() as DaySummary
	add_child_autofree(_summary_panel)

	_day_cycle = DayCycleController.new()
	add_child_autofree(_day_cycle)
	_day_cycle.initialize(
		_time, _economy, _staff, _progression, _ending_evaluator, _perf_report
	)
	_day_cycle.set_day_summary(_summary_panel)

func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores


## Scenario 1: Full loop — panel shows on day_ended, day advances after acknowledgement.
func test_full_loop_forward() -> void:
	_emit_daily_activity(TEST_REVENUE, TEST_CUSTOMERS)
	EventBus.day_ended.emit(1)

	var history: Array[PerformanceReport] = _perf_report.get_history()
	assert_eq(
		history.size(), 1,
		"One report should be generated after day_ended"
	)
	var report: PerformanceReport = history.back()
	assert_almost_eq(
		report.revenue, TEST_REVENUE, FLOAT_EPSILON,
		"Report revenue should equal emitted item_sold total"
	)
	assert_eq(
		report.customers_served, TEST_CUSTOMERS,
		"Report should record all customers served"
	)
	assert_true(
		_summary_panel.visible,
		"Day summary panel should be visible after day_ended"
	)
	assert_eq(
		_time.current_day, 1,
		"TimeSystem.current_day should remain 1 before acknowledgement"
	)

	_acknowledge_day()
	await get_tree().create_timer(CLOSE_WAIT_SECS).timeout

	assert_eq(
		_time.current_day, 2,
		"TimeSystem.current_day should advance to 2 after acknowledgement"
	)
	assert_false(
		_summary_panel.visible,
		"Day summary panel should be hidden after acknowledgement"
	)


## Scenario 2: Wages deducted from player cash before day advances.
func test_wages_deducted_before_advance() -> void:
	_staff.hire_staff("test_worker", STORE_ID)

	EventBus.day_ended.emit(1)

	assert_almost_eq(
		_economy.get_cash(), STARTING_CASH, FLOAT_EPSILON,
		"Cash should not change before acknowledgement"
	)

	_acknowledge_day()

	assert_almost_eq(
		_economy.get_cash(), STARTING_CASH - STAFF_WAGE, FLOAT_EPSILON,
		"Player cash should be reduced by one staff wage after acknowledgement"
	)


## Scenario 3: Wages that push cash negative trigger bankruptcy and block day advance.
func test_bankruptcy_on_wage_deduction() -> void:
	_staff.hire_staff("test_worker", STORE_ID)
	_economy._current_cash = 30.0

	EventBus.day_ended.emit(1)
	watch_signals(EventBus)

	_acknowledge_day()

	assert_signal_emitted(
		EventBus, "bankruptcy_declared",
		"bankruptcy_declared should fire when wages push cash below zero"
	)
	assert_eq(
		GameManager.current_state, GameManager.State.GAME_OVER,
		"GameManager should enter GAME_OVER state after bankruptcy"
	)
	assert_eq(
		_time.current_day, 1,
		"TimeSystem.current_day should remain 1 after bankruptcy"
	)


## Scenario 4: Ending fired while waiting for acknowledgement blocks day advance.
func test_ending_blocks_day_advance() -> void:
	EventBus.day_ended.emit(1)

	assert_true(
		_summary_panel.visible,
		"Summary panel should be visible while waiting for acknowledgement"
	)

	# Ending fires before the player acknowledges
	EventBus.ending_triggered.emit(&"test_ending", {})

	assert_eq(
		GameManager.current_state, GameManager.State.GAME_OVER,
		"GameManager should be GAME_OVER after ending_triggered"
	)

	EventBus.next_day_confirmed.emit()

	assert_eq(
		_time.current_day, 1,
		"TimeSystem.current_day should remain 1 when game over blocks advance"
	)


## Scenario 5: Summary panel stays hidden when GameManager is already GAME_OVER.
func test_panel_suppressed_when_game_over() -> void:
	GameManager.current_state = GameManager.State.GAME_OVER

	EventBus.day_ended.emit(1)

	assert_false(
		_summary_panel.visible,
		"Day summary panel should not show when GameManager is GAME_OVER"
	)


## Scenario 6: staff_wages_paid signal fires before day_started in the acknowledgement flow.
## Validates that wage processing is ordered before day advance.
func test_wages_paid_signal_fires_before_day_started() -> void:
	_staff.hire_staff("test_worker", STORE_ID)

	var call_log: Array[StringName] = []
	var _on_wages := func(_total: float) -> void:
		call_log.append(&"wages_paid")
	var _on_advance := func(_day: int) -> void:
		call_log.append(&"day_started")

	EventBus.staff_wages_paid.connect(_on_wages)
	EventBus.day_started.connect(_on_advance)

	EventBus.day_ended.emit(1)
	_acknowledge_day()

	EventBus.staff_wages_paid.disconnect(_on_wages)
	EventBus.day_started.disconnect(_on_advance)

	assert_true(
		call_log.has(&"wages_paid"),
		"staff_wages_paid should fire during the acknowledgement flow"
	)
	assert_true(
		call_log.has(&"day_started"),
		"day_started should fire after acknowledgement"
	)
	var wages_index: int = call_log.find(&"wages_paid")
	var advance_index: int = call_log.find(&"day_started")
	assert_true(
		wages_index < advance_index,
		"wages_paid must be ordered before day_started in the call sequence"
	)


## Scenario 7: Progression system evaluated during acknowledgement flow — day advances normally.
## After acknowledgement, ProgressionSystem.evaluate_day_end() is called before endings are checked.
## The day advancing to 2 proves the full orchestration ran without interruption.
func test_progression_evaluated_then_day_advances() -> void:
	EventBus.day_ended.emit(1)

	assert_eq(
		_time.current_day, 1,
		"Day should not advance from day_ended alone"
	)

	_acknowledge_day()

	assert_eq(
		_time.current_day, 2,
		"Day should advance to 2 after acknowledgement with progression integrated"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.State.GAMEPLAY,
		"State should return to GAMEPLAY after full orchestration cycle"
	)


## Scenario 8: EndingEvaluatorSystem.evaluate() triggers an ending via the orchestration path,
## blocking TimeSystem.advance_day() — panel is not re-shown after the ending fires.
func test_ending_evaluate_path_blocks_advance_and_suppresses_panel_reshow() -> void:
	# Pre-set stats so evaluate() will return "lights_out" (bankruptcy, days_survived <= 7)
	_ending_evaluator._stats["trigger_type_bankruptcy"] = 1.0
	_ending_evaluator._stats["days_survived"] = 3.0

	watch_signals(EventBus)

	EventBus.day_ended.emit(1)

	assert_true(
		_summary_panel.visible,
		"Panel should be shown while awaiting acknowledgement"
	)

	_acknowledge_day()

	assert_signal_emitted(
		EventBus, "ending_triggered",
		"ending_triggered should fire when evaluate() returns a non-default ending"
	)
	assert_eq(
		_time.current_day, 1,
		"advance_day must NOT be called when ending evaluation blocks progression"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.State.GAME_OVER,
		"GameManager must be GAME_OVER after ending evaluation triggers an ending"
	)
	# Panel should not be re-shown — it was already hidden by _acknowledge_day()
	assert_false(
		_summary_panel.visible,
		"Day summary panel must not be re-shown after ending blocks day advance"
	)


## Scenario 9: MilestoneSystem evaluated before EndingEvaluatorSystem in the ack flow.
## When wages leave cash positive, the progression → ending order completes and day advances.
## A second acknowledgement is a no-op — day counter does not increment twice.
func test_duplicate_acknowledgement_does_not_double_advance() -> void:
	EventBus.day_ended.emit(1)
	_acknowledge_day()

	assert_eq(
		_time.current_day, 2,
		"Day should be 2 after first acknowledgement"
	)

	EventBus.next_day_confirmed.emit()

	assert_eq(
		_time.current_day, 2,
		"Duplicate acknowledgement must not advance day a second time"
	)


# ── Helpers ──────────────────────────────────────────────────────────────────


func _emit_daily_activity(revenue: float, customer_count: int) -> void:
	EventBus.item_sold.emit("test_item", revenue, "electronics")
	for _i: int in range(customer_count):
		EventBus.customer_left.emit({"satisfied": true})


func _acknowledge_day() -> void:
	_summary_panel.hide_summary()
	EventBus.next_day_confirmed.emit()


func _register_test_staff() -> void:
	var staff_def := StaffDefinition.new()
	staff_def.staff_id = "test_worker"
	staff_def.display_name = "Test Worker"
	staff_def.role = StaffDefinition.StaffRole.CASHIER
	staff_def.skill_level = 1
	staff_def.daily_wage = STAFF_WAGE
	_data_loader._staff_definitions["test_worker"] = staff_def
