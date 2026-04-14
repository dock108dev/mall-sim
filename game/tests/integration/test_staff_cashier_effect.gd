## Integration test: Staff cashier role — hire + assign → checkout speed reduction measured.
extends GutTest

const STORE_ID: String = "test_cashier_effect_store"
const FLOAT_EPSILON: float = 0.05

var _checkout: PlayerCheckout


func before_each() -> void:
	GameManager.current_store_id = StringName(STORE_ID)
	_checkout = PlayerCheckout.new()
	add_child_autofree(_checkout)
	_checkout.initialize(null, null, null, null)


func after_each() -> void:
	var test_ids: Array[String] = [
		"test_cashier_sk1",
		"test_cashier_sk2",
		"test_cashier_sk3",
		"test_cashier_fire",
		"test_cashier_sig",
	]
	for staff_id: String in test_ids:
		if StaffManager._staff_registry.has(staff_id):
			StaffManager._staff_registry.erase(staff_id)
	for def: StaffDefinition in StaffManager._candidate_pool.duplicate():
		if def.staff_id.begins_with("test_cashier"):
			StaffManager._candidate_pool.erase(def)
	GameManager.current_store_id = &""


# ── Scenario A — skill 1 cashier: performance_multiplier = 1.0 → baseline ────


func test_scenario_a_skill1_cashier_duration_equals_baseline() -> void:
	var cashier: StaffDefinition = partial_double(StaffDefinition).new()
	stub(cashier, "performance_multiplier").to_return(1.0)
	cashier.role = StaffDefinition.StaffRole.CASHIER
	_checkout._cashier = cashier

	assert_almost_eq(
		_checkout._get_checkout_duration(),
		PlayerCheckout.CHECKOUT_DURATION,
		FLOAT_EPSILON,
		"Skill 1 cashier (perf_mult=1.0) duration should equal baseline 2.0s"
	)


# ── Scenario B — skill 2 cashier: performance_multiplier = 1.5 → faster ──────


func test_scenario_b_skill2_cashier_duration_less_than_baseline() -> void:
	var cashier: StaffDefinition = partial_double(StaffDefinition).new()
	stub(cashier, "performance_multiplier").to_return(1.5)
	cashier.role = StaffDefinition.StaffRole.CASHIER
	_checkout._cashier = cashier

	var duration: float = _checkout._get_checkout_duration()
	assert_true(
		duration < PlayerCheckout.CHECKOUT_DURATION,
		"Skill 2 cashier (perf_mult=1.5) duration should be strictly less than 2.0s"
	)
	assert_almost_eq(
		duration,
		PlayerCheckout.CHECKOUT_DURATION / 1.5,
		FLOAT_EPSILON,
		"Skill 2 cashier duration should equal CHECKOUT_DURATION / 1.5"
	)


# ── Scenario C — skill 3 cashier strictly faster than skill 2 ────────────────


func test_scenario_c_skill3_cashier_duration_less_than_skill2() -> void:
	var cashier_sk2: StaffDefinition = partial_double(StaffDefinition).new()
	stub(cashier_sk2, "performance_multiplier").to_return(1.5)
	cashier_sk2.role = StaffDefinition.StaffRole.CASHIER
	_checkout._cashier = cashier_sk2
	var duration_sk2: float = _checkout._get_checkout_duration()

	var cashier_sk3: StaffDefinition = partial_double(StaffDefinition).new()
	stub(cashier_sk3, "performance_multiplier").to_return(2.0)
	cashier_sk3.role = StaffDefinition.StaffRole.CASHIER
	_checkout._cashier = cashier_sk3
	var duration_sk3: float = _checkout._get_checkout_duration()

	assert_true(
		duration_sk3 < duration_sk2,
		"Skill 3 cashier duration should be strictly less than skill 2 duration"
	)
	assert_almost_eq(
		duration_sk3,
		PlayerCheckout.CHECKOUT_DURATION / 2.0,
		FLOAT_EPSILON,
		"Skill 3 cashier duration should equal CHECKOUT_DURATION / 2.0 = 1.0s"
	)


# ── Scenario D — no cashier assigned produces baseline duration ───────────────


func test_scenario_d_no_cashier_assigned_uses_baseline() -> void:
	_checkout._cashier = null

	assert_almost_eq(
		_checkout._get_checkout_duration(),
		PlayerCheckout.CHECKOUT_DURATION,
		FLOAT_EPSILON,
		"No assigned cashier should produce baseline duration of 2.0s"
	)


# ── Scenario E — fire cashier reverts checkout to baseline ───────────────────


func test_scenario_e_fire_cashier_reverts_to_baseline() -> void:
	var cashier: StaffDefinition = _make_cashier("test_cashier_fire")
	StaffManager._candidate_pool.append(cashier)
	StaffManager.hire_candidate("test_cashier_fire", STORE_ID)

	StaffManager.fire_staff("test_cashier_fire")

	assert_null(
		_checkout._cashier,
		"_cashier must be null after fire_staff"
	)
	assert_almost_eq(
		_checkout._get_checkout_duration(),
		PlayerCheckout.CHECKOUT_DURATION,
		FLOAT_EPSILON,
		"Checkout duration must revert to baseline 2.0s after cashier is fired"
	)


# ── Signal: staff_hired emitted when hiring a cashier ────────────────────────


func test_staff_hired_signal_emitted_during_hire() -> void:
	watch_signals(EventBus)
	var cashier: StaffDefinition = _make_cashier("test_cashier_sig")
	StaffManager._candidate_pool.append(cashier)

	StaffManager.hire_candidate("test_cashier_sig", STORE_ID)

	assert_signal_emitted(
		EventBus,
		"staff_hired",
		"EventBus.staff_hired must be emitted when a cashier is hired"
	)
	if StaffManager._staff_registry.has("test_cashier_sig"):
		StaffManager._staff_registry.erase("test_cashier_sig")


func test_staff_hired_signal_carries_correct_staff_id() -> void:
	watch_signals(EventBus)
	var cashier: StaffDefinition = _make_cashier("test_cashier_sig")
	StaffManager._candidate_pool.append(cashier)

	StaffManager.hire_candidate("test_cashier_sig", STORE_ID)

	var params: Array = get_signal_parameters(EventBus, "staff_hired")
	assert_eq(
		params[0] as String,
		"test_cashier_sig",
		"staff_hired first param should be the staff_id"
	)
	if StaffManager._staff_registry.has("test_cashier_sig"):
		StaffManager._staff_registry.erase("test_cashier_sig")


# ── Cashier is cached in PlayerCheckout after hire ───────────────────────────


func test_cashier_cached_in_checkout_after_hire() -> void:
	var cashier: StaffDefinition = _make_cashier("test_cashier_sk1")
	StaffManager._candidate_pool.append(cashier)

	StaffManager.hire_candidate("test_cashier_sk1", STORE_ID)

	assert_not_null(
		_checkout._cashier,
		"PlayerCheckout must cache the CASHIER after staff_hired signal"
	)
	assert_eq(
		_checkout._cashier.staff_id,
		"test_cashier_sk1",
		"Cached cashier staff_id must match the hired staff"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _make_cashier(staff_id: String) -> StaffDefinition:
	var def: StaffDefinition = StaffDefinition.new()
	def.staff_id = staff_id
	def.display_name = "Test Cashier"
	def.role = StaffDefinition.StaffRole.CASHIER
	def.skill_level = 1
	def.morale = 1.0
	return def
