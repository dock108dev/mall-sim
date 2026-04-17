## ISSUE-028: Haggle negotiation coverage.
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
	GameManager.current_store_id = &"test_store"
	EventBus.active_store_changed.emit(&"test_store")

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store("test_store")

	_haggle = HaggleSystem.new()
	add_child_autofree(_haggle)
	_haggle.initialize(_reputation)
	_haggle._on_active_store_changed(&"test_store")

	_profile = CustomerTypeDefinition.new()
	_profile.id = "test_haggler"
	_profile.customer_name = "Test Haggler"
	_profile.budget_range = [5.0, 200.0]
	_profile.patience = 0.9
	_profile.price_sensitivity = 0.6
	_profile.preferred_categories = PackedStringArray(["cards"])
	_profile.preferred_tags = PackedStringArray([])
	_profile.condition_preference = "good"
	_profile.browse_time_range = [30.0, 60.0]
	_profile.purchase_probability_base = 0.8
	_profile.impulse_buy_chance = 0.0
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


func test_haggle_offer_values_stay_within_item_price_bounds() -> void:
	var customer: Customer = _make_customer()
	assert_true(_haggle.begin_negotiation(customer, _item))

	var offer: float = _haggle._current_customer_offer
	var floor_price: float = _item.get_current_value() * 0.7
	var sticker_price: float = _item.player_set_price

	assert_between(
		offer,
		floor_price,
		sticker_price,
		"Opening offer should stay between perceived floor and sticker price"
	)


func test_multi_round_negotiation_terminates_within_max_rounds() -> void:
	var customer: Customer = _make_customer()
	assert_true(_haggle.begin_negotiation(customer, _item))

	var counters_used: int = 0
	while _haggle.is_active() and counters_used <= HaggleSystem.MAX_ROUNDS:
		_haggle.player_counter(_item.player_set_price * 1.5)
		counters_used += 1

	assert_false(_haggle.is_active(), "Haggle should converge or fail")
	assert_lte(
		counters_used,
		HaggleSystem.MAX_ROUNDS,
		"Haggle must terminate within max rounds"
	)
	assert_eq(HaggleSystem.MAX_ROUNDS, 5, "Max rounds should be 5")


func test_accepting_haggle_uses_customer_offer_as_final_price() -> void:
	var customer: Customer = _make_customer()
	var accepted_price: Array[float] = [0.0]
	_haggle.negotiation_accepted.connect(
		func(price: float) -> void: accepted_price[0] = price
	)

	assert_true(_haggle.begin_negotiation(customer, _item))
	var expected_price: float = _haggle._current_customer_offer
	_haggle.accept_offer()

	assert_almost_eq(
		accepted_price[0],
		expected_price,
		0.01,
		"Accepting should finalize at the customer's current offer"
	)


func test_declining_haggle_emits_failure_and_clears_state() -> void:
	var customer: Customer = _make_customer()
	var failed: Array[bool] = [false]
	_haggle.negotiation_failed.connect(func() -> void: failed[0] = true)

	assert_true(_haggle.begin_negotiation(customer, _item))
	_haggle.decline_offer()

	assert_true(failed[0], "Declining should emit negotiation_failed")
	assert_false(_haggle.is_active(), "Declining should end the haggle")


func test_haggle_success_and_failure_emit_eventbus_signals() -> void:
	watch_signals(EventBus)
	var accepted_customer: Customer = _make_customer()

	assert_true(_haggle.begin_negotiation(accepted_customer, _item))
	var final_price: float = _haggle._current_customer_offer
	_haggle.accept_offer()

	assert_signal_emitted(
		EventBus,
		"haggle_completed",
		"Accepted haggle should emit haggle_completed"
	)
	assert_signal_emitted_with_parameters(
		EventBus,
		"haggle_completed",
		[&"test_store", StringName(_item.instance_id), final_price, 65.0, true, 1]
	)

	var declined_customer: Customer = _make_customer()
	assert_true(_haggle.begin_negotiation(declined_customer, _item))
	_haggle.decline_offer()

	assert_signal_emitted(
		EventBus,
		"haggle_failed",
		"Declined haggle should emit haggle_failed"
	)
	assert_signal_emitted_with_parameters(
		EventBus,
		"haggle_failed",
		[String(_item.instance_id), declined_customer.get_instance_id()]
	)


func _make_customer() -> Customer:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer
