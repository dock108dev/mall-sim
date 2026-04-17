## Tests diminishing rarity multiplier formula across all rarities and price points.
extends GutTest


var _economy: EconomySystem


func before_all() -> void:
	_seed_difficulty_config()


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()


func _create_item(
	base_price: float, rarity: String, category: String = "trading_cards"
) -> ItemInstance:
	var item_def := ItemDefinition.new()
	item_def.id = "test_%s_%s" % [rarity, str(base_price)]
	item_def.base_price = base_price
	item_def.rarity = rarity
	item_def.category = category
	item_def.tags = []
	return ItemInstance.create_from_definition(item_def, "good")


# --- Common rarity: always 1.0 regardless of price ---


func test_common_at_0_20() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(0.20, "common")
	assert_almost_eq(eff, 1.0, 0.001, "Common at $0.20 should be 1.0")


func test_common_at_10() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(10.0, "common")
	assert_almost_eq(eff, 1.0, 0.001, "Common at $10 should be 1.0")


func test_common_at_65() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(65.0, "common")
	assert_almost_eq(eff, 1.0, 0.001, "Common at $65 should be 1.0")


func test_common_at_300() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(300.0, "common")
	assert_almost_eq(eff, 1.0, 0.001, "Common at $300 should be 1.0")


# --- Uncommon rarity (raw 2.5): diminishes above reference price ---


func test_uncommon_at_0_20() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(0.20, "uncommon")
	assert_almost_eq(
		eff, 2.5, 0.001,
		"Uncommon at $0.20 (below ref) should get full 2.5x"
	)


func test_uncommon_at_10() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(10.0, "uncommon")
	var expected: float = 1.0 + (2.5 - 1.0) * (5.0 / 10.0)
	assert_almost_eq(
		eff, expected, 0.001,
		"Uncommon at $10 should be ~1.75"
	)


func test_uncommon_at_65() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(65.0, "uncommon")
	var expected: float = 1.0 + (2.5 - 1.0) * (5.0 / 65.0)
	assert_almost_eq(
		eff, expected, 0.001,
		"Uncommon at $65 should be ~1.115"
	)


func test_uncommon_at_300() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(300.0, "uncommon")
	var expected: float = 1.0 + (2.5 - 1.0) * (5.0 / 300.0)
	assert_almost_eq(
		eff, expected, 0.001,
		"Uncommon at $300 should be ~1.025"
	)


# --- Rare rarity (raw 6.0): full below ref, diminishes above ---


func test_rare_at_0_20() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(0.20, "rare")
	assert_almost_eq(
		eff, 6.0, 0.001,
		"Rare at $0.20 should get full 6.0x"
	)


func test_rare_at_10() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(10.0, "rare")
	var expected: float = 1.0 + (6.0 - 1.0) * (5.0 / 10.0)
	assert_almost_eq(
		eff, expected, 0.001,
		"Rare at $10 should be ~3.5"
	)


func test_rare_at_65() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(65.0, "rare")
	var expected: float = 1.0 + (6.0 - 1.0) * (5.0 / 65.0)
	assert_almost_eq(
		eff, expected, 0.001,
		"Rare at $65 should be ~1.385"
	)


func test_rare_at_300() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(300.0, "rare")
	var expected: float = 1.0 + (6.0 - 1.0) * (5.0 / 300.0)
	assert_almost_eq(
		eff, expected, 0.001,
		"Rare at $300 should be ~1.083"
	)


# --- Very rare rarity (raw 15.0): full below ref, heavy diminish above ---


func test_very_rare_at_0_20() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(0.20, "very_rare")
	assert_almost_eq(
		eff, 15.0, 0.001,
		"Very rare at $0.20 should get full 15.0x"
	)


func test_very_rare_at_10() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(10.0, "very_rare")
	var expected: float = 1.0 + (15.0 - 1.0) * (5.0 / 10.0)
	assert_almost_eq(
		eff, expected, 0.001,
		"Very rare at $10 should be ~8.0"
	)


func test_very_rare_at_65() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(65.0, "very_rare")
	var expected: float = 1.0 + (15.0 - 1.0) * (5.0 / 65.0)
	assert_almost_eq(
		eff, expected, 0.001,
		"Very rare at $65 should be ~2.077"
	)


func test_very_rare_at_300() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(300.0, "very_rare")
	var expected: float = 1.0 + (15.0 - 1.0) * (5.0 / 300.0)
	assert_almost_eq(
		eff, expected, 0.001,
		"Very rare at $300 should be ~1.233"
	)


# --- MAX_MARKET_VALUE cap enforcement ---


func test_max_market_value_constant() -> void:
	assert_eq(
		EconomySystem.MAX_MARKET_VALUE, 1000.0,
		"MAX_MARKET_VALUE should be 1000.0"
	)


func test_cap_enforced_for_extreme_legendary() -> void:
	var item: ItemInstance = _create_item(800.0, "legendary")
	var value: float = _economy.calculate_market_value(item)
	assert_lte(
		value, EconomySystem.MAX_MARKET_VALUE,
		"$800 legendary must not exceed MAX_MARKET_VALUE cap"
	)


func test_cap_enforced_for_mint_legendary() -> void:
	var item_def := ItemDefinition.new()
	item_def.id = "test_cap_mint"
	item_def.base_price = 500.0
	item_def.rarity = "legendary"
	item_def.category = "trading_cards"
	item_def.tags = []
	var item: ItemInstance = ItemInstance.create_from_definition(
		item_def, "mint"
	)
	var value: float = _economy.calculate_market_value(item)
	assert_lte(
		value, EconomySystem.MAX_MARKET_VALUE,
		"Mint legendary at $500 base must not exceed cap"
	)


func test_moderate_item_below_cap() -> void:
	var item: ItemInstance = _create_item(10.0, "rare")
	var value: float = _economy.calculate_market_value(item)
	assert_lt(
		value, EconomySystem.MAX_MARKET_VALUE,
		"$10 rare should be well below cap"
	)
	assert_gt(value, 0.0, "Value should be positive")


func _seed_difficulty_config() -> void:
	DifficultySystemSingleton._current_tier_id = &"normal"
	DifficultySystemSingleton._tiers = {
		&"normal": {
			"modifiers": {
				"starting_cash_multiplier": 1.0,
			},
		},
	}
