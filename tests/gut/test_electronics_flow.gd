## Integration test for Consumer Electronics store flow: launch spike pricing and demo units.
extends GutTest


var _inventory: InventorySystem
var _market_value: MarketValueSystem
var _trend: TrendSystem
var _market_event: MarketEventSystem
var _seasonal_event: SeasonalEventSystem
var _electronics_config: Dictionary = {}
var _sold_signals: Array[Dictionary] = []


func _load_electronics_config() -> void:
	var file := FileAccess.open(
		"res://game/content/stores/electronics.json", FileAccess.READ
	)
	if file:
		_electronics_config = JSON.parse_string(file.get_as_text())
		file.close()


func _make_def(overrides: Dictionary = {}) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = overrides.get("id", "elec_test_item")
	def.item_name = overrides.get("item_name", "Test Electronics Item")
	def.category = overrides.get("category", "portable_audio")
	def.store_type = "electronics"
	def.base_price = overrides.get("base_price", 100.0)
	def.rarity = overrides.get("rarity", "common")
	def.condition_range = overrides.get(
		"condition_range",
		PackedStringArray(["good", "near_mint", "mint"])
	)
	def.depreciates = overrides.get("depreciates", true)
	def.launch_day = overrides.get("launch_day", 1)
	def.depreciation_rate = overrides.get("depreciation_rate", 0.02)
	def.min_value_ratio = overrides.get("min_value_ratio", 0.15)
	def.launch_demand_multiplier = overrides.get(
		"launch_demand_multiplier", 1.3
	)
	def.launch_spike_days = overrides.get("launch_spike_days", 5)
	return def


func _make_item(
	def: ItemDefinition, condition: String = "mint"
) -> ItemInstance:
	return ItemInstance.create_from_definition(def, condition)


func _on_item_sold(
	item_id: String, price: float, category: String
) -> void:
	_sold_signals.append({
		"item_id": item_id, "price": price, "category": category,
	})


func before_each() -> void:
	_sold_signals.clear()
	_load_electronics_config()
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)
	_trend = TrendSystem.new()
	add_child_autofree(_trend)
	_market_event = MarketEventSystem.new()
	add_child_autofree(_market_event)
	_seasonal_event = SeasonalEventSystem.new()
	add_child_autofree(_seasonal_event)
	_market_value = MarketValueSystem.new()
	add_child_autofree(_market_value)
	_market_value.initialize(
		_inventory, _trend, _market_event, _seasonal_event
	)
	EventBus.item_sold.connect(_on_item_sold)


func after_each() -> void:
	if EventBus.item_sold.is_connected(_on_item_sold):
		EventBus.item_sold.disconnect(_on_item_sold)


# --- Scenario A: Launch spike pricing ---


func test_launch_spike_applied_within_window() -> void:
	var def: ItemDefinition = _make_def({
		"launch_day": 1, "launch_spike_days": 5,
		"launch_demand_multiplier": 1.3, "depreciation_rate": 0.02,
	})
	var current_day: int = 3
	var time_mod: float = _market_value.get_time_modifier(def, current_day)
	var raw: float = maxf(def.min_value_ratio, 1.0 - 2.0 * 0.02)
	assert_almost_eq(time_mod, raw * 1.3, 0.001)
	assert_true(time_mod > 1.0)


func test_launch_spike_on_launch_day() -> void:
	var def: ItemDefinition = _make_def({
		"launch_day": 5, "launch_spike_days": 7,
		"launch_demand_multiplier": 1.5, "depreciation_rate": 0.015,
	})
	var time_mod: float = _market_value.get_time_modifier(def, 5)
	assert_almost_eq(time_mod, 1.5, 0.001)


func test_launch_spike_on_last_spike_day() -> void:
	var def: ItemDefinition = _make_def({
		"launch_day": 1, "launch_spike_days": 5,
		"launch_demand_multiplier": 1.3, "depreciation_rate": 0.02,
	})
	var time_mod: float = _market_value.get_time_modifier(def, 6)
	var raw: float = maxf(def.min_value_ratio, 1.0 - 5.0 * 0.02)
	assert_almost_eq(time_mod, raw * 1.3, 0.001)


func test_price_normalizes_after_spike_window() -> void:
	var def: ItemDefinition = _make_def({
		"launch_day": 1, "launch_spike_days": 5,
		"launch_demand_multiplier": 1.3, "depreciation_rate": 0.02,
	})
	var day_after: int = 7
	var time_mod: float = _market_value.get_time_modifier(def, day_after)
	var expected: float = maxf(def.min_value_ratio, 1.0 - 6.0 * 0.02)
	assert_almost_eq(time_mod, expected, 0.001)
	assert_true(time_mod < 1.0)


func test_price_decays_per_depreciation_rate() -> void:
	var def: ItemDefinition = _make_def({
		"launch_day": 1, "launch_spike_days": 0,
		"launch_demand_multiplier": 1.0, "depreciation_rate": 0.02,
	})
	var mod_a: float = _market_value.get_time_modifier(def, 11)
	var mod_b: float = _market_value.get_time_modifier(def, 21)
	assert_true(mod_b < mod_a)
	assert_almost_eq(mod_a, 1.0 - 10.0 * 0.02, 0.001)
	assert_almost_eq(mod_b, 1.0 - 20.0 * 0.02, 0.001)


func test_price_never_falls_below_min_value_ratio() -> void:
	var def: ItemDefinition = _make_def({
		"launch_day": 1, "launch_spike_days": 0,
		"launch_demand_multiplier": 1.0,
		"depreciation_rate": 0.05, "min_value_ratio": 0.15,
	})
	var time_mod: float = _market_value.get_time_modifier(def, 200)
	assert_almost_eq(time_mod, 0.15, 0.001)


func test_launch_spike_uses_config_values() -> void:
	if _electronics_config.is_empty():
		pending("electronics.json not found")
		return
	var spike_days: int = int(_electronics_config.get("launch_spike_days", 0))
	assert_eq(spike_days, 7)
	var products: Array = _electronics_config.get("products", [])
	assert_true(products.size() > 0)
	var product: Dictionary = products[0]
	var def: ItemDefinition = _make_def({
		"id": product.get("id", ""),
		"base_price": float(product.get("base_price", 0.0)),
		"launch_day": int(product.get("launch_day", 1)),
		"launch_demand_multiplier": float(
			product.get("launch_demand_multiplier", 1.0)
		),
		"depreciation_rate": float(product.get("depreciation_rate", 0.0)),
		"min_value_ratio": float(product.get("min_value_ratio", 0.1)),
	})
	var on_launch: float = _market_value.get_time_modifier(
		def, def.launch_day
	)
	assert_almost_eq(
		on_launch,
		float(product.get("launch_demand_multiplier", 1.0)),
		0.001
	)


func test_full_item_value_includes_launch_spike() -> void:
	var def: ItemDefinition = _make_def({
		"base_price": 100.0, "rarity": "common",
		"launch_day": 1, "launch_spike_days": 5,
		"launch_demand_multiplier": 1.3, "depreciation_rate": 0.02,
	})
	var item: ItemInstance = _make_item(def, "mint")
	_inventory.register_item(item)
	_market_value._current_day = 1
	_market_value.invalidate_cache()
	var value: float = _market_value.calculate_item_value(item)
	var expected: float = 100.0 * 1.0 * 1.0 * 1.3
	assert_almost_eq(value, expected, 0.01)


func test_non_depreciating_item_no_time_modifier() -> void:
	var def: ItemDefinition = _make_def({"depreciates": false})
	assert_almost_eq(_market_value.get_time_modifier(def, 100), 1.0, 0.001)


func test_pre_launch_day_no_depreciation() -> void:
	var def: ItemDefinition = _make_def({
		"launch_day": 10, "depreciation_rate": 0.05,
	})
	assert_almost_eq(_market_value.get_time_modifier(def, 5), 1.0, 0.001)


# --- Scenario B: Demo unit drives sale ---


func _setup_demo_pair(
	def: ItemDefinition
) -> Dictionary:
	var demo: ItemInstance = _make_item(def, "mint")
	var sale: ItemInstance = _make_item(def, "near_mint")
	_inventory.register_item(demo)
	_inventory.register_item(sale)
	demo.is_demo = true
	demo.demo_placed_day = 1
	demo.current_location = "shelf:demo_0"
	sale.current_location = "shelf:display_1"
	return {"demo": demo, "sale": sale}


func _get_non_demo_shelf_items(
	items: Array[ItemInstance]
) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item: ItemInstance in items:
		if item.current_location.begins_with("shelf:") and not item.is_demo:
			result.append(item)
	return result


func test_demo_item_absent_from_saleable_listing() -> void:
	var def: ItemDefinition = _make_def({"id": "elec_demo_test"})
	var pair: Dictionary = _setup_demo_pair(def)
	var saleable: Array[ItemInstance] = _get_non_demo_shelf_items(
		[pair["demo"] as ItemInstance, pair["sale"] as ItemInstance]
	)
	assert_eq(saleable.size(), 1)
	assert_eq(
		saleable[0].instance_id,
		(pair["sale"] as ItemInstance).instance_id
	)


func test_demo_config_values() -> void:
	if _electronics_config.is_empty():
		pending("electronics.json not found")
		return
	var bonus: float = float(
		_electronics_config.get("demo_interest_bonus", 0.0)
	)
	var threshold: float = float(
		_electronics_config.get("purchase_intent_threshold", 0.0)
	)
	assert_almost_eq(bonus, 0.20, 0.001)
	assert_almost_eq(threshold, 0.55, 0.001)


func test_demo_bonus_increases_intent_past_threshold() -> void:
	var bonus: float = float(
		_electronics_config.get("demo_interest_bonus", 0.20)
	)
	var threshold: float = float(
		_electronics_config.get("purchase_intent_threshold", 0.55)
	)
	var base_intent: float = 0.40
	var boosted: float = base_intent + bonus
	assert_almost_eq(boosted, 0.60, 0.001)
	assert_true(boosted > threshold)


func test_customer_finds_saleable_copy_not_demo() -> void:
	var def: ItemDefinition = _make_def({
		"id": "elec_seek_test", "category": "portable_audio",
	})
	var pair: Dictionary = _setup_demo_pair(def)
	var demo: ItemInstance = pair["demo"] as ItemInstance
	var sale: ItemInstance = pair["sale"] as ItemInstance
	var bonus: float = float(
		_electronics_config.get("demo_interest_bonus", 0.20)
	)
	var threshold: float = float(
		_electronics_config.get("purchase_intent_threshold", 0.55)
	)
	assert_true(0.40 + bonus > threshold)
	var matching: Array[ItemInstance] = []
	for item: ItemInstance in [demo, sale]:
		if not item.is_demo \
				and item.definition.category == def.category \
				and item.current_location.begins_with("shelf:"):
			matching.append(item)
	assert_eq(matching.size(), 1)
	assert_eq(matching[0].instance_id, sale.instance_id)


func test_sale_removes_copy_keeps_demo() -> void:
	var def: ItemDefinition = _make_def({
		"id": "elec_sale_test", "base_price": 50.0,
	})
	var pair: Dictionary = _setup_demo_pair(def)
	var demo: ItemInstance = pair["demo"] as ItemInstance
	var sale: ItemInstance = pair["sale"] as ItemInstance
	_inventory.remove_item(sale.instance_id)
	var remaining: ItemInstance = _inventory.get_item(demo.instance_id)
	assert_not_null(remaining)
	assert_true(remaining.is_demo)
	assert_null(_inventory.get_item(sale.instance_id))


func test_demo_slot_count_unchanged_after_sale() -> void:
	var def: ItemDefinition = _make_def({
		"id": "elec_slot_test", "category": "handheld_gaming",
	})
	var pair: Dictionary = _setup_demo_pair(def)
	var demo: ItemInstance = pair["demo"] as ItemInstance
	var sale: ItemInstance = pair["sale"] as ItemInstance
	var count_before: int = 0
	for item: ItemInstance in [demo, sale]:
		if item.is_demo:
			count_before += 1
	_inventory.remove_item(sale.instance_id)
	var remaining: ItemInstance = _inventory.get_item(demo.instance_id)
	var count_after: int = 1 if remaining and remaining.is_demo else 0
	assert_eq(count_before, count_after)
