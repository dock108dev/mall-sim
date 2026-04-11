## Tests diminishing rarity multiplier and market value cap.
extends GutTest


var _economy: EconomySystem


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
	item_def.tags = PackedStringArray()
	return ItemInstance.create_from_definition(item_def, "good")


# --- calculate_effective_rarity tests ---


func test_cheap_common_card_unchanged() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(0.20, "common")
	assert_almost_eq(eff, 1.0, 0.001, "Common rarity should always be 1.0")


func test_cheap_rare_card_gets_full_scaling() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(0.20, "rare")
	var raw: float = ItemInstance.RARITY_MULTIPLIERS["rare"]
	assert_almost_eq(
		eff, raw, 0.001,
		"$0.20 item should get full rare multiplier (below reference price)"
	)


func test_at_reference_price_gets_full_scaling() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(5.0, "rare")
	var raw: float = ItemInstance.RARITY_MULTIPLIERS["rare"]
	assert_almost_eq(
		eff, raw, 0.001,
		"Item at reference price should get full rarity multiplier"
	)


func test_expensive_very_rare_cartridge_diminished() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(65.0, "very_rare")
	var expected: float = 1.0 + (15.0 - 1.0) * (5.0 / 65.0)
	assert_almost_eq(
		eff, expected, 0.001,
		"$65 very_rare should get diminished rarity"
	)
	assert_lt(eff, 3.0, "$65 very_rare effective rarity should be well below raw 15x")


func test_expensive_very_rare_baseball_diminished() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(300.0, "very_rare")
	var expected: float = 1.0 + (15.0 - 1.0) * (5.0 / 300.0)
	assert_almost_eq(
		eff, expected, 0.001,
		"$300 very_rare should get heavily diminished rarity"
	)


func test_rarity_1_or_below_bypasses_formula() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(100.0, "common")
	assert_almost_eq(eff, 1.0, 0.001, "Common should always return 1.0")


func test_unknown_rarity_returns_one() -> void:
	var eff: float = ItemInstance.calculate_effective_rarity(10.0, "nonexistent")
	assert_almost_eq(eff, 1.0, 0.001, "Unknown rarity should default to 1.0")


# --- Market value acceptance criteria ---


func test_cheap_common_card_market_value_unchanged() -> void:
	var item: ItemInstance = _create_item(0.20, "rare")
	var value: float = _economy.calculate_market_value(item)
	var expected: float = 0.20 * 6.0
	assert_almost_eq(
		value, expected, 0.01,
		"$0.20 rare card should still get normal rarity scaling"
	)


func test_65_dollar_very_rare_cartridge() -> void:
	var item: ItemInstance = _create_item(65.0, "very_rare")
	var value: float = _economy.calculate_market_value(item)
	var eff_rarity: float = 1.0 + (15.0 - 1.0) * (5.0 / 65.0)
	var expected: float = 65.0 * eff_rarity
	assert_almost_eq(
		value, expected, 1.0,
		"$65 very_rare cartridge should be ~$135, not $975"
	)
	assert_lt(value, 200.0, "Must be sellable, not $975")


func test_300_dollar_very_rare_baseball() -> void:
	var item: ItemInstance = _create_item(300.0, "very_rare")
	var value: float = _economy.calculate_market_value(item)
	var eff_rarity: float = 1.0 + (15.0 - 1.0) * (5.0 / 300.0)
	var expected: float = 300.0 * eff_rarity
	assert_almost_eq(
		value, expected, 1.0,
		"$300 very_rare baseball should be ~$369, not $4500"
	)
	assert_lt(value, 500.0, "Must be within customer budget range")


# --- MAX_MARKET_VALUE cap ---


func test_market_value_cap_applied() -> void:
	assert_eq(
		EconomySystem.MAX_MARKET_VALUE, 1000.0,
		"MAX_MARKET_VALUE constant should be 1000.0"
	)


func test_market_value_never_exceeds_cap() -> void:
	var item: ItemInstance = _create_item(800.0, "legendary")
	var value: float = _economy.calculate_market_value(item)
	assert_lte(
		value, EconomySystem.MAX_MARKET_VALUE,
		"Market value must not exceed MAX_MARKET_VALUE"
	)


func test_fake_item_still_returns_low_value() -> void:
	var item: ItemInstance = _create_item(300.0, "very_rare")
	item.authentication_status = "fake"
	var value: float = _economy.calculate_market_value(item)
	assert_almost_eq(value, 0.50, 0.01, "Fake items should still be $0.50")


# --- get_current_value uses diminishing rarity too ---


func test_get_current_value_uses_diminishing_rarity() -> void:
	var item: ItemInstance = _create_item(65.0, "very_rare")
	var value: float = item.get_current_value()
	assert_lt(
		value, 975.0,
		"get_current_value should use diminishing rarity, not raw"
	)
	var eff_rarity: float = ItemInstance.calculate_effective_rarity(
		65.0, "very_rare"
	)
	var expected: float = 65.0 * 1.0 * eff_rarity
	assert_almost_eq(value, expected, 0.01)
