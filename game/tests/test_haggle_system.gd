## GUT unit tests for HaggleSystem offer lifecycle, counter-offer limits,
## and signal contracts.
extends GutTest


var _haggle: HaggleSystem
var _reputation: ReputationSystem
var _profile: CustomerTypeDefinition
var _definition: ItemDefinition
var _item: ItemInstance


func before_all() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()


func before_each() -> void:
	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
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


func after_each() -> void:
	GameManager.current_store_id = &""


func _make_customer() -> Customer:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer


# --- haggle_started signal contract ---


func test_haggle_started_fires_with_correct_item_id() -> void:
	var customer: Customer = _make_customer()
	var received_item_id: Array = [""]
	var received_cust_id: Array = [0]
	EventBus.haggle_started.connect(
		func(item_id: String, cust_id: int) -> void:
			received_item_id[0] = item_id
			received_cust_id[0] = cust_id
	)
	_haggle.begin_negotiation(customer, _item)
	assert_eq(
		received_item_id[0], _item.instance_id,
		"haggle_started should emit matching item_id"
	)
	assert_eq(
		received_cust_id[0], customer.get_instance_id(),
		"haggle_started should emit matching customer_id"
	)


func test_negotiation_started_fires_with_ask_price() -> void:
	var customer: Customer = _make_customer()
	var received_sticker: Array = [0.0]
	var received_offer: Array = [0.0]
	_haggle.negotiation_started.connect(
		func(
			_name: String, _cond: String, sticker: float,
			offer: float, _rounds: int
		) -> void:
			received_sticker[0] = sticker
			received_offer[0] = offer
	)
	_haggle.begin_negotiation(customer, _item)
	assert_eq(
		received_sticker[0], _item.player_set_price,
		"negotiation_started should emit sticker price as ask_price"
	)
	assert_true(
		received_offer[0] > 0.0,
		"negotiation_started should emit a positive customer offer"
	)


# --- ISSUE-069 formula contracts ---


func test_haggle_chance_uses_sensitivity_mood_and_markup() -> void:
	var expected: float = (
		HaggleSystem.BASE_HAGGLE_CHANCE
		* _profile.price_sensitivity
		* 1.3
		* ((_item.player_set_price / _item.get_current_value()) - 1.0)
	)
	var actual: float = _haggle._calculate_haggle_chance(
		_item, _profile.price_sensitivity, 1.3
	)
	assert_almost_eq(
		actual, expected, 0.001,
		"haggle_chance should be 0.40 * sensitivity * mood * markup"
	)


func test_opening_offer_uses_perceived_floor_to_sticker_lerp() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var expected: float = lerpf(
		_item.get_current_value() * 0.7,
		_item.player_set_price,
		1.0 - _profile.price_sensitivity
	)
	assert_almost_eq(
		_haggle._current_customer_offer, expected, 0.001,
		"Opening offer should lerp from 70% perceived value to sticker price"
	)


func test_customer_counter_closes_quarter_to_half_of_player_value_gap() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var player_offer: float = _item.player_set_price
	var perceived: float = _haggle._perceived_value
	var counter_offer: float = _haggle._calculate_customer_counter(player_offer)
	assert_between(
		counter_offer,
		perceived + ((player_offer - perceived) * HaggleSystem.MIN_COUNTER_CLOSE_RATE),
		perceived + ((player_offer - perceived) * HaggleSystem.MAX_COUNTER_CLOSE_RATE),
		"Customer counter should close 25-50% of the remaining value gap"
	)


func test_gap_within_counter_threshold_emits_customer_counter() -> void:
	_profile.patience = 0.9
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var countered: Array = [false]
	_haggle.customer_countered.connect(
		func(_offer: float, _round: int) -> void:
			countered[0] = true
	)
	_haggle.player_counter(_haggle._perceived_value * 1.4)
	assert_true(
		countered[0],
		"Gap below patience-derived counter threshold should counter"
	)
	assert_true(
		_haggle.is_active(),
		"Countered haggle should remain active"
	)


func test_walkaway_emits_completed_with_rejected_flag() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	watch_signals(EventBus)
	_haggle.player_counter(_haggle._perceived_value * 3.0)
	assert_signal_emitted(
		EventBus,
		"haggle_completed",
		"Walkaway should still emit haggle_completed with accepted=false"
	)
	var params: Array = get_signal_parameters(EventBus, "haggle_completed", 0)
	assert_false(
		params[4] as bool,
		"Walkaway haggle_completed accepted flag should be false"
	)


func test_insulting_counter_applies_minus_three_reputation() -> void:
	var store_id: String = "test_haggle_store"
	GameManager.current_store_id = StringName(store_id)
	_reputation.initialize_store(store_id)
	_haggle._on_active_store_changed(StringName(store_id))
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var rep_before: float = _reputation.get_reputation(store_id)
	_haggle._previous_player_offer = _haggle._perceived_value * 2.0
	_haggle._previous_customer_offer = _haggle._perceived_value * 1.6
	_haggle._current_customer_offer = _haggle._perceived_value * 1.4
	_haggle.player_counter(_haggle._previous_player_offer * 1.005)
	assert_almost_eq(
		_reputation.get_reputation(store_id),
		rep_before + HaggleSystem.REP_INSULT_PENALTY,
		0.001,
		"Insulting counter should apply the -3 reputation penalty"
	)


# --- Below-floor offer auto-declined ---


func test_counter_below_floor_is_declined() -> void:
	_profile.price_sensitivity = 0.9
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var perceived: float = _haggle._perceived_value
	var above_walkaway: float = perceived * 3.0
	var failed: Array = [false]
	_haggle.negotiation_failed.connect(
		func() -> void: failed[0] = true
	)
	_haggle.player_counter(above_walkaway)
	assert_true(
		failed[0],
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
	var received_item_id: Array = [""]
	EventBus.haggle_failed.connect(
		func(item_id: String, _cust_id: int) -> void:
			received_item_id[0] = item_id
	)
	var extreme_price: float = _item.get_current_value() * 5.0
	_haggle.player_counter(extreme_price)
	assert_eq(
		received_item_id[0], _item.instance_id,
		"haggle_failed should fire with correct item_id on decline"
	)


# --- Above-floor offer auto-accepted ---


func test_counter_at_or_above_floor_is_accepted() -> void:
	_profile.price_sensitivity = 0.3
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var market_value: float = _item.get_current_value()
	var accepted: Array = [false]
	var final: Array = [0.0]
	_haggle.negotiation_accepted.connect(
		func(price: float) -> void:
			accepted[0] = true
			final[0] = price
	)
	_haggle.player_counter(market_value)
	assert_true(
		accepted[0],
		"Counter at market value should be accepted (low sensitivity)"
	)
	assert_almost_eq(
		final[0], market_value, 0.01,
		"Final price should equal the accepted counter-offer"
	)


func test_above_floor_fires_haggle_completed() -> void:
	_profile.price_sensitivity = 0.3
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var received_item_id: Array = [""]
	var received_price: Array = [0.0]
	EventBus.haggle_completed.connect(
		func(
			_sid: StringName, iid: StringName,
			price: float, _ask: float,
			_acc: bool, _cnt: int
		) -> void:
			received_item_id[0] = iid
			received_price[0] = price
	)
	var market_value: float = _item.get_current_value()
	_haggle.player_counter(market_value)
	assert_eq(
		received_item_id[0], _item.instance_id,
		"haggle_completed should fire with correct item_id"
	)
	assert_almost_eq(
		received_price[0], market_value, 0.01,
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
	var round_count: Array = [0]
	var failed: Array = [false]
	_haggle.negotiation_failed.connect(
		func() -> void: failed[0] = true
	)
	for i: int in range(HaggleSystem.MAX_ROUNDS + 2):
		if not _haggle.is_active():
			break
		round_count[0] += 1
		_haggle.player_counter(moderate_price)
	assert_true(
		failed[0],
		"Haggle should fail after max rounds exceeded"
	)
	assert_false(
		_haggle.is_active(),
		"Haggle must not be active after max rounds"
	)


func test_offers_declined_after_limit_regardless_of_price() -> void:
	_profile.patience = 0.3
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
	var received_item_id: Array = [""]
	var received_price: Array = [0.0]
	EventBus.haggle_completed.connect(
		func(
			_sid: StringName, iid: StringName,
			price: float, _ask: float,
			_acc: bool, _cnt: int
		) -> void:
			received_item_id[0] = iid
			received_price[0] = price
	)
	_haggle.accept_offer()
	assert_eq(
		received_item_id[0], _item.instance_id,
		"haggle_completed should fire on accept"
	)
	assert_almost_eq(
		received_price[0], expected_price, 0.01,
		"haggle_completed price should match customer offer"
	)


func test_declined_haggle_fires_failed_signal() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var received_item_id: Array = [""]
	var received_cust_id: Array = [0]
	EventBus.haggle_failed.connect(
		func(item_id: String, cust_id: int) -> void:
			received_item_id[0] = item_id
			received_cust_id[0] = cust_id
	)
	_haggle.decline_offer()
	assert_eq(
		received_item_id[0], _item.instance_id,
		"haggle_failed should fire on decline"
	)
	assert_eq(
		received_cust_id[0], customer.get_instance_id(),
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
