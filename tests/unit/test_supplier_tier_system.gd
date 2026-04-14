## GUT unit tests for SupplierTierSystem tier unlock conditions, catalog availability, and order eligibility.
extends GutTest


# --- Default tier ---


func test_default_tier_is_one() -> void:
	var tier: int = SupplierTierSystem.get_tier_for_reputation(0.0)
	assert_eq(
		tier, 1,
		"Fresh reputation (0.0) should resolve to tier 1"
	)


# --- Tier advancement at conditions ---


func test_tier_two_unlocks_at_condition() -> void:
	var threshold: float = SupplierTierSystem.TIERS[2]["rep_threshold"]
	var tier_below: int = SupplierTierSystem.get_tier_for_reputation(
		threshold - 0.1
	)
	var tier_at: int = SupplierTierSystem.get_tier_for_reputation(threshold)
	assert_eq(
		tier_below, 1,
		"Below tier 2 threshold (%.1f) should stay tier 1" % threshold
	)
	assert_eq(
		tier_at, 2,
		"At tier 2 threshold (%.1f) should advance to tier 2" % threshold
	)


func test_tier_three_unlocks_at_condition() -> void:
	var threshold: float = SupplierTierSystem.TIERS[3]["rep_threshold"]
	var tier_below: int = SupplierTierSystem.get_tier_for_reputation(
		threshold - 0.1
	)
	var tier_at: int = SupplierTierSystem.get_tier_for_reputation(threshold)
	assert_eq(
		tier_below, 2,
		"Below tier 3 threshold (%.1f) should stay tier 2" % threshold
	)
	assert_eq(
		tier_at, 3,
		"At tier 3 threshold (%.1f) should advance to tier 3" % threshold
	)


# --- Tier-1 items always available ---


func test_tier_one_items_always_available() -> void:
	var tier_1_rarities: Array = SupplierTierSystem.TIERS[1]["rarities"]
	for tier: int in [1, 2, 3]:
		for rarity: String in tier_1_rarities:
			assert_true(
				SupplierTierSystem.is_rarity_available(rarity, tier),
				"Tier-1 rarity '%s' should be available at tier %d"
				% [rarity, tier]
			)


# --- High-tier items locked at lower tiers ---


func test_tier_three_items_locked_at_tier_one() -> void:
	assert_false(
		SupplierTierSystem.is_rarity_available("very_rare", 1),
		"very_rare should not be available at tier 1"
	)
	assert_false(
		SupplierTierSystem.is_rarity_available("rare", 1),
		"rare should not be available at tier 1"
	)


func test_tier_three_items_locked_at_tier_two() -> void:
	assert_false(
		SupplierTierSystem.is_rarity_available("very_rare", 2),
		"very_rare should not be available at tier 2"
	)


# --- Signal fires on tier change ---


func test_tier_unlocked_signal_fires() -> void:
	watch_signals(EventBus)
	EventBus.supplier_tier_changed.emit(1, 2)
	assert_signal_emitted(
		EventBus, "supplier_tier_changed",
		"supplier_tier_changed should be emittable on tier advancement"
	)
	var params: Array = get_signal_parameters(
		EventBus, "supplier_tier_changed"
	)
	assert_eq(
		params[0] as int, 1,
		"Old tier parameter should be 1"
	)
	assert_eq(
		params[1] as int, 2,
		"New tier parameter should be 2"
	)


# --- Save/load preserves tier (via reputation round-trip) ---


func test_save_load_preserves_tier() -> void:
	var rep_tier_2: float = SupplierTierSystem.TIERS[2]["rep_threshold"]
	var tier_before: int = SupplierTierSystem.get_tier_for_reputation(
		rep_tier_2
	)
	assert_eq(tier_before, 2, "Should be tier 2 before save")

	var save_data: Dictionary = {"reputation": rep_tier_2}
	var loaded_rep: float = save_data["reputation"]
	var tier_after: int = SupplierTierSystem.get_tier_for_reputation(
		loaded_rep
	)
	assert_eq(
		tier_after, 2,
		"Tier should remain 2 after save/load round-trip"
	)
	assert_eq(
		tier_before, tier_after,
		"Tier before save must equal tier after load"
	)
