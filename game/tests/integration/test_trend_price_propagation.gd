## Integration test: TrendSystem category multiplier propagates to
## MarketValueSystem via trend_updated.
extends GutTest

const FLOAT_TOLERANCE: float = 0.01


const TEST_STORE_ID: StringName = &"test_store"

var _market_value: MarketValueSystem
var _inventory: InventorySystem
var _collectibles_item: ItemInstance
var _electronics_item: ItemInstance

func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)

	_market_value = MarketValueSystem.new()
	add_child_autofree(_market_value)
	_market_value.initialize(_inventory, null, null)
	_market_value.register_store_price_cap(TEST_STORE_ID, 0.0)

	_collectibles_item = _make_item(
		"test_collectible_01", "collectibles", 10.0, "mint"
	)
	_electronics_item = _make_item(
		"test_electronics_01", "electronics", 20.0, "mint"
	)
	# Inject items directly to avoid ContentRegistry dependency in add_item.
	_inventory._items[_collectibles_item.instance_id] = _collectibles_item
	_inventory._items[_electronics_item.instance_id] = _electronics_item


func after_each() -> void:
	EventBus.trend_updated.emit(&"collectibles", 1.0)
	EventBus.trend_updated.emit(&"electronics", 1.0)


# ── Baseline: no trend active → price = base × rarity × condition ────────────


func test_baseline_no_trend_collectibles_price_is_base_times_condition() -> void:
	var expected: float = _expected_price(_collectibles_item, 1.0)
	var actual: float = _market_value.get_item_price(
		TEST_STORE_ID, StringName(_collectibles_item.instance_id)
	)
	assert_almost_eq(
		actual,
		expected,
		FLOAT_TOLERANCE,
		"Baseline collectibles price should be base × rarity × condition × 1.0"
	)


func test_baseline_no_trend_electronics_price_is_base_times_condition() -> void:
	var expected: float = _expected_price(_electronics_item, 1.0)
	var actual: float = _market_value.get_item_price(
		TEST_STORE_ID, StringName(_electronics_item.instance_id)
	)
	assert_almost_eq(
		actual,
		expected,
		FLOAT_TOLERANCE,
		"Baseline electronics price should be base × rarity × condition × 1.0"
	)


# ── Active trend: trend_updated('collectibles', 1.8) → collectibles priced × 1.8 ─


func test_active_trend_collectibles_price_multiplied_by_18() -> void:
	EventBus.trend_updated.emit(&"collectibles", 1.8)

	var expected: float = _expected_price(_collectibles_item, 1.8)
	var actual: float = _market_value.get_item_price(
		TEST_STORE_ID, StringName(_collectibles_item.instance_id)
	)
	assert_almost_eq(
		actual,
		expected,
		FLOAT_TOLERANCE,
		"After trend_updated(collectibles, 1.8) price should be base × rarity × cond × 1.8"
	)


# ── Unaffected category: collectibles trend does NOT change electronics price ──


func test_collectibles_trend_does_not_affect_electronics_price() -> void:
	EventBus.trend_updated.emit(&"collectibles", 1.8)

	var expected: float = _expected_price(_electronics_item, 1.0)
	var actual: float = _market_value.get_item_price(
		TEST_STORE_ID, StringName(_electronics_item.instance_id)
	)
	assert_almost_eq(
		actual,
		expected,
		FLOAT_TOLERANCE,
		"Electronics price must remain unchanged when only collectibles trend is set"
	)


# ── Trend expired: trend_updated('collectibles', 1.0) reverts to base ─────────


func test_trend_reset_to_one_reverts_collectibles_price_to_base() -> void:
	EventBus.trend_updated.emit(&"collectibles", 1.8)
	EventBus.trend_updated.emit(&"collectibles", 1.0)

	var expected: float = _expected_price(_collectibles_item, 1.0)
	var actual: float = _market_value.get_item_price(
		TEST_STORE_ID, StringName(_collectibles_item.instance_id)
	)
	assert_almost_eq(
		actual,
		expected,
		FLOAT_TOLERANCE,
		"After trend_updated(collectibles, 1.0) price should revert to base × rarity × cond"
	)


# ── Multiple categories: each priced with its own independent multiplier ───────


func test_multiple_categories_each_use_own_multiplier_independently() -> void:
	EventBus.trend_updated.emit(&"collectibles", 1.8)
	EventBus.trend_updated.emit(&"electronics", 0.7)

	var expected_col: float = _expected_price(_collectibles_item, 1.8)
	var expected_elec: float = _expected_price(_electronics_item, 0.7)

	var actual_col: float = _market_value.get_item_price(
		TEST_STORE_ID, StringName(_collectibles_item.instance_id)
	)
	var actual_elec: float = _market_value.get_item_price(
		TEST_STORE_ID, StringName(_electronics_item.instance_id)
	)

	assert_almost_eq(
		actual_col,
		expected_col,
		FLOAT_TOLERANCE,
		"Collectibles price should use its own 1.8 multiplier"
	)
	assert_almost_eq(
		actual_elec,
		expected_elec,
		FLOAT_TOLERANCE,
		"Electronics price should use its own 0.7 multiplier"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _make_item(
	item_id: String,
	category: String,
	base_price: float,
	cond: String
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = item_id
	def.item_name = item_id
	def.category = category
	def.base_price = base_price
	def.rarity = "common"
	return ItemInstance.create_from_definition(def, cond)


## Returns expected get_item_price result: base_price × rarity_mult × cond_mult × trend.
## rarity "common" → rarity_mult = 1.0; condition "mint" → cond_mult = 1.0.
func _expected_price(item: ItemInstance, trend_mult: float) -> float:
	var rarity_mult: float = MarketValueSystem.RARITY_MULTIPLIERS.get(
		item.definition.rarity, 1.0
	) as float
	var cond_mult: float = MarketValueSystem.CONDITION_MULTIPLIERS.get(
		item.condition, 0.75
	) as float
	return item.definition.base_price * rarity_mult * cond_mult * trend_mult
