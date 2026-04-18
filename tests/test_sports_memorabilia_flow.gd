## Integration test: Sports Memorabilia store flow — authentication, haggle, and sale.
extends GutTest


const STARTING_CASH: float = 500.0
const ITEM_BASE_PRICE: float = 50.0
const ITEM_STICKER_PRICE: float = 160.0
const HAGGLE_FLOOR_RATIO: float = 0.5

var _economy: EconomySystem
var _inventory: InventorySystem
var _auth: AuthenticationSystem
var _haggle: HaggleSystem
var _reputation: ReputationSystem

var _definition: ItemDefinition
var _suspicious_definition: ItemDefinition

var _auth_signals: Array[Dictionary] = []
var _item_sold_signals: Array[Dictionary] = []
var _customer_purchased_signals: Array[Dictionary] = []


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_auth = AuthenticationSystem.new()
	_auth.initialize(_inventory, _economy)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)

	_haggle = HaggleSystem.new()
	add_child_autofree(_haggle)
	_haggle.initialize(_reputation)

	_definition = _make_definition("test_sports_card", false)
	_suspicious_definition = _make_definition("test_suspicious_card", true)

	_auth_signals.clear()
	_item_sold_signals.clear()
	_customer_purchased_signals.clear()

	EventBus.authentication_completed.connect(_on_auth_completed)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.customer_purchased.connect(_on_customer_purchased)


func after_each() -> void:
	_safe_disconnect(EventBus.authentication_completed, _on_auth_completed)
	_safe_disconnect(EventBus.item_sold, _on_item_sold)
	_safe_disconnect(EventBus.customer_purchased, _on_customer_purchased)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_auth_completed(
	instance_id: Variant, success: bool, message: Variant = ""
) -> void:
	_auth_signals.append({
		"instance_id": String(instance_id),
		"success": success,
		"message": str(message),
	})


func _on_item_sold(
	item_id: String, price: float, category: String
) -> void:
	_item_sold_signals.append({
		"item_id": item_id,
		"price": price,
		"category": category,
	})


func _on_customer_purchased(
	store_id: StringName,
	item_id: StringName,
	price: float,
	_customer_id: StringName,
) -> void:
	_customer_purchased_signals.append({
		"store_id": store_id,
		"item_id": item_id,
		"price": price,
	})


func _make_definition(
	def_id: String, suspicious: bool
) -> ItemDefinition:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = def_id
	def.item_name = "Test Sports Card"
	def.category = "trading_cards"
	def.store_type = "sports"
	def.base_price = ITEM_BASE_PRICE
	def.rarity = "rare"
	def.suspicious_chance = 1.0 if suspicious else 0.0
	def.condition_range = PackedStringArray(["good"])
	def.tags = PackedStringArray([])
	return def


func _make_item(
	definition: ItemDefinition,
	auth_status: String = "none",
) -> ItemInstance:
	var item: ItemInstance = ItemInstance.create_from_definition(
		definition, "good"
	)
	item.authentication_status = auth_status
	item.player_set_price = ITEM_STICKER_PRICE
	_inventory._items[item.instance_id] = item
	return item


func _make_customer() -> Customer:
	var scene: PackedScene = preload(
		"res://game/scenes/characters/customer.tscn"
	)
	var customer: Customer = scene.instantiate()
	add_child_autofree(customer)
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "test_buyer"
	profile.customer_name = "Test Buyer"
	profile.budget_range = [50.0, 600.0]
	profile.patience = 1.0
	profile.price_sensitivity = 0.2
	profile.preferred_categories = PackedStringArray(["trading_cards"])
	profile.preferred_tags = PackedStringArray([])
	profile.condition_preference = "good"
	profile.browse_time_range = [30.0, 60.0]
	profile.purchase_probability_base = 1.0
	profile.impulse_buy_chance = 0.0
	profile.max_price_to_market_ratio = 5.0
	profile.mood_tags = PackedStringArray([])
	customer.profile = profile
	return customer


func _get_auth_market_value(item: ItemInstance) -> float:
	return _economy.calculate_market_value(item)


func _get_floor_ratio() -> float:
	if GameManager.data_loader:
		var cfg: EconomyConfig = GameManager.data_loader.get_economy_config()
		if cfg:
			return cfg.haggle_floor_ratio
	return HAGGLE_FLOOR_RATIO


# --- Scenario A: Authenticated item — haggle and sale ---


func test_a1_authentication_sets_authenticated_flag() -> void:
	var item: ItemInstance = _make_item(_definition)
	assert_eq(
		item.authentication_status, "none",
		"Item should start with 'none' authentication status"
	)
	var result: bool = _auth.authenticate(item.instance_id)
	assert_true(result, "authenticate() should return true for eligible item")
	assert_eq(
		item.authentication_status, "authenticated",
		"authentication_status should be 'authenticated' after successful auth"
	)


func test_a2_authentication_completed_signal_on_success() -> void:
	var item: ItemInstance = _make_item(_definition)
	_auth.authenticate(item.instance_id)
	assert_eq(
		_auth_signals.size(), 1,
		"authentication_completed should be emitted exactly once"
	)
	assert_eq(
		_auth_signals[0]["instance_id"], item.instance_id,
		"Signal instance_id should match the authenticated item"
	)
	assert_true(
		_auth_signals[0]["success"],
		"Signal success should be true on successful authentication"
	)


func test_a3_authentication_deducts_fee_from_economy() -> void:
	var item: ItemInstance = _make_item(_definition)
	var cash_before: float = _economy.get_cash()
	_auth.authenticate(item.instance_id)
	var deducted: float = cash_before - _economy.get_cash()
	assert_almost_eq(
		deducted, _auth.get_auth_fee(), 0.01,
		"Auth fee should be deducted from economy cash"
	)


func test_a4_market_value_applies_auth_multiplier_from_config() -> void:
	var item: ItemInstance = _make_item(_definition)
	var value_before: float = _economy.calculate_market_value(item)
	_auth.authenticate(item.instance_id)
	var value_after: float = _economy.calculate_market_value(item)
	assert_gt(value_before, 0.0, "Item value before auth must be positive")
	var actual_multiplier: float = value_after / value_before
	assert_almost_eq(
		actual_multiplier, _auth.get_auth_multiplier(), 0.01,
		"Authenticated market value should apply auth_multiplier (%.1f)"
		% _auth.get_auth_multiplier()
	)


func test_a5_pricing_config_authentication_bonus_is_positive() -> void:
	if not GameManager.data_loader:
		pass_test("DataLoader unavailable; skip pricing_config validation")
		return
	var cfg: EconomyConfig = GameManager.data_loader.get_economy_config()
	if not cfg:
		pass_test("EconomyConfig unavailable; skip pricing_config validation")
		return
	assert_gt(
		cfg.authentication_price_bonus, 0.0,
		"authentication_price_bonus from pricing_config.json must be positive"
	)


func test_a6_haggle_opening_offer_below_sticker_price() -> void:
	var item: ItemInstance = _make_item(_definition)
	_auth.authenticate(item.instance_id)
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, item)
	var opening_offer: float = _haggle._current_customer_offer
	assert_lt(
		opening_offer, item.player_set_price,
		"Opening offer $%.2f should be below sticker $%.2f"
		% [opening_offer, item.player_set_price]
	)
	assert_gt(opening_offer, 0.0, "Opening offer must be positive")
	_haggle.decline_offer()


func test_a7_counter_at_floor_ratio_times_auth_price_accepted() -> void:
	var item: ItemInstance = _make_item(_definition)
	_auth.authenticate(item.instance_id)
	var auth_price: float = _get_auth_market_value(item)
	var counter_price: float = _get_floor_ratio() * auth_price
	assert_gt(auth_price, 0.0, "Authenticated market value must be positive")

	var accepted: Array = [false]
	var customer: Customer = _make_customer()
	_haggle.negotiation_accepted.connect(
		func(_price: float) -> void: accepted[0] = true
	)
	_haggle.begin_negotiation(customer, item)
	_haggle.player_counter(counter_price)
	assert_true(
		accepted[0],
		"Counter at floor_ratio × auth_price ($%.2f) should be accepted"
		% counter_price
	)


func test_a8_final_negotiated_price_at_or_above_floor_ratio() -> void:
	var item: ItemInstance = _make_item(_definition)
	_auth.authenticate(item.instance_id)
	var auth_price: float = _get_auth_market_value(item)
	var floor_price: float = _get_floor_ratio() * auth_price

	var final_price: Array = [0.0]
	var customer: Customer = _make_customer()
	_haggle.negotiation_accepted.connect(
		func(price: float) -> void: final_price[0] = price
	)
	_haggle.begin_negotiation(customer, item)
	_haggle.player_counter(floor_price)
	assert_gte(
		final_price[0], floor_price - 0.01,
		"Final negotiated price $%.2f must be >= floor_ratio × auth_price $%.2f"
		% [final_price, floor_price]
	)


func test_a9_economy_cash_increases_by_negotiated_price() -> void:
	var item: ItemInstance = _make_item(_definition)
	_auth.authenticate(item.instance_id)
	var auth_price: float = _get_auth_market_value(item)
	var floor_price: float = _get_floor_ratio() * auth_price

	var final_price: Array = [0.0]
	var customer: Customer = _make_customer()
	_haggle.negotiation_accepted.connect(
		func(price: float) -> void: final_price[0] = price
	)
	_haggle.begin_negotiation(customer, item)
	_haggle.player_counter(floor_price)

	var cash_before: float = _economy.get_cash()
	EventBus.customer_purchased.emit(
		&"sports",
		StringName(item.instance_id),
		final_price[0],
		&"test_customer",
	)
	var cash_after: float = _economy.get_cash()
	assert_almost_eq(
		cash_after - cash_before, final_price[0], 0.01,
		"Economy cash should increase by final negotiated price $%.2f"
		% final_price[0]
	)


func test_a10_item_sold_signal_carries_correct_params() -> void:
	var item: ItemInstance = _make_item(_definition)
	_auth.authenticate(item.instance_id)
	var auth_price: float = _get_auth_market_value(item)
	var floor_price: float = _get_floor_ratio() * auth_price

	var final_price: Array = [0.0]
	var customer: Customer = _make_customer()
	_haggle.negotiation_accepted.connect(
		func(price: float) -> void: final_price[0] = price
	)
	_haggle.begin_negotiation(customer, item)
	_haggle.player_counter(floor_price)

	var item_id: String = item.instance_id
	var category: String = item.definition.category
	EventBus.item_sold.emit(item_id, final_price[0], category)

	assert_eq(
		_item_sold_signals.size(), 1,
		"item_sold should be emitted exactly once"
	)
	assert_eq(
		_item_sold_signals[0]["item_id"], item_id,
		"item_sold should carry correct item_id"
	)
	assert_almost_eq(
		_item_sold_signals[0]["price"], final_price[0], 0.01,
		"item_sold should carry correct final_price"
	)
	assert_eq(
		_item_sold_signals[0]["category"], category,
		"item_sold should carry correct category"
	)


# --- Scenario B: Suspicious item rejected at authentication ---


func test_b1_suspicious_item_fails_authentication() -> void:
	var item: ItemInstance = _make_item(_suspicious_definition, "suspicious")
	var result: bool = _auth.authenticate(item.instance_id)
	assert_false(
		result,
		"authenticate() should return false for suspicious item"
	)


func test_b2_authentication_completed_emits_failure_for_suspicious() -> void:
	var item: ItemInstance = _make_item(_suspicious_definition, "suspicious")
	_auth.authenticate(item.instance_id)
	assert_eq(
		_auth_signals.size(), 1,
		"authentication_completed should be emitted for suspicious item"
	)
	assert_false(
		_auth_signals[0]["success"],
		"authentication_completed success should be false for suspicious item"
	)
	assert_false(
		_auth_signals[0]["instance_id"].is_empty(),
		"authentication_completed should carry the item instance_id"
	)


func test_b3_suspicious_item_status_not_changed_to_authenticated() -> void:
	var item: ItemInstance = _make_item(_suspicious_definition, "suspicious")
	_auth.authenticate(item.instance_id)
	assert_ne(
		item.authentication_status, "authenticated",
		"Suspicious item must not become 'authenticated' after failed auth"
	)
	assert_eq(
		item.authentication_status, "suspicious",
		"Suspicious item authentication_status should remain 'suspicious'"
	)


func test_b4_suspicious_item_market_value_not_updated_with_bonus() -> void:
	var item: ItemInstance = _make_item(_suspicious_definition, "suspicious")
	var value_before: float = _economy.calculate_market_value(item)
	_auth.authenticate(item.instance_id)
	var value_after: float = _economy.calculate_market_value(item)
	assert_almost_eq(
		value_before, value_after, 0.01,
		"Suspicious item market value must NOT increase after failed authentication"
	)


func test_b5_suspicious_item_remains_in_inventory() -> void:
	var item: ItemInstance = _make_item(_suspicious_definition, "suspicious")
	_auth.authenticate(item.instance_id)
	var retrieved: ItemInstance = _inventory.get_item(item.instance_id)
	assert_not_null(
		retrieved,
		"Suspicious item should remain in inventory after failed authentication"
	)


func test_b6_no_fee_deducted_when_suspicious_auth_fails() -> void:
	var item: ItemInstance = _make_item(_suspicious_definition, "suspicious")
	var cash_before: float = _economy.get_cash()
	_auth.authenticate(item.instance_id)
	var cash_after: float = _economy.get_cash()
	assert_almost_eq(
		cash_before, cash_after, 0.01,
		"No authentication fee should be deducted when suspicious auth fails"
	)
