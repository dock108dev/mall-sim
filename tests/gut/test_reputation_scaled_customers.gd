## Tests reputation-scaled customer budgets and traffic caps.
extends GutTest


var _rep: ReputationSystem


func before_each() -> void:
	_rep = ReputationSystem.new()
	add_child_autofree(_rep)


# --- Budget multiplier values ---


func test_budget_multiplier_unknown_is_1_0() -> void:
	assert_eq(
		ReputationSystem.BUDGET_MULTIPLIERS[ReputationSystem.Tier.UNKNOWN],
		1.0,
		"Unknown tier budget multiplier should be 1.0"
	)


func test_budget_multiplier_local_favorite_is_1_2() -> void:
	assert_eq(
		ReputationSystem.BUDGET_MULTIPLIERS[
			ReputationSystem.Tier.LOCAL_FAVORITE
		],
		1.2,
		"Local Favorite tier budget multiplier should be 1.2"
	)


func test_budget_multiplier_destination_shop_is_1_5() -> void:
	assert_eq(
		ReputationSystem.BUDGET_MULTIPLIERS[
			ReputationSystem.Tier.DESTINATION_SHOP
		],
		1.5,
		"Destination Shop tier budget multiplier should be 1.5"
	)


func test_budget_multiplier_legendary_is_2_0() -> void:
	assert_eq(
		ReputationSystem.BUDGET_MULTIPLIERS[
			ReputationSystem.Tier.LEGENDARY
		],
		2.0,
		"Legendary tier budget multiplier should be 2.0"
	)


# --- Max customers small store ---


func test_max_customers_small_unknown_is_5() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_SMALL[
			ReputationSystem.Tier.UNKNOWN
		],
		5,
		"Unknown tier small store max should be 5"
	)


func test_max_customers_small_local_favorite_is_6() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_SMALL[
			ReputationSystem.Tier.LOCAL_FAVORITE
		],
		6,
		"Local Favorite tier small store max should be 6"
	)


func test_max_customers_small_destination_shop_is_8() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_SMALL[
			ReputationSystem.Tier.DESTINATION_SHOP
		],
		8,
		"Destination Shop tier small store max should be 8"
	)


func test_max_customers_small_legendary_is_10() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_SMALL[
			ReputationSystem.Tier.LEGENDARY
		],
		10,
		"Legendary tier small store max should be 10"
	)


# --- Max customers medium store ---


func test_max_customers_medium_unknown_is_8() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_MEDIUM[
			ReputationSystem.Tier.UNKNOWN
		],
		8,
		"Unknown tier medium store max should be 8"
	)


func test_max_customers_medium_local_favorite_is_10() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_MEDIUM[
			ReputationSystem.Tier.LOCAL_FAVORITE
		],
		10,
		"Local Favorite tier medium store max should be 10"
	)


func test_max_customers_medium_destination_shop_is_12() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_MEDIUM[
			ReputationSystem.Tier.DESTINATION_SHOP
		],
		12,
		"Destination Shop tier medium store max should be 12"
	)


func test_max_customers_medium_legendary_is_15() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_MEDIUM[
			ReputationSystem.Tier.LEGENDARY
		],
		15,
		"Legendary tier medium store max should be 15"
	)


# --- get_budget_multiplier() follows tier ---


func test_get_budget_multiplier_at_unknown() -> void:
	_rep.initialize()
	assert_eq(
		_rep.get_budget_multiplier(), 1.0,
		"Budget multiplier at Unknown should be 1.0"
	)


func test_get_budget_multiplier_at_legendary() -> void:
	_rep.initialize()
	_rep.modify_reputation("", 85.0)
	assert_eq(
		_rep.get_budget_multiplier(), 2.0,
		"Budget multiplier at Legendary should be 2.0"
	)


# --- get_max_customers() follows tier and size ---


func test_get_max_customers_small_at_unknown() -> void:
	_rep.initialize()
	assert_eq(
		_rep.get_max_customers("small"), 5,
		"Unknown small store should allow 5 customers"
	)


func test_get_max_customers_medium_at_legendary() -> void:
	_rep.initialize()
	_rep.modify_reputation("", 85.0)
	assert_eq(
		_rep.get_max_customers("medium"), 15,
		"Legendary medium store should allow 15 customers"
	)


func test_get_max_customers_large_uses_medium_table() -> void:
	_rep.initialize()
	_rep.modify_reputation("", 50.0)
	assert_eq(
		_rep.get_max_customers("large"),
		_rep.get_max_customers("medium"),
		"Large stores should use the medium customer table"
	)


# --- Legendary is 2x Unknown for both budgets and traffic ---


func test_legendary_budget_is_2x_unknown() -> void:
	var unknown_mult: float = ReputationSystem.BUDGET_MULTIPLIERS[
		ReputationSystem.Tier.UNKNOWN
	]
	var legendary_mult: float = ReputationSystem.BUDGET_MULTIPLIERS[
		ReputationSystem.Tier.LEGENDARY
	]
	assert_eq(
		legendary_mult / unknown_mult, 2.0,
		"Legendary budget should be 2x Unknown budget"
	)


func test_legendary_small_customers_is_2x_unknown() -> void:
	var unknown_max: int = ReputationSystem.MAX_CUSTOMERS_BY_TIER_SMALL[
		ReputationSystem.Tier.UNKNOWN
	]
	var legendary_max: int = ReputationSystem.MAX_CUSTOMERS_BY_TIER_SMALL[
		ReputationSystem.Tier.LEGENDARY
	]
	assert_eq(
		legendary_max, unknown_max * 2,
		"Legendary small store max should be 2x Unknown"
	)


# --- Tier boundaries match existing thresholds ---


func test_tier_boundaries_match() -> void:
	assert_eq(
		ReputationSystem.TIER_THRESHOLDS[ReputationSystem.Tier.UNKNOWN],
		0.0,
		"Unknown threshold should be 0"
	)
	assert_eq(
		ReputationSystem.TIER_THRESHOLDS[
			ReputationSystem.Tier.LOCAL_FAVORITE
		],
		25.0,
		"Local Favorite threshold should be 25"
	)
	assert_eq(
		ReputationSystem.TIER_THRESHOLDS[
			ReputationSystem.Tier.DESTINATION_SHOP
		],
		50.0,
		"Destination Shop threshold should be 50"
	)
	assert_eq(
		ReputationSystem.TIER_THRESHOLDS[
			ReputationSystem.Tier.LEGENDARY
		],
		80.0,
		"Legendary threshold should be 80"
	)
