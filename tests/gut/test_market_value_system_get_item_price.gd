## ISSUE-402: GUT tests for MarketValueSystem.get_item_price — base price lookup,
## trend multiplier, difficulty modifier, combined multipliers, floor, and store cap.
extends GutTest


const STORE_ID: StringName = &"test_store"
const UNKNOWN_STORE_ID: StringName = &"unregistered_store"
const BASE_PRICE: float = 20.0
const STORE_CAP: float = 50.0

var _system: MarketValueSystem
var _inventory: InventorySystem


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)

	_system = MarketValueSystem.new()
	add_child_autofree(_system)
	_system.initialize(_inventory, null, null)
	_system.register_store_price_cap(STORE_ID, STORE_CAP)

	DifficultySystem.set_tier(&"normal")


func after_each() -> void:
	DifficultySystem.set_tier(&"normal")


func _make_item(
	base_price: float,
	category: String = "trading_cards",
	condition: String = "mint",
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_pricing_item"
	def.name = "Test Pricing Item"
	def.base_price = base_price
	def.rarity = "common"
	def.category = category
	def.tags = PackedStringArray()
	def.store_type = "retro_games"
	return ItemInstance.create_from_definition(def, condition)


## AC1: No active modifiers returns exact base_price.
func test_base_price_lookup_no_modifiers() -> void:
	var item: ItemInstance = _make_item(BASE_PRICE)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	# Normal difficulty price_modifier = 1.0, no trend set → trend defaults to 1.0.
	var price: float = _system.get_item_price(STORE_ID, id)
	assert_almost_eq(price, BASE_PRICE, 0.001)


## AC2: Trend multiplier 1.3 returns base_price * 1.3.
func test_trend_multiplier_applied() -> void:
	var item: ItemInstance = _make_item(BASE_PRICE)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	EventBus.trend_updated.emit(&"trading_cards", 1.3)
	var price: float = _system.get_item_price(STORE_ID, id)
	assert_almost_eq(price, BASE_PRICE * 1.3, 0.001)


## AC3: Difficulty modifier 0.8 (hard tier) returns base_price * 0.8.
func test_difficulty_modifier_applied() -> void:
	DifficultySystem.set_tier(&"hard")
	var item: ItemInstance = _make_item(BASE_PRICE)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	var price: float = _system.get_item_price(STORE_ID, id)
	assert_almost_eq(price, BASE_PRICE * 0.8, 0.001)


## AC4: Trend 1.3 + difficulty 0.8 = base_price * 1.04 (multiplicative).
func test_combined_multipliers_are_multiplicative() -> void:
	DifficultySystem.set_tier(&"hard")
	var item: ItemInstance = _make_item(BASE_PRICE)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	EventBus.trend_updated.emit(&"trading_cards", 1.3)
	var price: float = _system.get_item_price(STORE_ID, id)
	assert_almost_eq(price, BASE_PRICE * 1.3 * 0.8, 0.001)


## AC5: Result is never below MINIMUM_ITEM_PRICE regardless of multipliers.
func test_price_floor_enforced() -> void:
	var item: ItemInstance = _make_item(0.001)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	# Even with default multipliers, a near-zero base must be floored.
	var price: float = _system.get_item_price(STORE_ID, id)
	assert_true(
		price >= MarketValueSystem.MINIMUM_ITEM_PRICE,
		"Price must be at least MINIMUM_ITEM_PRICE"
	)
	assert_almost_eq(price, MarketValueSystem.MINIMUM_ITEM_PRICE, 0.0001)


## AC5 variant: floor holds even with a very low trend multiplier.
func test_price_floor_with_low_trend() -> void:
	var item: ItemInstance = _make_item(0.001)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	EventBus.trend_updated.emit(&"trading_cards", 0.001)
	var price: float = _system.get_item_price(STORE_ID, id)
	assert_true(
		price >= MarketValueSystem.MINIMUM_ITEM_PRICE,
		"Price must never go below MINIMUM_ITEM_PRICE"
	)


## AC6: Result is never above StoreConfig.price_cap for the store.
func test_price_cap_enforced() -> void:
	# Item base_price 100 with trend 2.0 would be 200 — well above STORE_CAP (50).
	var item: ItemInstance = _make_item(100.0)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	EventBus.trend_updated.emit(&"trading_cards", 2.0)
	var price: float = _system.get_item_price(STORE_ID, id)
	assert_almost_eq(price, STORE_CAP, 0.001)


## AC6 variant: price below cap is not clamped.
func test_price_below_cap_not_clamped() -> void:
	var item: ItemInstance = _make_item(10.0)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	var price: float = _system.get_item_price(STORE_ID, id)
	# 10.0 < STORE_CAP (50.0) — must pass through unchanged.
	assert_almost_eq(price, 10.0, 0.001)


## AC7: Unknown item_id returns 0.0 and does not crash.
func test_unknown_item_id_returns_zero() -> void:
	var price: float = _system.get_item_price(STORE_ID, &"nonexistent_item_402")
	assert_eq(price, 0.0)


## AC8: Unknown store_id returns the computed price with no cap applied.
func test_unknown_store_id_returns_uncapped_price() -> void:
	var item: ItemInstance = _make_item(100.0)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	EventBus.trend_updated.emit(&"trading_cards", 2.0)
	# Uncapped: 100 * 2.0 * 1.0 = 200
	var price: float = _system.get_item_price(UNKNOWN_STORE_ID, id)
	assert_almost_eq(price, 200.0, 0.001)


## MINIMUM_ITEM_PRICE constant is accessible and positive.
func test_minimum_item_price_constant_defined() -> void:
	assert_true(
		MarketValueSystem.MINIMUM_ITEM_PRICE > 0.0,
		"MINIMUM_ITEM_PRICE must be a positive constant"
	)


## Store with cap=0 has no upper bound applied.
func test_store_cap_zero_means_no_cap() -> void:
	_system.register_store_price_cap(&"nocap_store", 0.0)
	var item: ItemInstance = _make_item(1000.0)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	var price: float = _system.get_item_price(&"nocap_store", id)
	assert_almost_eq(price, 1000.0, 0.001)
