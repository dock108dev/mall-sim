## Tests for MarketValueSystem: value calculation, caching, and cache invalidation.
extends GutTest


var _system: MarketValueSystem
var _inventory: InventorySystem
var _market_event: MarketEventSystem
var _seasonal_event: SeasonalEventSystem


func _create_item_def(overrides: Dictionary = {}) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = overrides.get("id", "test_item")
	def.item_name = overrides.get("name", "Test Item")
	def.base_price = overrides.get("base_price", 10.0)
	def.rarity = overrides.get("rarity", "common")
	def.category = overrides.get("category", "trading_cards")
	def.tags = overrides.get("tags", PackedStringArray())
	def.store_type = overrides.get("store_type", "retro_games")
	return def


func _create_item(
	overrides: Dictionary = {},
	condition: String = "good",
) -> ItemInstance:
	var def: ItemDefinition = _create_item_def(overrides)
	return ItemInstance.create_from_definition(def, condition)


func before_all() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)

	_market_event = MarketEventSystem.new()
	add_child_autofree(_market_event)

	_seasonal_event = SeasonalEventSystem.new()
	add_child_autofree(_seasonal_event)

	_system = MarketValueSystem.new()
	add_child_autofree(_system)
	_system.initialize(
		_inventory, _market_event, _seasonal_event
	)


func test_base_value_common_good() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common"}, "good"
	)
	var value: float = _system.calculate_item_value(item)
	var expected: float = 10.0 * 1.0 * 0.75
	assert_almost_eq(value, expected, 0.001)


func test_base_value_rare_mint() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 20.0, "rarity": "rare"}, "mint"
	)
	var value: float = _system.calculate_item_value(item)
	var expected: float = 20.0 * 1.8 * 1.0
	assert_almost_eq(value, expected, 0.001)


func test_base_value_legendary_poor() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 50.0, "rarity": "legendary"}, "poor"
	)
	var value: float = _system.calculate_item_value(item)
	var expected: float = 50.0 * 4.0 * 0.3
	assert_almost_eq(value, expected, 0.001)


func test_base_value_uncommon_fair() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 15.0, "rarity": "uncommon"}, "fair"
	)
	var value: float = _system.calculate_item_value(item)
	var expected: float = 15.0 * 1.3 * 0.5
	assert_almost_eq(value, expected, 0.001)


func test_base_value_very_rare_near_mint() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 30.0, "rarity": "very_rare"}, "near_mint"
	)
	var value: float = _system.calculate_item_value(item)
	var expected: float = 30.0 * 2.5 * 0.85
	assert_almost_eq(value, expected, 0.001)


func test_null_item_returns_zero() -> void:
	var value: float = _system.calculate_item_value(null)
	assert_eq(value, 0.0)


func test_no_modifiers_returns_base_rarity_condition() -> void:
	var no_trend_system := MarketValueSystem.new()
	add_child_autofree(no_trend_system)
	no_trend_system.initialize(
		_inventory, null, null
	)
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "rare"}, "mint"
	)
	var value: float = no_trend_system.calculate_item_value(item)
	var expected: float = 10.0 * 1.8 * 1.0
	assert_almost_eq(value, expected, 0.001)


func test_get_market_value_with_registered_item() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common"}, "good"
	)
	_inventory.register_item(item)
	var value: float = _system.get_market_value(
		StringName(item.instance_id)
	)
	var expected: float = 10.0 * 1.0 * 0.75
	assert_almost_eq(value, expected, 0.001)


func test_get_market_value_unknown_id_returns_zero() -> void:
	var value: float = _system.get_market_value(&"nonexistent_999")
	assert_eq(value, 0.0)


func test_cache_returns_same_value() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common"}, "good"
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	var first: float = _system.get_market_value(id)
	var second: float = _system.get_market_value(id)
	assert_eq(first, second)


func test_cache_invalidated_on_trend_changed() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0}, "good"
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	_system.get_market_value(id)
	assert_true(_system._cache.has(id))
	EventBus.trend_changed.emit([], [])
	assert_true(_system._cache.is_empty())


func test_cache_invalidated_on_trend_shifted() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0}, "good"
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	_system.get_market_value(id)
	assert_true(_system._cache.has(id))
	EventBus.trend_shifted.emit(&"tech", 1.5)
	assert_true(_system._cache.is_empty())


func test_cache_invalidated_on_trend_updated() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "category": "trading_cards"}, "good"
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	_system.get_market_value(id)
	assert_true(_system._cache.has(id))
	EventBus.trend_updated.emit(&"trading_cards", 1.5)
	assert_true(_system._cache.is_empty())


func test_cache_invalidated_on_market_event_started() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0}, "good"
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	_system.get_market_value(id)
	assert_true(_system._cache.has(id))
	EventBus.market_event_started.emit("test_event")
	assert_true(_system._cache.is_empty())


func test_cache_invalidated_on_market_event_ended() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0}, "good"
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	_system.get_market_value(id)
	assert_true(_system._cache.has(id))
	EventBus.market_event_ended.emit("test_event")
	assert_true(_system._cache.is_empty())


func test_cache_invalidated_after_one_hour() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0}, "good"
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	EventBus.hour_changed.emit(8)
	_system.get_market_value(id)
	assert_true(_system._cache.has(id))
	EventBus.hour_changed.emit(9)
	assert_true(_system._cache.is_empty())


func test_cache_not_invalidated_within_hour() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0}, "good"
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	EventBus.hour_changed.emit(8)
	_system.get_market_value(id)
	assert_false(_system._cache.is_empty())


func test_rarity_constants_defined() -> void:
	assert_eq(
		MarketValueSystem.RARITY_MULTIPLIERS["common"], 1.0
	)
	assert_eq(
		MarketValueSystem.RARITY_MULTIPLIERS["uncommon"], 1.3
	)
	assert_eq(
		MarketValueSystem.RARITY_MULTIPLIERS["rare"], 1.8
	)
	assert_eq(
		MarketValueSystem.RARITY_MULTIPLIERS["very_rare"], 2.5
	)
	assert_eq(
		MarketValueSystem.RARITY_MULTIPLIERS["legendary"], 4.0
	)


func test_condition_constants_defined() -> void:
	assert_eq(
		MarketValueSystem.CONDITION_MULTIPLIERS["mint"], 1.0
	)
	assert_eq(
		MarketValueSystem.CONDITION_MULTIPLIERS["good"], 0.75
	)
	assert_eq(
		MarketValueSystem.CONDITION_MULTIPLIERS["fair"], 0.5
	)
	assert_eq(
		MarketValueSystem.CONDITION_MULTIPLIERS["poor"], 0.3
	)
	assert_eq(
		MarketValueSystem.CONDITION_MULTIPLIERS["damaged"], 0.15
	)


func test_damaged_condition_multiplier() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 100.0, "rarity": "common"}, "damaged"
	)
	var value: float = _system.calculate_item_value(item)
	var expected: float = 100.0 * 1.0 * 0.15
	assert_almost_eq(value, expected, 0.001)


func test_condition_half_multiplier_halves_price() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 40.0, "rarity": "common"}, "fair"
	)
	var value: float = _system.calculate_item_value(item)
	assert_almost_eq(value, 20.0, 0.001)


func test_trend_above_one_increases_price() -> void:
	EventBus.trend_updated.emit(&"trading_cards", 1.5)
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common", "category": "trading_cards"},
		"mint",
	)
	var value: float = _system.calculate_item_value(item)
	var expected: float = 10.0 * 1.0 * 1.0 * 1.5
	assert_almost_eq(value, expected, 0.001)


func test_trend_below_one_reduces_price() -> void:
	EventBus.trend_updated.emit(&"trading_cards", 0.75)
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common", "category": "trading_cards"},
		"mint",
	)
	var value: float = _system.calculate_item_value(item)
	var expected: float = 10.0 * 1.0 * 1.0 * 0.75
	assert_almost_eq(value, expected, 0.001)
	assert_true(value < 10.0, "Price should be below base when trend < 1.0")


func test_seasonal_multiplier_applied() -> void:
	var season_def := SeasonalEventDefinition.new()
	season_def.id = "test_season"
	season_def.spending_multiplier = 1.25
	_seasonal_event._active_events.append({
		"definition": season_def,
		"start_day": 1,
	})
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common"}, "mint"
	)
	var value: float = _system.calculate_item_value(item)
	var expected: float = 10.0 * 1.0 * 1.0 * 1.25
	assert_almost_eq(value, expected, 0.001)


func test_all_multipliers_compose() -> void:
	EventBus.trend_updated.emit(&"trading_cards", 1.5)
	var season_def := SeasonalEventDefinition.new()
	season_def.id = "test_season"
	season_def.spending_multiplier = 1.2
	_seasonal_event._active_events.append({
		"definition": season_def,
		"start_day": 1,
	})
	var item: ItemInstance = _create_item(
		{"base_price": 20.0, "rarity": "rare", "category": "trading_cards"},
		"good",
	)
	var value: float = _system.calculate_item_value(item)
	var expected: float = 20.0 * 1.8 * 0.75 * 1.5 * 1.2 * 1.0
	assert_almost_eq(value, expected, 0.01)


func test_cache_recomputes_after_invalidation() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common", "category": "trading_cards"},
		"mint",
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	var first: float = _system.get_market_value(id)
	assert_almost_eq(first, 10.0, 0.001)
	EventBus.trend_updated.emit(&"trading_cards", 2.0)
	var second: float = _system.get_market_value(id)
	assert_almost_eq(second, 20.0, 0.001)
	assert_true(
		not is_equal_approx(first, second),
		"Value must change after trend invalidation"
	)


func test_get_item_price_default_trend_is_one() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common", "category": "trading_cards"},
		"good",
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	_system.register_store_price_cap(&"test_store", 0.0)
	var price: float = _system.get_item_price(&"test_store", id)
	# base * trend(1.0) * difficulty(1.0) — rarity/condition not applied
	assert_almost_eq(price, 10.0, 0.001)


func test_get_item_price_trend_updated_changes_output() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common", "category": "trading_cards"},
		"mint",
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	_system.register_store_price_cap(&"test_store", 0.0)
	var price_before: float = _system.get_item_price(&"test_store", id)
	assert_almost_eq(price_before, 10.0, 0.001)
	EventBus.trend_updated.emit(&"trading_cards", 2.0)
	var price_after: float = _system.get_item_price(&"test_store", id)
	assert_almost_eq(price_after, 20.0, 0.001)
	assert_true(
		not is_equal_approx(price_before, price_after),
		"get_item_price must reflect trend_updated change"
	)


func test_get_item_price_unknown_category_uses_default() -> void:
	var item: ItemInstance = _create_item(
		{"base_price": 10.0, "rarity": "common", "category": "obscure_niche"},
		"mint",
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	_system.register_store_price_cap(&"test_store", 0.0)
	# No trend_updated emitted for "obscure_niche" — should default to 1.0
	var price: float = _system.get_item_price(&"test_store", id)
	assert_almost_eq(price, 10.0, 0.001)


func test_get_item_price_unknown_id_returns_zero() -> void:
	_system.register_store_price_cap(&"test_store", 0.0)
	var price: float = _system.get_item_price(&"test_store", &"nonexistent_999")
	assert_eq(price, 0.0)


func test_trend_multipliers_cache_updated_on_trend_updated() -> void:
	assert_false(_system._trend_multipliers.has(&"trading_cards"))
	EventBus.trend_updated.emit(&"trading_cards", 1.8)
	assert_true(_system._trend_multipliers.has(&"trading_cards"))
	assert_almost_eq(
		_system._trend_multipliers[&"trading_cards"] as float, 1.8, 0.001
	)
