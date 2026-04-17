## Tests reputation-scaled customer budgets and traffic caps.
extends GutTest


const TEST_STORE: String = "test_store"
var _rep: ReputationSystem


func before_each() -> void:
	_rep = ReputationSystem.new()
	add_child_autofree(_rep)
	_rep.initialize_store(TEST_STORE)


# --- Budget multiplier values ---


func test_budget_multiplier_notorious() -> void:
	assert_eq(
		ReputationSystemSingleton.BUDGET_MULTIPLIERS[
			ReputationSystemSingleton.ReputationTier.NOTORIOUS
		],
		1.0,
		"Unknown tier budget multiplier should be 1.0"
	)


func test_budget_multiplier_unremarkable() -> void:
	assert_eq(
		ReputationSystemSingleton.BUDGET_MULTIPLIERS[
			ReputationSystemSingleton.ReputationTier.UNREMARKABLE
		],
		1.2,
		"Local Favorite tier budget multiplier should be 1.2"
	)


func test_budget_multiplier_reputable() -> void:
	assert_eq(
		ReputationSystemSingleton.BUDGET_MULTIPLIERS[
			ReputationSystemSingleton.ReputationTier.REPUTABLE
		],
		1.5,
		"Destination Shop tier budget multiplier should be 1.5"
	)


func test_budget_multiplier_legendary() -> void:
	assert_eq(
		ReputationSystemSingleton.BUDGET_MULTIPLIERS[
			ReputationSystemSingleton.ReputationTier.LEGENDARY
		],
		2.0,
		"Legendary tier budget multiplier should be 2.0"
	)


# --- Max customers small store ---


func test_max_customers_small_notorious() -> void:
	assert_eq(
		ReputationSystemSingleton.MAX_CUSTOMERS_BY_TIER_SMALL[
			ReputationSystemSingleton.ReputationTier.NOTORIOUS
		],
		5,
		"Unknown tier small store max should be 5"
	)


func test_max_customers_small_unremarkable() -> void:
	assert_eq(
		ReputationSystemSingleton.MAX_CUSTOMERS_BY_TIER_SMALL[
			ReputationSystemSingleton.ReputationTier.UNREMARKABLE
		],
		6,
		"Local Favorite tier small store max should be 6"
	)


func test_max_customers_small_reputable() -> void:
	assert_eq(
		ReputationSystemSingleton.MAX_CUSTOMERS_BY_TIER_SMALL[
			ReputationSystemSingleton.ReputationTier.REPUTABLE
		],
		8,
		"Destination Shop tier small store max should be 8"
	)


func test_max_customers_small_legendary() -> void:
	assert_eq(
		ReputationSystemSingleton.MAX_CUSTOMERS_BY_TIER_SMALL[
			ReputationSystemSingleton.ReputationTier.LEGENDARY
		],
		10,
		"Legendary tier small store max should be 10"
	)


# --- Max customers medium store ---


func test_max_customers_medium_notorious() -> void:
	assert_eq(
		ReputationSystemSingleton.MAX_CUSTOMERS_BY_TIER_MEDIUM[
			ReputationSystemSingleton.ReputationTier.NOTORIOUS
		],
		8,
		"Unknown tier medium store max should be 8"
	)


func test_max_customers_medium_unremarkable() -> void:
	assert_eq(
		ReputationSystemSingleton.MAX_CUSTOMERS_BY_TIER_MEDIUM[
			ReputationSystemSingleton.ReputationTier.UNREMARKABLE
		],
		10,
		"Local Favorite tier medium store max should be 10"
	)


func test_max_customers_medium_reputable() -> void:
	assert_eq(
		ReputationSystemSingleton.MAX_CUSTOMERS_BY_TIER_MEDIUM[
			ReputationSystemSingleton.ReputationTier.REPUTABLE
		],
		12,
		"Destination Shop tier medium store max should be 12"
	)


func test_max_customers_medium_legendary() -> void:
	assert_eq(
		ReputationSystemSingleton.MAX_CUSTOMERS_BY_TIER_MEDIUM[
			ReputationSystemSingleton.ReputationTier.LEGENDARY
		],
		15,
		"Legendary tier medium store max should be 15"
	)


# --- get_budget_multiplier() follows tier ---


func test_get_budget_multiplier_at_default() -> void:
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 1.5,
		"Budget multiplier at default (50.0) should be 1.5 (Destination Shop)"
	)


func test_get_budget_multiplier_at_legendary() -> void:
	_rep.add_reputation(TEST_STORE, 35.0)
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 2.0,
		"Budget multiplier at Legendary should be 2.0"
	)


# --- get_max_customers() follows tier and size ---


func test_get_max_customers_small_at_default() -> void:
	assert_eq(
		_rep.get_max_customers("small", TEST_STORE), 8,
		"Destination Shop small store should allow 8 customers"
	)


func test_get_max_customers_medium_at_legendary() -> void:
	_rep.add_reputation(TEST_STORE, 35.0)
	assert_eq(
		_rep.get_max_customers("medium", TEST_STORE), 15,
		"Legendary medium store should allow 15 customers"
	)


func test_get_max_customers_large_uses_medium_table() -> void:
	assert_eq(
		_rep.get_max_customers("large", TEST_STORE),
		_rep.get_max_customers("medium", TEST_STORE),
		"Large stores should use the medium customer table"
	)


# --- Budget multipliers increase monotonically ---


func test_budget_multipliers_increase_with_tier() -> void:
	var notorious: float = ReputationSystemSingleton.BUDGET_MULTIPLIERS[
		ReputationSystemSingleton.ReputationTier.NOTORIOUS
	]
	var unremarkable: float = ReputationSystemSingleton.BUDGET_MULTIPLIERS[
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE
	]
	var reputable: float = ReputationSystemSingleton.BUDGET_MULTIPLIERS[
		ReputationSystemSingleton.ReputationTier.REPUTABLE
	]
	var legendary: float = ReputationSystemSingleton.BUDGET_MULTIPLIERS[
		ReputationSystemSingleton.ReputationTier.LEGENDARY
	]
	assert_lt(notorious, unremarkable, "Notorious < Unremarkable budget mult")
	assert_lt(unremarkable, reputable, "Unremarkable < Reputable")
	assert_lt(reputable, legendary, "Reputable < Legendary")


# --- Tier boundaries match spec ---


func test_tier_boundaries_match() -> void:
	assert_eq(
		ReputationSystemSingleton.TIER_THRESHOLDS[
			ReputationSystemSingleton.ReputationTier.NOTORIOUS
		],
		0.0,
		"Notorious threshold should be 0"
	)
	assert_eq(
		ReputationSystemSingleton.TIER_THRESHOLDS[
			ReputationSystemSingleton.ReputationTier.UNREMARKABLE
		],
		25.0,
		"Local Favorite threshold should be 25"
	)
	assert_eq(
		ReputationSystemSingleton.TIER_THRESHOLDS[
			ReputationSystemSingleton.ReputationTier.REPUTABLE
		],
		50.0,
		"Destination Shop threshold should be 50"
	)
	assert_eq(
		ReputationSystemSingleton.TIER_THRESHOLDS[
			ReputationSystemSingleton.ReputationTier.LEGENDARY
		],
		80.0,
		"Legendary threshold should be 80"
	)
