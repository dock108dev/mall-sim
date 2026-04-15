## Tests payroll deduction, morale events, and quit triggers in StaffManager.
extends GutTest


var _manager: Node = null
var _cash: float = 1000.0
var _wages_paid_total: float = 0.0
var _not_paid_ids: Array[String] = []
var _morale_changes: Array[Dictionary] = []
var _quit_ids: Array[String] = []
var _had_economy_payroll_cash_check: bool = false
var _had_economy_payroll_cash_deduct: bool = false


func before_each() -> void:
	_cash = 1000.0
	_wages_paid_total = 0.0
	_not_paid_ids = []
	_morale_changes = []
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
	_manager = preload(
		"res://game/autoload/staff_manager.gd"
	).new()
	_manager._generate_initial_pool()
	EventBus.payroll_cash_check.connect(_mock_cash_check)
	EventBus.payroll_cash_deduct.connect(_mock_cash_deduct)
	EventBus.staff_wages_paid.connect(_on_wages_paid)
	EventBus.staff_not_paid.connect(_on_not_paid)
	EventBus.staff_morale_changed.connect(_on_morale_changed)
	EventBus.staff_quit.connect(_on_quit)


func after_each() -> void:
	EventBus.payroll_cash_check.disconnect(_mock_cash_check)
	EventBus.payroll_cash_deduct.disconnect(_mock_cash_deduct)
	EventBus.staff_wages_paid.disconnect(_on_wages_paid)
	EventBus.staff_not_paid.disconnect(_on_not_paid)
	EventBus.staff_morale_changed.disconnect(_on_morale_changed)
	EventBus.staff_quit.disconnect(_on_quit)
	if _had_economy_payroll_cash_check:
		EventBus.payroll_cash_check.connect(
			EconomySystemSingleton._on_payroll_cash_check
		)
	if _had_economy_payroll_cash_deduct:
		EventBus.payroll_cash_deduct.connect(
			EconomySystemSingleton._on_payroll_cash_deduct
		)
	if _manager:
		_manager.free()
		_manager = null


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


func _on_morale_changed(
	staff_id: String, new_morale: float
) -> void:
	_morale_changes.append({
		"staff_id": staff_id,
		"new_morale": new_morale,
	})


func _on_quit(staff_id: String) -> void:
	_quit_ids.append(staff_id)


func _hire_test_staff(
	store_id: String, count: int = 1
) -> Array[String]:
	var ids: Array[String] = []
	var pool: Array = _manager.get_candidate_pool()
	for i: int in range(mini(count, pool.size())):
		var candidate: StaffDefinition = pool[0] as StaffDefinition
		_manager.hire_candidate(candidate.staff_id, store_id)
		ids.append(candidate.staff_id)
	return ids


func test_payroll_deducts_wages_from_cash() -> void:
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	var wage: float = staff.daily_wage
	_manager._run_payroll()
	assert_almost_eq(_cash, 1000.0 - wage, 0.01)


func test_payroll_emits_wages_paid_signal() -> void:
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	_manager._run_payroll()
	assert_almost_eq(_wages_paid_total, staff.daily_wage, 0.01)


func test_payroll_unpaid_when_insufficient_funds() -> void:
	_cash = 0.0
	var ids: Array[String] = _hire_test_staff("store_a")
	_manager._run_payroll()
	assert_eq(_not_paid_ids.size(), 1)
	assert_eq(_not_paid_ids[0], ids[0])


func test_payroll_unpaid_applies_morale_penalty() -> void:
	_cash = 0.0
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	var old_morale: float = staff.morale
	_manager._run_payroll()
	assert_almost_eq(
		staff.morale, old_morale - 0.20, 0.001
	)


func test_payroll_senior_staff_paid_first() -> void:
	var ids: Array[String] = _hire_test_staff("store_a", 2)
	var staff_a: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	var staff_b: StaffDefinition = _manager.get_staff_registry()[ids[1]]
	staff_a.seniority_days = 10
	staff_b.seniority_days = 1
	_cash = staff_a.daily_wage
	_manager._run_payroll()
	assert_eq(_not_paid_ids.size(), 1)
	assert_eq(_not_paid_ids[0], staff_b.staff_id)


func test_morale_paid_bonus_applied() -> void:
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	staff.morale = 0.50
	_manager._run_payroll()
	_morale_changes.clear()
	_manager._run_morale_ticks()
	assert_almost_eq(staff.morale, 0.50 + 0.05 - 0.05, 0.001)


func test_morale_high_sales_bonus() -> void:
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	staff.morale = 0.50
	_manager._daily_sales_per_store["store_a"] = 5
	_manager._run_payroll()
	_manager._run_morale_ticks()
	assert_almost_eq(
		staff.morale, 0.50 + 0.05 + 0.03, 0.001
	)


func test_morale_no_sales_penalty() -> void:
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	staff.morale = 0.50
	_manager._daily_sales_per_store["store_a"] = 0
	_manager._run_payroll()
	_manager._run_morale_ticks()
	assert_almost_eq(
		staff.morale, 0.50 + 0.05 - 0.05, 0.001
	)


func test_morale_witnessed_firing_penalty() -> void:
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	staff.morale = 0.50
	_manager._stores_with_firing_today["store_a"] = true
	_manager._run_payroll()
	_manager._run_morale_ticks()
	assert_almost_eq(
		staff.morale, 0.50 + 0.05 - 0.05 - 0.08, 0.001
	)


func test_morale_clamped_to_zero() -> void:
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	staff.morale = 0.05
	_cash = 0.0
	_manager._run_payroll()
	assert_true(staff.morale >= 0.0)


func test_morale_clamped_to_one() -> void:
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	staff.morale = 0.98
	_manager._daily_sales_per_store["store_a"] = 10
	_manager._run_payroll()
	_manager._run_morale_ticks()
	assert_true(staff.morale <= 1.0)


func test_staff_morale_changed_signal_emitted() -> void:
	_hire_test_staff("store_a")
	_manager._run_payroll()
	_manager._run_morale_ticks()
	assert_true(_morale_changes.size() > 0)


func test_quit_trigger_fires_after_two_consecutive_days() -> void:
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	staff.morale = 0.10
	staff.consecutive_low_morale_days = 1
	_manager._check_quit_triggers()
	assert_eq(_quit_ids.size(), 1)
	assert_eq(_quit_ids[0], ids[0])


func test_quit_does_not_fire_on_first_low_day() -> void:
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	staff.morale = 0.10
	staff.consecutive_low_morale_days = 0
	_manager._check_quit_triggers()
	assert_eq(_quit_ids.size(), 0)
	assert_eq(staff.consecutive_low_morale_days, 1)


func test_consecutive_low_morale_resets_above_threshold() -> void:
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	staff.morale = 0.50
	staff.consecutive_low_morale_days = 3
	_manager._check_quit_triggers()
	assert_eq(staff.consecutive_low_morale_days, 0)


func test_full_day_end_flow() -> void:
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	var old_seniority: int = staff.seniority_days
	_manager._on_day_ended(1)
	assert_eq(staff.seniority_days, old_seniority + 1)
	assert_true(_wages_paid_total > 0.0)


func test_no_debt_mechanic() -> void:
	_cash = 10.0
	var ids: Array[String] = _hire_test_staff("store_a")
	var staff: StaffDefinition = _manager.get_staff_registry()[ids[0]]
	if staff.daily_wage > 10.0:
		_manager._run_payroll()
		assert_almost_eq(_cash, 10.0, 0.01)
		assert_eq(_not_paid_ids.size(), 1)
