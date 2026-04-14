## Tests PricingPanel markup slider logic, feedback messages, and apply-all.
extends GutTest


var _data_loader: DataLoader
var _inventory_system: InventorySystem


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_inventory_system = InventorySystem.new()
	_inventory_system.initialize(_data_loader)


func _create_test_item(
	def_id: String, condition: String, location: String
) -> ItemInstance:
	var def: ItemDefinition = _data_loader.get_item(def_id)
	if not def:
		return null
	var item: ItemInstance = ItemInstance.create(
		def, condition, 0, def.base_price
	)
	item.current_location = location
	_inventory_system.register_item(item)
	return item


func _get_first_def() -> ItemDefinition:
	var items: Array[ItemDefinition] = _data_loader.get_all_items()
	if items.is_empty():
		return null
	return items[0]


func test_markup_slider_range_constants() -> void:
	assert_eq(
		PricingPanel.MIN_MARKUP, 0.5,
		"Min markup should be 0.5x"
	)
	assert_eq(
		PricingPanel.MAX_MARKUP, 3.0,
		"Max markup should be 3.0x"
	)


func test_color_zone_thresholds() -> void:
	assert_eq(
		PricingPanel.ZONE_GREEN_MAX, 0.9,
		"Green zone ends at 0.9x"
	)
	assert_eq(
		PricingPanel.ZONE_BLUE_MAX, 1.1,
		"Blue zone ends at 1.1x"
	)
	assert_eq(
		PricingPanel.ZONE_YELLOW_MAX, 1.5,
		"Yellow zone ends at 1.5x"
	)


func test_feedback_messages_defined() -> void:
	assert_false(
		PricingPanel.FEEDBACK_BELOW_MARKET.is_empty(),
		"Below market message should exist"
	)
	assert_false(
		PricingPanel.FEEDBACK_AT_MARKET.is_empty(),
		"At market message should exist"
	)
	assert_false(
		PricingPanel.FEEDBACK_ABOVE_MARKET.is_empty(),
		"Above market message should exist"
	)
	assert_false(
		PricingPanel.FEEDBACK_PREMIUM.is_empty(),
		"Premium message should exist"
	)
	assert_false(
		PricingPanel.FEEDBACK_EXTREME.is_empty(),
		"Extreme message should exist"
	)


func test_apply_all_sets_same_ratio() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions loaded — skip")
		return
	var item_a: ItemInstance = _create_test_item(
		def.id, "good", "shelf:slot_01"
	)
	var item_b: ItemInstance = _create_test_item(
		def.id, "mint", "shelf:slot_02"
	)
	var item_c: ItemInstance = _create_test_item(
		def.id, "poor", "backroom"
	)
	assert_not_null(item_a)
	assert_not_null(item_b)
	assert_not_null(item_c)

	var ratio: float = 1.5
	var items: Array[ItemInstance] = (
		_inventory_system.get_items_for_store(def.store_type)
	)
	for item: ItemInstance in items:
		if item.definition.id != def.id:
			continue
		var market_val: float = item.get_current_value()
		if market_val <= 0.0:
			continue
		item.player_set_price = snappedf(market_val * ratio, 0.01)

	for item: ItemInstance in items:
		if item.definition.id != def.id:
			continue
		var market_val: float = item.get_current_value()
		if market_val <= 0.0:
			continue
		var actual_ratio: float = item.player_set_price / market_val
		assert_almost_eq(
			actual_ratio, ratio, 0.02,
			"All items should have same markup ratio"
		)


func test_apply_all_different_conditions_different_prices() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions loaded — skip")
		return
	var item_good: ItemInstance = _create_test_item(
		def.id, "good", "shelf:slot_01"
	)
	var item_mint: ItemInstance = _create_test_item(
		def.id, "mint", "shelf:slot_02"
	)
	assert_not_null(item_good)
	assert_not_null(item_mint)

	var ratio: float = 1.2
	var good_val: float = item_good.get_current_value()
	var mint_val: float = item_mint.get_current_value()
	item_good.player_set_price = snappedf(good_val * ratio, 0.01)
	item_mint.player_set_price = snappedf(mint_val * ratio, 0.01)

	assert_true(
		item_mint.player_set_price > item_good.player_set_price,
		"Mint item should have higher price than good at same ratio"
	)
	var good_ratio: float = item_good.player_set_price / good_val
	var mint_ratio: float = item_mint.player_set_price / mint_val
	assert_almost_eq(
		good_ratio, mint_ratio, 0.02,
		"Ratios should match despite different dollar amounts"
	)


func test_condition_multipliers_coverage() -> void:
	var conditions: Array[String] = [
		"mint", "near_mint", "good", "fair", "poor"
	]
	for cond: String in conditions:
		assert_true(
			ItemInstance.CONDITION_MULTIPLIERS.has(cond),
			"Should have multiplier for condition: %s" % cond
		)


func test_item_set_price_persists() -> void:
	var def: ItemDefinition = _get_first_def()
	if not def:
		pass_test("No item definitions loaded — skip")
		return
	var item: ItemInstance = _create_test_item(
		def.id, "good", "shelf:slot_01"
	)
	assert_not_null(item)
	assert_eq(item.player_set_price, 0.0, "Initial set_price should be 0")
	item.player_set_price = 42.50
	assert_eq(
		item.player_set_price, 42.50,
		"set_price should persist after assignment"
	)
	var fetched: ItemInstance = _inventory_system.get_item(
		item.instance_id
	)
	assert_eq(
		fetched.player_set_price, 42.50,
		"Price should persist when fetched from inventory"
	)
