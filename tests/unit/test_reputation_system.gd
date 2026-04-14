## Unit tests for ReputationSystem tier thresholds, event adjustments, and daily decay.
extends GutTest


const STORE_ID: String = "test_store"

var _rep: ReputationSystem


func before_each() -> void:
	_rep = ReputationSystem.new()
	add_child_autofree(_rep)


func test_initial_reputation_is_default() -> void:
	_rep.initialize_store(STORE_ID)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		ReputationSystem.DEFAULT_REPUTATION, 0.01,
		"Fresh store should start at DEFAULT_REPUTATION (50.0)"
	)


func test_add_reputation_increases_score() -> void:
	_rep.initialize_store(STORE_ID)
	var before: float = _rep.get_reputation(STORE_ID)
	_rep.add_reputation(STORE_ID, 10.0)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID), before + 10.0, 0.01,
		"Score should increase by exact delta"
	)


func test_add_reputation_decreases_score() -> void:
	_rep.initialize_store(STORE_ID)
	var before: float = _rep.get_reputation(STORE_ID)
	_rep.add_reputation(STORE_ID, -5.0)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID), before - 5.0, 0.01,
		"Score should decrease by exact negative delta"
	)


func test_reputation_tier_upgrades_at_threshold() -> void:
	_rep._scores[STORE_ID] = 0.0
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.NOTORIOUS,
		"Score 0 should be NOTORIOUS tier"
	)
	watch_signals(EventBus)
	_rep.add_reputation(STORE_ID, 26.0)
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.UNREMARKABLE,
		"Score 26 should reach UNREMARKABLE tier"
	)
	assert_signal_emitted(
		EventBus, "reputation_changed",
		"reputation_changed should fire on tier crossing"
	)


func test_tier_thresholds_are_correct() -> void:
	_rep._scores[STORE_ID] = 0.0
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.NOTORIOUS,
		"Score 0 should be NOTORIOUS"
	)

	_rep._scores[STORE_ID] = 26.0
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.UNREMARKABLE,
		"Score 26 should be UNREMARKABLE"
	)

	_rep._scores[STORE_ID] = 51.0
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.REPUTABLE,
		"Score 51 should be REPUTABLE"
	)

	_rep._scores[STORE_ID] = 76.0
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.LEGENDARY,
		"Score 76 should be LEGENDARY"
	)


func test_tier_stays_below_threshold() -> void:
	_rep._scores[STORE_ID] = 25.9
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.NOTORIOUS,
		"Score 25.9 should remain NOTORIOUS (below 26 threshold)"
	)

	_rep._scores[STORE_ID] = 50.9
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.UNREMARKABLE,
		"Score 50.9 should remain UNREMARKABLE (below 51 threshold)"
	)

	_rep._scores[STORE_ID] = 75.9
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.REPUTABLE,
		"Score 75.9 should remain REPUTABLE (below 76 threshold)"
	)


func test_negative_event_can_downgrade_tier() -> void:
	_rep._scores[STORE_ID] = 52.0
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.REPUTABLE,
		"Score 52 should be REPUTABLE"
	)
	_rep.add_reputation(STORE_ID, -5.0)
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.UNREMARKABLE,
		"Score dropping below 51 should downgrade to UNREMARKABLE"
	)


func test_daily_decay_reduces_score_above_floor() -> void:
	_rep._scores[STORE_ID] = 80.0
	var before: float = _rep.get_reputation(STORE_ID)
	_rep._on_day_ended(1)
	assert_lt(
		_rep.get_reputation(STORE_ID), before,
		"Score above DECAY_FLOOR should decrease after day end"
	)


func test_daily_decay_does_not_reduce_score_at_floor() -> void:
	_rep._scores[STORE_ID] = ReputationSystem.DECAY_FLOOR
	_rep._on_day_ended(1)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		ReputationSystem.DECAY_FLOOR, 0.01,
		"Score at DECAY_FLOOR should not decay further"
	)


func test_daily_decay_does_not_reduce_score_below_floor() -> void:
	_rep._scores[STORE_ID] = 30.0
	_rep._on_day_ended(1)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID), 30.0, 0.01,
		"Score below DECAY_FLOOR should not decay"
	)


func test_score_clamped_at_max() -> void:
	_rep._scores[STORE_ID] = 95.0
	_rep.add_reputation(STORE_ID, 50.0)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		ReputationSystem.MAX_REPUTATION, 0.01,
		"Score should never exceed MAX_REPUTATION (100)"
	)


func test_score_clamped_at_min() -> void:
	_rep._scores[STORE_ID] = 5.0
	_rep.add_reputation(STORE_ID, -50.0)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		ReputationSystem.MIN_REPUTATION, 0.01,
		"Score should never go below MIN_REPUTATION (0)"
	)


func test_max_tier_is_legendary() -> void:
	_rep._scores[STORE_ID] = 100.0
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.LEGENDARY,
		"Max score should yield LEGENDARY tier"
	)

	_rep._scores[STORE_ID] = 9999.0
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.LEGENDARY,
		"Extremely high score should still yield LEGENDARY"
	)


func test_serialize_deserialize_preserves_score() -> void:
	_rep._scores[STORE_ID] = 72.5
	var save_data: Dictionary = _rep.get_save_data()

	var fresh_rep: ReputationSystem = ReputationSystem.new()
	add_child_autofree(fresh_rep)
	fresh_rep.load_save_data(save_data)

	assert_almost_eq(
		fresh_rep.get_reputation(STORE_ID),
		72.5, 0.01,
		"Score should match after save/load round-trip"
	)


func test_serialize_deserialize_preserves_tier() -> void:
	_rep._scores[STORE_ID] = 60.0
	var original_tier: ReputationSystem.ReputationTier = _rep.get_tier(
		STORE_ID
	)
	var save_data: Dictionary = _rep.get_save_data()

	var fresh_rep: ReputationSystem = ReputationSystem.new()
	add_child_autofree(fresh_rep)
	fresh_rep.load_save_data(save_data)

	assert_eq(
		fresh_rep.get_tier(STORE_ID), original_tier,
		"Tier should match after save/load round-trip"
	)


func test_serialize_deserialize_multiple_stores() -> void:
	_rep._scores["store_a"] = 30.0
	_rep._scores["store_b"] = 80.0
	var save_data: Dictionary = _rep.get_save_data()

	var fresh_rep: ReputationSystem = ReputationSystem.new()
	add_child_autofree(fresh_rep)
	fresh_rep.load_save_data(save_data)

	assert_almost_eq(
		fresh_rep.get_reputation("store_a"), 30.0, 0.01,
		"Store A score should survive round-trip"
	)
	assert_almost_eq(
		fresh_rep.get_reputation("store_b"), 80.0, 0.01,
		"Store B score should survive round-trip"
	)


func test_reputation_changed_signal_fires() -> void:
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
		params[1] as float, 55.0, 0.01,
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


func test_reset_clears_all_scores() -> void:
	_rep._scores[STORE_ID] = 75.0
	_rep._scores["other_store"] = 30.0
	_rep.reset()
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		ReputationSystem.DEFAULT_REPUTATION, 0.01,
		"Score should return to default after reset"
	)
	assert_almost_eq(
		_rep.get_reputation("other_store"),
		ReputationSystem.DEFAULT_REPUTATION, 0.01,
		"All store scores should reset"
	)


func test_modify_reputation_alias_works() -> void:
	_rep._scores[STORE_ID] = 50.0
	_rep.modify_reputation(STORE_ID, 10.0)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID), 60.0, 0.01,
		"modify_reputation should behave identically to add_reputation"
	)


func test_global_reputation_averages_stores() -> void:
	_rep._scores["store_a"] = 40.0
	_rep._scores["store_b"] = 60.0
	assert_almost_eq(
		_rep.get_global_reputation(), 50.0, 0.01,
		"Global reputation should be the average of all store scores"
	)


func test_adjust_positive_1_5_increases_score_exactly() -> void:
	_rep._scores[STORE_ID] = 50.0
	_rep.add_reputation(STORE_ID, 1.5)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID), 51.5, 0.01,
		"Score should increase by exactly 1.5"
	)


func test_adjust_negative_2_0_decreases_score_exactly() -> void:
	_rep._scores[STORE_ID] = 50.0
	_rep.add_reputation(STORE_ID, -2.0)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID), 48.0, 0.01,
		"Score should decrease by exactly 2.0"
	)


func test_tier_downgrade_emits_reputation_changed_signal() -> void:
	_rep._scores[STORE_ID] = 52.0
	_rep._tiers[STORE_ID] = ReputationSystem.ReputationTier.REPUTABLE
	watch_signals(EventBus)
	_rep.add_reputation(STORE_ID, -5.0)
	assert_signal_emitted(
		EventBus, "reputation_changed",
		"reputation_changed should fire when score drops across a tier boundary"
	)
	assert_eq(
		_rep.get_tier(STORE_ID),
		ReputationSystem.ReputationTier.UNREMARKABLE,
		"Tier should downgrade to UNREMARKABLE after score drops below 51"
	)


func test_floor_clamp_at_zero_with_negative_delta() -> void:
	_rep._scores[STORE_ID] = 0.0
	_rep.add_reputation(STORE_ID, -5.0)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		ReputationSystem.MIN_REPUTATION, 0.01,
		"Score at 0.0 with -5.0 delta should remain at MIN_REPUTATION (0.0)"
	)


func test_ceiling_clamp_at_max_with_positive_delta() -> void:
	_rep._scores[STORE_ID] = ReputationSystem.MAX_REPUTATION
	_rep.add_reputation(STORE_ID, 5.0)
	assert_almost_eq(
		_rep.get_reputation(STORE_ID),
		ReputationSystem.MAX_REPUTATION, 0.01,
		"Score at MAX_REPUTATION with +5.0 delta should remain at MAX_REPUTATION (100.0)"
	)
