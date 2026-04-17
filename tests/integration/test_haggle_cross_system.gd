## Integration test: HaggleSystem outcomes propagate to EconomySystem and
## ReputationSystem correctly across accepted, walked, and max-round scenarios.
extends GutTest

const CUSTOMER_SCENE: PackedScene = preload(
	"res://game/scenes/characters/customer.tscn"
)
const STARTING_CASH: float = 500.0
const LIST_PRICE: float = 50.0
const TEST_STORE_ID: String = "test_haggle_store"

var _haggle: HaggleSystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _inventory: InventorySystem
var _checkout: PlayerCheckout
var _customer: Customer
var _item: ItemInstance


func before_each() -> void:
	_register_test_store()
	GameManager.current_store_id = &"test_haggle_store"

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store(TEST_STORE_ID)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_haggle = HaggleSystem.new()
	add_child_autofree(_haggle)
	_haggle.initialize(_reputation)
	_haggle._active_store_id = &"test_haggle_store"

	_checkout = PlayerCheckout.new()
	add_child_autofree(_checkout)
	_checkout.initialize(_economy, _inventory, null, _reputation)
	_checkout.set_haggle_system(_haggle)

	_customer = CUSTOMER_SCENE.instantiate() as Customer
	add_child_autofree(_customer)
	_customer.profile = _create_customer_profile()

	_item = _create_test_item()
	_inventory._items[_item.instance_id] = _item
	_customer._desired_item = _item

	# Mirror the checkout state that _begin_checkout() sets before starting a haggle.
	_checkout._active_customer = _customer
	_checkout._active_item = _item


func after_each() -> void:
	_unregister_test_store()
	GameManager.current_store_id = &""


# ── Scenario A: haggle accepted — negotiated price, not list price ─────────────


func test_scenario_a_accepted_haggle_charges_negotiated_price_not_list_price() -> void:
	watch_signals(EventBus)

	_haggle.begin_negotiation(_customer, _item)
	var accepted_price: float = _haggle._current_customer_offer
	assert_true(
		accepted_price < LIST_PRICE,
		"Customer opening offer should be below list price with price_sensitivity = 0.5"
	)

	_haggle.accept_offer()
	# Trigger checkout timer callback directly to bypass the async 2-second timer.
	_checkout._checkout_timer.stop()
	_checkout._on_checkout_timer_timeout()

	assert_almost_eq(
		_economy.get_cash(),
		STARTING_CASH + accepted_price, 0.01,
		"Cash should increase by the negotiated price, not the list price"
	)
	assert_signal_emitted(
		EventBus, "haggle_completed",
		"haggle_completed should fire on an accepted haggle"
	)
	assert_signal_emitted(
		EventBus, "customer_purchased",
		"customer_purchased should fire after checkout processes the haggled sale"
	)


func test_scenario_a_accepted_haggle_gives_positive_reputation_delta() -> void:
	var rep_before: float = _reputation.get_reputation(TEST_STORE_ID)

	_haggle.begin_negotiation(_customer, _item)
	_haggle.accept_offer()

	assert_true(
		_reputation.get_reputation(TEST_STORE_ID) > rep_before,
		"Reputation should increase after an accepted haggle"
	)


func test_scenario_a_haggle_completed_carries_accepted_flag_and_final_price() -> void:
	watch_signals(EventBus)

	_haggle.begin_negotiation(_customer, _item)
	var accepted_price: float = _haggle._current_customer_offer
	_haggle.accept_offer()

	assert_signal_emitted(EventBus, "haggle_completed")
	var params: Array = get_signal_parameters(EventBus, "haggle_completed", 0)
	var signal_accepted: bool = params[4] as bool
	var signal_price: float = params[2] as float
	assert_true(
		signal_accepted,
		"haggle_completed.accepted should be true on a player-accepted offer"
	)
	assert_almost_eq(
		signal_price, accepted_price, 0.01,
		"haggle_completed.final_price should equal the customer's accepted offer"
	)


func test_begin_negotiation_uses_profile_patience_for_session_rounds() -> void:
	_customer.profile.patience = 0.8
	_haggle.begin_negotiation(_customer, _item)
	assert_eq(
		_haggle._max_rounds_for_customer, 4,
		"Casual-fan patience should map to four rounds"
	)

	_haggle.decline_offer()
	_customer.profile.patience = 0.3
	_haggle.begin_negotiation(_customer, _item)
	assert_eq(
		_haggle._max_rounds_for_customer, 2,
		"Investor patience should map to two rounds"
	)


func test_begin_negotiation_reduces_turn_time_for_busy_queue() -> void:
	_customer.profile.patience = 0.5
	_haggle.begin_negotiation(_customer, _item, 0)
	var no_queue_time: float = _haggle.time_per_turn
	_haggle.decline_offer()

	_haggle.begin_negotiation(_customer, _item, 2)
	assert_almost_eq(
		_haggle.time_per_turn,
		no_queue_time * 0.7,
		0.01,
		"Queue pressure should reduce haggle turn time by 30%"
	)


# ── Scenario B: customer walks — economy unchanged, reputation drops ───────────


func test_scenario_b_walkaway_leaves_cash_unchanged() -> void:
	var cash_before: float = _economy.get_cash()

	_haggle.begin_negotiation(_customer, _item)
	_haggle.decline_offer()

	assert_almost_eq(
		_economy.get_cash(), cash_before, 0.01,
		"Cash should be unchanged after a haggle walkaway"
	)


func test_scenario_b_walkaway_emits_haggle_failed_and_clears_active_state() -> void:
	watch_signals(EventBus)

	_haggle.begin_negotiation(_customer, _item)
	_haggle.decline_offer()

	assert_signal_emitted(
		EventBus, "haggle_failed",
		"haggle_failed should fire when the player declines and the customer walks"
	)
	assert_false(
		_haggle.is_active(),
		"HaggleSystem should be inactive after walkaway"
	)


func test_scenario_b_walkaway_gives_negative_reputation_delta() -> void:
	var rep_before: float = _reputation.get_reputation(TEST_STORE_ID)

	_haggle.begin_negotiation(_customer, _item)
	_haggle.decline_offer()

	assert_true(
		_reputation.get_reputation(TEST_STORE_ID) < rep_before,
		"Reputation should decrease after a customer walkaway"
	)


# ── Scenario C: max counter-offer rounds reached — terminal state ─────────────


func test_scenario_c_max_rounds_terminates_without_economy_change() -> void:
	var cash_before: float = _economy.get_cash()

	_haggle.begin_negotiation(_customer, _item)
	_force_to_last_round()
	# One more counter advances the round past the limit, triggering termination.
	_haggle.player_counter(LIST_PRICE * 1.2)

	assert_false(
		_haggle.is_active(),
		"HaggleSystem should be inactive after max counter rounds exceeded"
	)
	assert_almost_eq(
		_economy.get_cash(), cash_before, 0.01,
		"Cash should be unchanged after max-round termination"
	)


func test_scenario_c_max_rounds_leaves_inventory_intact() -> void:
	_haggle.begin_negotiation(_customer, _item)
	_force_to_last_round()
	_haggle.player_counter(LIST_PRICE * 1.2)

	assert_true(
		_inventory._items.has(_item.instance_id),
		"Item should remain in inventory when the haggle terminates without a sale"
	)


func test_scenario_c_max_rounds_emits_haggle_failed() -> void:
	watch_signals(EventBus)

	_haggle.begin_negotiation(_customer, _item)
	_force_to_last_round()
	_haggle.player_counter(LIST_PRICE * 1.2)

	assert_signal_emitted(
		EventBus, "haggle_failed",
		"haggle_failed should fire when max counter rounds are exceeded"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


## Sets round state so the next player_counter() call exceeds the round limit.
## Disables probabilistic early exit paths to guarantee a deterministic outcome.
func _force_to_last_round() -> void:
	_haggle._current_round = _haggle._max_rounds_for_customer
	# Values outside the valid range prevent gap_ratio checks from triggering
	# early walkaway (threshold > any realistic gap) or early acceptance
	# (threshold below any realistic gap), leaving only the round-limit path.
	_haggle._acceptance_threshold = -1.0
	_haggle._walkaway_threshold = 10.0
	# _evaluate_offer() returns false immediately when _sticker_price <= 0.
	_haggle._sticker_price = 0.0


func _create_customer_profile() -> CustomerTypeDefinition:
	var p := CustomerTypeDefinition.new()
	p.id = "test_customer"
	p.customer_name = "Test Customer"
	p.patience = 0.5
	p.price_sensitivity = 0.5
	p.budget_range = [100.0, 200.0]
	p.mood_tags = PackedStringArray()
	return p


func _create_test_item() -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_haggle_item"
	def.item_name = "Test Item"
	def.base_price = LIST_PRICE
	def.category = "test"
	def.store_type = TEST_STORE_ID
	def.rarity = "common"
	return ItemInstance.create_from_definition(def, "good")


func _register_test_store() -> void:
	if ContentRegistry.exists(TEST_STORE_ID):
		return
	ContentRegistry.register_entry(
		{
			"id": TEST_STORE_ID,
			"name": "Test Haggle Store",
			"scene_path": "",
			"backroom_capacity": 50,
		},
		"store",
	)


func _unregister_test_store() -> void:
	if not ContentRegistry.exists(TEST_STORE_ID):
		return
	var key: StringName = &"test_haggle_store"
	ContentRegistry._entries.erase(key)
	ContentRegistry._types.erase(key)
	ContentRegistry._display_names.erase(key)
	ContentRegistry._scene_map.erase(key)
	for alias_key: StringName in ContentRegistry._aliases.keys():
		if ContentRegistry._aliases[alias_key] == key:
			ContentRegistry._aliases.erase(alias_key)
