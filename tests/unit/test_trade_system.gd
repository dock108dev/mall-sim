## Unit tests for TradeSystem offer generation, acceptance, rejection, and signals.
extends GutTest


var _trade: TradeSystem
var _economy: EconomySystem
var _inventory: InventorySystem
var _reputation: ReputationSystem
var _data_loader: DataLoader

var _def_a: ItemDefinition
var _def_b: ItemDefinition
var _def_c: ItemDefinition
var _def_d: ItemDefinition
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
	_register_store_in_content_registry()
	_reputation.initialize_store("pocket_creatures")

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)

	_def_a = _make_definition("pc_card_alpha", "Alpha Card", 10.0, "common")
	_def_b = _make_definition("pc_card_beta", "Beta Card", 10.0, "common")
	# Candidates cover all random conditions: fair→10 (base 20), near_mint→10.5 (base 7).
	_def_c = _make_definition("pc_card_gamma", "Gamma Card", 20.0, "common")
	_def_d = _make_definition("pc_card_delta", "Delta Card", 7.0, "common")
	_data_loader._items["pc_card_alpha"] = _def_a
	_data_loader._items["pc_card_beta"] = _def_b
	_data_loader._items["pc_card_gamma"] = _def_c
	_data_loader._items["pc_card_delta"] = _def_d

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


func after_each() -> void:
	if _trade != null:
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
	if not started:
		_cleanup_customer(customer)
		return
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


func test_evaluate_offer_common_for_rare_is_unfair() -> void:
	var expensive_def: ItemDefinition = _make_definition(
		"pc_card_rare", "Rare Card", 10.0, "rare"
	)
	_data_loader._items["pc_card_rare"] = expensive_def

	var cheap_def: ItemDefinition = _make_definition(
		"pc_card_cheap", "Cheap Card", 10.0, "common"
	)
	_data_loader._items["pc_card_cheap"] = cheap_def

	var offer: Dictionary = {
		"npc_id": 1,
		"offered_cards": [
			ItemInstance.create(cheap_def, "good", 0, cheap_def.base_price),
		],
		"target_card": ItemInstance.create(
			expensive_def, "good", 0, expensive_def.base_price
		),
	}
	assert_eq(
		_trade.evaluate_offer(offer),
		TradeSystem.UNFAIR_CLASSIFICATION,
		"Common-for-rare offers should be classified as unfair"
	)


func test_accept_trade_fails_when_item_removed_from_inventory() -> void:
	var wanted: ItemInstance = _setup_active_trade()

	watch_signals(EventBus)
	assert_true(
		_inventory.remove_item(wanted.instance_id),
		"Setup should remove the target card from inventory"
	)
	var accepted: bool = _trade.accept_trade()

	assert_false(accepted, "Trade should fail when target card is missing")
	assert_signal_not_emitted(
		EventBus, "trade_accepted",
		"trade_accepted should not fire on failed accept"
	)
	assert_signal_emitted(
		EventBus, "trade_resolved",
		"trade_resolved should fire on failed accept"
	)
	var params: Array = get_signal_parameters(EventBus, "trade_resolved")
	if params.size() < 2:
		return
	assert_false(
		params[1] as bool,
		"trade_resolved accepted flag should be false on failed accept"
	)


func test_begin_trade_emits_trade_offer_received() -> void:
	var wanted: ItemInstance = ItemInstance.create(
		_def_a, "good", 0, _def_a.base_price
	)
	wanted.current_location = "shelf:slot_0"
	_inventory._items[wanted.instance_id] = wanted

	var customer: Customer = _make_customer()
	customer._desired_item = wanted
	customer._desired_item_slot = null

	watch_signals(EventBus)
	var started: bool = _trade.begin_trade(customer)

	assert_true(started, "begin_trade should return true with valid offer")
	if not started:
		_cleanup_customer(customer)
		return
	assert_signal_emitted(
		EventBus, "trade_offer_received",
		"trade_offer_received should fire when trade begins"
	)
	var params: Array = get_signal_parameters(EventBus, "trade_offer_received")
	if params.is_empty():
		_cleanup_customer(customer)
		return
	var offer: Dictionary = params[0] as Dictionary
	assert_true(offer.has("offered_cards"), "Offer should include offered_cards")
	assert_true(offer.has("target_card"), "Offer should include target_card")
	assert_true(offer.has("npc_id"), "Offer should include npc_id")
	_cleanup_customer(customer)


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
	def.tags = []
	def.condition_range = PackedStringArray(
		["fair", "good", "near_mint"]
	)
	return def


func _make_customer() -> Customer:
	var customer: Customer = Customer.new()
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
	_trade._active_offer = {
		"npc_id": customer.get_instance_id(),
		"offered_cards": [offered],
		"target_card": wanted,
	}
	return wanted


func _cleanup_customer(customer: Customer) -> void:
	if is_instance_valid(customer) and customer.is_inside_tree():
		customer.queue_free()


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _register_store_in_content_registry() -> void:
	if ContentRegistry.exists("pocket_creatures"):
		return
	ContentRegistry.register_entry(
		{
			"id": "pocket_creatures",
			"name": "Pocket Creatures",
			"scene_path": "",
			"backroom_capacity": 150,
		},
		"store"
	)
