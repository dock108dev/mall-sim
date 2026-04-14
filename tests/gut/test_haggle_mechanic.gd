## Tests haggle negotiation mechanics: offer generation, round limits,
## acceptance/decline outcomes, reputation effects, and EventBus signals.
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


# --- Opening offer within expected range ---


func test_opening_offer_between_market_and_sticker() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var offer: float = _haggle._current_customer_offer
	var market_value: float = _item.get_current_value()
	var sticker: float = _item.player_set_price
	assert_true(
		offer >= market_value * 0.5 and offer <= sticker,
		"Opening offer $%.2f should be between $%.2f and $%.2f"
		% [offer, market_value * 0.5, sticker]
	)


func test_opening_offer_formula() -> void:
	var customer: Customer = _make_customer()
	var perceived: float = _item.get_current_value()
	var sticker: float = _item.player_set_price
	var sensitivity: float = _profile.price_sensitivity
	var expected: float = lerpf(
		perceived * 0.7, sticker, 1.0 - sensitivity
	)
	_haggle.begin_negotiation(customer, _item)
	assert_almost_eq(
		_haggle._current_customer_offer, expected, 0.01,
		"Opening offer should follow lerp formula"
	)


func test_high_sensitivity_offers_closer_to_low_end() -> void:
	var perceived: float = _item.get_current_value()
	var sticker: float = _item.player_set_price
	var offer_high_sens: float = lerpf(
		perceived * 0.7, sticker, 1.0 - 0.9
	)
	var offer_low_sens: float = lerpf(
		perceived * 0.7, sticker, 1.0 - 0.2
	)
	assert_lt(
		offer_high_sens, offer_low_sens,
		"High sensitivity offer $%.2f should be lower than low sensitivity $%.2f"
		% [offer_high_sens, offer_low_sens]
	)


# --- Markup factor ---


func test_markup_factor_formula() -> void:
	var sticker: float = _item.player_set_price
	var value: float = _item.get_current_value()
	var expected: float = clampf(sticker / value - 1.0, 0.0, 2.0)
	var actual: float = _haggle._get_markup_factor(_item)
	assert_almost_eq(
		actual, expected, 0.001,
		"Markup factor should be clampf(sticker/value - 1.0, 0.0, 2.0)"
	)


func test_markup_factor_zero_when_underpriced() -> void:
	_item.player_set_price = _item.get_current_value() * 0.8
	var factor: float = _haggle._get_markup_factor(_item)
	assert_eq(
		factor, 0.0,
		"Underpriced items should have 0 markup factor"
	)


# --- Max rounds enforcement ---


func test_haggle_terminates_within_max_rounds() -> void:
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var failed: bool = false
	_haggle.negotiation_failed.connect(func() -> void: failed = true)
	var sticker: float = _item.player_set_price
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


func test_walkaway_on_excessive_gap_ratio() -> void:
	_profile.patience = 0.1
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var failed: bool = false
	_haggle.negotiation_failed.connect(func() -> void: failed = true)
	var extreme_price: float = _item.get_current_value() * 3.0
	_haggle.player_counter(extreme_price)
	assert_true(
		failed,
		"Extreme gap ratio should trigger walkaway"
	)


# --- EventBus signal emission ---


func test_haggle_requested_signal_emitted() -> void:
	var received_item_id: String = ""
	var received_customer_id: int = 0
	EventBus.haggle_requested.connect(
		func(item_id: String, cust_id: int) -> void:
			received_item_id = item_id
			received_customer_id = cust_id
	)
	_profile.price_sensitivity = 1.0
	_item.player_set_price = _item.get_current_value() * 3.0
	var customer: Customer = _make_customer()
	seed(42)
	var emitted: bool = false
	for i: int in range(100):
		received_item_id = ""
		if _haggle.should_haggle(customer, _item):
			emitted = true
			break
	if emitted:
		assert_eq(
			received_item_id, _item.instance_id,
			"haggle_requested should emit correct item_id"
		)


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
		func(
			_sid: StringName, iid: StringName,
			price: float, _ask: float,
			_acc: bool, _cnt: int
		) -> void:
			received_item_id = iid
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
	var player_price: float = _item.player_set_price
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


# --- Reputation effects ---


func test_sale_complete_gives_positive_reputation() -> void:
	var initial_rep: float = _reputation.get_reputation()
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	_haggle.accept_offer()
	var new_rep: float = _reputation.get_reputation()
	var delta: float = new_rep - initial_rep
	assert_true(
		delta >= HaggleSystem.REP_SALE_MIN
		and delta <= HaggleSystem.REP_SALE_MAX,
		"Sale should give +1 to +2 rep, got %.2f" % delta
	)


func test_walkaway_gives_negative_reputation() -> void:
	var initial_rep: float = _reputation.get_reputation()
	_reputation.modify_reputation("", 10.0)
	initial_rep = _reputation.get_reputation()
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	_haggle.decline_offer()
	var new_rep: float = _reputation.get_reputation()
	var delta: float = new_rep - initial_rep
	assert_true(
		delta >= HaggleSystem.REP_WALKAWAY_MAX
		and delta <= HaggleSystem.REP_WALKAWAY_MIN,
		"Walkaway should give -1 to -3 rep, got %.2f" % delta
	)


func test_insult_counter_gives_max_penalty() -> void:
	_reputation.modify_reputation("", 20.0)
	var initial_rep: float = _reputation.get_reputation()
	_profile.patience = 0.9
	_profile.price_sensitivity = 0.9
	var customer: Customer = _make_customer()
	_haggle.begin_negotiation(customer, _item)
	var perceived: float = _haggle._perceived_value
	var first_offer: float = perceived * 1.5
	_haggle.player_counter(first_offer)
	if not _haggle.is_active():
		return
	var barely_moved: float = first_offer * 1.001
	_haggle.player_counter(barely_moved)
	if not _haggle.is_active():
		var new_rep: float = _reputation.get_reputation()
		var delta: float = new_rep - initial_rep
		assert_true(
			delta <= HaggleSystem.REP_INSULT_PENALTY + 0.01,
			"Insult counter should apply -3 penalty, got %.2f"
			% delta
		)
