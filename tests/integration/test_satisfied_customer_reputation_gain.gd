## Integration test — satisfied customer departure raises store reputation via ReputationSystemSingleton.
extends GutTest

const STORE_ID: String = "sports_memorabilia"

var _rep: ReputationSystem
var _mock_customer: Node


func before_each() -> void:
	_rep = ReputationSystem.new()
	add_child_autofree(_rep)
	_rep.initialize_store(STORE_ID)
	GameManager.current_store_id = &"sports_memorabilia"

	_mock_customer = Node.new()
	add_child_autofree(_mock_customer)


func after_each() -> void:
	GameManager.current_store_id = &""


# ── Basic satisfaction gain ────────────────────────────────────────────────────

func test_satisfied_customer_increases_score_by_satisfaction_gain() -> void:
	var score_before: float = _rep.get_reputation(STORE_ID)
	EventBus.customer_left_mall.emit(_mock_customer, true)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		score_before + ReputationSystemSingleton.SATISFACTION_GAIN, 0.01,
		"Satisfied customer should increase score by exactly SATISFACTION_GAIN"
	)


func test_satisfied_customer_emits_reputation_changed() -> void:
	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, true)
	assert_signal_emitted(
		EventBus, "reputation_changed",
		"reputation_changed must fire after a satisfied customer departs"
	)


func test_reputation_changed_carries_correct_store_id() -> void:
	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, true)
	var params: Array = get_signal_parameters(EventBus, "reputation_changed")
	assert_eq(
		params[0], STORE_ID,
		"reputation_changed first parameter must be the active store_id"
	)


func test_reputation_changed_carries_updated_score() -> void:
	var score_before: float = _rep.get_reputation(STORE_ID)
	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, true)
	var params: Array = get_signal_parameters(EventBus, "reputation_changed")
	assert_almost_eq(
		params[1] as float,
		score_before + ReputationSystemSingleton.SATISFACTION_GAIN, 0.01,
		"reputation_changed second parameter must equal the updated score"
	)


# ── Tier boundary crossing ─────────────────────────────────────────────────────

func test_tier_crossing_score_matches_expected_new_tier() -> void:
	var tier_reputable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	# Place score just below REPUTABLE so one satisfaction gain crosses the boundary.
	_rep._scores[STORE_ID] = tier_reputable - (ReputationSystemSingleton.SATISFACTION_GAIN - 0.01)

	var old_tier: ReputationSystemSingleton.ReputationTier = _rep.get_tier(STORE_ID)
	assert_eq(
		old_tier,
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Store must start at UNREMARKABLE for this tier-crossing test"
	)

	EventBus.customer_left_mall.emit(_mock_customer, true)

	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Tier must advance to REPUTABLE after score crosses the threshold"
	)


func test_tier_crossing_emits_reputation_changed() -> void:
	var tier_reputable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	_rep._scores[STORE_ID] = tier_reputable - (ReputationSystemSingleton.SATISFACTION_GAIN - 0.01)

	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, true)

	assert_signal_emitted(
		EventBus, "reputation_changed",
		"reputation_changed must fire when satisfaction gain crosses a tier boundary"
	)


func test_tier_crossing_emits_toast_requested_with_reputation_up_category() -> void:
	var tier_reputable: float = ReputationSystemSingleton.TIER_THRESHOLDS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	_rep._scores[STORE_ID] = tier_reputable - (ReputationSystemSingleton.SATISFACTION_GAIN - 0.01)

	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, true)

	assert_signal_emitted(
		EventBus, "toast_requested",
		"toast_requested must fire on tier upgrade"
	)
	var params: Array = get_signal_parameters(EventBus, "toast_requested")
	assert_eq(
		params[1], &"reputation_up",
		"toast_requested category must be reputation_up for a tier upgrade"
	)


func test_no_tier_change_does_not_emit_toast() -> void:
	# Default score (50.0) is UNREMARKABLE; adding 1.5 stays in UNREMARKABLE.
	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, true)

	assert_signal_not_emitted(
		EventBus, "toast_requested",
		"toast_requested must not fire when score change stays within the same tier"
	)


# ── MAX_REPUTATION ceiling clamping ───────────────────────────────────────────

func test_score_at_max_reputation_remains_clamped() -> void:
	_rep._scores[STORE_ID] = ReputationSystemSingleton.MAX_REPUTATION
	EventBus.customer_left_mall.emit(_mock_customer, true)
	assert_eq(
		_rep.get_reputation(STORE_ID),
		ReputationSystemSingleton.MAX_REPUTATION,
		"Score must not exceed MAX_REPUTATION when already at ceiling"
	)


func test_score_at_max_reputation_does_not_emit_reputation_changed() -> void:
	_rep._scores[STORE_ID] = ReputationSystemSingleton.MAX_REPUTATION
	watch_signals(EventBus)
	EventBus.customer_left_mall.emit(_mock_customer, true)
	assert_signal_not_emitted(
		EventBus, "reputation_changed",
		"reputation_changed must not fire when score is already at MAX_REPUTATION"
	)


# ── Guard: valid active store processes without error ─────────────────────────

func test_valid_active_store_processes_satisfaction_without_crash() -> void:
	var score_before: float = _rep.get_reputation(STORE_ID)
	EventBus.customer_left_mall.emit(_mock_customer, true)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		score_before + ReputationSystemSingleton.SATISFACTION_GAIN, 0.01,
		"A valid active store_id must process satisfaction gain cleanly"
	)
