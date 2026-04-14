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
		_rep.get_budget_multiplier(TEST_STORE), 1.0,
		"At default rep 50 (Unremarkable) budget multiplier should be 1.0"
	)


func test_budget_multiplier_at_notorious() -> void:
	_rep.add_reputation(TEST_STORE, -50.0)
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 0.8,
		"At rep 0 (Notorious) budget multiplier should be 0.8"
	)


func test_budget_multiplier_at_reputable() -> void:
	_rep.add_reputation(TEST_STORE, 10.0)
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 1.3,
		"At rep 60 (Reputable) budget multiplier should be 1.3"
	)


func test_budget_multiplier_at_legendary() -> void:
	_rep.add_reputation(TEST_STORE, 35.0)
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 2.0,
		"At rep 85 (Legendary) budget multiplier should be 2.0"
	)


# --- Just below each boundary stays in lower tier ---


func test_budget_just_below_unremarkable() -> void:
	_rep.add_reputation(TEST_STORE, -25.0)
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 0.8,
		"At rep 25 should still be Notorious (0.8x budget)"
	)


func test_budget_just_below_reputable() -> void:
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 1.0,
		"At rep 50 should still be Unremarkable (1.0x budget)"
	)


func test_budget_just_below_legendary() -> void:
	_rep.add_reputation(TEST_STORE, 25.0)
	assert_eq(
		_rep.get_budget_multiplier(TEST_STORE), 1.3,
		"At rep 75 should still be Reputable (1.3x budget)"
	)


# --- Tier enum matches at each boundary ---


func test_tier_at_rep_0_is_notorious() -> void:
	_rep.add_reputation(TEST_STORE, -50.0)
	assert_eq(
		_rep.get_tier(TEST_STORE),
		ReputationSystem.ReputationTier.NOTORIOUS,
		"Rep 0 should be Notorious tier"
	)


func test_tier_at_rep_26_is_unremarkable() -> void:
	_rep.add_reputation(TEST_STORE, -24.0)
	assert_eq(
		_rep.get_tier(TEST_STORE),
		ReputationSystem.ReputationTier.UNREMARKABLE,
		"Rep 26 should be Unremarkable tier"
	)


func test_tier_at_rep_51_is_reputable() -> void:
	_rep.add_reputation(TEST_STORE, 1.0)
	assert_eq(
		_rep.get_tier(TEST_STORE),
		ReputationSystem.ReputationTier.REPUTABLE,
		"Rep 51 should be Reputable tier"
	)


func test_tier_at_rep_76_is_legendary() -> void:
	_rep.add_reputation(TEST_STORE, 26.0)
	assert_eq(
		_rep.get_tier(TEST_STORE),
		ReputationSystem.ReputationTier.LEGENDARY,
		"Rep 76 should be Legendary tier"
	)


# --- Budget multiplier increases monotonically with tier ---


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


# --- Max customers scale with tier ---


func test_max_customers_small_at_notorious() -> void:
	_rep.add_reputation(TEST_STORE, -50.0)
	assert_eq(
		_rep.get_max_customers("small", TEST_STORE), 3,
		"Notorious small store should allow 3 customers"
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
		_rep.get_max_customers("medium", TEST_STORE), 5,
		"Notorious medium store should allow 5 customers"
	)


func test_max_customers_medium_at_legendary() -> void:
	_rep.add_reputation(TEST_STORE, 35.0)
	assert_eq(
		_rep.get_max_customers("medium", TEST_STORE), 15,
		"Legendary medium store should allow 15 customers"
	)
