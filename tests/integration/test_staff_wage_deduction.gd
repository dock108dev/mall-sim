## Integration test: staff wage deduction on day end — hire → wages → balance reduced.
extends GutTest

var _staff: StaffSystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _data_loader: DataLoader

const STARTING_CASH: float = 1000.0
const WAGE_A: float = 50.0
const WAGE_B: float = 80.0
const STORE_ID: String = "test_store"


func before_each() -> void:
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

	GameManager.current_store_id = &"test_store"


func after_each() -> void:
	GameManager.current_store_id = &""


func test_single_staff_wage_deduction() -> void:
	watch_signals(EventBus)

	var result: Dictionary = _staff.hire_staff("wage_staff_a", STORE_ID)
	assert_false(
		result.is_empty(),
		"hire_staff should return a non-empty dictionary"
	)
	assert_signal_emitted(
		EventBus, "staff_hired",
		"staff_hired signal should fire on hire"
	)
	assert_almost_eq(
		_economy.get_cash(), STARTING_CASH, 0.01,
		"Cash should remain unchanged immediately after hire"
	)

	_staff.process_daily_wages()

	assert_signal_emitted(
		EventBus, "staff_wages_paid",
		"staff_wages_paid should fire after day-end wage processing"
	)
	var params: Array = get_signal_parameters(
		EventBus, "staff_wages_paid"
	)
	assert_almost_eq(
		params[0] as float, WAGE_A, 0.01,
		"staff_wages_paid total should equal the single staff wage"
	)
	assert_almost_eq(
		_economy.get_cash(), STARTING_CASH - WAGE_A, 0.01,
		"Player cash should be reduced by the staff member's daily wage"
	)


func test_multiple_staff_wage_summation() -> void:
	watch_signals(EventBus)

	_staff.hire_staff("wage_staff_a", STORE_ID)
	_staff.hire_staff("wage_staff_b", STORE_ID)

	assert_almost_eq(
		_economy.get_cash(), STARTING_CASH, 0.01,
		"Cash should remain unchanged after hiring two staff"
	)

	_staff.process_daily_wages()

	var expected_total: float = WAGE_A + WAGE_B
	assert_signal_emitted(
		EventBus, "staff_wages_paid",
		"staff_wages_paid should fire after processing two staff wages"
	)
	var params: Array = get_signal_parameters(
		EventBus, "staff_wages_paid"
	)
	assert_almost_eq(
		params[0] as float, expected_total, 0.01,
		"staff_wages_paid total should equal the sum of both wages"
	)
	assert_almost_eq(
		_economy.get_cash(), STARTING_CASH - expected_total, 0.01,
		"Player cash should be reduced by the combined daily wages"
	)


func test_zero_staff_no_deduction() -> void:
	watch_signals(EventBus)
	_economy.initialize(500.0)

	_staff.process_daily_wages()

	assert_almost_eq(
		_economy.get_cash(), 500.0, 0.01,
		"Cash should remain unchanged with no staff hired"
	)
	assert_signal_not_emitted(
		EventBus, "staff_wages_paid",
		"staff_wages_paid should not fire when no staff are hired"
	)


func _register_test_staff_definitions() -> void:
	var staff_a := StaffDefinition.new()
	staff_a.staff_id = "wage_staff_a"
	staff_a.display_name = "Wage Test A"
	staff_a.role = StaffDefinition.StaffRole.CASHIER
	staff_a.skill_level = 1
	staff_a.daily_wage = WAGE_A

	var staff_b := StaffDefinition.new()
	staff_b.staff_id = "wage_staff_b"
	staff_b.display_name = "Wage Test B"
	staff_b.role = StaffDefinition.StaffRole.STOCKER
	staff_b.skill_level = 1
	staff_b.daily_wage = WAGE_B

	_data_loader._staff_definitions["wage_staff_a"] = staff_a
	_data_loader._staff_definitions["wage_staff_b"] = staff_b
