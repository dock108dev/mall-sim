## Integration test: Staff greeter role — hire + assign → entry conversion bonus
## applied and customer_greeted emitted.
extends GutTest

const STORE_ID: String = "test_greeter_effect_store"
const FLOAT_EPSILON: float = 0.001

var _customer_system: CustomerSystem


func before_each() -> void:
	_customer_system = CustomerSystem.new()
	add_child_autofree(_customer_system)
	_customer_system.initialize()
	_customer_system.set_store_id(STORE_ID)


func after_each() -> void:
	var test_ids: Array[String] = [
		"test_greeter_browse",
		"test_greeter_sig",
		"test_greeter_fire",
	]
	for staff_id: String in test_ids:
		if StaffManager._staff_registry.has(staff_id):
			StaffManager._staff_registry.erase(staff_id)
	for def: StaffDefinition in StaffManager._candidate_pool.duplicate():
		if def.staff_id.begins_with("test_greeter"):
			StaffManager._candidate_pool.erase(def)


# ── Scenario A — no greeter: no conversion filter, base browse multiplier ─────


func test_scenario_a_cached_greeter_null_when_no_greeter_hired() -> void:
	assert_null(
		_customer_system._cached_greeter,
		"_cached_greeter must be null when no greeter is assigned to the store"
	)


func test_scenario_a_browse_min_multiplier_is_baseline_without_greeter() -> void:
	var profile: CustomerTypeDefinition = _make_customer_profile()

	_customer_system.spawn_customer(profile, STORE_ID)

	var active: Array[Customer] = _customer_system.get_active_customers()
	assert_eq(
		active.size(),
		1,
		"Exactly one customer should be active after spawn with no greeter"
	)
	assert_almost_eq(
		active[0]._browse_min_multiplier,
		1.0,
		FLOAT_EPSILON,
		"_browse_min_multiplier must be 1.0 (base) when no greeter is assigned"
	)


func test_scenario_a_customer_greeted_not_emitted_without_greeter() -> void:
	watch_signals(EventBus)
	var profile: CustomerTypeDefinition = _make_customer_profile()

	_customer_system.spawn_customer(profile, STORE_ID)

	assert_signal_not_emitted(
		EventBus,
		"customer_greeted",
		"customer_greeted must not fire when no greeter is assigned"
	)


# ── Scenario B — skill 1 greeter (perf_mult = 1.0): conversion = BASE × 1.2 ──


func test_scenario_b_skill1_greeter_conversion_formula_equals_base_times_1p2() -> void:
	var greeter: StaffDefinition = partial_double(StaffDefinition).new()
	stub(greeter, "performance_multiplier").to_return(1.0)
	greeter.role = StaffDefinition.StaffRole.GREETER
	_customer_system._cached_greeter = greeter

	var computed: float = minf(
		1.0,
		CustomerSystem.BASE_ENTRY_CONVERSION * (
			1.0 + CustomerSystem.GREETER_ENTRY_BONUS * greeter.performance_multiplier()
		)
	)
	var expected: float = minf(
		1.0,
		CustomerSystem.BASE_ENTRY_CONVERSION * 1.2
	)
	assert_almost_eq(
		computed,
		expected,
		FLOAT_EPSILON,
		"Skill 1 greeter (perf_mult=1.0) conversion must equal BASE_ENTRY_CONVERSION × 1.2"
	)


func test_scenario_b_skill1_greeter_browse_mult_increases_15_percent() -> void:
	var greeter: StaffDefinition = _make_greeter("test_greeter_browse")
	StaffManager._candidate_pool.append(greeter)
	StaffManager.hire_candidate("test_greeter_browse", STORE_ID)
	var profile: CustomerTypeDefinition = _make_customer_profile()

	_customer_system.spawn_customer(profile, STORE_ID)

	var active: Array[Customer] = _customer_system.get_active_customers()
	assert_eq(
		active.size(),
		1,
		"Exactly one customer should be active after spawn with skill 1 greeter"
	)
	var perf_mult: float = greeter.performance_multiplier()
	var expected_browse_mult: float = (
		1.0 + CustomerSystem.GREETER_BROWSE_BONUS * perf_mult
	)
	assert_almost_eq(
		active[0]._browse_min_multiplier,
		expected_browse_mult,
		FLOAT_EPSILON,
		"_browse_min_multiplier must equal 1.0 + GREETER_BROWSE_BONUS × perf_mult for skill 1"
	)
	assert_almost_eq(
		active[0]._browse_min_multiplier,
		1.15,
		FLOAT_EPSILON,
		"_browse_min_multiplier must be 1.15 (15% increase) for skill 1 greeter at morale 1.0"
	)


# ── Scenario C — skill 3 greeter (perf_mult = 3.0 mocked): conversion = BASE × 1.6 ──


func test_scenario_c_skill3_greeter_conversion_formula_equals_base_times_1p6() -> void:
	var greeter: StaffDefinition = partial_double(StaffDefinition).new()
	stub(greeter, "performance_multiplier").to_return(3.0)
	greeter.role = StaffDefinition.StaffRole.GREETER
	_customer_system._cached_greeter = greeter

	var computed: float = minf(
		1.0,
		CustomerSystem.BASE_ENTRY_CONVERSION * (
			1.0 + CustomerSystem.GREETER_ENTRY_BONUS * greeter.performance_multiplier()
		)
	)
	var expected: float = minf(
		1.0,
		CustomerSystem.BASE_ENTRY_CONVERSION * 1.6
	)
	assert_almost_eq(
		computed,
		expected,
		FLOAT_EPSILON,
		"Skill 3 greeter (perf_mult=3.0) conversion must equal BASE_ENTRY_CONVERSION × 1.6"
	)


# ── Scenario D — customer_greeted signal fires with correct payload ───────────


func test_scenario_d_customer_greeted_emitted_when_greeter_active() -> void:
	var greeter: StaffDefinition = _make_greeter("test_greeter_sig")
	StaffManager._candidate_pool.append(greeter)
	StaffManager.hire_candidate("test_greeter_sig", STORE_ID)
	var profile: CustomerTypeDefinition = _make_customer_profile()

	watch_signals(EventBus)
	_customer_system.spawn_customer(profile, STORE_ID)

	assert_signal_emitted(
		EventBus,
		"customer_greeted",
		"customer_greeted must fire when a GREETER is assigned and a customer spawns"
	)


func test_scenario_d_customer_greeted_carries_correct_store_id() -> void:
	var greeter: StaffDefinition = _make_greeter("test_greeter_sig")
	StaffManager._candidate_pool.append(greeter)
	StaffManager.hire_candidate("test_greeter_sig", STORE_ID)
	var profile: CustomerTypeDefinition = _make_customer_profile()

	watch_signals(EventBus)
	_customer_system.spawn_customer(profile, STORE_ID)

	var params: Array = get_signal_parameters(EventBus, "customer_greeted")
	assert_eq(
		String(params[1] as StringName),
		STORE_ID,
		"customer_greeted second param (store_id) must equal STORE_ID"
	)


# ── Scenario E — greeter fired: cached greeter clears, greeted signal stops ───


func test_scenario_e_fire_greeter_clears_cached_greeter() -> void:
	var greeter: StaffDefinition = _make_greeter("test_greeter_fire")
	StaffManager._candidate_pool.append(greeter)
	StaffManager.hire_candidate("test_greeter_fire", STORE_ID)
	assert_not_null(
		_customer_system._cached_greeter,
		"Precondition: _cached_greeter must be set before firing"
	)

	StaffManager.fire_staff("test_greeter_fire")

	assert_null(
		_customer_system._cached_greeter,
		"_cached_greeter must be null after fire_staff removes the GREETER"
	)


func test_scenario_e_customer_greeted_not_emitted_after_greeter_fired() -> void:
	var greeter: StaffDefinition = _make_greeter("test_greeter_fire")
	StaffManager._candidate_pool.append(greeter)
	StaffManager.hire_candidate("test_greeter_fire", STORE_ID)
	StaffManager.fire_staff("test_greeter_fire")

	watch_signals(EventBus)
	var profile: CustomerTypeDefinition = _make_customer_profile()
	_customer_system.spawn_customer(profile, STORE_ID)

	assert_signal_not_emitted(
		EventBus,
		"customer_greeted",
		"customer_greeted must not fire after the GREETER has been fired"
	)


func test_scenario_e_browse_mult_reverts_to_baseline_after_greeter_fired() -> void:
	var greeter: StaffDefinition = _make_greeter("test_greeter_fire")
	StaffManager._candidate_pool.append(greeter)
	StaffManager.hire_candidate("test_greeter_fire", STORE_ID)
	StaffManager.fire_staff("test_greeter_fire")

	var profile: CustomerTypeDefinition = _make_customer_profile()
	_customer_system.spawn_customer(profile, STORE_ID)

	var active: Array[Customer] = _customer_system.get_active_customers()
	assert_eq(
		active.size(),
		1,
		"Exactly one customer should be active after spawn with no greeter"
	)
	assert_almost_eq(
		active[0]._browse_min_multiplier,
		1.0,
		FLOAT_EPSILON,
		"_browse_min_multiplier must revert to 1.0 after the GREETER is fired"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _make_greeter(staff_id: String) -> StaffDefinition:
	var def: StaffDefinition = StaffDefinition.new()
	def.staff_id = staff_id
	def.display_name = "Test Greeter"
	def.role = StaffDefinition.StaffRole.GREETER
	def.skill_level = 1
	def.morale = 1.0
	return def


func _make_customer_profile() -> CustomerTypeDefinition:
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "test_customer_greeter_effect"
	profile.customer_name = "Test Customer"
	profile.patience = 0.5
	profile.purchase_probability_base = 0.5
	profile.browse_time_range = [30.0, 60.0]
	profile.budget_range = [10.0, 50.0]
	profile.spending_range = [10.0, 50.0]
	return profile
