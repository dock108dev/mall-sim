## Integration test — ReputationSystem tier upgrade chain via satisfied and
## dissatisfied customer signals, plus daily decay behaviour.
extends GutTest

const STORE_ID: String = "test_store"

var _rep: ReputationSystem
var _mock_customer: Node


func before_each() -> void:
	_rep = ReputationSystem.new()
	_rep.auto_connect_bus = false
	add_child_autofree(_rep)
	_rep.initialize_store(STORE_ID)
	GameManager.current_store_id = &"test_store"

	_mock_customer = Node.new()
	add_child_autofree(_mock_customer)


func after_each() -> void:
	GameManager.current_store_id = &""


# ── Scenario A: Tier 1 (UNREMARKABLE) → Tier 2 (REPUTABLE) ───────────────────

func test_scenario_a_satisfied_customers_accumulate_to_reputable() -> void:
	var tier_unremarkable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE
	]
	var tier_reputable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]

	_rep._scores[STORE_ID] = tier_unremarkable
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Store should start at UNREMARKABLE before accumulation"
	)

	watch_signals(EventBus)

	var gap: float = tier_reputable - tier_unremarkable
	var needed: int = ceili(gap / ReputationSystemSingleton.SATISFACTION_GAIN) + 1
	for i: int in range(needed):
		EventBus.customer_left_mall.emit(_mock_customer, true)

	assert_signal_emitted(
		EventBus, "reputation_changed",
		"reputation_changed should fire during tier upgrade accumulation"
	)
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Tier should be REPUTABLE after N satisfied customers"
	)
	assert_true(
		_rep.get_reputation(STORE_ID) >= tier_reputable,
		"Score should be at or above REPUTABLE threshold"
	)


func test_scenario_a_reputation_changed_fires_on_threshold_crossing() -> void:
	var tier_reputable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	# Place score just below REPUTABLE so a single signal crosses it.
	_rep._scores[STORE_ID] = tier_reputable - (ReputationSystemSingleton.SATISFACTION_GAIN - 0.01)

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Store should be UNREMARKABLE before the crossing signal"
	)

	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, true)

	assert_signal_emit_count(
		EventBus, "reputation_changed", 1,
		"reputation_changed should fire exactly once for the single threshold crossing"
	)
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"get_tier should return REPUTABLE after crossing threshold"
	)


func test_scenario_a_get_tier_returns_reputable_after_upgrade() -> void:
	var tier_reputable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	_rep._scores[STORE_ID] = tier_reputable

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"get_tier should return REPUTABLE once score equals the threshold"
	)


# ── Scenario B: Daily decay does not immediately reverse an earned upgrade ────

func test_scenario_b_day_ended_does_not_drop_tier_to_unremarkable() -> void:
	var tier_reputable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	# Set score well above REPUTABLE so a single decay cycle cannot drop below.
	_rep._scores[STORE_ID] = tier_reputable + 5.0

	EventBus.day_ended.emit(1)

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Tier should remain REPUTABLE after a single day of decay"
	)


func test_scenario_b_reputation_score_decreases_by_daily_decay() -> void:
	var tier_reputable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	_rep._scores[STORE_ID] = tier_reputable + 5.0
	var score_before: float = _rep.get_reputation(STORE_ID)

	watch_signals(EventBus)
	EventBus.day_ended.emit(1)

	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		score_before - ReputationSystemSingleton.DAILY_DECAY, 0.01,
		"Score should decrease by exactly DAILY_DECAY after day_ended"
	)
	assert_signal_emitted(
		EventBus, "reputation_changed",
		"reputation_changed should fire when decay reduces the score"
	)


func test_scenario_b_earned_tier_survives_single_decay_cycle() -> void:
	# Drive from UNREMARKABLE to REPUTABLE, then verify a day_ended does not
	# immediately undo the tier.
	var tier_unremarkable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE
	]
	var tier_reputable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	_rep._scores[STORE_ID] = tier_unremarkable

	var gap: float = tier_reputable - tier_unremarkable
	var needed: int = ceili(gap / ReputationSystemSingleton.SATISFACTION_GAIN) + 1
	for i: int in range(needed):
		EventBus.customer_left_mall.emit(_mock_customer, true)

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Tier should be REPUTABLE before decay"
	)

	EventBus.day_ended.emit(1)

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Tier should remain REPUTABLE after a single day_ended decay"
	)


# ── Scenario C: Dissatisfied customers degrade score and can reverse a tier ───

func test_scenario_c_dissatisfied_customer_decreases_score() -> void:
	var tier_reputable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	_rep._scores[STORE_ID] = tier_reputable + 5.0
	var score_before: float = _rep.get_reputation(STORE_ID)

	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, false)

	assert_signal_emitted(
		EventBus, "reputation_changed",
		"reputation_changed should fire when a dissatisfied customer leaves"
	)
	assert_true(
		_rep.get_reputation(STORE_ID) < score_before,
		"Score should decrease after a dissatisfied customer"
	)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		score_before + ReputationSystemSingleton.DISSATISFACTION_LOSS, 0.01,
		"Score should drop by exactly DISSATISFACTION_LOSS"
	)


func test_scenario_c_reputation_changed_fires_on_tier_downgrade() -> void:
	var tier_reputable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	# Place score just above threshold so one dissatisfied customer drops it below.
	_rep._scores[STORE_ID] = tier_reputable + 0.1

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Store should start at REPUTABLE before downgrade"
	)

	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, false)

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Tier should drop to UNREMARKABLE after score falls below REPUTABLE threshold"
	)
	assert_signal_emitted(
		EventBus, "reputation_changed",
		"reputation_changed should fire when score crosses back below tier threshold"
	)


func test_scenario_c_repeated_dissatisfied_customers_compound() -> void:
	var tier_reputable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	_rep._scores[STORE_ID] = tier_reputable + 10.0
	var score_before: float = _rep.get_reputation(STORE_ID)
	var emit_count: int = 3

	watch_signals(EventBus)
	for i: int in range(emit_count):
		EventBus.customer_left_mall.emit(_mock_customer, false)

	var expected: float = score_before + float(emit_count) * ReputationSystemSingleton.DISSATISFACTION_LOSS
	assert_almost_eq(
		_rep.get_reputation(STORE_ID), expected, 0.01,
		"Score should decrease by DISSATISFACTION_LOSS for each dissatisfied customer"
	)
	assert_signal_emit_count(
		EventBus, "reputation_changed", emit_count,
		"reputation_changed should fire once per dissatisfied customer signal"
	)
