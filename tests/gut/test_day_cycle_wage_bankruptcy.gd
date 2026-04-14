## Integration test: DayCycleController wage-triggered bankruptcy path.
## Verifies that wages exhausting cash emit bankruptcy_declared exactly once,
## transition GameManager to GAME_OVER, and prevent TimeSystem.advance_to_next_day().
extends GutTest

const STARTING_CASH: float = 50.0
const STAFF_WAGE: float = 75.0
const STORE_ID: String = "wage_test_store"
const FLOAT_EPSILON: float = 0.01

var _controller: DayCycleController
var _time: TimeSystem
var _economy: EconomySystem
var _staff: StaffSystem
var _ending_evaluator: EndingEvaluatorSystem
var _reputation: ReputationSystem
var _data_loader: DataLoader
var _perf_report: PerformanceReportSystem

var _saved_state: GameManager.GameState
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]
var _saved_difficulty: StringName

var _bankruptcy_count: int = 0
var _day_started_count: int = 0


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_difficulty = DifficultySystemSingleton.get_current_tier_id()

	DifficultySystemSingleton.set_tier(&"normal")
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager.current_store_id = &"wage_test_store"
	GameManager.owned_stores = []

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_test_staff_definition()

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.initialize()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

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

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()

	_controller = DayCycleController.new()
	add_child_autofree(_controller)
	_controller.initialize(
		_time, _economy, _staff, null, _ending_evaluator, _perf_report
	)

	_bankruptcy_count = 0
	_day_started_count = 0
	EventBus.bankruptcy_declared.connect(_on_bankruptcy_declared)
	EventBus.day_started.connect(_on_day_started)


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	DifficultySystemSingleton.set_tier(_saved_difficulty)
	_safe_disconnect(EventBus.bankruptcy_declared, _on_bankruptcy_declared)
	_safe_disconnect(EventBus.day_started, _on_day_started)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_bankruptcy_declared() -> void:
	_bankruptcy_count += 1


func _on_day_started(_day: int) -> void:
	_day_started_count += 1


func _register_test_staff_definition() -> void:
	var staff_def := StaffDefinition.new()
	staff_def.staff_id = "wage_bankrupt_staff"
	staff_def.display_name = "Wage Bankrupt Staff"
	staff_def.role = StaffDefinition.StaffRole.CASHIER
	staff_def.skill_level = 1
	staff_def.daily_wage = STAFF_WAGE
	_data_loader._staff_definitions["wage_bankrupt_staff"] = staff_def


## Wages exceed cash: bankruptcy_declared fires once, GameManager enters GAME_OVER,
## and TimeSystem.advance_to_next_day is never called.
func test_wage_triggered_bankruptcy_emits_once_and_enters_game_over() -> void:
	_staff.hire_staff("wage_bankrupt_staff", STORE_ID)
	assert_almost_eq(
		_staff.get_total_daily_wages(), STAFF_WAGE, FLOAT_EPSILON,
		"Staff wages should total %.2f" % STAFF_WAGE
	)

	EventBus.day_ended.emit(5)
	EventBus.next_day_confirmed.emit()

	assert_eq(
		_bankruptcy_count, 1,
		"bankruptcy_declared should fire exactly once"
	)
	assert_eq(
		GameManager.current_state, GameManager.GameState.GAME_OVER,
		"GameManager should be in GAME_OVER after wage-triggered bankruptcy"
	)
	assert_eq(
		_day_started_count, 0,
		"advance_to_next_day must not be called when game enters GAME_OVER"
	)
	assert_true(
		_economy.get_cash() < 0.0,
		"Cash should be negative after wages exceed starting balance"
	)


## State transitions correctly from DAY_SUMMARY to GAME_OVER (not back to GAMEPLAY).
func test_day_summary_transitions_to_game_over_not_gameplay() -> void:
	_staff.hire_staff("wage_bankrupt_staff", STORE_ID)

	EventBus.day_ended.emit(5)
	assert_eq(
		GameManager.current_state, GameManager.GameState.DAY_SUMMARY,
		"State should be DAY_SUMMARY while awaiting player acknowledgement"
	)

	EventBus.next_day_confirmed.emit()

	assert_eq(
		GameManager.current_state, GameManager.GameState.GAME_OVER,
		"State should be GAME_OVER after bankruptcy, not GAMEPLAY"
	)
	assert_eq(
		_day_started_count, 0,
		"Day must not advance when bankruptcy terminates the cycle"
	)


## EconomySystem guard prevents re-emission even after additional forced deductions.
func test_bankruptcy_guard_prevents_second_emission_on_further_deductions() -> void:
	_staff.hire_staff("wage_bankrupt_staff", STORE_ID)
	EventBus.day_ended.emit(5)
	EventBus.next_day_confirmed.emit()

	var count_after_bankruptcy: int = _bankruptcy_count

	_economy.force_deduct_cash(10.0, "extra test deduction")

	assert_eq(
		_bankruptcy_count, count_after_bankruptcy,
		"bankruptcy_declared guard should prevent re-emission on additional deductions"
	)


## TimeSystem.current_day must not increment when bankruptcy fires during day cycle.
func test_current_day_unchanged_when_bankruptcy_prevents_advance() -> void:
	_staff.hire_staff("wage_bankrupt_staff", STORE_ID)
	var initial_day: int = _time.current_day

	EventBus.day_ended.emit(5)
	EventBus.next_day_confirmed.emit()

	assert_eq(
		_time.current_day, initial_day,
		"current_day must not increment when bankruptcy blocks day advance"
	)


## Without staff, wages are zero and the day cycle completes normally.
func test_no_staff_no_bankruptcy_day_advances() -> void:
	EventBus.day_ended.emit(5)
	EventBus.next_day_confirmed.emit()

	assert_eq(
		_bankruptcy_count, 0,
		"bankruptcy_declared should not fire when there are no staff wages"
	)
	assert_eq(
		GameManager.current_state, GameManager.GameState.GAMEPLAY,
		"GameManager should remain in GAMEPLAY when no bankruptcy occurs"
	)
	assert_eq(
		_day_started_count, 1,
		"Day should advance normally when wages do not cause bankruptcy"
	)
