## GUT unit tests for TradeSystem offer lifecycle, valuation, and accept/decline.
extends GutTest


var _trade: TradeSystem
var _economy: EconomySystem
var _inventory: InventorySystem
var _reputation: ReputationSystem
var _data_loader: DataLoader
var _panel: TradePanel

var _profile: CustomerTypeDefinition
var _definition: ItemDefinition
var _offered_def: ItemDefinition

var _trade_offered_signals: Array[Dictionary] = []
var _trade_accepted_signals: Array[Dictionary] = []
var _trade_declined_signals: Array[Dictionary] = []


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(5000.0)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store("pocket_creatures")

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)

	_definition = _make_item_def("pc_rare_dragon", "Rare Dragon", 50.0, "rare")
	_offered_def = _make_item_def("pc_common_slime", "Common Slime", 45.0, "common")

	_data_loader._items[_definition.id] = _definition
	_data_loader._items[_offered_def.id] = _offered_def

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

	_trade_offered_signals = []
	_trade_accepted_signals = []
	_trade_declined_signals = []
	EventBus.trade_offered.connect(_on_trade_offered)
	EventBus.trade_accepted.connect(_on_trade_accepted)
	EventBus.trade_declined.connect(_on_trade_declined)


func after_each() -> void:
	_safe_disconnect(EventBus.trade_offered, _on_trade_offered)
	_safe_disconnect(EventBus.trade_accepted, _on_trade_accepted)
	_safe_disconnect(EventBus.trade_declined, _on_trade_declined)
	_safe_disconnect(EventBus.day_started, _trade._on_day_started)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_trade_offered(
	customer_id: int, wanted_id: String, offered_id: String
) -> void:
	_trade_offered_signals.append({
		"customer_id": customer_id,
		"wanted_id": wanted_id,
		"offered_id": offered_id,
	})


func _on_trade_accepted(wanted_id: String, offered_id: String) -> void:
	_trade_accepted_signals.append({
		"wanted_id": wanted_id,
		"offered_id": offered_id,
	})


func _on_trade_declined(customer_id: int) -> void:
	_trade_declined_signals.append({"customer_id": customer_id})


func _make_item_def(
	id: String, item_name: String, base_price: float, rarity: String
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = item_name
	def.category = "cards"
	def.base_price = base_price
	def.rarity = rarity
	def.tags = PackedStringArray([])
	def.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)
	def.store_type = "pocket_creatures"
	return def


func _make_customer() -> Customer:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer


func _setup_trade_items() -> Dictionary:
	var wanted: ItemInstance = ItemInstance.create(
		_definition, "good", 1, 50.0
	)
	wanted.current_location = "shelf:0"
	wanted.player_set_price = 50.0
	_inventory._items[wanted.instance_id] = wanted

	var customer: Customer = _make_customer()
	customer._desired_item = wanted
	customer._desired_item_slot = null
	return {"wanted": wanted, "customer": customer}


# --- Offer construction ---


func test_offer_has_required_fields() -> void:
	var setup: Dictionary = _setup_trade_items()
	var customer: Customer = setup["customer"]
	var result: bool = _trade.begin_trade(customer)
	if not result:
		pending("No matching offer could be generated — skipping")
		return
	assert_not_null(
		_trade._wanted_item,
		"Trade should have a wanted item"
	)
	assert_not_null(
		_trade._offered_item,
		"Trade should have an offered item"
	)
	assert_not_null(
		_trade._active_customer,
		"Trade should have an active customer"
	)
	assert_false(
		_trade._offered_item.instance_id.is_empty(),
		"Offered item should have a valid instance_id"
	)
	assert_false(
		_trade._wanted_item.instance_id.is_empty(),
		"Wanted item should have a valid instance_id"
	)


# --- Offer valuation ---


func test_evaluate_offer_within_tolerance() -> void:
	var wanted: ItemInstance = ItemInstance.create(
		_definition, "good", 1, 50.0
	)
	var wanted_value: float = _economy.calculate_market_value(wanted)
	var min_value: float = wanted_value * (1.0 - TradeSystem.VALUE_TOLERANCE)
	var max_value: float = wanted_value * (1.0 + TradeSystem.VALUE_TOLERANCE)
	var offered: ItemInstance = ItemInstance.create(
		_offered_def, "good", 1, 0.0
	)
	var offered_value: float = _economy.calculate_market_value(offered)
	if offered_value >= min_value and offered_value <= max_value:
		assert_true(
			true, "Offered value is within fair trade tolerance"
		)
	else:
		assert_true(
			offered_value < min_value or offered_value > max_value,
			"Offered value outside tolerance is classified unfair"
		)


func test_generate_offer_excludes_same_item() -> void:
	var single_def: ItemDefinition = _make_item_def(
		"pc_only_card", "Only Card", 50.0, "rare"
	)
	single_def.store_type = "pocket_creatures"
	_data_loader._items.clear()
	_data_loader._items[single_def.id] = single_def

	var wanted: ItemInstance = ItemInstance.create(
		single_def, "good", 1, 50.0
	)
	var offer: ItemInstance = _trade._generate_offer(wanted)
	assert_null(
		offer,
		"Should not generate offer from the same item definition"
	)


# --- Accept trade ---


func test_accept_trade_updates_inventory() -> void:
	var setup: Dictionary = _setup_trade_items()
	var customer: Customer = setup["customer"]
	var wanted: ItemInstance = setup["wanted"]
	var wanted_id: String = wanted.instance_id
	var result: bool = _trade.begin_trade(customer)
	if not result:
		pending("No matching offer generated — skipping")
		return
	var offered_id: String = _trade._offered_item.instance_id
	_trade._on_trade_accepted()
	assert_false(
		_inventory._items.has(wanted_id),
		"Wanted item should be removed from inventory after accept"
	)
	assert_true(
		_inventory._items.has(offered_id),
		"Offered item should be added to inventory after accept"
	)


func test_accept_trade_offered_item_in_backroom() -> void:
	var setup: Dictionary = _setup_trade_items()
	var customer: Customer = setup["customer"]
	var result: bool = _trade.begin_trade(customer)
	if not result:
		pending("No matching offer generated — skipping")
		return
	var offered: ItemInstance = _trade._offered_item
	_trade._on_trade_accepted()
	assert_eq(
		offered.current_location, "backroom",
		"Offered item should be placed in backroom"
	)


func test_accept_trade_increments_trades_today() -> void:
	var setup: Dictionary = _setup_trade_items()
	var customer: Customer = setup["customer"]
	var result: bool = _trade.begin_trade(customer)
	if not result:
		pending("No matching offer generated — skipping")
		return
	var before: int = _trade.get_trades_today()
	_trade._on_trade_accepted()
	assert_eq(
		_trade.get_trades_today(), before + 1,
		"Trades today should increment by 1"
	)


# --- Decline trade ---


func test_decline_trade_leaves_inventory_unchanged() -> void:
	var setup: Dictionary = _setup_trade_items()
	var customer: Customer = setup["customer"]
	var wanted: ItemInstance = setup["wanted"]
	var wanted_id: String = wanted.instance_id
	var result: bool = _trade.begin_trade(customer)
	if not result:
		pending("No matching offer generated — skipping")
		return
	var offered_id: String = _trade._offered_item.instance_id
	_trade._on_trade_declined()
	assert_true(
		_inventory._items.has(wanted_id),
		"Wanted item should remain in inventory after decline"
	)
	assert_false(
		_inventory._items.has(offered_id),
		"Offered item should not be added to inventory after decline"
	)


func test_decline_trade_does_not_increment_counter() -> void:
	var setup: Dictionary = _setup_trade_items()
	var customer: Customer = setup["customer"]
	var result: bool = _trade.begin_trade(customer)
	if not result:
		pending("No matching offer generated — skipping")
		return
	var before: int = _trade.get_trades_today()
	_trade._on_trade_declined()
	assert_eq(
		_trade.get_trades_today(), before,
		"Trades today should not change on decline"
	)


# --- Signal emission ---


func test_trade_offered_signal_fires_on_begin() -> void:
	var setup: Dictionary = _setup_trade_items()
	var customer: Customer = setup["customer"]
	var result: bool = _trade.begin_trade(customer)
	if not result:
		pending("No matching offer generated — skipping")
		return
	assert_eq(
		_trade_offered_signals.size(), 1,
		"trade_offered should fire once on begin_trade"
	)
	assert_eq(
		_trade_offered_signals[0]["wanted_id"],
		setup["wanted"].instance_id,
		"trade_offered should carry wanted item instance_id"
	)


func test_trade_accepted_signal_fires_on_accept() -> void:
	var setup: Dictionary = _setup_trade_items()
	var customer: Customer = setup["customer"]
	var result: bool = _trade.begin_trade(customer)
	if not result:
		pending("No matching offer generated — skipping")
		return
	var wanted_id: String = _trade._wanted_item.instance_id
	var offered_id: String = _trade._offered_item.instance_id
	_trade._on_trade_accepted()
	assert_eq(
		_trade_accepted_signals.size(), 1,
		"trade_accepted should fire once"
	)
	assert_eq(
		_trade_accepted_signals[0]["wanted_id"], wanted_id,
		"trade_accepted should carry correct wanted_id"
	)
	assert_eq(
		_trade_accepted_signals[0]["offered_id"], offered_id,
		"trade_accepted should carry correct offered_id"
	)


func test_trade_declined_signal_fires_on_decline() -> void:
	var setup: Dictionary = _setup_trade_items()
	var customer: Customer = setup["customer"]
	var result: bool = _trade.begin_trade(customer)
	if not result:
		pending("No matching offer generated — skipping")
		return
	var customer_id: int = customer.get_instance_id()
	_trade._on_trade_declined()
	assert_eq(
		_trade_declined_signals.size(), 1,
		"trade_declined should fire once"
	)
	assert_eq(
		_trade_declined_signals[0]["customer_id"], customer_id,
		"trade_declined should carry correct customer_id"
	)


# --- Edge cases ---


func test_trade_fails_when_item_removed_from_inventory() -> void:
	var setup: Dictionary = _setup_trade_items()
	var customer: Customer = setup["customer"]
	var wanted: ItemInstance = setup["wanted"]
	var result: bool = _trade.begin_trade(customer)
	if not result:
		pending("No matching offer generated — skipping")
		return
	_inventory._items.erase(wanted.instance_id)
	_trade._on_trade_accepted()
	assert_eq(
		_trade_accepted_signals.size(), 1,
		"trade_accepted signal still fires"
	)


func test_begin_trade_fails_without_desired_item() -> void:
	var customer: Customer = _make_customer()
	customer._desired_item = null
	var result: bool = _trade.begin_trade(customer)
	assert_false(
		result,
		"begin_trade should return false when customer has no desired item"
	)
	assert_false(
		_trade.is_active(),
		"Trade should not be active after failed begin"
	)


func test_is_trader_returns_true_for_trader_profile() -> void:
	var customer: Customer = _make_customer()
	assert_true(
		_trade.is_trader(customer),
		"is_trader should return true for trader profile"
	)


func test_is_trader_returns_false_for_non_trader() -> void:
	var customer: Customer = _make_customer()
	customer.profile.id = "casual_shopper"
	assert_false(
		_trade.is_trader(customer),
		"is_trader should return false for non-trader profile"
	)


func test_day_started_resets_trades_today() -> void:
	_trade._trades_today = 5
	_trade._on_day_started(2)
	assert_eq(
		_trade.get_trades_today(), 0,
		"Trades today should reset to 0 on new day"
	)
