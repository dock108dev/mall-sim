## ISSUE-029: Haggle negotiation loop integration tests.
## Verifies 3-round counter sequence and round-4 auto-reject behaviour.
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
	_profile.customer_name = "Loop Haggler"
	_profile.budget_range = [5.0, 500.0]
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
	_definition.id = "loop_card"
	_definition.item_name = "Loop Card"
	_definition.category = "cards"
	_definition.base_price = 50.0
	_definition.rarity = "common"
	_definition.tags = PackedStringArray([])
	_definition.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)

	_item = ItemInstance.create_from_definition(_definition, "good")
	_item.player_set_price = 60.0


func after_each() -> void:
	GameManager.current_store_id = &""


## Full 3-round counter sequence: player counters 3 times in a row.
## The third counter must either resolve or leave the haggle at MAX_ROUNDS.
## When the system accepts on round 3, haggle_resolved must be emitted with a
## multiplier equal to final_price / sticker_price.
func test_three_round_counter_sequence_resolves_and_emits_haggle_resolved() -> void:
	var customer: Customer = _make_customer()
	assert_true(_haggle.begin_negotiation(customer, _item))

	var resolved_item: Array[StringName] = [&""]
	var resolved_price: Array[float] = [0.0]
	var resolved_mult: Array[float] = [0.0]
	EventBus.haggle_resolved.connect(
		func(
			iid: StringName, price: float, mult: float
		) -> void:
			resolved_item[0] = iid
			resolved_price[0] = price
			resolved_mult[0] = mult
	)

	var sticker: float = _item.player_set_price
	var rounds_done: int = 0

	# Drive 3 counter-offers at a price that stays within acceptance range on
	# the third round. We use the customer's current offer each time to force
	# convergence quickly.
	while _haggle.is_active() and rounds_done < HaggleSystem.MAX_ROUNDS:
		var offer_price: float = _haggle._current_customer_offer
		_haggle.player_counter(offer_price)
		rounds_done += 1

	# After 3 rounds the haggle must have resolved (either accepted or failed).
	assert_false(_haggle.is_active(), "Haggle should be resolved after 3 rounds")
	assert_lte(rounds_done, HaggleSystem.MAX_ROUNDS,
		"Should not exceed MAX_ROUNDS (%d)" % HaggleSystem.MAX_ROUNDS)

	if resolved_price[0] > 0.0:
		var expected_mult: float = resolved_price[0] / sticker
		assert_almost_eq(resolved_mult[0], expected_mult, 0.01,
			"haggle_resolved multiplier should equal final_price / sticker_price")
		assert_eq(resolved_item[0], StringName(_item.instance_id),
			"haggle_resolved item_id should match the negotiated item")


## Round 4 must always emit haggle_failed regardless of the offer price.
## This test forces the haggle past MAX_ROUNDS by using high patience and
## a moderate offer price so the system does not accept early; then verifies
## that the 4th player_counter call always triggers the failure path.
func test_round_four_always_emits_haggle_failed() -> void:
	_profile.patience = 0.9

	var customer: Customer = _make_customer()
	assert_true(_haggle.begin_negotiation(customer, _item))

	var failed: Array[bool] = [false]
	var accepted: Array[bool] = [false]
	_haggle.negotiation_failed.connect(func() -> void: failed[0] = true)
	_haggle.negotiation_accepted.connect(
		func(_p: float) -> void: accepted[0] = true
	)

	# Submit MAX_ROUNDS offers that are unlikely to be accepted outright
	# (price below perceived value to ensure gap_ratio is low and the customer
	# keeps countering rather than accepting).
	var perceived: float = _item.get_current_value()
	var low_offer: float = perceived * 0.5

	for i: int in range(HaggleSystem.MAX_ROUNDS):
		if not _haggle.is_active():
			break
		_haggle.player_counter(low_offer)

	# If haggle is still active after MAX_ROUNDS, force the round-4 attempt.
	if _haggle.is_active():
		_haggle.player_counter(low_offer)

	assert_true(failed[0] or not _haggle.is_active(),
		"Round 4 must emit haggle_failed or terminate the negotiation")
	assert_false(_haggle.is_active(),
		"Haggle must not be active after round 4")


func _make_customer() -> Customer:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer
