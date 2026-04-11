## Tests reputation gain/loss rate constants per economy balance research.
extends GutTest


var _rep: ReputationSystem


func before_each() -> void:
	_rep = ReputationSystem.new()
	add_child_autofree(_rep)


# --- Constant value acceptance criteria ---


func test_daily_decay_is_0_3() -> void:
	assert_eq(
		ReputationSystem.DAILY_DECAY, 0.3,
		"DAILY_DECAY should be 0.3"
	)


func test_rep_fair_sale_is_2_5() -> void:
	assert_eq(
		ReputationSystem.REP_FAIR_SALE, 2.5,
		"REP_FAIR_SALE should be 2.5"
	)


func test_rep_no_purchase_is_neg_0_5() -> void:
	assert_eq(
		ReputationSystem.REP_NO_PURCHASE, -0.5,
		"REP_NO_PURCHASE should be -0.5"
	)


func test_rep_patience_expired_is_neg_1_5() -> void:
	assert_eq(
		ReputationSystem.REP_PATIENCE_EXPIRED, -1.5,
		"REP_PATIENCE_EXPIRED should be -1.5"
	)


func test_fair_price_threshold_is_0_25() -> void:
	assert_eq(
		ReputationSystem.FAIR_PRICE_THRESHOLD, 0.25,
		"FAIR_PRICE_THRESHOLD should be 0.25"
	)


# --- Daily decay erodes less than 10% of Tier 2 threshold ---


func test_daily_decay_under_10_percent_of_tier_2() -> void:
	var tier_2_threshold: float = ReputationSystem.TIER_THRESHOLDS[
		ReputationSystem.Tier.LOCAL_FAVORITE
	]
	var ten_percent: float = tier_2_threshold * 0.1
	assert_lt(
		ReputationSystem.DAILY_DECAY, ten_percent,
		"DAILY_DECAY (%.1f) must be < 10%% of Tier 2 threshold (%.1f)"
		% [ReputationSystem.DAILY_DECAY, ten_percent]
	)
