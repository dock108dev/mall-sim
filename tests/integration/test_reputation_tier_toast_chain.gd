## Integration test — reputation tier change toast chain: score crosses threshold
## → reputation_changed → toast_requested emitted with correct category and message.
extends GutTest

const STORE_ID: String = "retro_quest"

var _rep: ReputationSystem
var _mock_customer: Node


func before_each() -> void:
	_rep = ReputationSystem.new()
	add_child_autofree(_rep)
	_rep.initialize_store(STORE_ID)
	GameManager.current_store_id = &"retro_quest"

	_mock_customer = Node.new()
	add_child_autofree(_mock_customer)


func after_each() -> void:
	GameManager.current_store_id = &""


# ── Test 1: Tier up (UNREMARKABLE → REPUTABLE) triggers toast ────────────────

func test_tier_up_emits_reputation_changed() -> void:
	var reputable_threshold: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	# Place score so a single satisfied customer crosses the REPUTABLE threshold.
	_rep._scores[STORE_ID] = reputable_threshold - (ReputationSystemSingleton.SATISFACTION_GAIN - 0.01)

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Store should start at UNREMARKABLE before the tier-up signal"
	)

	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, true)

	assert_signal_emitted(
		EventBus, "reputation_changed",
		"reputation_changed should fire when score crosses REPUTABLE threshold"
	)
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Tier should be REPUTABLE after threshold crossing"
	)


func test_tier_up_emits_toast_with_reputation_up_category() -> void:
	var reputable_threshold: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	_rep._scores[STORE_ID] = reputable_threshold - (ReputationSystemSingleton.SATISFACTION_GAIN - 0.01)

	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, true)

	assert_signal_emitted(
		EventBus, "toast_requested",
		"toast_requested should fire on tier upgrade"
	)
	var params: Array = get_signal_parameters(EventBus, "toast_requested", 0)
	assert_eq(
		params[1],
		&"reputation_up",
		"toast category should be reputation_up on tier upgrade"
	)


func test_tier_up_toast_message_contains_new_tier_name() -> void:
	var reputable_threshold: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	_rep._scores[STORE_ID] = reputable_threshold - (ReputationSystemSingleton.SATISFACTION_GAIN - 0.01)

	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, true)

	var params: Array = get_signal_parameters(EventBus, "toast_requested", 0)
	var message: String = params[0] as String
	assert_true(
		message.contains("Reputable"),
		"Toast message should contain the new tier name 'Reputable'"
	)


# ── Test 2: Tier down (REPUTABLE → UNREMARKABLE) triggers toast ───────────────

func test_tier_down_emits_reputation_changed() -> void:
	var reputable_threshold: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	# Place score just above REPUTABLE so one dissatisfied customer drops it below.
	_rep._scores[STORE_ID] = reputable_threshold + 0.1

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Store should start at REPUTABLE before the tier-down signal"
	)

	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, false)

	assert_signal_emitted(
		EventBus, "reputation_changed",
		"reputation_changed should fire when score drops below REPUTABLE threshold"
	)
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Tier should be UNREMARKABLE after score falls below REPUTABLE threshold"
	)


func test_tier_down_emits_toast_with_reputation_down_category() -> void:
	var reputable_threshold: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	_rep._scores[STORE_ID] = reputable_threshold + 0.1

	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, false)

	assert_signal_emitted(
		EventBus, "toast_requested",
		"toast_requested should fire on tier downgrade"
	)
	var params: Array = get_signal_parameters(EventBus, "toast_requested", 0)
	assert_eq(
		params[1],
		&"reputation_down",
		"toast category should be reputation_down on tier downgrade"
	)


# ── Test 3: Score change within tier does NOT emit toast ──────────────────────

func test_within_tier_score_change_does_not_emit_toast() -> void:
	var unremarkable_threshold: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE
	]
	var reputable_threshold: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	# Start at 30 — within UNREMARKABLE (26.0–51.0).
	_rep._scores[STORE_ID] = 30.0

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Store should start at UNREMARKABLE"
	)

	# Emit 13 satisfied customers: 30 + 13 * 1.5 = 49.5, still below REPUTABLE.
	var emissions: int = ceili(
		(reputable_threshold - 1.0 - 30.0) / ReputationSystemSingleton.SATISFACTION_GAIN
	)

	watch_signals(EventBus)
	for i: int in range(emissions):
		EventBus.customer_left_mall.emit(_mock_customer, true)

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Tier should remain UNREMARKABLE — threshold must not be crossed"
	)
	assert_true(
		_rep.get_reputation(STORE_ID) < reputable_threshold,
		"Score must stay below REPUTABLE threshold for test to be valid"
	)
	assert_true(
		_rep.get_reputation(STORE_ID) > unremarkable_threshold,
		"Score must stay above UNREMARKABLE threshold"
	)
	assert_signal_not_emitted(
		EventBus, "toast_requested",
		"toast_requested must NOT fire when tier does not change"
	)


# ── Test 4: Skipping tiers in one step fires exactly one toast ────────────────

func test_skip_tier_fires_exactly_one_toast() -> void:
	# Start at NOTORIOUS (score 10, below UNREMARKABLE threshold of 26).
	_rep._scores[STORE_ID] = 10.0

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.NOTORIOUS,
		"Store should start at NOTORIOUS before the jump"
	)

	# A single add_reputation call jumps past UNREMARKABLE straight to REPUTABLE.
	watch_signals(EventBus)
	_rep.add_reputation(STORE_ID, 52.0)

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Tier should be REPUTABLE after a 52-point jump from NOTORIOUS"
	)
	assert_signal_emit_count(
		EventBus, "toast_requested", 1,
		"Exactly one toast_requested should fire regardless of tiers skipped"
	)
	var params: Array = get_signal_parameters(EventBus, "toast_requested", 0)
	assert_eq(
		params[1],
		&"reputation_up",
		"The single toast category should be reputation_up"
	)
