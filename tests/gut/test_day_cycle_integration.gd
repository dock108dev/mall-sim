## Integration test: full day cycle across TimeSystem, EconomySystem,
## CheckoutSystem, and InventorySystem.
extends GutTest


var _time: TimeSystem
var _economy: EconomySystem
var _inventory: InventorySystem
var _checkout: PlayerCheckout
var _reputation: ReputationSystem
var _customer_system: CustomerSystem
var _definition: ItemDefinition
var _item: ItemInstance
var _customer_scene: PackedScene
var _profile: CustomerTypeDefinition

var _day_ended_days: Array[int] = []
var _sold_signals: Array[Dictionary] = []
var _phase_signals: Array[int] = []

var _saved_store_id: StringName = &""
var _saved_owned_stores: Array[StringName] = []


func before_each() -> void:
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	GameManager.current_store_id = &"pocket_creatures"
	GameManager.owned_stores = []

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.initialize()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)

	_customer_system = CustomerSystem.new()
	add_child_autofree(_customer_system)

	_checkout = PlayerCheckout.new()
	add_child_autofree(_checkout)
	_checkout.initialize(
		_economy, _inventory, _customer_system, _reputation
	)

	_profile = CustomerTypeDefinition.new()
	_profile.id = "test_buyer"
	_profile.customer_name = "Test Buyer"
	_profile.budget_range = [5.0, 500.0]
	_profile.patience = 0.8
	_profile.price_sensitivity = 0.5
	_profile.preferred_categories = PackedStringArray([])
	_profile.preferred_tags = PackedStringArray([])
	_profile.condition_preference = "good"
	_profile.browse_time_range = [30.0, 60.0]
	_profile.purchase_probability_base = 0.9
	_profile.impulse_buy_chance = 0.1
	_profile.mood_tags = PackedStringArray([])

	_definition = ItemDefinition.new()
	_definition.id = "test_item"
	_definition.item_name = "Test Item"
	_definition.category = "cards"
	_definition.base_price = 50.0
	_definition.rarity = "common"
	_definition.tags = PackedStringArray([])
	_definition.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)
	_definition.store_type = "pocket_creatures"

	_item = ItemInstance.create_from_definition(_definition, "good")
	_item.player_set_price = 50.0
	_item.current_location = "shelf:slot_1"
	_inventory._items[_item.instance_id] = _item

	_customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)

	_day_ended_days = []
	_sold_signals = []
	_phase_signals = []

	EventBus.day_ended.connect(_on_day_ended)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)


func after_each() -> void:
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	_safe_disconnect(EventBus.day_ended, _on_day_ended)
	_safe_disconnect(EventBus.item_sold, _on_item_sold)
	_safe_disconnect(
		EventBus.day_phase_changed, _on_day_phase_changed
	)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _make_customer() -> Customer:
	var customer: Customer = _customer_scene.instantiate()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer


func _on_day_ended(day: int) -> void:
	_day_ended_days.append(day)


func _on_item_sold(
	item_id: String, price: float, category: String
) -> void:
	_sold_signals.append({
		"item_id": item_id,
		"price": price,
		"category": category,
	})


func _on_day_phase_changed(new_phase: int) -> void:
	_phase_signals.append(new_phase)


func _force_complete_checkout() -> void:
	_checkout._checkout_timer.stop()
	_checkout._on_checkout_timer_timeout()


## Advances game time by the given number of game-minutes.
## At NORMAL speed (1x), 1 real second = 1 game minute.
func _advance_time(game_minutes: float) -> void:
	if _time.speed_multiplier <= 0.0:
		return
	var delta: float = game_minutes / _time.speed_multiplier
	_time._process(delta)


# --- Full day cycle test ---


func test_full_day_cycle_with_sale() -> void:
	var sale_price: float = 75.0
	var initial_cash: float = _economy.get_cash()
	var item_id: String = _item.instance_id

	assert_eq(
		_time.current_day, 1,
		"Should start on day 1"
	)
	assert_eq(
		_time.current_phase, TimeSystem.DayPhase.PRE_OPEN,
		"Should start in PRE_OPEN phase"
	)

	_advance_time(120.0)

	assert_eq(
		_time.current_phase, TimeSystem.DayPhase.MORNING_RAMP,
		"Phase should be MORNING_RAMP after advancing past 540 min"
	)
	assert_true(
		_phase_signals.has(TimeSystem.DayPhase.MORNING_RAMP),
		"day_phase_changed should have fired for MORNING_RAMP"
	)

	var customer: Customer = _make_customer()
	_checkout.initiate_sale(customer, _item, sale_price)
	_force_complete_checkout()

	assert_eq(
		_sold_signals.size(), 1,
		"item_sold should fire exactly once"
	)
	assert_eq(
		_sold_signals[0]["item_id"], item_id,
		"item_sold should carry correct item_id"
	)
	assert_almost_eq(
		_sold_signals[0]["price"] as float, sale_price, 0.01,
		"item_sold should carry correct price"
	)
	assert_false(
		_inventory._items.has(item_id),
		"Item should be removed from inventory after sale"
	)
	assert_almost_eq(
		_economy.get_cash(), initial_cash + sale_price, 0.01,
		"Cash should increase by sale price"
	)

	_advance_time(720.0)

	assert_eq(
		_day_ended_days.size(), 1,
		"day_ended should fire exactly once"
	)
	assert_eq(
		_day_ended_days[0], 1,
		"day_ended should carry day 1"
	)

	assert_eq(
		_economy.get_items_sold_today(), 1,
		"Economy should track 1 item sold today"
	)

	var summary: Dictionary = _economy.get_daily_summary()
	assert_true(
		summary["items_sold"] as int >= 1,
		"Daily summary should include at least 1 item sold"
	)
	assert_true(
		(summary["total_revenue"] as float) >= sale_price - 0.01,
		"Daily summary revenue should include the sale"
	)

	var store_revenue: float = _economy.get_store_daily_revenue(
		"pocket_creatures"
	)
	assert_almost_eq(
		store_revenue, sale_price, 0.01,
		"Store daily revenue should match the sale price"
	)


func test_time_phases_progress_through_full_day() -> void:
	_advance_time(840.0)

	assert_true(
		_phase_signals.has(TimeSystem.DayPhase.MORNING_RAMP),
		"Should have transitioned through MORNING_RAMP"
	)
	assert_true(
		_phase_signals.has(TimeSystem.DayPhase.MIDDAY_RUSH),
		"Should have transitioned through MIDDAY_RUSH"
	)
	assert_true(
		_phase_signals.has(TimeSystem.DayPhase.AFTERNOON),
		"Should have transitioned through AFTERNOON"
	)
	assert_true(
		_phase_signals.has(TimeSystem.DayPhase.EVENING),
		"Should have transitioned through EVENING"
	)
	assert_eq(
		_day_ended_days.size(), 1,
		"day_ended should fire at end of day"
	)


func test_inventory_decremented_after_sale_and_day_end() -> void:
	var item_id: String = _item.instance_id
	assert_true(
		_inventory._items.has(item_id),
		"Item should exist before sale"
	)

	var customer: Customer = _make_customer()
	_checkout.initiate_sale(customer, _item, 50.0)
	_force_complete_checkout()

	assert_false(
		_inventory._items.has(item_id),
		"Item should not exist after sale"
	)
	assert_eq(
		_inventory.get_item_count(), 0,
		"Inventory count should be 0 after selling the only item"
	)

	_advance_time(840.0)

	assert_false(
		_inventory._items.has(item_id),
		"Item should still not exist after day ends"
	)


func test_economy_daily_reset_on_new_day() -> void:
	var customer: Customer = _make_customer()
	_checkout.initiate_sale(customer, _item, 60.0)
	_force_complete_checkout()

	assert_eq(
		_economy.get_items_sold_today(), 1,
		"Should have 1 item sold before day end"
	)

	_advance_time(840.0)

	assert_eq(
		_day_ended_days.size(), 1,
		"day_ended should have fired"
	)

	_time.advance_to_next_day()

	assert_eq(
		_economy.get_items_sold_today(), 0,
		"Items sold should reset to 0 after new day starts"
	)
	assert_eq(
		_economy.get_store_daily_revenue("pocket_creatures"), 0.0,
		"Store daily revenue should reset after new day"
	)


func test_day_ended_summary_contains_transaction() -> void:
	var sale_price: float = 99.0
	var customer: Customer = _make_customer()
	_checkout.initiate_sale(customer, _item, sale_price)
	_force_complete_checkout()

	_advance_time(840.0)

	assert_eq(
		_day_ended_days.size(), 1,
		"day_ended should fire"
	)

	var summary: Dictionary = _economy.get_daily_summary()
	assert_true(
		summary.has("transaction_count"),
		"Summary should have transaction_count"
	)
	assert_true(
		(summary["transaction_count"] as int) >= 1,
		"Summary should have at least 1 transaction"
	)
	assert_true(
		(summary["total_revenue"] as float) >= sale_price - 0.01,
		"Summary total_revenue should include the sale"
	)
	assert_true(
		(summary["items_sold"] as int) >= 1,
		"Summary should show at least 1 item sold"
	)
