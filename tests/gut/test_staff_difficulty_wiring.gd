## Tests that DifficultySystem modifiers apply to StaffManager payroll, morale, and quit logic.
extends GutTest


var _manager: Node = null
var _cash: float = 1000.0
var _wages_paid_total: float = 0.0
var _not_paid_ids: Array[String] = []
var _quit_ids: Array[String] = []
var _saved_tier: StringName
var _had_economy_payroll_cash_check: bool = false
var _had_economy_payroll_cash_deduct: bool = false


func before_all() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()


func before_each() -> void:
	_saved_tier = DifficultySystemSingleton.get_current_tier_id()
	_cash = 1000.0
	_wages_paid_total = 0.0
	_not_paid_ids = []
	_quit_ids = []
	_had_economy_payroll_cash_check = EventBus.payroll_cash_check.is_connected(
		EconomySystemSingleton._on_payroll_cash_check
	)
	_had_economy_payroll_cash_deduct = EventBus.payroll_cash_deduct.is_connected(
		EconomySystemSingleton._on_payroll_cash_deduct
	)
	if _had_economy_payroll_cash_check:
		EventBus.payroll_cash_check.disconnect(
			EconomySystemSingleton._on_payroll_cash_check
		)
	if _had_economy_payroll_cash_deduct:
		EventBus.payroll_cash_deduct.disconnect(
			EconomySystemSingleton._on_payroll_cash_deduct
		)
	_manager = preload("res://game/autoload/staff_manager.gd").new()
	_manager._generate_initial_pool()
	EventBus.payroll_cash_check.connect(_mock_cash_check)
	EventBus.payroll_cash_deduct.connect(_mock_cash_deduct)
	EventBus.staff_wages_paid.connect(_on_wages_paid)
	EventBus.staff_not_paid.connect(_on_not_paid)
	EventBus.staff_quit.connect(_on_quit)


func after_each() -> void:
	EventBus.payroll_cash_check.disconnect(_mock_cash_check)
	EventBus.payroll_cash_deduct.disconnect(_mock_cash_deduct)
	EventBus.staff_wages_paid.disconnect(_on_wages_paid)
	EventBus.staff_not_paid.disconnect(_on_not_paid)
	EventBus.staff_quit.disconnect(_on_quit)
	if _manager:
		_manager.free()
		_manager = null
	if _had_economy_payroll_cash_check:
		EventBus.payroll_cash_check.connect(
			EconomySystemSingleton._on_payroll_cash_check
		)
	if _had_economy_payroll_cash_deduct:
		EventBus.payroll_cash_deduct.connect(
			EconomySystemSingleton._on_payroll_cash_deduct
		)
	DifficultySystemSingleton.set_tier(_saved_tier)


func _mock_cash_check(amount: float, result: Array) -> void:
	result.append(_cash >= amount)


func _mock_cash_deduct(
	amount: float, _reason: String, result: Array
) -> void:
	if _cash >= amount:
		_cash -= amount
		result.append(true)
	else:
		result.append(false)


func _on_wages_paid(total: float) -> void:
	_wages_paid_total = total


func _on_not_paid(staff_id: String) -> void:
	_not_paid_ids.append(staff_id)


func _on_quit(staff_id: String) -> void:
	_quit_ids.append(staff_id)


func _hire_test_staff(store_id: String) -> StaffDefinition:
	var pool: Array = _manager.get_candidate_pool()
	var candidate: StaffDefinition = pool[0] as StaffDefinition
	_manager.hire_candidate(candidate.staff_id, store_id)
	return _manager.get_staff_registry()[candidate.staff_id]


## Wage multiplier — Easy (0.85)

func test_easy_wage_multiplier_applied_to_deduction() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	var base_wage: float = staff.daily_wage
	_manager._run_payroll()
	var expected_cash: float = 1000.0 - base_wage * 0.85
	assert_almost_eq(
		_cash, expected_cash, 0.01,
		"Easy wage deduction should be base_wage × 0.85"
	)


func test_easy_wages_paid_signal_uses_multiplied_wage() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	var base_wage: float = staff.daily_wage
	_manager._run_payroll()
	assert_almost_eq(
		_wages_paid_total, base_wage * 0.85, 0.01,
		"staff_wages_paid should emit base_wage × 0.85 on Easy"
	)


## Wage multiplier — Hard (1.20)

func test_hard_wage_multiplier_applied_to_deduction() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	var base_wage: float = staff.daily_wage
	_manager._run_payroll()
	var expected_cash: float = 1000.0 - base_wage * 1.20
	assert_almost_eq(
		_cash, expected_cash, 0.01,
		"Hard wage deduction should be base_wage × 1.20"
	)


func test_hard_wages_paid_signal_uses_multiplied_wage() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	var base_wage: float = staff.daily_wage
	_manager._run_payroll()
	assert_almost_eq(
		_wages_paid_total, base_wage * 1.20, 0.01,
		"staff_wages_paid should emit base_wage × 1.20 on Hard"
	)


## Wage multiplier — Normal (1.0, unchanged)

func test_normal_wage_multiplier_is_one() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	var base_wage: float = staff.daily_wage
	_manager._run_payroll()
	assert_almost_eq(
		_wages_paid_total, base_wage, 0.01,
		"Normal wage should equal base_wage unchanged"
	)


## Morale decay multiplier — Easy (0.70)

func test_easy_morale_decay_scaled_down() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	staff.morale = 0.50
	_manager._run_payroll()
	var morale_before: float = staff.morale
	# No sales → decay of MORALE_NO_SALES_PENALTY (-0.05)
	# Paid → +0.05 bonus
	# Combined positive: +0.05; negative raw: -0.05 → net = 0.0 before split
	# Force a negative-only scenario: set _daily_sales_per_store["store_a"] = 0
	# and mark staff as unpaid so we skip the paid bonus
	_manager._unpaid_staff_today[staff.staff_id] = true
	_manager._daily_sales_per_store["store_a"] = 0
	_manager._run_morale_ticks()
	# raw decay = -0.05; scaled = -0.05 * 0.70 = -0.035
	var expected_morale: float = morale_before + (-0.05 * 0.70)
	assert_almost_eq(
		staff.morale, expected_morale, 0.001,
		"Easy morale decay should be base_decay × 0.70"
	)


func test_hard_morale_decay_scaled_up() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	staff.morale = 0.80
	_manager._run_payroll()
	var morale_before: float = staff.morale
	_manager._unpaid_staff_today[staff.staff_id] = true
	_manager._daily_sales_per_store["store_a"] = 0
	_manager._run_morale_ticks()
	# raw decay = -0.05; scaled = -0.05 * 1.40 = -0.07
	var expected_morale: float = morale_before + (-0.05 * 1.40)
	assert_almost_eq(
		staff.morale, expected_morale, 0.001,
		"Hard morale decay should be base_decay × 1.40"
	)


func test_normal_morale_decay_unscaled() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	staff.morale = 0.50
	_manager._run_payroll()
	var morale_before: float = staff.morale
	_manager._unpaid_staff_today[staff.staff_id] = true
	_manager._daily_sales_per_store["store_a"] = 0
	_manager._run_morale_ticks()
	# raw decay = -0.05; scaled = -0.05 * 1.00 = -0.05
	assert_almost_eq(
		staff.morale, morale_before - 0.05, 0.001,
		"Normal morale decay should be unscaled"
	)


func test_positive_morale_delta_not_affected_by_decay_multiplier() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	staff.morale = 0.50
	_manager._run_payroll()
	var morale_before: float = staff.morale
	_manager._daily_sales_per_store["store_a"] = 10
	_manager._run_morale_ticks()
	# paid bonus +0.05, high sales bonus +0.03 → delta = +0.08 (positive, no scaling)
	assert_almost_eq(
		staff.morale, morale_before + 0.08, 0.001,
		"Positive morale delta must not be scaled by decay multiplier"
	)


## Quit threshold — Easy (0.15)

func test_easy_quit_threshold_is_0_15() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	# Morale above Easy threshold (0.15) → no quit
	staff.morale = 0.20
	staff.consecutive_low_morale_days = 5
	_manager._check_quit_triggers()
	assert_eq(_quit_ids.size(), 0, "Morale 0.20 is above Easy threshold 0.15 — no quit")
	assert_eq(staff.consecutive_low_morale_days, 0, "Counter should reset above threshold")


func test_easy_staff_quits_below_0_15() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	staff.morale = 0.10
	staff.consecutive_low_morale_days = 1
	_manager._check_quit_triggers()
	assert_eq(_quit_ids.size(), 1, "Morale 0.10 below Easy threshold 0.15 — should quit")


## Quit threshold — Hard (0.35)

func test_hard_quit_threshold_is_0_35() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	# Morale above Hard threshold (0.35) → no quit
	staff.morale = 0.40
	staff.consecutive_low_morale_days = 5
	_manager._check_quit_triggers()
	assert_eq(_quit_ids.size(), 0, "Morale 0.40 is above Hard threshold 0.35 — no quit")
	assert_eq(staff.consecutive_low_morale_days, 0, "Counter should reset above threshold")


func test_hard_staff_quits_below_0_35() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	staff.morale = 0.30
	staff.consecutive_low_morale_days = 1
	_manager._check_quit_triggers()
	assert_eq(_quit_ids.size(), 1, "Morale 0.30 below Hard threshold 0.35 — should quit")


## Modifiers read per cycle, not cached

func test_wage_modifier_read_per_cycle_not_cached() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var staff: StaffDefinition = _hire_test_staff("store_a")
	var base_wage: float = staff.daily_wage
	_manager._run_payroll()
	var easy_deduction: float = 1000.0 - _cash

	# Switch difficulty and run payroll again with topped-up cash
	_cash = 1000.0
	DifficultySystemSingleton.set_tier(&"hard")
	_manager._run_payroll()
	var hard_deduction: float = 1000.0 - _cash

	assert_almost_eq(
		easy_deduction, base_wage * 0.85, 0.01,
		"First cycle Easy deduction should be base × 0.85"
	)
	assert_almost_eq(
		hard_deduction, base_wage * 1.20, 0.01,
		"Second cycle Hard deduction should be base × 1.20"
	)
