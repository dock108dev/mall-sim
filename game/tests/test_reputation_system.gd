## GUT unit tests for ReputationSystem tier advancement, decay, and signal emission.
extends GutTest


const STORE_ID: String = "test_store"

var _rep: ReputationSystem


func before_each() -> void:
	_rep = ReputationSystem.new()
	_rep.auto_connect_bus = false
	add_child_autofree(_rep)
	_rep.initialize_store(STORE_ID)


func test_tier_advances_when_threshold_passed() -> void:
	_rep._scores[STORE_ID] = 24.0
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.NOTORIOUS,
		"Score 24 should be NOTORIOUS"
	)
	_rep.add_reputation(STORE_ID, 3.0)
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Score 27 should advance to UNREMARKABLE"
	)


func test_tier_advances_through_multiple_thresholds() -> void:
	_rep._scores[STORE_ID] = 24.0
	_rep.add_reputation(STORE_ID, 28.0)
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Score 52 should advance to REPUTABLE"
	)


func test_tier_does_not_advance_beyond_legendary() -> void:
	_rep._scores[STORE_ID] = 76.0
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.LEGENDARY,
		"Score 76 should be LEGENDARY"
	)
	_rep.add_reputation(STORE_ID, 50.0)
	assert_eq(
		_rep.get_reputation(STORE_ID),
		ReputationSystemSingleton.MAX_REPUTATION,
		"Score should clamp to MAX_REPUTATION"
	)
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.LEGENDARY,
		"Tier should remain LEGENDARY at max score"
	)


func test_daily_decay_reduces_score_above_floor() -> void:
	_rep._scores[STORE_ID] = 80.0
	var before: float = _rep.get_reputation(STORE_ID)
	_rep._on_day_ended(1)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		before - ReputationSystemSingleton.DAILY_DECAY, 0.01,
		"Score above DECAY_FLOOR should decay by DAILY_DECAY"
	)


func test_daily_decay_can_downgrade_tier() -> void:
	_rep._scores[STORE_ID] = 51.1
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Score 51.1 should be REPUTABLE"
	)
	_rep._on_day_ended(1)
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Decay below 51 should downgrade to UNREMARKABLE"
	)


func test_daily_decay_does_not_reduce_at_floor() -> void:
	_rep._scores[STORE_ID] = ReputationSystemSingleton.DECAY_FLOOR
	_rep._on_day_ended(1)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		ReputationSystemSingleton.DECAY_FLOOR, 0.01,
		"Score at DECAY_FLOOR should not decay"
	)


func test_daily_decay_does_not_reduce_below_floor() -> void:
	_rep._scores[STORE_ID] = 30.0
	_rep._on_day_ended(1)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID), 30.0, 0.01,
		"Score below DECAY_FLOOR should not decay"
	)


func test_reputation_changed_signal_fires_with_correct_params() -> void:
	_rep._scores[STORE_ID] = 50.0
	watch_signals(EventBus)
	_rep.add_reputation(STORE_ID, 5.0)
	assert_signal_emitted(
		EventBus, "reputation_changed",
		"reputation_changed should fire when score changes"
	)
	var params: Array = get_signal_parameters(
		EventBus, "reputation_changed"
	)
	assert_eq(
		params[0] as String, STORE_ID,
		"Signal should carry correct store_id"
	)
	assert_almost_eq(
		params[1] as float, 50.0, 0.01,
		"Signal should carry old score value"
	)
	assert_almost_eq(
		params[2] as float, 55.0, 0.01,
		"Signal should carry new score value"
	)


func test_reputation_changed_signal_not_fired_on_zero_delta() -> void:
	_rep._scores[STORE_ID] = 50.0
	watch_signals(EventBus)
	_rep.add_reputation(STORE_ID, 0.0)
	assert_signal_not_emitted(
		EventBus, "reputation_changed",
		"reputation_changed should not fire when score unchanged"
	)


func test_tier_change_emits_toast_requested() -> void:
	_rep._scores[STORE_ID] = 50.0
	watch_signals(EventBus)
	_rep.add_reputation(STORE_ID, 1.0)
	assert_signal_emitted(
		EventBus, "toast_requested",
		"Crossing tier threshold should emit toast"
	)


func test_new_store_starts_at_default_reputation() -> void:
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		ReputationSystemSingleton.DEFAULT_REPUTATION, 0.01,
		"Initialized store should start at DEFAULT_REPUTATION"
	)


func test_new_store_starts_at_base_tier() -> void:
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Default reputation 50 should place store at UNREMARKABLE"
	)


func test_tier_0_cannot_decay_below_floor() -> void:
	_rep._scores[STORE_ID] = 0.0
	_rep._on_day_ended(1)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID), 0.0, 0.01,
		"Score 0 (below DECAY_FLOOR) should not decay further"
	)
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystemSingleton.ReputationTier.NOTORIOUS,
		"Should remain NOTORIOUS at score 0"
	)


func test_unknown_store_id_returns_default_without_error() -> void:
	var score: float = _rep.get_reputation("nonexistent_store")
	assert_almost_eq(
		score,
		ReputationSystemSingleton.DEFAULT_REPUTATION, 0.01,
		"Unknown store_id should return DEFAULT_REPUTATION"
	)


func test_unknown_store_id_tier_returns_default_tier() -> void:
	var tier: ReputationSystemSingleton.ReputationTier = _rep.get_tier(
		"nonexistent_store"
	)
	assert_eq(
		tier,
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Unknown store_id tier should match DEFAULT_REPUTATION tier"
	)


const ALL_STORE_IDS: Array[String] = [
	"sports", "retro_games", "rentals", "pocket_creatures", "electronics"
]


func test_good_sale_increases_reputation_for_all_stores() -> void:
	for sid: String in ALL_STORE_IDS:
		_rep.initialize_store(sid)
		var before: float = _rep.get_reputation(sid)
		_rep.add_reputation(sid, ReputationSystemSingleton.REP_FAIR_SALE)
		var after: float = _rep.get_reputation(sid)
		assert_gt(
			after, before,
			"Fair-sale delta should raise reputation for %s" % sid
		)


func test_bad_sale_decreases_reputation_for_all_stores() -> void:
	for sid: String in ALL_STORE_IDS:
		_rep.initialize_store(sid)
		var before: float = _rep.get_reputation(sid)
		_rep.add_reputation(sid, ReputationSystemSingleton.REP_OVERPRICED_REJECTED)
		var after: float = _rep.get_reputation(sid)
		assert_lt(
			after, before,
			"Overpriced-rejection delta should lower reputation for %s" % sid
		)


func test_multiplier_clamps_at_upper_bound() -> void:
	_rep.initialize_store(STORE_ID)
	_rep._scores[STORE_ID] = ReputationSystemSingleton.MAX_REPUTATION
	var mult: float = _rep.get_reputation_multiplier(STORE_ID)
	assert_almost_eq(
		mult, 2.0, 0.001,
		"Max reputation (100) should map to multiplier 2.0"
	)
	assert_true(
		mult <= 2.0,
		"Multiplier must not exceed 2.0"
	)


func test_multiplier_clamps_at_lower_bound() -> void:
	_rep.initialize_store(STORE_ID)
	_rep._scores[STORE_ID] = ReputationSystemSingleton.MIN_REPUTATION
	var mult: float = _rep.get_reputation_multiplier(STORE_ID)
	assert_almost_eq(
		mult, 0.0, 0.001,
		"Min reputation (0) should map to multiplier 0.0"
	)
	assert_true(
		mult >= 0.0,
		"Multiplier must not be negative"
	)


func test_multiplier_defaults_to_one_at_default_score() -> void:
	_rep.initialize_store(STORE_ID)
	var mult: float = _rep.get_reputation_multiplier(STORE_ID)
	assert_almost_eq(
		mult, 1.0, 0.001,
		"Default reputation should map to multiplier 1.0"
	)


func test_reputation_changed_emits_old_and_new_score() -> void:
	_rep._scores[STORE_ID] = 40.0
	watch_signals(EventBus)
	_rep.add_reputation(STORE_ID, 10.0)
	var params: Array = get_signal_parameters(
		EventBus, "reputation_changed"
	)
	assert_almost_eq(
		params[1] as float, 40.0, 0.01,
		"old_score should be pre-mutation value"
	)
	assert_almost_eq(
		params[2] as float, 50.0, 0.01,
		"new_score should be post-mutation value"
	)
