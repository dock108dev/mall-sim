## Integration test: GREETER staff effect on customer entry conversion and browse duration.
extends GutTest

const STORE_ID: String = "test_greeter_store"
const OTHER_STORE_ID: String = "test_greeter_other_store"
const FLOAT_EPSILON: float = 0.001

var _customer_system: CustomerSystem
var _greeter_def: StaffDefinition
var _test_profile: CustomerTypeDefinition


func before_each() -> void:
	_greeter_def = _make_greeter()
	_test_profile = _make_customer_profile()

	_customer_system = CustomerSystem.new()
	add_child_autofree(_customer_system)
	_customer_system.initialize()
	_customer_system.set_store_id(STORE_ID)

	StaffManager._candidate_pool.append(_greeter_def)


func after_each() -> void:
	if StaffManager._staff_registry.has("test_greeter_001"):
		StaffManager._staff_registry.erase("test_greeter_001")
	StaffManager._candidate_pool.erase(_greeter_def)


# ── Scenario A — entry conversion bonus with greeter ──────────────────────────


func test_scenario_a_greeter_is_cached_after_hire() -> void:
	StaffManager.hire_candidate("test_greeter_001", STORE_ID)

	assert_not_null(
		_customer_system._cached_greeter,
		"CustomerSystem should cache the GREETER after staff_hired signal"
	)
	assert_eq(
		_customer_system._cached_greeter.staff_id,
		"test_greeter_001",
		"Cached greeter staff_id should match the hired GREETER"
	)


func test_scenario_a_customer_greeted_fires_with_greeter_assigned() -> void:
	watch_signals(EventBus)
	StaffManager.hire_candidate("test_greeter_001", STORE_ID)

	_customer_system.spawn_customer(_test_profile, STORE_ID)

	assert_signal_emitted(
		EventBus,
		"customer_greeted",
		"customer_greeted should fire when a GREETER is assigned and a customer spawns"
	)


func test_scenario_a_customer_greeted_carries_correct_store_id() -> void:
	watch_signals(EventBus)
	StaffManager.hire_candidate("test_greeter_001", STORE_ID)

	_customer_system.spawn_customer(_test_profile, STORE_ID)

	var params: Array = get_signal_parameters(EventBus, "customer_greeted")
	assert_eq(
		String(params[1] as StringName),
		STORE_ID,
		"customer_greeted second param (store_id) should equal STORE_ID"
	)


## Verifies the conversion formula from CustomerSystem constants matches
## BASE_ENTRY_CONVERSION * (1 + GREETER_ENTRY_BONUS * perf_mult), capped at 1.0.
func test_scenario_a_entry_conversion_formula_with_morale_one() -> void:
	var perf_mult: float = _greeter_def.performance_multiplier()
	var computed: float = minf(
		1.0,
		CustomerSystem.BASE_ENTRY_CONVERSION * (
			1.0 + CustomerSystem.GREETER_ENTRY_BONUS * perf_mult
		)
	)

	assert_almost_eq(
		perf_mult,
		1.0,
		FLOAT_EPSILON,
		"performance_multiplier should be 1.0 when morale == 1.0"
	)
	assert_almost_eq(
		computed,
		1.0,
		FLOAT_EPSILON,
		"Entry conversion caps at 1.0 when BASE * (1 + BONUS * perf) exceeds 1"
	)


# ── Scenario B — browse duration extension with greeter ───────────────────────


func test_scenario_b_browse_min_multiplier_is_one_fifteen_with_greeter() -> void:
	StaffManager.hire_candidate("test_greeter_001", STORE_ID)

	_customer_system.spawn_customer(_test_profile, STORE_ID)

	var active: Array[Customer] = _customer_system.get_active_customers()
	assert_eq(
		active.size(),
		1,
		"Exactly one customer should be active after spawn"
	)

	var expected_browse_mult: float = (
		1.0 + CustomerSystem.GREETER_BROWSE_BONUS
			* _greeter_def.performance_multiplier()
	)
	assert_almost_eq(
		active[0]._browse_min_multiplier,
		expected_browse_mult,
		FLOAT_EPSILON,
		"browse_min_multiplier should be 1.0 + GREETER_BROWSE_BONUS * perf_mult"
	)


# ── Scenario C — no greeter after fired, baseline probability ─────────────────


func test_scenario_c_cached_greeter_cleared_after_fire() -> void:
	StaffManager.hire_candidate("test_greeter_001", STORE_ID)
	assert_not_null(
		_customer_system._cached_greeter,
		"Precondition: greeter must be cached before firing"
	)

	StaffManager.fire_staff("test_greeter_001")

	assert_null(
		_customer_system._cached_greeter,
		"Cached greeter should be null after the GREETER is fired"
	)


func test_scenario_c_customer_greeted_not_emitted_after_greeter_fired() -> void:
	StaffManager.hire_candidate("test_greeter_001", STORE_ID)
	StaffManager.fire_staff("test_greeter_001")

	watch_signals(EventBus)
	_customer_system.spawn_customer(_test_profile, STORE_ID)

	assert_signal_not_emitted(
		EventBus,
		"customer_greeted",
		"customer_greeted must not fire when no GREETER is assigned"
	)


func test_scenario_c_browse_min_multiplier_returns_to_baseline_after_greeter_fired() -> void:
	StaffManager.hire_candidate("test_greeter_001", STORE_ID)
	StaffManager.fire_staff("test_greeter_001")

	_customer_system.spawn_customer(_test_profile, STORE_ID)

	var active: Array[Customer] = _customer_system.get_active_customers()
	assert_eq(
		active.size(),
		1,
		"Exactly one customer should be active after spawn"
	)
	assert_almost_eq(
		active[0]._browse_min_multiplier,
		1.0,
		FLOAT_EPSILON,
		"browse_min_multiplier should return to 1.0 when no GREETER is assigned"
	)


# --- Scenario D: greeter effects are store-scoped and refresh on staff events ---


func test_scenario_d_greeter_bonus_does_not_apply_to_other_store() -> void:
	watch_signals(EventBus)
	StaffManager.hire_candidate("test_greeter_001", STORE_ID)

	_customer_system.spawn_customer(_test_profile, OTHER_STORE_ID)

	var active: Array[Customer] = _customer_system.get_active_customers()
	assert_eq(
		active.size(),
		1,
		"Exactly one customer should spawn for an ungreeted store"
	)
	assert_almost_eq(
		active[0]._browse_min_multiplier,
		1.0,
		FLOAT_EPSILON,
		"browse_min_multiplier should stay baseline for stores without a GREETER"
	)
	assert_signal_not_emitted(
		EventBus,
		"customer_greeted",
		"customer_greeted must not fire for stores without an assigned GREETER"
	)


func test_scenario_d_staff_morale_changed_refreshes_cached_greeter() -> void:
	StaffManager.hire_candidate("test_greeter_001", STORE_ID)
	_customer_system._cached_greeter = null

	EventBus.staff_morale_changed.emit("test_greeter_001", 0.5)

	assert_not_null(
		_customer_system._cached_greeter,
		"staff_morale_changed should refresh the cached GREETER reference"
	)
	assert_eq(
		_customer_system._cached_greeter.staff_id,
		"test_greeter_001",
		"Refreshed greeter should match the assigned GREETER"
	)


func test_scenario_d_staff_quit_clears_cached_greeter() -> void:
	StaffManager.hire_candidate("test_greeter_001", STORE_ID)
	assert_not_null(
		_customer_system._cached_greeter,
		"Precondition: greeter must be cached before quitting"
	)

	StaffManager.quit_staff("test_greeter_001")

	assert_null(
		_customer_system._cached_greeter,
		"staff_quit should clear the cached GREETER reference"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _make_greeter() -> StaffDefinition:
	var def: StaffDefinition = StaffDefinition.new()
	def.staff_id = "test_greeter_001"
	def.display_name = "Test Greeter"
	def.role = StaffDefinition.StaffRole.GREETER
	def.skill_level = 2
	def.morale = 1.0
	return def


func _make_customer_profile() -> CustomerTypeDefinition:
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "test_customer"
	profile.customer_name = "Test Customer"
	profile.patience = 0.5
	profile.purchase_probability_base = 0.5
	profile.browse_time_range = [30.0, 60.0]
	profile.budget_range = [10.0, 50.0]
	profile.spending_range = [10.0, 50.0]
	return profile
