## Integration test: staff wages pipeline — process_daily_wages → EconomySystem debit → signals.
extends GutTest

const STARTING_CASH: float = 500.0
const WAGE_A: float = 75.0
const WAGE_B: float = 100.0
const STORE_ID: String = "pipeline_test_store"
const WAGES_REASON: String = "Staff wages"
const FLOAT_EPSILON: float = 0.01

var _economy: EconomySystem
var _reputation: ReputationSystem
var _staff: StaffSystem
var _data_loader: DataLoader

var _saved_store_id: StringName


func before_each() -> void:
	_saved_store_id = GameManager.current_store_id
	GameManager.current_store_id = &"pipeline_test_store"

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_ID)
	_reputation.add_reputation(STORE_ID, 50.0)

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_test_staff_definitions()

	_staff = StaffSystem.new()
	add_child_autofree(_staff)
	_staff.initialize(_economy, _reputation, null, _data_loader)


func after_each() -> void:
	GameManager.current_store_id = _saved_store_id


## Two hired staff → exact combined wage deducted, transaction_completed carries correct params.
func test_two_staff_pipeline_cash_and_signal() -> void:
	_staff.hire_staff("pipeline_staff_a", STORE_ID)
	_staff.hire_staff("pipeline_staff_b", STORE_ID)
	watch_signals(EventBus)

	_staff.process_daily_wages()

	var expected_total: float = WAGE_A + WAGE_B
	assert_almost_eq(
		_economy.get_cash(), STARTING_CASH - expected_total, FLOAT_EPSILON,
		"Player cash should decrease by the sum of both staff wages"
	)
	assert_signal_emitted(
		EventBus, "transaction_completed",
		"transaction_completed must fire after wage deduction"
	)
	var params: Array = get_signal_parameters(EventBus, "transaction_completed")
	assert_almost_eq(
		params[0] as float, expected_total, FLOAT_EPSILON,
		"transaction_completed amount should equal total wages deducted"
	)
	assert_true(
		params[1] as bool,
		"transaction_completed success should be true for a force deduction"
	)
	assert_eq(
		params[2] as String, WAGES_REASON,
		"transaction_completed message should identify wage type"
	)


## Zero-staff scenario: no transaction_completed or staff_wages_paid emitted, cash unchanged.
func test_zero_staff_no_transaction_emitted() -> void:
	watch_signals(EventBus)

	_staff.process_daily_wages()

	assert_almost_eq(
		_economy.get_cash(), STARTING_CASH, FLOAT_EPSILON,
		"Player cash must remain unchanged when no staff are hired"
	)
	assert_signal_not_emitted(
		EventBus, "transaction_completed",
		"transaction_completed must not fire with zero staff"
	)
	assert_signal_not_emitted(
		EventBus, "staff_wages_paid",
		"staff_wages_paid must not fire with zero staff"
	)


## Insufficient-funds: wages exceed cash → force deduction drives cash negative → bankruptcy fires.
func test_insufficient_funds_path_triggers_bankruptcy() -> void:
	_staff.hire_staff("pipeline_staff_a", STORE_ID)
	_staff.hire_staff("pipeline_staff_b", STORE_ID)
	_economy._current_cash = 50.0
	watch_signals(EventBus)

	_staff.process_daily_wages()

	assert_signal_emitted(
		EventBus, "bankruptcy_declared",
		"bankruptcy_declared must fire when wages exceed available cash"
	)
	assert_true(
		_economy.get_cash() < 0.0,
		"Cash must be negative after force deduction exceeds available balance"
	)
	assert_signal_emitted(
		EventBus, "transaction_completed",
		"transaction_completed must still fire when force deduction causes negative balance"
	)


func _register_test_staff_definitions() -> void:
	var staff_a := StaffDefinition.new()
	staff_a.staff_id = "pipeline_staff_a"
	staff_a.display_name = "Pipeline Staff A"
	staff_a.role = StaffDefinition.StaffRole.CASHIER
	staff_a.skill_level = 2
	staff_a.daily_wage = WAGE_A

	var staff_b := StaffDefinition.new()
	staff_b.staff_id = "pipeline_staff_b"
	staff_b.display_name = "Pipeline Staff B"
	staff_b.role = StaffDefinition.StaffRole.STOCKER
	staff_b.skill_level = 2
	staff_b.daily_wage = WAGE_B

	_data_loader._staff_definitions["pipeline_staff_a"] = staff_a
	_data_loader._staff_definitions["pipeline_staff_b"] = staff_b
