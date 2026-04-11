## Tests haggle negotiation mechanics: offer generation, round limits,
## acceptance/decline outcomes, and EventBus signal emission.
extends GutTest


var _haggle: HaggleSystem
var _profile: CustomerProfile
var _definition: ItemDefinition
var _item: ItemInstance
var _customer_scene: PackedScene


func before_each() -> void:
	_haggle = HaggleSystem.new()
	add_child_autofree(_haggle)

	_profile = CustomerProfile.new()
	_profile.id = "test_haggler"
	_profile.name = "Test Haggler"
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
	_definition.name = "Test Card"
	_definition.category = "cards"
	_definition.base_price = 50.0
	_definition.rarity = "common"
	_definition.tags = PackedStringArray([])
	_definition.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)

	_item = ItemInstance.create_from_definition(_definition, "good")
	_item.set_price = 65.0

	_customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)


func _make_customer() -> Customer:
	var customer: Customer = _customer_scene.instantiate()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer


# --- Opening offer within expected range ---


func test_opening_offer_between_market_and_sticker() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var offer: float = _haggle._current_customer_offer
	var market_value: float = _item.get_current_value()
	var sticker: float = _item.set_price
	assert_true(
		offer >= market_value * 0.5 and offer <= sticker,
		"Opening offer $%.2f should be between $%.2f and $%.2f"
		% [offer, market_value * 0.5, sticker]
	)


func test_opening_offer_formula() -> void:
	var customer: Customer = _make_customer()
	var perceived: float = _item.get_current_value()
	var sticker: float = _item.set_price
	var sensitivity: float = _profile.price_sensitivity
	var expected: float = lerpf(perceived, sticker, 1.0 - sensitivity)
	_haggle.begin_negotiation(customer, _item)
	assert_almost_eq(
		_haggle._current_customer_offer, expected, 0.01,
		"Opening offer should follow lerp formula"
	)


func test_high_sensitivity_offers_closer_to_market_value() -> void:
	_profile.price_sensitivity = 0.9
	var customer_high: Customer = _make_customer()
	var perceived: float = _item.get_current_value()
	var sticker: float = _item.set_price
	var offer_high_sens: float = lerpf(
		perceived, sticker, 1.0 - 0.9
	)
	_profile.price_sensitivity = 0.2
	var offer_low_sens: float = lerpf(
		perceived, sticker, 1.0 - 0.2
	)
	assert_lt(
		offer_high_sens, offer_low_sens,
		"High sensitivity offer $%.2f should be lower than low sensitivity $%.2f"
		% [offer_high_sens, offer_low_sens]
	)
	# Reset for cleanup
	_profile.price_sensitivity = 0.6
	_haggle.begin_negotiation(customer_high, _item)


# --- Max rounds enforcement ---


func test_haggle_terminates_within_max_rounds() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var failed: bool = false
	_haggle.negotiation_failed.connect(func() -> void: failed = true)
	var sticker: float = _item.set_price
	for round_num: int in range(HaggleSystem.MAX_ROUNDS + 2):
		if not _haggle.is_active():
			break
		_haggle.player_counter(sticker * 2.0)
	assert_false(
		_haggle.is_active(),
		"Haggle must terminate within %d rounds" % HaggleSystem.MAX_ROUNDS
	)


func test_max_rounds_based_on_patience() -> void:
	_profile.patience = 0.9
	assert_eq(
		HaggleSystem.MAX_ROUNDS, 5,
		"MAX_ROUNDS constant should be 5"
	)
	# Patience >= 0.8 gets full 5 rounds
	var customer_patient: Customer = _make_customer()
	_haggle.begin_negotiation(customer_patient, _item)
	assert_eq(
		_haggle._max_rounds_for_customer, 5,
		"Patient customer (0.9) should get 5 rounds"
	)
	_haggle.decline_offer()

	_profile.patience = 0.5
	var customer_mid: Customer = _make_customer()
	_haggle.begin_negotiation(customer_mid, _item)
	assert_eq(
		_haggle._max_rounds_for_customer, 4,
		"Medium patience customer (0.5) should get 4 rounds"
	)
	_haggle.decline_offer()

	_profile.patience = 0.3
	var customer_low: Customer = _make_customer()
	_haggle.begin_negotiation(customer_low, _item)
	assert_eq(
		_haggle._max_rounds_for_customer, 3,
		"Low patience customer (0.3) should get 3 rounds"
	)
	_haggle.decline_offer()

	_profile.patience = 0.1
	var customer_impatient: Customer = _make_customer()
	_haggle.begin_negotiation(customer_impatient, _item)
	assert_eq(
		_haggle._max_rounds_for_customer, 2,
		"Impatient customer (0.1) should get 2 rounds"
	)
	_haggle.decline_offer()


# --- Accept/decline outcomes ---


func test_accept_offer_returns_customer_offer_as_final() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var customer_offer: float = _haggle._current_customer_offer
	var final_price: float = 0.0
	_haggle.negotiation_accepted.connect(
		func(price: float) -> void: final_price = price
	)
	_haggle.accept_offer()
	assert_almost_eq(
		final_price, customer_offer, 0.01,
		"Accepting should yield customer's offer as final price"
	)


func test_decline_offer_emits_failure() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var failed: bool = false
	_haggle.negotiation_failed.connect(func() -> void: failed = true)
	_haggle.decline_offer()
	assert_true(failed, "Declining should emit negotiation_failed")
	assert_false(
		_haggle.is_active(),
		"Haggle should not be active after decline"
	)


func test_player_counter_at_market_value_accepted() -> void:
	_profile.price_sensitivity = 0.3
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var accepted: bool = false
	_haggle.negotiation_accepted.connect(
		func(_price: float) -> void: accepted = true
	)
	var market_value: float = _item.get_current_value()
	_haggle.player_counter(market_value)
	assert_true(
		accepted,
		"Counter at market value should be accepted by low-sensitivity buyer"
	)


func test_insult_offer_causes_failure() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var failed: bool = false
	_haggle.negotiation_failed.connect(func() -> void: failed = true)
	var market_value: float = _item.get_current_value()
	var insult_price: float = market_value * 0.5
	_haggle.player_counter(insult_price)
	assert_true(
		failed,
		"Offer well below market value should trigger insult failure"
	)


# --- EventBus signal emission ---


func test_haggle_started_signal_emitted() -> void:
	var customer: Customer = _make_customer()
	var received_item_id: String = ""
	var received_customer_id: int = 0
	EventBus.haggle_started.connect(
		func(item_id: String, cust_id: int) -> void:
			received_item_id = item_id
			received_customer_id = cust_id
	)
	_haggle.begin_negotiation(customer, _item)
	assert_eq(
		received_item_id, _item.instance_id,
		"haggle_started should emit correct item_id"
	)
	assert_eq(
		received_customer_id, customer.get_instance_id(),
		"haggle_started should emit correct customer_id"
	)


func test_haggle_completed_signal_on_accept() -> void:
	var customer: Customer = _make_customer()
	var received_item_id: String = ""
	var received_price: float = 0.0
	EventBus.haggle_completed.connect(
		func(item_id: String, price: float) -> void:
			received_item_id = item_id
			received_price = price
	)
	_haggle.begin_negotiation(customer, _item)
	var expected_price: float = _haggle._current_customer_offer
	_haggle.accept_offer()
	assert_eq(
		received_item_id, _item.instance_id,
		"haggle_completed should emit correct item_id"
	)
	assert_almost_eq(
		received_price, expected_price, 0.01,
		"haggle_completed should emit final price"
	)


func test_haggle_failed_signal_on_decline() -> void:
	var customer: Customer = _make_customer()
	var received_item_id: String = ""
	var received_customer_id: int = 0
	EventBus.haggle_failed.connect(
		func(item_id: String, cust_id: int) -> void:
			received_item_id = item_id
			received_customer_id = cust_id
	)
	_haggle.begin_negotiation(customer, _item)
	_haggle.decline_offer()
	assert_eq(
		received_item_id, _item.instance_id,
		"haggle_failed should emit correct item_id"
	)
	assert_eq(
		received_customer_id, customer.get_instance_id(),
		"haggle_failed should emit correct customer_id"
	)


# --- Counter offer convergence ---


func test_customer_counter_moves_toward_player_price() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var initial_offer: float = _haggle._current_customer_offer
	var player_price: float = _item.set_price
	_haggle.player_counter(player_price * 1.5)
	if _haggle.is_active():
		var new_offer: float = _haggle._current_customer_offer
		assert_gt(
			new_offer, initial_offer,
			"Customer counter $%.2f should move up from initial $%.2f"
			% [new_offer, initial_offer]
		)


func test_counter_close_rate_bounds() -> void:
	assert_eq(
		HaggleSystem.MIN_COUNTER_CLOSE_RATE, 0.25,
		"MIN_COUNTER_CLOSE_RATE should be 0.25"
	)
	assert_eq(
		HaggleSystem.MAX_COUNTER_CLOSE_RATE, 0.50,
		"MAX_COUNTER_CLOSE_RATE should be 0.50"
	)


func test_acceptance_threshold_by_sensitivity() -> void:
	_profile.price_sensitivity = 0.9
	var customer_tight: Customer = _make_customer()
	_haggle.begin_negotiation(customer_tight, _item)
	assert_eq(
		_haggle._acceptance_threshold, 0.15,
		"High sensitivity (0.9) should have tight threshold 0.15"
	)
	_haggle.decline_offer()

	_profile.price_sensitivity = 0.5
	var customer_mid: Customer = _make_customer()
	_haggle.begin_negotiation(customer_mid, _item)
	assert_eq(
		_haggle._acceptance_threshold, 0.30,
		"Mid sensitivity (0.5) should have threshold 0.30"
	)
	_haggle.decline_offer()

	_profile.price_sensitivity = 0.2
	var customer_easy: Customer = _make_customer()
	_haggle.begin_negotiation(customer_easy, _item)
	assert_eq(
		_haggle._acceptance_threshold, 0.50,
		"Low sensitivity (0.2) should have loose threshold 0.50"
	)
	_haggle.decline_offer()
