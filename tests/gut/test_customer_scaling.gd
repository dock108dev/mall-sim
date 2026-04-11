## Tests reputation-scaled customer budget multipliers at each tier boundary.
extends GutTest


var _rep: ReputationSystem


func before_each() -> void:
	_rep = ReputationSystem.new()
	add_child_autofree(_rep)
	_rep.initialize()


# --- Budget multiplier at each tier boundary ---


func test_budget_multiplier_at_rep_0() -> void:
	assert_eq(
		_rep.get_budget_multiplier(), 1.0,
		"At rep 0 (Unknown) budget multiplier should be 1.0"
	)


func test_budget_multiplier_at_rep_25() -> void:
	_rep.modify_reputation("", 25.0)
	assert_eq(
		_rep.get_budget_multiplier(), 1.2,
		"At rep 25 (Local Favorite) budget multiplier should be 1.2"
	)


func test_budget_multiplier_at_rep_50() -> void:
	_rep.modify_reputation("", 50.0)
	assert_eq(
		_rep.get_budget_multiplier(), 1.5,
		"At rep 50 (Destination Shop) budget multiplier should be 1.5"
	)


func test_budget_multiplier_at_rep_80() -> void:
	_rep.modify_reputation("", 80.0)
	assert_eq(
		_rep.get_budget_multiplier(), 2.0,
		"At rep 80 (Legendary) budget multiplier should be 2.0"
	)


# --- Just below each boundary stays in lower tier ---


func test_budget_just_below_local_favorite() -> void:
	_rep.modify_reputation("", 24.9)
	assert_eq(
		_rep.get_budget_multiplier(), 1.0,
		"At rep 24.9 should still be Unknown (1.0x budget)"
	)


func test_budget_just_below_destination_shop() -> void:
	_rep.modify_reputation("", 49.9)
	assert_eq(
		_rep.get_budget_multiplier(), 1.2,
		"At rep 49.9 should still be Local Favorite (1.2x budget)"
	)


func test_budget_just_below_legendary() -> void:
	_rep.modify_reputation("", 79.9)
	assert_eq(
		_rep.get_budget_multiplier(), 1.5,
		"At rep 79.9 should still be Destination Shop (1.5x budget)"
	)


# --- Tier enum matches at each boundary ---


func test_tier_at_rep_0_is_unknown() -> void:
	assert_eq(
		_rep.get_tier(), ReputationSystem.Tier.UNKNOWN,
		"Rep 0 should be Unknown tier"
	)


func test_tier_at_rep_25_is_local_favorite() -> void:
	_rep.modify_reputation("", 25.0)
	assert_eq(
		_rep.get_tier(), ReputationSystem.Tier.LOCAL_FAVORITE,
		"Rep 25 should be Local Favorite tier"
	)


func test_tier_at_rep_50_is_destination_shop() -> void:
	_rep.modify_reputation("", 50.0)
	assert_eq(
		_rep.get_tier(), ReputationSystem.Tier.DESTINATION_SHOP,
		"Rep 50 should be Destination Shop tier"
	)


func test_tier_at_rep_80_is_legendary() -> void:
	_rep.modify_reputation("", 80.0)
	assert_eq(
		_rep.get_tier(), ReputationSystem.Tier.LEGENDARY,
		"Rep 80 should be Legendary tier"
	)


# --- Budget multiplier increases monotonically with tier ---


func test_budget_multipliers_increase_with_tier() -> void:
	var unknown: float = ReputationSystem.BUDGET_MULTIPLIERS[
		ReputationSystem.Tier.UNKNOWN
	]
	var local_fav: float = ReputationSystem.BUDGET_MULTIPLIERS[
		ReputationSystem.Tier.LOCAL_FAVORITE
	]
	var dest_shop: float = ReputationSystem.BUDGET_MULTIPLIERS[
		ReputationSystem.Tier.DESTINATION_SHOP
	]
	var legendary: float = ReputationSystem.BUDGET_MULTIPLIERS[
		ReputationSystem.Tier.LEGENDARY
	]
	assert_lt(unknown, local_fav, "Unknown < Local Favorite budget mult")
	assert_lt(local_fav, dest_shop, "Local Favorite < Destination Shop")
	assert_lt(dest_shop, legendary, "Destination Shop < Legendary")


# --- Max customers scale with tier ---


func test_max_customers_small_at_rep_0() -> void:
	assert_eq(
		_rep.get_max_customers("small"), 5,
		"Unknown small store should allow 5 customers"
	)


func test_max_customers_small_at_rep_80() -> void:
	_rep.modify_reputation("", 80.0)
	assert_eq(
		_rep.get_max_customers("small"), 10,
		"Legendary small store should allow 10 customers"
	)


func test_max_customers_medium_at_rep_0() -> void:
	assert_eq(
		_rep.get_max_customers("medium"), 8,
		"Unknown medium store should allow 8 customers"
	)


func test_max_customers_medium_at_rep_80() -> void:
	_rep.modify_reputation("", 80.0)
	assert_eq(
		_rep.get_max_customers("medium"), 15,
		"Legendary medium store should allow 15 customers"
	)
