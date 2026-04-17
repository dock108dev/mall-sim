## GUT unit tests for StaffSystem roster, firing, morale, and signals.
extends GutTest


const STORE_ID: String = "test_store"
const CASHIER_DEF_ID: String = "test_cashier"
const STOCKER_DEF_ID: String = "test_stocker"
const CASHIER_STAFF_ID: String = "staff_cashier_001"
const STOCKER_STAFF_ID: String = "staff_stocker_001"

var _staff: StaffSystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _data_loader: DataLoader


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy._apply_state({"current_cash": 1000.0})

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_ID)
	_reputation.add_reputation(STORE_ID, 50.0)

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_staff_definitions()

	_staff = StaffSystem.new()
	add_child_autofree(_staff)
	_staff.initialize(_economy, _reputation, null, _data_loader)

	GameManager.current_store_id = StringName(STORE_ID)


func after_each() -> void:
	GameManager.current_store_id = &""


func test_hiring_valid_staff_id_adds_to_active_roster() -> void:
	var hired: bool = _staff.hire_staff_by_id(
		CASHIER_STAFF_ID, CASHIER_DEF_ID, STORE_ID
	)

	assert_true(hired, "Valid staff_id should hire successfully")
	assert_true(
		_roster_has_staff_id(CASHIER_STAFF_ID),
		"Roster should contain hired staff_id"
	)


func test_hiring_same_staff_id_twice_returns_false_without_duplicate() -> void:
	var first_hire: bool = _staff.hire_staff_by_id(
		CASHIER_STAFF_ID, CASHIER_DEF_ID, STORE_ID
	)
	var duplicate_hire: bool = _staff.hire_staff_by_id(
		CASHIER_STAFF_ID, STOCKER_DEF_ID, STORE_ID
	)

	assert_true(first_hire, "First hire should succeed")
	assert_false(
		duplicate_hire,
		"Duplicate staff_id should be rejected"
	)
	assert_eq(
		_count_roster_staff_id(CASHIER_STAFF_ID), 1,
		"Duplicate staff_id should not be added twice"
	)


func test_firing_staff_member_removes_them_from_roster() -> void:
	_staff.hire_staff_by_id(CASHIER_STAFF_ID, CASHIER_DEF_ID, STORE_ID)

	var fired: bool = _staff.fire_staff(CASHIER_STAFF_ID, STORE_ID)

	assert_true(fired, "Firing active staff should return true")
	assert_false(
		_roster_has_staff_id(CASHIER_STAFF_ID),
		"Fired staff_id should no longer appear in roster"
	)


func test_firing_missing_staff_member_returns_false_without_error() -> void:
	var fired: bool = _staff.fire_staff("missing_staff", STORE_ID)

	assert_false(
		fired,
		"Firing a staff_id that is not hired should return false"
	)
	assert_eq(
		_staff.get_staff_count(STORE_ID), 0,
		"Roster should stay empty when firing missing staff"
	)


func test_morale_update_valid_staff_member_changes_value() -> void:
	_staff.hire_staff_by_id(CASHIER_STAFF_ID, CASHIER_DEF_ID, STORE_ID)

	var updated: bool = _staff.set_staff_morale(CASHIER_STAFF_ID, 0.42)

	assert_true(updated, "Morale update should succeed for active staff")
	assert_almost_eq(
		_staff.get_staff_morale(CASHIER_STAFF_ID),
		0.42,
		0.001,
		"Stored morale should match requested value in range"
	)


func test_morale_is_clamped_to_valid_range() -> void:
	_staff.hire_staff_by_id(CASHIER_STAFF_ID, CASHIER_DEF_ID, STORE_ID)

	_staff.set_staff_morale(CASHIER_STAFF_ID, 1.25)
	assert_almost_eq(
		_staff.get_staff_morale(CASHIER_STAFF_ID),
		1.0,
		0.001,
		"Morale above 1.0 should be stored as 1.0"
	)

	_staff.set_staff_morale(CASHIER_STAFF_ID, -0.25)
	assert_almost_eq(
		_staff.get_staff_morale(CASHIER_STAFF_ID),
		0.0,
		0.001,
		"Morale below 0.0 should be stored as 0.0"
	)


func test_staff_hired_signal_fires_with_staff_id() -> void:
	watch_signals(EventBus)

	_staff.hire_staff_by_id(CASHIER_STAFF_ID, CASHIER_DEF_ID, STORE_ID)

	assert_signal_emitted(
		EventBus,
		"staff_hired",
		"staff_hired should emit when staff is hired"
	)
	var params: Array = get_signal_parameters(EventBus, "staff_hired")
	assert_eq(
		params[0],
		CASHIER_STAFF_ID,
		"staff_hired should carry the hired staff_id"
	)


func test_staff_fired_signal_fires_with_staff_id() -> void:
	_staff.hire_staff_by_id(CASHIER_STAFF_ID, CASHIER_DEF_ID, STORE_ID)
	watch_signals(EventBus)

	_staff.fire_staff(CASHIER_STAFF_ID, STORE_ID)

	assert_signal_emitted(
		EventBus,
		"staff_fired",
		"staff_fired should emit when staff is fired"
	)
	var params: Array = get_signal_parameters(EventBus, "staff_fired")
	assert_eq(
		params[0],
		CASHIER_STAFF_ID,
		"staff_fired should carry the fired staff_id"
	)


func test_staff_morale_changed_signal_fires_with_staff_id_and_morale() -> void:
	_staff.hire_staff_by_id(CASHIER_STAFF_ID, CASHIER_DEF_ID, STORE_ID)
	watch_signals(EventBus)

	_staff.set_staff_morale(CASHIER_STAFF_ID, 0.73)

	assert_signal_emitted(
		EventBus,
		"staff_morale_changed",
		"staff_morale_changed should emit on morale update"
	)
	var params: Array = get_signal_parameters(
		EventBus, "staff_morale_changed"
	)
	assert_eq(
		params[0],
		CASHIER_STAFF_ID,
		"staff_morale_changed should carry the staff_id"
	)
	assert_almost_eq(
		params[1] as float,
		0.73,
		0.001,
		"staff_morale_changed should carry the new morale value"
	)


func _roster_has_staff_id(staff_id: String) -> bool:
	return _count_roster_staff_id(staff_id) > 0


func _count_roster_staff_id(staff_id: String) -> int:
	var count: int = 0
	for entry: Dictionary in _staff.get_staff_for_store(STORE_ID):
		if entry.get("instance_id", "") == staff_id:
			count += 1
	return count


func _register_staff_definitions() -> void:
	var cashier: StaffDefinition = StaffDefinition.new()
	cashier.staff_id = CASHIER_DEF_ID
	cashier.display_name = "Test Cashier"
	cashier.role = StaffDefinition.StaffRole.CASHIER
	cashier.skill_level = 1
	cashier.daily_wage = 30.0

	var stocker: StaffDefinition = StaffDefinition.new()
	stocker.staff_id = STOCKER_DEF_ID
	stocker.display_name = "Test Stocker"
	stocker.role = StaffDefinition.StaffRole.STOCKER
	stocker.skill_level = 2
	stocker.daily_wage = 60.0

	_data_loader._staff_definitions[CASHIER_DEF_ID] = cashier
	_data_loader._staff_definitions[STOCKER_DEF_ID] = stocker
