## Tests reputation gain/loss rates produce expected net changes for day scenarios.
extends GutTest


var _rep: ReputationSystem


func before_each() -> void:
	_rep = ReputationSystem.new()
	add_child_autofree(_rep)


# --- Good day scenario: 3 fair sales + 2 browsers = positive net ---


func test_good_day_net_reputation_is_positive() -> void:
	_rep.initialize()
	_rep.modify_reputation("", 20.0)
	var start_rep: float = _rep.get_reputation()

	var fair_sales: int = 3
	var browsers: int = 2
	var expected_gain: float = fair_sales * ReputationSystem.REP_FAIR_SALE
	var expected_loss: float = browsers * ReputationSystem.REP_NO_PURCHASE
	var expected_net: float = expected_gain + expected_loss

	for i: int in range(fair_sales):
		_rep.modify_reputation("", ReputationSystem.REP_FAIR_SALE)
	for i: int in range(browsers):
		_rep.modify_reputation("", ReputationSystem.REP_NO_PURCHASE)

	var actual_net: float = _rep.get_reputation() - start_rep
	assert_almost_eq(
		actual_net, expected_net, 0.01,
		"Good day net should be +%.1f (3 sales × %.1f + 2 browsers × %.1f)"
		% [expected_net, ReputationSystem.REP_FAIR_SALE,
			ReputationSystem.REP_NO_PURCHASE]
	)
	assert_gt(
		actual_net, 0.0,
		"Good day (3 fair sales, 2 browsers) must be net positive"
	)


# --- Bad day: 0 sales, 5 browsers + decay ---


func test_bad_day_net_reputation_is_negative() -> void:
	_rep.initialize()
	_rep.modify_reputation("", 30.0)
	var start_rep: float = _rep.get_reputation()

	var browsers: int = 5
	for i: int in range(browsers):
		_rep.modify_reputation("", ReputationSystem.REP_NO_PURCHASE)
	_rep.modify_reputation("", -ReputationSystem.DAILY_DECAY)

	var actual_net: float = _rep.get_reputation() - start_rep
	assert_lt(
		actual_net, 0.0,
		"Bad day (0 sales, 5 browsers + decay) must be net negative"
	)


# --- Single fair sale outweighs daily decay ---


func test_one_fair_sale_beats_decay() -> void:
	assert_gt(
		ReputationSystem.REP_FAIR_SALE, ReputationSystem.DAILY_DECAY,
		"One fair sale (+%.1f) should outweigh daily decay (%.1f)"
		% [ReputationSystem.REP_FAIR_SALE, ReputationSystem.DAILY_DECAY]
	)


# --- Patience expired is worse than no purchase ---


func test_patience_expired_worse_than_no_purchase() -> void:
	assert_lt(
		ReputationSystem.REP_PATIENCE_EXPIRED,
		ReputationSystem.REP_NO_PURCHASE,
		"Patience expired (%.1f) should be more negative than no purchase (%.1f)"
		% [ReputationSystem.REP_PATIENCE_EXPIRED,
			ReputationSystem.REP_NO_PURCHASE]
	)


# --- Reputation clamps to 0-100 ---


func test_reputation_does_not_go_below_zero() -> void:
	_rep.initialize()
	for i: int in range(50):
		_rep.modify_reputation("", ReputationSystem.REP_PATIENCE_EXPIRED)
	assert_eq(
		_rep.get_reputation(), 0.0,
		"Reputation should never go below 0"
	)


func test_reputation_does_not_exceed_100() -> void:
	_rep.initialize()
	for i: int in range(50):
		_rep.modify_reputation("", ReputationSystem.REP_FAIR_SALE)
	assert_eq(
		_rep.get_reputation(), ReputationSystem.MAX_REPUTATION,
		"Reputation should never exceed MAX_REPUTATION"
	)


# --- Moderate day: 2 sales, 3 browsers, no patience expirations ---


func test_moderate_day_still_positive() -> void:
	_rep.initialize()
	_rep.modify_reputation("", 15.0)
	var start_rep: float = _rep.get_reputation()

	var fair_sales: int = 2
	var browsers: int = 3
	for i: int in range(fair_sales):
		_rep.modify_reputation("", ReputationSystem.REP_FAIR_SALE)
	for i: int in range(browsers):
		_rep.modify_reputation("", ReputationSystem.REP_NO_PURCHASE)

	var actual_net: float = _rep.get_reputation() - start_rep
	var expected_net: float = (
		fair_sales * ReputationSystem.REP_FAIR_SALE
		+ browsers * ReputationSystem.REP_NO_PURCHASE
	)
	assert_almost_eq(actual_net, expected_net, 0.01)
	assert_gt(
		actual_net, 0.0,
		"Moderate day (2 fair sales, 3 browsers) should still be positive"
	)
