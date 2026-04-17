## Tests reputation-scaled customer budget multipliers at each tier boundary.
extends GutTest


const TEST_STORE: String = "test_store"
var _rep: ReputationSystem


func before_each() -> void:
	_rep = ReputationSystem.new()
	add_child_autofree(_rep)
	_rep.initialize_store(TEST_STORE)


# --- Budget multiplier at each tier boundary ---


func test_budget_multiplier_at_default() -> void:
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 1.5,
		"At default rep 50 (Destination Shop) budget multiplier should be 1.5"
	)


func test_budget_multiplier_at_notorious() -> void:
	_rep.add_reputation(TEST_STORE, -50.0)
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 1.0,
		"At rep 0 (Unknown) budget multiplier should be 1.0"
	)


func test_budget_multiplier_at_reputable() -> void:
	_rep.add_reputation(TEST_STORE, -10.0)
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 1.2,
		"At rep 40 (Local Favorite) budget multiplier should be 1.2"
	)


func test_budget_multiplier_at_legendary() -> void:
	_rep.add_reputation(TEST_STORE, 35.0)
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 2.0,
		"At rep 85 (Legendary) budget multiplier should be 2.0"
	)


# --- Just below each boundary stays in lower tier ---


func test_budget_just_below_unremarkable() -> void:
	_rep.add_reputation(TEST_STORE, -26.0)
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 1.0,
		"At rep 24 should still be Unknown (1.0x budget)"
	)


func test_budget_just_below_reputable() -> void:
	_rep.add_reputation(TEST_STORE, -1.0)
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 1.2,
		"At rep 49 should still be Local Favorite (1.2x budget)"
	)


func test_budget_just_below_legendary() -> void:
	_rep.add_reputation(TEST_STORE, 29.0)
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 1.5,
		"At rep 79 should still be Destination Shop (1.5x budget)"
	)


# --- Tier enum matches at each boundary ---


func test_tier_at_rep_0_is_notorious() -> void:
	_rep.add_reputation(TEST_STORE, -50.0)
	assert_eq(
		_rep.get_tier(TEST_STORE),
		ReputationSystemSingleton.ReputationTier.NOTORIOUS,
		"Rep 0 should be Unknown tier"
	)


func test_tier_at_rep_25_is_unremarkable() -> void:
	_rep.add_reputation(TEST_STORE, -25.0)
	assert_eq(
		_rep.get_tier(TEST_STORE),
		ReputationSystemSingleton.ReputationTier.UNREMARKABLE,
		"Rep 25 should be Local Favorite tier"
	)


func test_tier_at_rep_50_is_reputable() -> void:
	assert_eq(
		_rep.get_tier(TEST_STORE),
		ReputationSystemSingleton.ReputationTier.REPUTABLE,
		"Rep 50 should be Destination Shop tier"
	)


func test_tier_at_rep_80_is_legendary() -> void:
	_rep.add_reputation(TEST_STORE, 30.0)
	assert_eq(
		_rep.get_tier(TEST_STORE),
		ReputationSystemSingleton.ReputationTier.LEGENDARY,
		"Rep 80 should be Legendary tier"
	)


# --- Budget multiplier increases monotonically with tier ---


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


# --- Max customers scale with tier ---


func test_max_customers_small_at_notorious() -> void:
	_rep.add_reputation(TEST_STORE, -50.0)
	assert_eq(
		_rep.get_max_customers("small", TEST_STORE), 5,
		"Unknown small store should allow 5 customers"
	)


func test_max_customers_small_at_legendary() -> void:
	_rep.add_reputation(TEST_STORE, 35.0)
	assert_eq(
		_rep.get_max_customers("small", TEST_STORE), 10,
		"Legendary small store should allow 10 customers"
	)


func test_max_customers_medium_at_notorious() -> void:
	_rep.add_reputation(TEST_STORE, -50.0)
	assert_eq(
		_rep.get_max_customers("medium", TEST_STORE), 8,
		"Unknown medium store should allow 8 customers"
	)


func test_max_customers_medium_at_legendary() -> void:
	_rep.add_reputation(TEST_STORE, 35.0)
	assert_eq(
		_rep.get_max_customers("medium", TEST_STORE), 15,
		"Legendary medium store should allow 15 customers"
	)
