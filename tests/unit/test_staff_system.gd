## Unit tests for StaffSystem hiring, firing, wages, and save/load.
extends GutTest


var _staff: StaffSystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _data_loader: DataLoader


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_test_staff_definitions()

	_staff = StaffSystem.new()
	add_child_autofree(_staff)
	_staff.initialize(_economy, _reputation, null, _data_loader)

	GameManager.current_store_id = &"test_store"
	_reputation.initialize_store("test_store")
	_reputation.add_reputation("test_store", 50.0)


func after_each() -> void:
	GameManager.current_store_id = &""


func test_hire_staff_adds_to_roster() -> void:
	watch_signals(EventBus)
	var result: Dictionary = _staff.hire_staff(
		"test_cashier", "test_store"
	)
	assert_false(
		result.is_empty(),
		"hire_staff should return a non-empty dictionary"
	)
	assert_eq(
		_staff.get_staff_count("test_store"), 1,
		"Roster should contain one staff member after hire"
	)
	assert_signal_emitted(
		EventBus, "staff_hired",
		"staff_hired signal should be emitted on hire"
	)
	var params: Array = get_signal_parameters(
		EventBus, "staff_hired"
	)
	assert_eq(
		params[0], result["instance_id"],
		"Signal staff_id should match returned instance_id"
	)
	assert_eq(
		params[1], "test_store",
		"Signal store_id should match the hiring store"
	)


func test_hire_same_definition_twice_fills_capacity() -> void:
	var first: Dictionary = _staff.hire_staff(
		"test_cashier", "test_store"
	)
	var second: Dictionary = _staff.hire_staff(
		"test_cashier", "test_store"
	)
	assert_false(
		first.is_empty(),
		"First hire of same definition should succeed"
	)
	assert_false(
		second.is_empty(),
		"Second hire of same definition should succeed"
	)
	assert_ne(
		first["instance_id"], second["instance_id"],
		"Each hire should receive a unique instance_id"
	)
	assert_eq(
		_staff.get_staff_count("test_store"), 2,
		"Both hires should appear in the roster"
	)
	var third: Dictionary = _staff.hire_staff(
		"test_cashier", "test_store"
	)
	assert_true(
		third.is_empty(),
		"Third hire should fail at max capacity"
	)
	assert_eq(
		_staff.get_staff_count("test_store"), 2,
		"Roster should not exceed MAX_STAFF_PER_STORE"
	)


func test_hire_max_staff_guard() -> void:
	_staff.hire_staff("test_cashier", "test_store")
	_staff.hire_staff("test_stocker", "test_store")
	var third: Dictionary = _staff.hire_staff(
		"test_cashier", "test_store"
	)
	assert_true(
		third.is_empty(),
		"Hiring beyond MAX_STAFF_PER_STORE should return empty dict"
	)
	assert_eq(
		_staff.get_staff_count("test_store"), 2,
		"Roster should not exceed MAX_STAFF_PER_STORE"
	)


func test_hire_low_reputation_guard() -> void:
	_reputation.add_reputation("test_store", -90.0)
	var result: Dictionary = _staff.hire_staff(
		"test_cashier", "test_store"
	)
	assert_true(
		result.is_empty(),
		"Hiring should fail when reputation is below threshold"
	)
	assert_eq(
		_staff.get_staff_count("test_store"), 0,
		"Roster should remain empty after rejected hire"
	)


func test_fire_staff_removes_from_roster() -> void:
	watch_signals(EventBus)
	var hired: Dictionary = _staff.hire_staff(
		"test_cashier", "test_store"
	)
	var instance_id: String = hired["instance_id"]
	var fired: bool = _staff.fire_staff(instance_id, "test_store")
	assert_true(fired, "fire_staff should return true on success")
	assert_eq(
		_staff.get_staff_count("test_store"), 0,
		"Roster should be empty after firing the only staff"
	)
	assert_signal_emitted(
		EventBus, "staff_fired",
		"staff_fired signal should be emitted"
	)
	var params: Array = get_signal_parameters(
		EventBus, "staff_fired"
	)
	assert_eq(
		params[0], instance_id,
		"Signal staff_id should match the fired staff"
	)
	assert_eq(
		params[1], "test_store",
		"Signal store_id should match the store"
	)


func test_fire_nonexistent_staff_returns_false() -> void:
	var fired: bool = _staff.fire_staff(
		"nonexistent_id", "test_store"
	)
	assert_false(
		fired,
		"Firing nonexistent staff should return false"
	)


func test_get_staff_for_store_returns_correct_subset() -> void:
	_reputation.initialize_store("store_a")
	_reputation.add_reputation("store_a", 50.0)
	_reputation.initialize_store("store_b")
	_reputation.add_reputation("store_b", 50.0)

	_staff.hire_staff("test_cashier", "store_a")
	_staff.hire_staff("test_stocker", "store_b")

	var store_a_staff: Array[Dictionary] = (
		_staff.get_staff_for_store("store_a")
	)
	var store_b_staff: Array[Dictionary] = (
		_staff.get_staff_for_store("store_b")
	)
	assert_eq(
		store_a_staff.size(), 1,
		"store_a should have exactly 1 staff member"
	)
	assert_eq(
		store_b_staff.size(), 1,
		"store_b should have exactly 1 staff member"
	)
	assert_eq(
		store_a_staff[0]["definition_id"], "test_cashier",
		"store_a staff should be the cashier"
	)
	assert_eq(
		store_b_staff[0]["definition_id"], "test_stocker",
		"store_b staff should be the stocker"
	)


func test_get_staff_for_store_empty_returns_empty() -> void:
	var result: Array[Dictionary] = (
		_staff.get_staff_for_store("nonexistent_store")
	)
	assert_eq(
		result.size(), 0,
		"Querying unstaffed store should return empty array"
	)


func test_process_daily_wages_deducts_correct_total() -> void:
	watch_signals(EventBus)
	_staff.hire_staff("test_cashier", "test_store")
	_staff.hire_staff("test_stocker", "test_store")

	var expected_wages: float = 30.0 + 60.0
	var cash_before: float = _economy.get_cash()
	_staff.process_daily_wages()

	assert_almost_eq(
		_economy.get_cash(),
		cash_before - expected_wages,
		0.01,
		"Cash should decrease by total staff wages"
	)
	assert_signal_emitted(
		EventBus, "staff_wages_paid",
		"staff_wages_paid should be emitted after wage deduction"
	)
	var params: Array = get_signal_parameters(
		EventBus, "staff_wages_paid"
	)
	assert_almost_eq(
		params[0] as float, expected_wages, 0.01,
		"Emitted total should match expected wages"
	)


func test_process_daily_wages_empty_roster_deducts_nothing() -> void:
	watch_signals(EventBus)
	var cash_before: float = _economy.get_cash()
	_staff.process_daily_wages()

	assert_almost_eq(
		_economy.get_cash(), cash_before, 0.01,
		"Cash should not change with no staff"
	)
	assert_signal_not_emitted(
		EventBus, "staff_wages_paid",
		"staff_wages_paid should not emit with zero staff"
	)


func test_morale_clamp_within_bounds() -> void:
	var def: StaffDefinition = StaffDefinition.new()
	def.morale = 0.5

	def.morale = def.morale + 2.0
	assert_almost_eq(
		def.morale, 1.0, 0.01,
		"Morale should clamp to 1.0 maximum"
	)

	def.morale = def.morale - 5.0
	assert_almost_eq(
		def.morale, 0.0, 0.01,
		"Morale should clamp to 0.0 minimum"
	)


func test_morale_delta_adjusts_correctly() -> void:
	var def: StaffDefinition = StaffDefinition.new()
	def.morale = 0.5
	def.morale = clampf(def.morale + 0.2, 0.0, 1.0)
	assert_almost_eq(
		def.morale, 0.7, 0.01,
		"Morale should increase by delta within bounds"
	)
	def.morale = clampf(def.morale - 0.3, 0.0, 1.0)
	assert_almost_eq(
		def.morale, 0.4, 0.01,
		"Morale should decrease by delta within bounds"
	)


func test_staff_morale_changed_signal_emitted() -> void:
	watch_signals(EventBus)
	var def: StaffDefinition = StaffDefinition.new()
	def.staff_id = "test_signal_staff"
	def.morale = 0.5
	var new_morale: float = clampf(def.morale + 0.2, 0.0, 1.0)
	def.morale = new_morale
	EventBus.staff_morale_changed.emit(
		def.staff_id, def.morale
	)
	assert_signal_emitted(
		EventBus, "staff_morale_changed",
		"staff_morale_changed should be emitted on morale update"
	)
	var params: Array = get_signal_parameters(
		EventBus, "staff_morale_changed"
	)
	assert_eq(
		params[0], "test_signal_staff",
		"Signal staff_id should match the staff member"
	)
	assert_almost_eq(
		params[1] as float, 0.7, 0.01,
		"Signal new_morale should match the updated value"
	)


func test_save_load_round_trip_preserves_state() -> void:
	_staff.hire_staff("test_cashier", "test_store")
	_staff.hire_staff("test_stocker", "test_store")
	_staff.set_price_policy("test_store", 0.8, 1.5)

	var save_data: Dictionary = _staff.get_save_data()

	var fresh_staff: StaffSystem = StaffSystem.new()
	add_child_autofree(fresh_staff)
	fresh_staff.initialize(_economy, _reputation, null, _data_loader)
	fresh_staff.load_save_data(save_data)

	assert_eq(
		fresh_staff.get_staff_count("test_store"), 2,
		"Staff count should survive round-trip"
	)

	var original_list: Array[Dictionary] = (
		_staff.get_staff_for_store("test_store")
	)
	var loaded_list: Array[Dictionary] = (
		fresh_staff.get_staff_for_store("test_store")
	)
	assert_eq(
		loaded_list.size(), original_list.size(),
		"Staff list size should match after load"
	)
	for i: int in range(original_list.size()):
		assert_eq(
			loaded_list[i]["instance_id"],
			original_list[i]["instance_id"],
			"Staff instance_id at index %d should match" % i
		)
		assert_eq(
			loaded_list[i]["definition_id"],
			original_list[i]["definition_id"],
			"Staff definition_id at index %d should match" % i
		)
		assert_eq(
			loaded_list[i]["store_id"],
			original_list[i]["store_id"],
			"Staff store_id at index %d should match" % i
		)

	var loaded_policy: Dictionary = (
		fresh_staff.get_price_policy("test_store")
	)
	assert_almost_eq(
		loaded_policy["min_ratio"] as float, 0.8, 0.01,
		"Price policy min_ratio should survive round-trip"
	)
	assert_almost_eq(
		loaded_policy["max_ratio"] as float, 1.5, 0.01,
		"Price policy max_ratio should survive round-trip"
	)


func test_save_load_empty_roster() -> void:
	var save_data: Dictionary = _staff.get_save_data()
	var fresh_staff: StaffSystem = StaffSystem.new()
	add_child_autofree(fresh_staff)
	fresh_staff.initialize(_economy, _reputation, null, _data_loader)
	fresh_staff.load_save_data(save_data)

	assert_eq(
		fresh_staff.get_staff_count("test_store"), 0,
		"Empty roster should survive round-trip"
	)


func test_get_total_daily_wages_sums_all_stores() -> void:
	_reputation.initialize_store("store_a")
	_reputation.add_reputation("store_a", 50.0)
	_reputation.initialize_store("store_b")
	_reputation.add_reputation("store_b", 50.0)

	_staff.hire_staff("test_cashier", "store_a")
	_staff.hire_staff("test_stocker", "store_b")

	var total: float = _staff.get_total_daily_wages()
	assert_almost_eq(
		total, 30.0 + 60.0, 0.01,
		"Total wages should sum across all stores"
	)


func test_get_store_daily_wages_single_store() -> void:
	_staff.hire_staff("test_cashier", "test_store")
	var wages: float = _staff.get_store_daily_wages("test_store")
	assert_almost_eq(
		wages, 30.0, 0.01,
		"Store wages should match the hired staff's wage"
	)


func _register_test_staff_definitions() -> void:
	var cashier := StaffDefinition.new()
	cashier.staff_id = "test_cashier"
	cashier.display_name = "Test Cashier"
	cashier.role = StaffDefinition.StaffRole.CASHIER
	cashier.skill_level = 1
	cashier.daily_wage = 30.0

	var stocker := StaffDefinition.new()
	stocker.staff_id = "test_stocker"
	stocker.display_name = "Test Stocker"
	stocker.role = StaffDefinition.StaffRole.STOCKER
	stocker.skill_level = 2
	stocker.daily_wage = 60.0

	_data_loader._staff_definitions["test_cashier"] = cashier
	_data_loader._staff_definitions["test_stocker"] = stocker
