## Tests for OrderPanel cart logic and tier selection.
extends GutTest


var _order_system: OrderSystem
var _inventory_system: InventorySystem
var _reputation_system: ReputationSystem
var _progression_system: ProgressionSystem
var _economy_system: EconomySystem


func before_each() -> void:
	_economy_system = EconomySystem.new()
	_economy_system.name = "EconomySystem"
	add_child(_economy_system)
	_economy_system.initialize()

	_inventory_system = InventorySystem.new()
	_inventory_system.name = "InventorySystem"
	add_child(_inventory_system)
	_inventory_system.initialize(GameManager.data_loader)

	_reputation_system = ReputationSystem.new()
	_reputation_system.name = "ReputationSystem"
	add_child(_reputation_system)

	_progression_system = ProgressionSystem.new()
	_progression_system.name = "ProgressionSystem"
	add_child(_progression_system)
	_progression_system.initialize(_economy_system, _reputation_system)

	_order_system = OrderSystem.new()
	_order_system.name = "OrderSystem"
	add_child(_order_system)
	_order_system.initialize(
		_inventory_system, _reputation_system, _progression_system
	)


func after_each() -> void:
	_order_system.queue_free()
	_progression_system.queue_free()
	_reputation_system.queue_free()
	_inventory_system.queue_free()
	_economy_system.queue_free()


func test_basic_tier_always_unlocked_for_panel() -> void:
	assert_true(
		_order_system.is_tier_unlocked(
			OrderSystem.SupplierTier.BASIC
		),
		"Panel should always have BASIC tier available"
	)


func test_tier_catalog_filters_by_rarity() -> void:
	var item_def := ItemDefinition.new()
	item_def.id = "test_common"
	item_def.rarity = "common"
	assert_true(
		_order_system.is_item_in_tier_catalog(
			item_def, OrderSystem.SupplierTier.BASIC
		),
		"Common items should be in BASIC catalog"
	)
	var rare_def := ItemDefinition.new()
	rare_def.id = "test_rare"
	rare_def.rarity = "rare"
	assert_false(
		_order_system.is_item_in_tier_catalog(
			rare_def, OrderSystem.SupplierTier.BASIC
		),
		"Rare items should not be in BASIC catalog"
	)


func test_order_cost_uses_tier_multiplier() -> void:
	var item_def := ItemDefinition.new()
	item_def.id = "test_item"
	item_def.base_price = 100.0
	var cost: float = _order_system.get_order_cost(
		item_def, OrderSystem.SupplierTier.BASIC
	)
	var expected: float = 100.0 * OrderSystem.TIER_CONFIG[
		OrderSystem.SupplierTier.BASIC
	]["price_multiplier"]
	assert_almost_eq(
		cost, expected, 0.01,
		"Order cost should use tier price multiplier"
	)


func test_pending_orders_returns_copy() -> void:
	var orders: Array[Dictionary] = (
		_order_system.get_pending_orders()
	)
	assert_eq(
		orders.size(), 0,
		"Should start with no pending orders"
	)


func test_daily_budget_tracking_across_tiers() -> void:
	var basic_remaining: float = (
		_order_system.get_remaining_daily_budget(
			OrderSystem.SupplierTier.BASIC
		)
	)
	var basic_limit: float = _order_system.get_daily_limit(
		OrderSystem.SupplierTier.BASIC
	)
	assert_eq(
		basic_remaining, basic_limit,
		"Remaining budget should equal full limit initially"
	)
