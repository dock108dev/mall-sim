## GUT unit tests for HaggleSystem offer lifecycle, counter-offer limits,
## and signal contracts.
extends GutTest


var _haggle: HaggleSystem
var _reputation: ReputationSystem
var _profile: CustomerTypeDefinition
var _definition: ItemDefinition
var _item: ItemInstance
var _customer_scene: PackedScene


func before_each() -> void:
	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)

	_haggle = HaggleSystem.new()
	add_child_autofree(_haggle)
	_haggle.initialize(_reputation)

	_profile = CustomerTypeDefinition.new()
	_profile.id = "test_haggler"
	_profile.customer_name = "Test Haggler"
	_profile.budget_range = [5.0, 200.0]
	_profile.patience = 0.7
	_profile.price_sensitivity = 0.6
	_profile.preferred_categories = PackedStringArray(["cards"])
	_profile.preferred_tags = PackedStringArray([])
	_profile.condition_preference = "good"
	_profile.browse_time_range = [30.0, 60.0]
	_profile.purchase_probability_base = 0.8
	_profile.impulse_buy_chance = 0.1
	_profile.mood_tags = PackedStringArray([])

	_definition = ItemDefinition.new()
	_definition.id = "test_card"
	_definition.item_name = "Test Card"
	_definition.category = "cards"
	_definition.base_price = 50.0
	_definition.rarity = "common"
	_definition.tags = PackedStringArray([])
	_definition.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)

	_item = ItemInstance.create_from_definition(_definition, "good")
	_item.player_set_price = 65.0

	_customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)


func _make_customer() -> Customer:
	var customer: Customer = _customer_scene.instantiate()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer


# --- haggle_started signal contract ---


func test_haggle_started_fires_with_correct_item_id() -> void:
	var customer: Customer = _make_customer()
	var received_item_id: String = ""
	var received_cust_id: int = 0
	EventBus.haggle_started.connect(
		func(item_id: String, cust_id: int) -> void:
			received_item_id = item_id
			received_cust_id = cust_id
	)
	_haggle.begin_negotiation(customer, _item)
	assert_eq(
		received_item_id, _item.instance_id,
		"haggle_started should emit matching item_id"
	)
	assert_eq(
		received_cust_id, customer.get_instance_id(),
		"haggle_started should emit matching customer_id"
	)


func test_negotiation_started_fires_with_ask_price() -> void:
	var customer: Customer = _make_customer()
	var received_sticker: float = 0.0
	var received_offer: float = 0.0
	_haggle.negotiation_started.connect(
		func(
			_name: String, _cond: String, sticker: float,
			offer: float, _rounds: int
		) -> void:
			received_sticker = sticker
			received_offer = offer
	)
	_haggle.begin_negotiation(customer, _item)
	assert_eq(
		received_sticker, _item.player_set_price,
		"negotiation_started should emit sticker price as ask_price"
	)
	assert_true(
		received_offer > 0.0,
		"negotiation_started should emit a positive customer offer"
	)


# --- Below-floor offer auto-declined ---


func test_counter_below_floor_is_declined() -> void:
	_profile.price_sensitivity = 0.9
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var perceived: float = _haggle._perceived_value
	var above_walkaway: float = perceived * 3.0
	var failed: bool = false
	_haggle.negotiation_failed.connect(
		func() -> void: failed = true
	)
	_haggle.player_counter(above_walkaway)
	assert_true(
		failed,
		"Offer far above perceived value should be auto-declined"
	)
	assert_false(
		_haggle.is_active(),
		"Haggle should end after declined offer"
	)


func test_below_floor_fires_haggle_failed() -> void:
	_profile.patience = 0.1
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var received_item_id: String = ""
	EventBus.haggle_failed.connect(
		func(item_id: String, _cust_id: int) -> void:
			received_item_id = item_id
	)
	var extreme_price: float = _item.get_current_value() * 5.0
	_haggle.player_counter(extreme_price)
	assert_eq(
		received_item_id, _item.instance_id,
		"haggle_failed should fire with correct item_id on decline"
	)


# --- Above-floor offer auto-accepted ---


func test_counter_at_or_above_floor_is_accepted() -> void:
	_profile.price_sensitivity = 0.3
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var market_value: float = _item.get_current_value()
	var accepted: bool = false
	var final: float = 0.0
	_haggle.negotiation_accepted.connect(
		func(price: float) -> void:
			accepted = true
			final = price
	)
	_haggle.player_counter(market_value)
	assert_true(
		accepted,
		"Counter at market value should be accepted (low sensitivity)"
	)
	assert_almost_eq(
		final, market_value, 0.01,
		"Final price should equal the accepted counter-offer"
	)


func test_above_floor_fires_haggle_completed() -> void:
	_profile.price_sensitivity = 0.3
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var received_item_id: String = ""
	var received_price: float = 0.0
	EventBus.haggle_completed.connect(
		func(
			_sid: StringName, iid: StringName,
			price: float, _ask: float,
			_acc: bool, _cnt: int
		) -> void:
			received_item_id = iid
			received_price = price
	)
	var market_value: float = _item.get_current_value()
	_haggle.player_counter(market_value)
	assert_eq(
		received_item_id, _item.instance_id,
		"haggle_completed should fire with correct item_id"
	)
	assert_almost_eq(
		received_price, market_value, 0.01,
		"haggle_completed should fire with correct final_price"
	)


# --- Max counter-offers reached ---


func test_max_rounds_declines_further_offers() -> void:
	_profile.patience = 0.9
	_profile.price_sensitivity = 0.9
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var perceived: float = _haggle._perceived_value
	var moderate_price: float = perceived * 1.3
	var round_count: int = 0
	var failed: bool = false
	_haggle.negotiation_failed.connect(
		func() -> void: failed = true
	)
	for i: int in range(HaggleSystem.MAX_ROUNDS + 2):
		if not _haggle.is_active():
			break
		round_count += 1
		_haggle.player_counter(moderate_price)
	assert_true(
		failed,
		"Haggle should fail after max rounds exceeded"
	)
	assert_false(
		_haggle.is_active(),
		"Haggle must not be active after max rounds"
	)


func test_offers_declined_after_limit_regardless_of_price() -> void:
	_profile.patience = 0.1
	_profile.price_sensitivity = 0.9
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var max_rounds: int = _haggle._max_rounds_for_customer
	assert_eq(
		max_rounds, 2,
		"Impatient customer should have 2 max rounds"
	)
	var perceived: float = _haggle._perceived_value
	var moderate_offer: float = perceived * 1.3
	for i: int in range(max_rounds):
		if not _haggle.is_active():
			break
		_haggle.player_counter(moderate_offer)
	assert_false(
		_haggle.is_active(),
		"Haggle should terminate at round limit"
	)


# --- Resolved haggle signal contracts ---


func test_accepted_haggle_fires_completed_signal() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var expected_price: float = _haggle._current_customer_offer
	var received_item_id: String = ""
	var received_price: float = 0.0
	EventBus.haggle_completed.connect(
		func(
			_sid: StringName, iid: StringName,
			price: float, _ask: float,
			_acc: bool, _cnt: int
		) -> void:
			received_item_id = iid
			received_price = price
	)
	_haggle.accept_offer()
	assert_eq(
		received_item_id, _item.instance_id,
		"haggle_completed should fire on accept"
	)
	assert_almost_eq(
		received_price, expected_price, 0.01,
		"haggle_completed price should match customer offer"
	)


func test_declined_haggle_fires_failed_signal() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var received_item_id: String = ""
	var received_cust_id: int = 0
	EventBus.haggle_failed.connect(
		func(item_id: String, cust_id: int) -> void:
			received_item_id = item_id
			received_cust_id = cust_id
	)
	_haggle.decline_offer()
	assert_eq(
		received_item_id, _item.instance_id,
		"haggle_failed should fire on decline"
	)
	assert_eq(
		received_cust_id, customer.get_instance_id(),
		"haggle_failed should include correct customer_id"
	)


# --- Concurrent session prevention ---


func test_concurrent_sessions_blocked() -> void:
	var customer_a: Customer = _make_customer()
	var first_result: bool = _haggle.begin_negotiation(
		customer_a, _item
	)
	assert_true(
		first_result,
		"First session should start successfully"
	)
	assert_true(
		_haggle.is_active(),
		"First session should be active"
	)
	var second_item: ItemInstance = ItemInstance.create_from_definition(
		_definition, "fair"
	)
	second_item.player_set_price = 40.0
	var customer_b: Customer = _make_customer()
	var second_result: bool = _haggle.begin_negotiation(
		customer_b, second_item
	)
	assert_false(
		second_result,
		"Second start_haggle should return false"
	)
	assert_eq(
		_haggle._active_item, _item,
		"Original session item should be preserved"
	)
