## GUT unit tests for TradeSystem offer lifecycle, valuation, and resolution flow.
extends GutTest

const TEST_SIGNAL_UTILS: GDScript = preload("res://game/tests/test_signal_utils.gd")


var _trade: TradeSystem
var _economy: EconomySystem
var _inventory: InventorySystem
var _reputation: ReputationSystem
var _data_loader: DataLoader
var _panel: TradePanel

var _wanted_def: ItemDefinition
var _good_offer_def: ItemDefinition
var _fair_offer_def: ItemDefinition
var _near_mint_offer_def: ItemDefinition
var _rare_def: ItemDefinition
var _common_def: ItemDefinition
var _profile: CustomerTypeDefinition

var _trade_offer_received_signals: Array[Dictionary] = []
var _trade_resolved_signals: Array[Dictionary] = []


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(5000.0)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_register_store_in_content_registry()
	_reputation.initialize_store("pocket_creatures")

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)

	_wanted_def = _make_item_def("pc_target_card", "Target Card", 10.0, "common")
	_good_offer_def = _make_item_def("pc_good_offer", "Good Offer", 10.0, "common")
	_fair_offer_def = _make_item_def("pc_fair_offer", "Fair Offer", 20.0, "common")
	_near_mint_offer_def = _make_item_def(
		"pc_near_mint_offer", "Near Mint Offer", 7.0, "common"
	)
	_rare_def = _make_item_def("pc_rare_card", "Rare Card", 10.0, "rare")
	_common_def = _make_item_def("pc_common_card", "Common Card", 10.0, "common")
	for item_def: ItemDefinition in [
		_wanted_def, _good_offer_def, _fair_offer_def,
		_near_mint_offer_def, _rare_def, _common_def,
	]:
		_data_loader._items[item_def.id] = item_def

	_panel = TradePanel.new()
	add_child_autofree(_panel)

	_trade = TradeSystem.new()
	_trade.initialize(_data_loader, _inventory, _economy, _reputation)
	_trade.set_trade_panel(_panel)

	_profile = CustomerTypeDefinition.new()
	_profile.id = TradeSystem.TRADER_PROFILE_ID
	_profile.customer_name = "Card Trader"
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

	_trade_offer_received_signals = []
	_trade_resolved_signals = []
	EventBus.trade_offer_received.connect(_on_trade_offer_received)
	EventBus.trade_resolved.connect(_on_trade_resolved)


func after_each() -> void:
	if _trade != null:
		TEST_SIGNAL_UTILS.safe_disconnect(EventBus.day_started, _trade._on_day_started)
	TEST_SIGNAL_UTILS.safe_disconnect(
		EventBus.trade_offer_received, _on_trade_offer_received
	)
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.trade_resolved, _on_trade_resolved)


func test_offer_construction_includes_required_fields() -> void:
	var setup: Dictionary = _begin_trade()
	assert_true(setup["started"], "begin_trade should succeed for a valid trader")
	if not bool(setup["started"]):
		return
	assert_eq(
		_trade_offer_received_signals.size(), 1,
		"trade_offer_received should fire when the NPC initiates a trade"
	)
	if _trade_offer_received_signals.is_empty():
		return
	var offer: Dictionary = _trade_offer_received_signals[0]
	assert_true(offer.has("offered_cards"), "Offer should include offered_cards")
	assert_true(offer.has("target_card"), "Offer should include target_card")
	assert_true(offer.has("npc_id"), "Offer should include npc_id")
	assert_eq(
		offer["npc_id"], setup["customer"].get_instance_id(),
		"Offer npc_id should match the initiating customer"
	)
	var offered_cards: Array[ItemInstance] = []
	offered_cards.assign(offer["offered_cards"])
	assert_eq(offered_cards.size(), 1, "Offer should include one offered card")
	assert_eq(
		(offer["target_card"] as ItemInstance).instance_id,
		(setup["wanted"] as ItemInstance).instance_id,
		"Offer target card should match the customer's requested card"
	)


func test_evaluate_offer_marks_common_for_rare_as_unfair() -> void:
	var offer: Dictionary = {
		"npc_id": 42,
		"offered_cards": [
			ItemInstance.create(_common_def, "good", 1, _common_def.base_price),
		],
		"target_card": ItemInstance.create(_rare_def, "good", 1, _rare_def.base_price),
	}
	assert_eq(
		_trade.evaluate_offer(offer),
		TradeSystem.UNFAIR_CLASSIFICATION,
		"Trading a common card for a rare card should be unfair"
	)


func test_accept_trade_moves_cards_between_inventories() -> void:
	var setup: Dictionary = _setup_active_trade()
	var wanted: ItemInstance = setup["wanted"]
	var offered: ItemInstance = setup["offered"]
	assert_true(
		_trade.accept_trade(),
		"accept_trade should succeed when the player still owns the target card"
	)
	assert_false(
		_inventory._items.has(wanted.instance_id),
		"Accepting should remove the player's target card from inventory"
	)
	assert_true(
		_inventory._items.has(offered.instance_id),
		"Accepting should add the offered card to inventory"
	)
	assert_eq(
		offered.current_location, "backroom",
		"Accepted cards should enter the player's backroom inventory"
	)


func test_decline_trade_leaves_inventories_unchanged() -> void:
	var setup: Dictionary = _setup_active_trade()
	var wanted: ItemInstance = setup["wanted"]
	var offered: ItemInstance = setup["offered"]
	var inventory_count_before: int = _inventory._items.size()
	assert_true(
		_trade.decline_trade(),
		"decline_trade should succeed while a trade is active"
	)
	assert_eq(
		_inventory._items.size(), inventory_count_before,
		"Declining should not change the player's inventory count"
	)
	assert_true(
		_inventory._items.has(wanted.instance_id),
		"Declining should keep the target card in inventory"
	)
	assert_false(
		_inventory._items.has(offered.instance_id),
		"Declining should not add the NPC's offered card to inventory"
	)


func test_trade_offer_received_signal_fires_on_begin_trade() -> void:
	var setup: Dictionary = _begin_trade()
	assert_true(setup["started"], "begin_trade should create an offer")
	if not bool(setup["started"]):
		return
	assert_eq(
		_trade_offer_received_signals.size(), 1,
		"trade_offer_received should fire exactly once"
	)
	if _trade_offer_received_signals.is_empty():
		return
	var offer: Dictionary = _trade_offer_received_signals[0]
	var offered_cards: Array[ItemInstance] = []
	offered_cards.assign(offer["offered_cards"])
	assert_eq(
		offered_cards[0].instance_id,
		_trade._offered_item.instance_id,
		"Signal payload should include the offered card instance"
	)


func test_trade_resolved_signal_reports_accept_and_decline_outcomes() -> void:
	_setup_active_trade()
	assert_true(_trade.accept_trade(), "accept_trade should resolve successfully")
	assert_eq(
		_trade_resolved_signals.size(), 1,
		"trade_resolved should fire after accepting"
	)
	assert_true(
		_trade_resolved_signals[0]["accepted"],
		"Resolved signal should report accepted=true for successful accept"
	)

	_trade_resolved_signals.clear()
	_setup_active_trade()
	assert_true(_trade.decline_trade(), "decline_trade should resolve successfully")
	assert_eq(
		_trade_resolved_signals.size(), 1,
		"trade_resolved should fire after declining"
	)
	assert_false(
		_trade_resolved_signals[0]["accepted"],
		"Resolved signal should report accepted=false for decline"
	)


func test_accept_trade_fails_cleanly_when_player_no_longer_owns_target_card() -> void:
	var setup: Dictionary = _setup_active_trade()
	var wanted: ItemInstance = setup["wanted"]
	var offered: ItemInstance = setup["offered"]
	assert_true(
		_inventory.remove_item(wanted.instance_id),
		"Test setup should remove the target card from inventory"
	)
	assert_false(
		_trade.accept_trade(),
		"accept_trade should fail when the player no longer owns the target card"
	)
	assert_false(
		_inventory._items.has(offered.instance_id),
		"Failed accept should not add the offered card to inventory"
	)
	assert_false(_trade.is_active(), "Trade should be cleared after a failed accept")
	assert_eq(
		_trade_resolved_signals.size(), 1,
		"trade_resolved should still fire for a failed accept"
	)
	assert_false(
		_trade_resolved_signals[0]["accepted"],
		"Failed accept should resolve as accepted=false"
	)


func _make_item_def(
	id: String, item_name: String, base_price: float, rarity: String
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = item_name
	def.category = "cards"
	def.base_price = base_price
	def.rarity = rarity
	def.tags = []
	def.condition_range = PackedStringArray(
		["fair", "good", "near_mint"]
	)
	def.store_type = "pocket_creatures"
	return def


func _make_customer() -> Customer:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer


func _begin_trade() -> Dictionary:
	var wanted: ItemInstance = ItemInstance.create(
		_wanted_def, "good", 1, _wanted_def.base_price
	)
	wanted.current_location = "shelf:slot_0"
	_inventory._items[wanted.instance_id] = wanted
	var customer: Customer = _make_customer()
	customer._desired_item = wanted
	customer._desired_item_slot = null
	return {
		"started": _trade.begin_trade(customer),
		"customer": customer,
		"wanted": wanted,
	}


func _setup_active_trade() -> Dictionary:
	var wanted: ItemInstance = ItemInstance.create(
		_wanted_def, "good", 1, _wanted_def.base_price
	)
	wanted.current_location = "shelf:slot_0"
	_inventory._items[wanted.instance_id] = wanted
	var offered: ItemInstance = ItemInstance.create(
		_good_offer_def, "good", 1, _good_offer_def.base_price
	)
	var customer: Customer = _make_customer()
	customer._desired_item = wanted
	customer._desired_item_slot = null
	_trade._active_customer = customer
	_trade._wanted_item = wanted
	_trade._wanted_item_slot = null
	_trade._offered_item = offered
	_trade._active_offer = {
		"npc_id": customer.get_instance_id(),
		"offered_cards": [offered],
		"target_card": wanted,
	}
	return {
		"customer": customer,
		"wanted": wanted,
		"offered": offered,
	}


func _on_trade_offer_received(offer: Dictionary) -> void:
	_trade_offer_received_signals.append(offer)


func _on_trade_resolved(offer: Dictionary, accepted: bool) -> void:
	_trade_resolved_signals.append({
		"offer": offer,
		"accepted": accepted,
	})


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
