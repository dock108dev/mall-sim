## Tests supplier tier wholesale rates yield better margins at higher tiers.
extends GutTest


# --- Wholesale rate ordering: higher tiers get lower wholesale (better margin) ---


func test_tier_3_wholesale_less_than_tier_2() -> void:
	var t2: Dictionary = SupplierTierSystem.get_config(2)
	var t3: Dictionary = SupplierTierSystem.get_config(3)
	assert_lt(
		t3["wholesale"], t2["wholesale"],
		"Tier 3 wholesale (%.2f) should be lower than Tier 2 (%.2f)"
		% [t3["wholesale"], t2["wholesale"]]
	)


func test_tier_2_wholesale_less_than_tier_1() -> void:
	var t1: Dictionary = SupplierTierSystem.get_config(1)
	var t2: Dictionary = SupplierTierSystem.get_config(2)
	assert_lt(
		t2["wholesale"], t1["wholesale"],
		"Tier 2 wholesale (%.2f) should be lower than Tier 1 (%.2f)"
		% [t2["wholesale"], t1["wholesale"]]
	)


func test_tier_3_margin_greater_than_tier_2() -> void:
	var t2_ws: float = SupplierTierSystem.get_config(2)["wholesale"]
	var t3_ws: float = SupplierTierSystem.get_config(3)["wholesale"]
	var t2_margin: float = 1.0 - t2_ws
	var t3_margin: float = 1.0 - t3_ws
	assert_gt(
		t3_margin, t2_margin,
		"Tier 3 margin (%.0f%%) should exceed Tier 2 (%.0f%%)"
		% [t3_margin * 100.0, t2_margin * 100.0]
	)


func test_tier_2_margin_greater_than_tier_1() -> void:
	var t1_ws: float = SupplierTierSystem.get_config(1)["wholesale"]
	var t2_ws: float = SupplierTierSystem.get_config(2)["wholesale"]
	var t1_margin: float = 1.0 - t1_ws
	var t2_margin: float = 1.0 - t2_ws
	assert_gt(
		t2_margin, t1_margin,
		"Tier 2 margin (%.0f%%) should exceed Tier 1 (%.0f%%)"
		% [t2_margin * 100.0, t1_margin * 100.0]
	)


# --- Concrete wholesale values per balance spec ---


func test_tier_1_wholesale_is_0_75() -> void:
	assert_eq(
		SupplierTierSystem.get_config(1)["wholesale"], 0.75,
		"Tier 1 wholesale should be 0.75"
	)


func test_tier_2_wholesale_is_0_65() -> void:
	assert_eq(
		SupplierTierSystem.get_config(2)["wholesale"], 0.65,
		"Tier 2 wholesale should be 0.65"
	)


func test_tier_3_wholesale_is_0_55() -> void:
	assert_eq(
		SupplierTierSystem.get_config(3)["wholesale"], 0.55,
		"Tier 3 wholesale should be 0.55"
	)


# --- Same item yields progressively better margins across tiers ---


func test_same_item_margin_progression() -> void:
	var base_price: float = 20.0
	var t1_cost: float = base_price * SupplierTierSystem.get_config(1)["wholesale"]
	var t2_cost: float = base_price * SupplierTierSystem.get_config(2)["wholesale"]
	var t3_cost: float = base_price * SupplierTierSystem.get_config(3)["wholesale"]
	var t1_profit: float = base_price - t1_cost
	var t2_profit: float = base_price - t2_cost
	var t3_profit: float = base_price - t3_cost
	assert_gt(
		t3_profit, t2_profit,
		"$20 item: Tier 3 profit ($%.2f) > Tier 2 ($%.2f)"
		% [t3_profit, t2_profit]
	)
	assert_gt(
		t2_profit, t1_profit,
		"$20 item: Tier 2 profit ($%.2f) > Tier 1 ($%.2f)"
		% [t2_profit, t1_profit]
	)


# --- Reputation thresholds for tier access ---


func test_tier_1_requires_zero_reputation() -> void:
	assert_eq(
		SupplierTierSystem.get_config(1)["rep_threshold"], 0.0,
		"Tier 1 should require 0 reputation"
	)


func test_tier_2_requires_25_reputation() -> void:
	assert_eq(
		SupplierTierSystem.get_config(2)["rep_threshold"], 25.0,
		"Tier 2 should require 25 reputation"
	)


func test_tier_3_requires_50_reputation() -> void:
	assert_eq(
		SupplierTierSystem.get_config(3)["rep_threshold"], 50.0,
		"Tier 3 should require 50 reputation"
	)


# --- Tier resolution from reputation ---


func test_zero_rep_gets_tier_1() -> void:
	assert_eq(
		SupplierTierSystem.get_tier_for_reputation(0.0), 1,
		"0 reputation should resolve to Tier 1"
	)


func test_25_rep_gets_tier_2() -> void:
	assert_eq(
		SupplierTierSystem.get_tier_for_reputation(25.0), 2,
		"25 reputation should resolve to Tier 2"
	)


func test_50_rep_gets_tier_3() -> void:
	assert_eq(
		SupplierTierSystem.get_tier_for_reputation(50.0), 3,
		"50 reputation should resolve to Tier 3"
	)


func test_24_rep_stays_tier_1() -> void:
	assert_eq(
		SupplierTierSystem.get_tier_for_reputation(24.9), 1,
		"24.9 reputation should still be Tier 1"
	)


# --- Rarity access expands with tier ---


func test_tier_1_has_common_and_uncommon() -> void:
	assert_true(
		SupplierTierSystem.is_rarity_available("common", 1),
		"Tier 1 should have common"
	)
	assert_true(
		SupplierTierSystem.is_rarity_available("uncommon", 1),
		"Tier 1 should have uncommon"
	)
	assert_false(
		SupplierTierSystem.is_rarity_available("rare", 1),
		"Tier 1 should not have rare"
	)


func test_tier_2_adds_rare() -> void:
	assert_true(
		SupplierTierSystem.is_rarity_available("rare", 2),
		"Tier 2 should have rare"
	)
	assert_false(
		SupplierTierSystem.is_rarity_available("very_rare", 2),
		"Tier 2 should not have very_rare"
	)


func test_tier_3_adds_very_rare() -> void:
	assert_true(
		SupplierTierSystem.is_rarity_available("very_rare", 3),
		"Tier 3 should have very_rare"
	)
