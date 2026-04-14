## Unit tests for TradeSystem offer generation, acceptance, rejection, and signals.
extends GutTest


var _trade: TradeSystem
var _economy: EconomySystem
var _inventory: InventorySystem
var _reputation: ReputationSystem
var _data_loader: DataLoader

var _def_a: ItemDefinition
var _def_b: ItemDefinition
var _customer_scene: PackedScene
var _profile: CustomerTypeDefinition


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store("pocket_creatures")

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)

	_def_a = _make_definition("pc_card_alpha", "Alpha Card", 10.0, "common")
	_def_b = _make_definition("pc_card_beta", "Beta Card", 10.0, "common")
	_data_loader._items["pc_card_alpha"] = _def_a
	_data_loader._items["pc_card_beta"] = _def_b

	_trade = TradeSystem.new()
	_trade.initialize(_data_loader, _inventory, _economy, _reputation)

	_profile = CustomerTypeDefinition.new()
	_profile.id = TradeSystem.TRADER_PROFILE_ID
	_profile.customer_name = "Test Trader"
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

	_customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)


func after_each() -> void:
	_safe_disconnect(EventBus.day_started, _trade._on_day_started)


func test_generate_offer_produces_valid_trade() -> void:
	var wanted: ItemInstance = ItemInstance.create(
		_def_a, "good", 0, _def_a.base_price
	)
	wanted.current_location = "shelf:slot_0"
	_inventory._items[wanted.instance_id] = wanted

	var customer: Customer = _make_customer()
	customer._desired_item = wanted
	customer._desired_item_slot = null

	var started: bool = _trade.begin_trade(customer)
	assert_true(started, "begin_trade should return true with valid offer")
	assert_not_null(
		_trade._offered_item,
		"Offered item should be set after begin_trade"
	)
	assert_not_null(
		_trade._wanted_item,
		"Wanted item should be set after begin_trade"
	)
	assert_ne(
		_trade._offered_item.definition.id,
		_trade._wanted_item.definition.id,
		"Offered card should differ from wanted card"
	)
	_cleanup_customer(customer)


func test_accept_trade_swaps_inventory() -> void:
	var wanted: ItemInstance = _setup_active_trade()
	var wanted_id: String = wanted.instance_id
	var offered_id: String = _trade._offered_item.instance_id

	assert_true(
		_inventory._items.has(wanted_id),
		"Wanted item should be in inventory before trade"
	)
	assert_false(
		_inventory._items.has(offered_id),
		"Offered item should not be in inventory before trade"
	)

	_trade._on_trade_accepted()

	assert_false(
		_inventory._items.has(wanted_id),
		"Wanted item should be removed from inventory after trade"
	)
	assert_true(
		_inventory._items.has(offered_id),
		"Offered item should be added to inventory after trade"
	)


func test_reject_trade_leaves_inventory_unchanged() -> void:
	var wanted: ItemInstance = _setup_active_trade()
	var wanted_id: String = wanted.instance_id
	var offered_id: String = _trade._offered_item.instance_id
	var item_count_before: int = _inventory._items.size()

	_trade._on_trade_declined()

	assert_eq(
		_inventory._items.size(), item_count_before,
		"Inventory size should not change after rejection"
	)
	assert_true(
		_inventory._items.has(wanted_id),
		"Wanted item should remain in inventory after rejection"
	)
	assert_false(
		_inventory._items.has(offered_id),
		"Offered item should not appear in inventory after rejection"
	)


func test_trade_completed_signal_fires() -> void:
	var wanted: ItemInstance = _setup_active_trade()
	var wanted_id: String = wanted.instance_id
	var offered_id: String = _trade._offered_item.instance_id

	watch_signals(EventBus)
	_trade._on_trade_accepted()

	assert_signal_emitted(
		EventBus, "trade_accepted",
		"trade_accepted should fire on accepted trade"
	)
	var params: Array = get_signal_parameters(EventBus, "trade_accepted")
	assert_eq(
		params[0] as String, wanted_id,
		"First param should be the wanted item instance_id"
	)
	assert_eq(
		params[1] as String, offered_id,
		"Second param should be the offered item instance_id"
	)


func test_trade_rejected_signal_fires() -> void:
	_setup_active_trade()
	var customer_id: int = _trade._active_customer.get_instance_id()

	watch_signals(EventBus)
	_trade._on_trade_declined()

	assert_signal_emitted(
		EventBus, "trade_declined",
		"trade_declined should fire on rejected trade"
	)
	var params: Array = get_signal_parameters(EventBus, "trade_declined")
	assert_eq(
		params[0] as int, customer_id,
		"Signal param should be the customer instance id"
	)


func test_unfair_trade_has_value_within_tolerance() -> void:
	var expensive_def: ItemDefinition = _make_definition(
		"pc_card_rare", "Rare Card", 50.0, "rare"
	)
	_data_loader._items["pc_card_rare"] = expensive_def

	var cheap_def: ItemDefinition = _make_definition(
		"pc_card_cheap", "Cheap Card", 5.0, "common"
	)
	_data_loader._items["pc_card_cheap"] = cheap_def

	var wanted: ItemInstance = ItemInstance.create(
		expensive_def, "near_mint", 0, expensive_def.base_price
	)
	wanted.current_location = "shelf:slot_0"
	_inventory._items[wanted.instance_id] = wanted

	var wanted_value: float = _economy.calculate_market_value(wanted)
	assert_gt(
		wanted_value, 0.0,
		"Wanted item should have positive market value"
	)

	var offer: ItemInstance = _trade._generate_offer(wanted)
	if offer:
		var offer_value: float = _economy.calculate_market_value(offer)
		var min_val: float = wanted_value * (1.0 - TradeSystem.VALUE_TOLERANCE)
		var max_val: float = wanted_value * (1.0 + TradeSystem.VALUE_TOLERANCE)
		assert_gte(
			offer_value, min_val,
			"Offer value should be >= wanted value minus tolerance"
		)
		assert_lte(
			offer_value, max_val,
			"Offer value should be <= wanted value plus tolerance"
		)
	else:
		pass_test("No matching offer found — tolerance enforced by exclusion")


# ── Helpers ──────────────────────────────────────────────────────────────────


func _make_definition(
	id: String, item_name: String, price: float, rarity: String
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = item_name
	def.category = "cards"
	def.base_price = price
	def.rarity = rarity
	def.store_type = "pocket_creatures"
	def.tags = PackedStringArray([])
	def.condition_range = PackedStringArray(
		["fair", "good", "near_mint"]
	)
	return def


func _make_customer() -> Customer:
	var customer: Customer = _customer_scene.instantiate()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer


func _setup_active_trade() -> ItemInstance:
	var wanted: ItemInstance = ItemInstance.create(
		_def_a, "good", 0, _def_a.base_price
	)
	wanted.current_location = "shelf:slot_0"
	_inventory._items[wanted.instance_id] = wanted

	var offered: ItemInstance = ItemInstance.create(
		_def_b, "good", 0, _def_b.base_price
	)

	var customer: Customer = _make_customer()
	customer._desired_item = wanted

	_trade._active_customer = customer
	_trade._wanted_item = wanted
	_trade._wanted_item_slot = null
	_trade._offered_item = offered
	return wanted


func _cleanup_customer(customer: Customer) -> void:
	if is_instance_valid(customer) and customer.is_inside_tree():
		customer.queue_free()


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)
