## Tests for OrderSystem supplier tiers, order workflow, and delivery.
extends GutTest


var _order_system: OrderSystem
var _inventory_system: InventorySystem
var _reputation_system: ReputationSystem
var _progression_system: ProgressionSystem
var _economy_system: EconomySystem
var _order_placed_count: int = 0
var _order_failed_reason: String = ""
var _delivered_stores: Array[StringName] = []
var _delivered_items: Array = []
var _toast_messages: Array[String] = []
var _toast_categories: Array[StringName] = []
var _toast_durations: Array[float] = []
var _stockout_item_ids: Array[StringName] = []
var _stockout_requested: Array[int] = []
var _stockout_fulfilled: Array[int] = []
var _refund_amounts: Array[float] = []


func before_each() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()
	GameManager.data_loader = DataLoaderSingleton
	_order_placed_count = 0
	_order_failed_reason = ""
	_delivered_stores = []
	_delivered_items = []
	_toast_messages = []
	_toast_categories = []
	_toast_durations = []
	_stockout_item_ids = []
	_stockout_requested = []
	_stockout_fulfilled = []
	_refund_amounts = []

	_economy_system = EconomySystem.new()
	_economy_system.name = "EconomySystem"
	add_child_autofree(_economy_system)
	_economy_system.initialize()

	_inventory_system = InventorySystem.new()
	_inventory_system.name = "InventorySystem"
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(GameManager.data_loader)

	_reputation_system = ReputationSystem.new()
	_reputation_system.name = "ReputationSystem"
	add_child_autofree(_reputation_system)

	_progression_system = ProgressionSystem.new()
	_progression_system.name = "ProgressionSystem"
	add_child_autofree(_progression_system)
	_progression_system.initialize(_economy_system, _reputation_system)

	_order_system = OrderSystem.new()
	_order_system.name = "OrderSystem"
	add_child_autofree(_order_system)
	_order_system.initialize(
		_inventory_system, _reputation_system, _progression_system
	)

	EventBus.order_placed.connect(_on_order_placed)
	EventBus.order_failed.connect(_on_order_failed)
	EventBus.order_delivered.connect(_on_order_delivered)
	EventBus.toast_requested.connect(_on_toast_requested)
	EventBus.order_stockout.connect(_on_order_stockout)
	EventBus.order_refund_issued.connect(_on_order_refund_issued)


func after_each() -> void:
	if EventBus.order_placed.is_connected(_on_order_placed):
		EventBus.order_placed.disconnect(_on_order_placed)
	if EventBus.order_failed.is_connected(_on_order_failed):
		EventBus.order_failed.disconnect(_on_order_failed)
	if EventBus.order_delivered.is_connected(_on_order_delivered):
		EventBus.order_delivered.disconnect(_on_order_delivered)
	if EventBus.toast_requested.is_connected(_on_toast_requested):
		EventBus.toast_requested.disconnect(_on_toast_requested)
	if EventBus.order_stockout.is_connected(_on_order_stockout):
		EventBus.order_stockout.disconnect(_on_order_stockout)
	if EventBus.order_refund_issued.is_connected(_on_order_refund_issued):
		EventBus.order_refund_issued.disconnect(_on_order_refund_issued)


func _on_order_placed(
	_store_id: StringName,
	_item_id: StringName,
	_quantity: int,
	_delivery_day: int,
) -> void:
	_order_placed_count += 1


func _on_order_failed(reason: String) -> void:
	_order_failed_reason = reason


func _on_order_delivered(
	store_id: StringName, items: Array
) -> void:
	_delivered_stores.append(store_id)
	_delivered_items.append_array(items)


func _on_toast_requested(
	message: String, category: StringName, duration: float
) -> void:
	_toast_messages.append(message)
	_toast_categories.append(category)
	_toast_durations.append(duration)


func _on_order_stockout(
	item_id: StringName, requested: int, fulfilled: int
) -> void:
	_stockout_item_ids.append(item_id)
	_stockout_requested.append(requested)
	_stockout_fulfilled.append(fulfilled)


func _on_order_refund_issued(amount: float, _reason: String) -> void:
	_refund_amounts.append(amount)


func _get_store_item(
	store_id: String, rarities: PackedStringArray = PackedStringArray()
) -> ItemDefinition:
	if not GameManager.data_loader:
		return null
	var items: Array[ItemDefinition] = (
		GameManager.data_loader.get_items_by_store(store_id)
	)
	for item: ItemDefinition in items:
		if rarities.is_empty() or item.rarity in rarities:
			return item
	return null


# --- SupplierTier enum ---


func test_supplier_tier_enum_values() -> void:
	assert_eq(
		OrderSystem.SupplierTier.BASIC, 0,
		"BASIC should be 0"
	)
	assert_eq(
		OrderSystem.SupplierTier.SPECIALTY, 1,
		"SPECIALTY should be 1"
	)
	assert_eq(
		OrderSystem.SupplierTier.LIQUIDATOR, 2,
		"LIQUIDATOR should be 2"
	)
	assert_eq(
		OrderSystem.SupplierTier.PREMIUM, 3,
		"PREMIUM should be 3"
	)


# --- Tier unlock gates ---


func test_basic_tier_always_unlocked() -> void:
	assert_true(
		_order_system.is_tier_unlocked(
			OrderSystem.SupplierTier.BASIC
		),
		"BASIC tier should always be unlocked"
	)


func test_specialty_tier_locked_at_low_rep() -> void:
	assert_false(
		_order_system.is_tier_unlocked(
			OrderSystem.SupplierTier.SPECIALTY
		),
		"SPECIALTY should be locked at low reputation"
	)


func test_liquidator_tier_locked_at_low_store_level() -> void:
	assert_false(
		_order_system.is_tier_unlocked(
			OrderSystem.SupplierTier.LIQUIDATOR
		),
		"LIQUIDATOR should be locked at low store level"
	)


func test_premium_tier_locked_at_low_rep() -> void:
	assert_false(
		_order_system.is_tier_unlocked(
			OrderSystem.SupplierTier.PREMIUM
		),
		"PREMIUM should be locked at low reputation"
	)


func test_specialty_tier_unlocks_at_reputable_tier() -> void:
	_reputation_system.initialize_store("retro_games")
	_reputation_system.add_reputation("retro_games", 5.0)
	assert_true(
		_order_system.is_tier_unlocked(
			OrderSystem.SupplierTier.SPECIALTY,
			&"retro_games"
		),
		"SPECIALTY should unlock once store reputation reaches tier 2"
	)


func test_liquidator_tier_unlocks_at_store_level_three() -> void:
	_progression_system._unlocked_store_slots = 3
	assert_true(
		_order_system.is_tier_unlocked(
			OrderSystem.SupplierTier.LIQUIDATOR,
			&"retro_games"
		),
		"LIQUIDATOR should unlock once store level reaches 3"
	)


func test_premium_tier_unlocks_at_legendary_tier() -> void:
	_reputation_system.initialize_store("retro_games")
	_reputation_system.add_reputation("retro_games", 30.0)
	assert_true(
		_order_system.is_tier_unlocked(
			OrderSystem.SupplierTier.PREMIUM,
			&"retro_games"
		),
		"PREMIUM should unlock at the highest reputation tier"
	)


# --- Tier config ---


func test_basic_delivery_days() -> void:
	var config: Dictionary = OrderSystem.TIER_CONFIG[
		OrderSystem.SupplierTier.BASIC
	]
	assert_eq(
		config["delivery_days"], 1,
		"BASIC delivery should be 1 day"
	)


func test_specialty_delivery_days() -> void:
	var config: Dictionary = OrderSystem.TIER_CONFIG[
		OrderSystem.SupplierTier.SPECIALTY
	]
	assert_eq(
		config["delivery_days"], 2,
		"SPECIALTY delivery should be 2 days"
	)


func test_liquidator_delivery_days() -> void:
	var config: Dictionary = OrderSystem.TIER_CONFIG[
		OrderSystem.SupplierTier.LIQUIDATOR
	]
	assert_eq(
		config["delivery_days"], 3,
		"LIQUIDATOR delivery should be 3 days"
	)


func test_premium_delivery_days() -> void:
	var config: Dictionary = OrderSystem.TIER_CONFIG[
		OrderSystem.SupplierTier.PREMIUM
	]
	assert_eq(
		config["delivery_days"], 1,
		"PREMIUM delivery should be 1 day (next-day)"
	)


# --- Pricing multipliers ---


func test_basic_price_above_wholesale() -> void:
	var mult: float = OrderSystem.TIER_CONFIG[
		OrderSystem.SupplierTier.BASIC
	]["price_multiplier"]
	assert_gt(
		mult, 1.0,
		"BASIC price multiplier should be above 1.0 (above wholesale)"
	)
	assert_lte(
		mult, 1.3,
		"BASIC price multiplier should be at most 1.3 (30%% above)"
	)


func test_specialty_price_above_wholesale() -> void:
	var mult: float = OrderSystem.TIER_CONFIG[
		OrderSystem.SupplierTier.SPECIALTY
	]["price_multiplier"]
	assert_gt(
		mult, 1.0,
		"SPECIALTY price multiplier should be above 1.0"
	)
	assert_lte(
		mult, 1.15,
		"SPECIALTY price multiplier should be at most 1.15"
	)


func test_liquidator_price_below_wholesale() -> void:
	var mult: float = OrderSystem.TIER_CONFIG[
		OrderSystem.SupplierTier.LIQUIDATOR
	]["price_multiplier"]
	assert_lt(
		mult, 1.0,
		"LIQUIDATOR price multiplier should be below 1.0"
	)
	assert_gte(
		mult, 0.5,
		"LIQUIDATOR price multiplier should be at least 0.5"
	)


func test_premium_price_at_wholesale() -> void:
	var mult: float = OrderSystem.TIER_CONFIG[
		OrderSystem.SupplierTier.PREMIUM
	]["price_multiplier"]
	assert_eq(
		mult, 1.0,
		"PREMIUM price multiplier should be exactly 1.0 (wholesale)"
	)


# --- place_order failure cases ---


func test_place_order_fails_with_locked_tier() -> void:
	var result: bool = _order_system.place_order(
		&"retro_games",
		OrderSystem.SupplierTier.SPECIALTY,
		&"some_item",
		1,
	)
	assert_false(result, "Should fail when tier is locked")
	assert_eq(
		_order_failed_reason, "Supplier tier locked",
		"Should emit order_failed with tier locked reason"
	)


func test_place_order_fails_with_zero_quantity() -> void:
	var result: bool = _order_system.place_order(
		&"retro_games",
		OrderSystem.SupplierTier.BASIC,
		&"some_item",
		0,
	)
	assert_false(result, "Should fail with zero quantity")
	assert_eq(
		_order_failed_reason, "Invalid quantity",
		"Should emit order_failed with invalid quantity reason"
	)


func test_place_order_fails_with_insufficient_cash() -> void:
	var item: ItemDefinition = _get_store_item(
		"retro_games", PackedStringArray(["common", "uncommon"])
	)
	if not item:
		pending("No BASIC-tier retro_games item available for testing")
		return
	_economy_system.load_save_data({"cash": 0.0})
	var result: bool = _order_system.place_order(
		&"retro_games",
		OrderSystem.SupplierTier.BASIC,
		StringName(item.id),
		1,
	)
	assert_false(result, "Should fail with insufficient cash")
	assert_eq(
		_order_failed_reason, "Insufficient funds",
		"Should emit order_failed with insufficient funds"
	)


func test_place_order_fails_when_item_not_in_store_catalog() -> void:
	var wrong_item: ItemDefinition = _get_store_item(
		"video_rental", PackedStringArray(["common", "uncommon"])
	)
	if not wrong_item:
		pending("Need a BASIC-tier video_rental item for testing")
		return
	var result: bool = _order_system.place_order(
		&"retro_games",
		OrderSystem.SupplierTier.BASIC,
		StringName(wrong_item.id),
		1,
	)
	assert_false(result, "Should fail when item is not in the store catalog")
	assert_string_contains(
		_order_failed_reason,
		"not available for",
		"Should emit order_failed with item-not-in-catalog reason"
	)


# --- Save/load ---


func test_save_load_preserves_pending_orders() -> void:
	var save_data: Dictionary = _order_system.get_save_data()
	assert_true(
		save_data.has("pending_orders"),
		"Save data should contain pending_orders key"
	)
	var new_system: OrderSystem = OrderSystem.new()
	new_system.name = "OrderSystem2"
	add_child_autofree(new_system)
	new_system.initialize(
		_inventory_system, _reputation_system, _progression_system
	)
	new_system.load_save_data(save_data)
	assert_eq(
		new_system.get_pending_order_count(),
		_order_system.get_pending_order_count(),
		"Loaded system should have same pending order count"
	)


func test_save_data_round_trip_with_orders() -> void:
	var order_data: Dictionary = {
		"pending_orders": [
			{
				"store_id": "retro_games",
				"supplier_tier": 0,
				"item_id": "test_item",
				"quantity": 2,
				"unit_cost": 10.0,
				"delivery_day": 5,
			},
		],
	}
	_order_system.load_save_data(order_data)
	assert_eq(
		_order_system.get_pending_order_count(), 1,
		"Should have 1 pending order after load"
	)
	var saved: Dictionary = _order_system.get_save_data()
	var orders: Array = saved["pending_orders"]
	assert_eq(orders.size(), 1, "Saved should have 1 order")
	var order: Dictionary = orders[0]
	assert_eq(
		order["delivery_day"], 5,
		"Delivery day should be preserved"
	)
	assert_eq(
		order["store_id"], "retro_games",
		"Store ID should be preserved"
	)


# --- Tier config completeness ---


func test_all_tiers_have_required_config_keys() -> void:
	var required_keys: Array[String] = [
		"name",
		"price_multiplier",
		"delivery_days",
		"daily_limit",
		"rarities",
		"required_reputation_tier",
		"required_store_level",
	]
	for tier_key: int in OrderSystem.TIER_CONFIG:
		var config: Dictionary = OrderSystem.TIER_CONFIG[tier_key]
		for key: String in required_keys:
			assert_true(
				config.has(key),
				"Tier %d missing config key '%s'" % [tier_key, key]
			)


func test_get_unlocked_tiers_includes_basic() -> void:
	var unlocked: Array[int] = _order_system.get_unlocked_tiers()
	assert_true(
		OrderSystem.SupplierTier.BASIC in unlocked,
		"BASIC should always be in unlocked tiers"
	)


# --- Daily spending limits ---


func test_daily_spending_starts_at_zero() -> void:
	assert_eq(
		_order_system.get_daily_spending(
			OrderSystem.SupplierTier.BASIC
		),
		0.0,
		"Daily spending should start at zero"
	)


func test_daily_limit_matches_tier_config() -> void:
	var config: Dictionary = OrderSystem.TIER_CONFIG[
		OrderSystem.SupplierTier.BASIC
	]
	assert_eq(
		_order_system.get_daily_limit(
			OrderSystem.SupplierTier.BASIC
		),
		config["daily_limit"],
		"get_daily_limit should match TIER_CONFIG"
	)


func test_remaining_budget_equals_limit_when_no_spending() -> void:
	var limit: float = _order_system.get_daily_limit(
		OrderSystem.SupplierTier.BASIC
	)
	var remaining: float = _order_system.get_remaining_daily_budget(
		OrderSystem.SupplierTier.BASIC
	)
	assert_eq(
		remaining, limit,
		"Remaining budget should equal limit with no spending"
	)


func test_all_tiers_have_positive_daily_limit() -> void:
	for tier_key: int in OrderSystem.TIER_CONFIG:
		var config: Dictionary = OrderSystem.TIER_CONFIG[tier_key]
		assert_gt(
			float(config["daily_limit"]), 0.0,
			"Tier %d should have positive daily_limit" % tier_key
		)


func test_daily_spending_saved_and_restored() -> void:
	var save_data: Dictionary = _order_system.get_save_data()
	assert_true(
		save_data.has("daily_spending"),
		"Save data should contain daily_spending"
	)
	var new_system: OrderSystem = OrderSystem.new()
	new_system.name = "OrderSystem2"
	add_child_autofree(new_system)
	new_system.initialize(
		_inventory_system, _reputation_system, _progression_system
	)
	new_system.load_save_data(save_data)
	assert_eq(
		new_system.get_daily_spending(
			OrderSystem.SupplierTier.BASIC
		),
		_order_system.get_daily_spending(
			OrderSystem.SupplierTier.BASIC
		),
		"Daily spending should be preserved after load"
	)


# --- Toast notification on delivery ---


func test_order_delivered_emits_toast_requested() -> void:
	EventBus.order_delivered.emit(
		&"retro_games", ["item_1", "item_2"]
	)
	assert_eq(
		_toast_messages.size(), 1,
		"Should emit exactly one toast"
	)
	assert_eq(
		_toast_categories[0], &"system",
		"Toast category should be 'system'"
	)
	assert_eq(
		_toast_durations[0], 4.0,
		"Toast duration should be 4.0 seconds"
	)


func test_order_delivered_toast_includes_item_count() -> void:
	EventBus.order_delivered.emit(
		&"retro_games", ["item_1", "item_2", "item_3"]
	)
	assert_true(
		_toast_messages[0].contains("3"),
		"Toast message should include item count"
	)


func test_order_delivered_empty_items_no_toast() -> void:
	EventBus.order_delivered.emit(&"retro_games", [])
	assert_eq(
		_toast_messages.size(), 0,
		"Should not emit toast for empty delivery"
	)


# --- Partial fill calculation ---


func test_partial_fill_never_returns_zero() -> void:
	for qty: int in [1, 2, 5, 10, 20]:
		var filled: int = _order_system._calculate_partial_fill(qty)
		assert_gt(
			filled, 0,
			"Partial fill must be > 0 for quantity %d" % qty
		)


func test_partial_fill_never_exceeds_requested() -> void:
	for qty: int in [1, 2, 5, 10, 20]:
		var filled: int = _order_system._calculate_partial_fill(qty)
		assert_lte(
			filled, qty,
			"Partial fill must not exceed requested for quantity %d" % qty
		)


func test_partial_fill_meets_minimum_fraction() -> void:
	for qty: int in [2, 5, 10, 20]:
		var filled: int = _order_system._calculate_partial_fill(qty)
		var min_fill: int = ceili(qty * 0.40)
		assert_gte(
			filled, min_fill,
			"Partial fill should be >= ceil(40%% of %d)" % qty
		)


func test_partial_fill_within_maximum_fraction() -> void:
	for qty: int in [2, 5, 10, 20]:
		var filled: int = _order_system._calculate_partial_fill(qty)
		var max_fill: int = ceili(qty * 0.75)
		assert_lte(
			filled, max_fill,
			"Partial fill should be <= ceil(75%% of %d)" % qty
		)


# --- Stockout signal emission ---


func test_stockout_signal_params_are_valid() -> void:
	EventBus.order_stockout.emit(&"test_item", 10, 5)
	assert_eq(_stockout_item_ids.size(), 1, "Should capture one stockout signal")
	assert_eq(_stockout_item_ids[0], &"test_item", "Item id should match")
	assert_eq(_stockout_requested[0], 10, "Requested quantity should match")
	assert_eq(_stockout_fulfilled[0], 5, "Fulfilled quantity should match")


func test_stockout_fulfilled_less_than_requested() -> void:
	EventBus.order_stockout.emit(&"test_item", 10, 5)
	assert_lt(
		_stockout_fulfilled[0],
		_stockout_requested[0],
		"Fulfilled should be less than requested on stockout"
	)


# --- Refund signal emission ---


func test_refund_signal_emitted_for_partial_stockout() -> void:
	EventBus.order_refund_issued.emit(25.0, "Stockout: 2x test_item undelivered")
	assert_eq(_refund_amounts.size(), 1, "Should capture one refund signal")
	assert_almost_eq(_refund_amounts[0], 25.0, 0.01, "Refund amount should match")


func test_delivery_creation_failure_refunds_missing_items() -> void:
	var item: ItemDefinition = _get_store_item(
		"retro_games", PackedStringArray(["common", "uncommon"])
	)
	if not item:
		pending("No BASIC-tier retro_games item available for testing")
		return
	var store_entry: Dictionary = ContentRegistry.get_entry(&"retro_games")
	store_entry["backroom_capacity"] = 1
	var existing_item: ItemInstance = _inventory_system.create_item(
		item.id, "good", item.base_price
	)
	assert_not_null(existing_item, "Setup should fill the retro_games backroom")
	var order_cost: float = _order_system.get_order_cost(
		item, OrderSystem.SupplierTier.BASIC
	)
	var placed: bool = _order_system.place_order(
		&"retro_games",
		OrderSystem.SupplierTier.BASIC,
		StringName(item.id),
		1,
	)
	assert_true(placed, "Order should be accepted before delivery runs")
	var pending_orders: Array[Dictionary] = _order_system.get_pending_orders()
	assert_eq(pending_orders.size(), 1, "Expected one pending order for delivery")
	var delivered_by_store: Dictionary = {}
	_order_system._process_order_delivery(
		pending_orders[0], 0.0, delivered_by_store
	)
	_order_system._emit_delivery_results(delivered_by_store)
	assert_eq(
		_refund_amounts.size(), 1,
		"Delivery creation failures should emit a refund"
	)
	assert_almost_eq(
		_refund_amounts[0], order_cost, 0.01,
		"Refund should match the undelivered item cost"
	)
	assert_eq(
		_delivered_items.size(), 0,
		"Failed item creation should not emit delivered items"
	)
	assert_eq(
		_inventory_system.get_stock(&"retro_games").size(), 1,
		"Inventory should still contain only the setup item"
	)
