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
		ReputationSystem.BUDGET_MULTIPLIERS[
			ReputationSystem.ReputationTier.NOTORIOUS
		],
		0.8,
		"Notorious tier budget multiplier should be 0.8"
	)


func test_budget_multiplier_unremarkable() -> void:
	assert_eq(
		ReputationSystem.BUDGET_MULTIPLIERS[
			ReputationSystem.ReputationTier.UNREMARKABLE
		],
		1.0,
		"Unremarkable tier budget multiplier should be 1.0"
	)


func test_budget_multiplier_reputable() -> void:
	assert_eq(
		ReputationSystem.BUDGET_MULTIPLIERS[
			ReputationSystem.ReputationTier.REPUTABLE
		],
		1.3,
		"Reputable tier budget multiplier should be 1.3"
	)


func test_budget_multiplier_legendary() -> void:
	assert_eq(
		ReputationSystem.BUDGET_MULTIPLIERS[
			ReputationSystem.ReputationTier.LEGENDARY
		],
		2.0,
		"Legendary tier budget multiplier should be 2.0"
	)


# --- Max customers small store ---


func test_max_customers_small_notorious() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_SMALL[
			ReputationSystem.ReputationTier.NOTORIOUS
		],
		3,
		"Notorious tier small store max should be 3"
	)


func test_max_customers_small_unremarkable() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_SMALL[
			ReputationSystem.ReputationTier.UNREMARKABLE
		],
		5,
		"Unremarkable tier small store max should be 5"
	)


func test_max_customers_small_reputable() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_SMALL[
			ReputationSystem.ReputationTier.REPUTABLE
		],
		7,
		"Reputable tier small store max should be 7"
	)


func test_max_customers_small_legendary() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_SMALL[
			ReputationSystem.ReputationTier.LEGENDARY
		],
		10,
		"Legendary tier small store max should be 10"
	)


# --- Max customers medium store ---


func test_max_customers_medium_notorious() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_MEDIUM[
			ReputationSystem.ReputationTier.NOTORIOUS
		],
		5,
		"Notorious tier medium store max should be 5"
	)


func test_max_customers_medium_unremarkable() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_MEDIUM[
			ReputationSystem.ReputationTier.UNREMARKABLE
		],
		8,
		"Unremarkable tier medium store max should be 8"
	)


func test_max_customers_medium_reputable() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_MEDIUM[
			ReputationSystem.ReputationTier.REPUTABLE
		],
		11,
		"Reputable tier medium store max should be 11"
	)


func test_max_customers_medium_legendary() -> void:
	assert_eq(
		ReputationSystem.MAX_CUSTOMERS_BY_TIER_MEDIUM[
			ReputationSystem.ReputationTier.LEGENDARY
		],
		15,
		"Legendary tier medium store max should be 15"
	)


# --- get_budget_multiplier() follows tier ---


func test_get_budget_multiplier_at_default() -> void:
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 1.0,
		"Budget multiplier at default (50.0) should be 1.0 (Unremarkable)"
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
		_rep.get_max_customers("small", TEST_STORE), 5,
		"Unremarkable small store should allow 5 customers"
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
	var notorious: float = ReputationSystem.BUDGET_MULTIPLIERS[
		ReputationSystem.ReputationTier.NOTORIOUS
	]
	var unremarkable: float = ReputationSystem.BUDGET_MULTIPLIERS[
		ReputationSystem.ReputationTier.UNREMARKABLE
	]
	var reputable: float = ReputationSystem.BUDGET_MULTIPLIERS[
		ReputationSystem.ReputationTier.REPUTABLE
	]
	var legendary: float = ReputationSystem.BUDGET_MULTIPLIERS[
		ReputationSystem.ReputationTier.LEGENDARY
	]
	assert_lt(notorious, unremarkable, "Notorious < Unremarkable budget mult")
	assert_lt(unremarkable, reputable, "Unremarkable < Reputable")
	assert_lt(reputable, legendary, "Reputable < Legendary")


# --- Tier boundaries match spec ---


func test_tier_boundaries_match() -> void:
	assert_eq(
		ReputationSystem.TIER_THRESHOLDS[
			ReputationSystem.ReputationTier.NOTORIOUS
		],
		0.0,
		"Notorious threshold should be 0"
	)
	assert_eq(
		ReputationSystem.TIER_THRESHOLDS[
			ReputationSystem.ReputationTier.UNREMARKABLE
		],
		26.0,
		"Unremarkable threshold should be 26"
	)
	assert_eq(
		ReputationSystem.TIER_THRESHOLDS[
			ReputationSystem.ReputationTier.REPUTABLE
		],
		51.0,
		"Reputable threshold should be 51"
	)
	assert_eq(
		ReputationSystem.TIER_THRESHOLDS[
			ReputationSystem.ReputationTier.LEGENDARY
		],
		76.0,
		"Legendary threshold should be 76"
	)
