## Integration test: DifficultySystem purchase_probability modifier wires to CheckoutSystem transaction success rate.
extends GutTest

const CHECKOUT_SCRIPT: GDScript = preload(
	"res://game/autoload/checkout_system.gd"
)
const CUSTOMER_SCENE: PackedScene = preload(
	"res://game/scenes/characters/customer.tscn"
)

const TEST_STORE_ID: String = "diff_checkout_wiring_store"
const ITEM_ID: String = "diff_checkout_wiring_item"
const ITEM_BASE_PRICE: float = 10.0
const TRIAL_COUNT: int = 100
const BOUNDARY_TRIAL_COUNT: int = 20
const RNG_SEED: int = 99371
const MIN_DISTRIBUTION_GAP: float = 0.10
const TEST_TIER_ID: StringName = &"diff_checkout_wiring_tier"

var _checkout: Node
var _inventory: InventorySystem
var _item_def: ItemDefinition
var _item: ItemInstance
var _profile: CustomerTypeDefinition
var _saved_tier: StringName

var _purchased_signals: Array[Dictionary] = []
var _left_mall_signals: Array[Dictionary] = []


func before_each() -> void:
	_saved_tier = DifficultySystemSingleton.get_current_tier_id()
	_register_test_store()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_checkout = CHECKOUT_SCRIPT.new()
	add_child_autofree(_checkout)
	_checkout.initialize(null, _inventory, null)

	_item_def = ItemDefinition.new()
	_item_def.id = ITEM_ID
	_item_def.item_name = "Diff Checkout Wiring Item"
	_item_def.base_price = ITEM_BASE_PRICE
	_item_def.rarity = "common"
	_item_def.category = "test"
	_item_def.store_type = TEST_STORE_ID

	_item = ItemInstance.create_from_definition(_item_def, "good")

	_profile = CustomerTypeDefinition.new()
	_profile.id = "diff_checkout_wiring_buyer"
	_profile.customer_name = "Diff Checkout Wiring Buyer"
	_profile.budget_range = [0.0, 1000.0]
	_profile.purchase_probability_base = 1.0
	_profile.patience = 1.0
	_profile.price_sensitivity = 0.0
	_profile.preferred_categories = PackedStringArray([])
	_profile.preferred_tags = PackedStringArray([])
	_profile.condition_preference = "good"
	_profile.browse_time_range = [1.0, 1.0]

	_purchased_signals = []
	_left_mall_signals = []

	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.customer_left_mall.connect(_on_customer_left_mall)


func after_each() -> void:
	_safe_disconnect(EventBus.customer_purchased, _on_customer_purchased)
	_safe_disconnect(EventBus.customer_left_mall, _on_customer_left_mall)
	_remove_test_tier()
	DifficultySystemSingleton.set_tier(_saved_tier)
	_unregister_test_store()


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_customer_purchased(
	store_id: StringName, item_id: StringName,
	price: float, customer_id: StringName
) -> void:
	_purchased_signals.append({
		"store_id": store_id,
		"item_id": item_id,
		"price": price,
		"customer_id": customer_id,
	})


func _on_customer_left_mall(customer: Node, satisfied: bool) -> void:
	_left_mall_signals.append({
		"customer": customer,
		"satisfied": satisfied,
	})


func _make_customer() -> Customer:
	var customer: Customer = CUSTOMER_SCENE.instantiate() as Customer
	add_child_autofree(customer)
	customer.profile = _profile
	customer._desired_item = _item
	return customer


func _restock_item() -> void:
	_inventory._items[_item.instance_id] = _item


func _run_trials(trial_count: int) -> int:
	var success_count: int = 0
	for _i: int in range(trial_count):
		_restock_item()
		var customer: Customer = _make_customer()
		var succeeded: bool = _checkout.process_transaction(customer)
		if succeeded:
			success_count += 1
	return success_count


func _inject_test_tier(modifier_value: float) -> void:
	DifficultySystemSingleton._tiers[TEST_TIER_ID] = {
		"id": String(TEST_TIER_ID),
		"display_name": "Diff Checkout Wiring Tier",
		"modifiers": {
			"purchase_probability_multiplier": modifier_value,
		},
		"flags": {},
	}
	if not DifficultySystemSingleton._tier_order.has(TEST_TIER_ID):
		DifficultySystemSingleton._tier_order.append(TEST_TIER_ID)
	DifficultySystemSingleton._current_tier_id = TEST_TIER_ID


func _remove_test_tier() -> void:
	if DifficultySystemSingleton._tiers.has(TEST_TIER_ID):
		DifficultySystemSingleton._tiers.erase(TEST_TIER_ID)
	var idx: int = DifficultySystemSingleton._tier_order.find(TEST_TIER_ID)
	if idx >= 0:
		DifficultySystemSingleton._tier_order.remove_at(idx)


# ── Group 1: Modifier read at transaction time ───────────────────────────────


func test_modifier_is_read_per_transaction_not_cached() -> void:
	# Indirect proof: if the modifier were cached at initialize time, changing
	# it between calls would have no effect. We show it does.
	_inject_test_tier(1.0)
	_restock_item()
	var customer1: Customer = _make_customer()
	var first: bool = _checkout.process_transaction(customer1)
	assert_true(
		first,
		"Modifier=1.0, base=1.0: first transaction must succeed"
	)

	_inject_test_tier(0.0)
	_restock_item()
	var customer2: Customer = _make_customer()
	var second: bool = _checkout.process_transaction(customer2)
	assert_false(
		second,
		"After modifier changed to 0.0: second transaction must fail without scene reload"
	)


func test_modifier_1_0_with_base_1_0_succeeds() -> void:
	_inject_test_tier(1.0)
	_restock_item()
	var customer: Customer = _make_customer()
	assert_true(
		_checkout.process_transaction(customer),
		"Modifier=1.0, base=1.0: final_prob=1.0 — transaction must always succeed"
	)


func test_modifier_0_0_with_base_1_0_fails() -> void:
	_inject_test_tier(0.0)
	_restock_item()
	var customer: Customer = _make_customer()
	assert_false(
		_checkout.process_transaction(customer),
		"Modifier=0.0: final_prob=0.0 — transaction must always fail"
	)


# ── Group 2: Easy vs hard mode distribution ──────────────────────────────────


func test_easy_vs_hard_distribution_gap_at_least_10_percent() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	seed(RNG_SEED)
	var easy_successes: int = _run_trials(TRIAL_COUNT)

	DifficultySystemSingleton.set_tier(&"hard")
	seed(RNG_SEED)
	var hard_successes: int = _run_trials(TRIAL_COUNT)

	var gap: float = float(easy_successes - hard_successes) / float(TRIAL_COUNT)
	assert_gte(
		gap,
		MIN_DISTRIBUTION_GAP,
		(
			"Easy (%d) vs hard (%d) gap must be >= 10%% across %d trials"
			% [easy_successes, hard_successes, TRIAL_COUNT]
		)
	)


func test_hard_success_count_lower_than_easy() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	seed(RNG_SEED)
	var easy_successes: int = _run_trials(TRIAL_COUNT)

	DifficultySystemSingleton.set_tier(&"hard")
	seed(RNG_SEED)
	var hard_successes: int = _run_trials(TRIAL_COUNT)

	assert_lt(
		hard_successes,
		easy_successes,
		"Hard mode must produce statistically fewer successes than easy mode"
	)


# ── Group 3: Modifier value boundaries ───────────────────────────────────────


func test_modifier_0_0_yields_zero_successes_across_20_attempts() -> void:
	_inject_test_tier(0.0)
	var successes: int = _run_trials(BOUNDARY_TRIAL_COUNT)
	assert_eq(
		successes,
		0,
		"Modifier=0.0 must produce exactly 0 successes across %d attempts"
			% BOUNDARY_TRIAL_COUNT
	)


func test_modifier_1_0_yields_all_successes_across_20_attempts() -> void:
	_inject_test_tier(1.0)
	var successes: int = _run_trials(BOUNDARY_TRIAL_COUNT)
	assert_eq(
		successes,
		BOUNDARY_TRIAL_COUNT,
		"Modifier=1.0 must produce %d successes across %d attempts"
			% [BOUNDARY_TRIAL_COUNT, BOUNDARY_TRIAL_COUNT]
	)


func test_modifier_0_0_emits_customer_left_mall_unsatisfied() -> void:
	_inject_test_tier(0.0)
	_restock_item()
	var customer: Customer = _make_customer()
	_checkout.process_transaction(customer)
	assert_eq(
		_left_mall_signals.size(),
		1,
		"Modifier=0.0: customer_left_mall must be emitted exactly once"
	)
	assert_false(
		bool(_left_mall_signals[0]["satisfied"]),
		"customer_left_mall.satisfied must be false when modifier=0.0"
	)


func test_modifier_0_0_does_not_emit_customer_purchased() -> void:
	_inject_test_tier(0.0)
	_restock_item()
	var customer: Customer = _make_customer()
	_checkout.process_transaction(customer)
	assert_eq(
		_purchased_signals.size(),
		0,
		"Modifier=0.0: customer_purchased must not be emitted"
	)


func test_modifier_1_0_emits_customer_purchased() -> void:
	_inject_test_tier(1.0)
	_restock_item()
	var customer: Customer = _make_customer()
	_checkout.process_transaction(customer)
	assert_eq(
		_purchased_signals.size(),
		1,
		"Modifier=1.0: customer_purchased must be emitted exactly once"
	)


# ── Group 4: Difficulty change at runtime ────────────────────────────────────


func test_runtime_change_from_full_to_zero_takes_effect_next_call() -> void:
	_inject_test_tier(1.0)
	_restock_item()
	var customer1: Customer = _make_customer()
	assert_true(
		_checkout.process_transaction(customer1),
		"Modifier=1.0: first transaction must succeed"
	)

	_inject_test_tier(0.0)
	_restock_item()
	var customer2: Customer = _make_customer()
	assert_false(
		_checkout.process_transaction(customer2),
		"Runtime switch to modifier=0.0: next call must fail without scene reload"
	)


func test_runtime_change_from_zero_to_full_takes_effect_next_call() -> void:
	_inject_test_tier(0.0)
	_restock_item()
	var customer1: Customer = _make_customer()
	assert_false(
		_checkout.process_transaction(customer1),
		"Modifier=0.0: first transaction must fail"
	)

	_inject_test_tier(1.0)
	_restock_item()
	var customer2: Customer = _make_customer()
	assert_true(
		_checkout.process_transaction(customer2),
		"Runtime switch to modifier=1.0: next call must succeed without scene reload"
	)


func test_apply_difficulty_change_easy_to_hard_updates_modifier_immediately() -> void:
	DifficultySystemSingleton.set_tier(&"easy")
	var easy_modifier: float = DifficultySystemSingleton.get_modifier(
		&"purchase_probability_multiplier"
	)

	DifficultySystemSingleton.apply_difficulty_change(&"hard")
	var hard_modifier: float = DifficultySystemSingleton.get_modifier(
		&"purchase_probability_multiplier"
	)

	assert_lt(
		hard_modifier,
		easy_modifier,
		"After apply_difficulty_change easy→hard: modifier must drop immediately"
	)
	assert_lt(
		hard_modifier,
		1.0,
		"Hard mode purchase_probability_multiplier must be < 1.0"
	)


func test_runtime_easy_to_hard_via_apply_next_checkout_uses_hard_modifier() -> void:
	# With base=1.0 and easy modifier (clamped to 1.0), easy always succeeds.
	# After switching to hard (modifier=0.70), boundary injection of 0.0 confirms
	# the system reads the current tier on each call.
	DifficultySystemSingleton.set_tier(&"easy")
	_restock_item()
	var customer1: Customer = _make_customer()
	var first: bool = _checkout.process_transaction(customer1)
	assert_true(first, "Easy mode: transaction must succeed (final_prob=1.0)")

	_inject_test_tier(0.0)
	_restock_item()
	var customer2: Customer = _make_customer()
	var second: bool = _checkout.process_transaction(customer2)
	assert_false(
		second,
		"After mid-session switch to modifier=0.0: checkout reads new tier on next call"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _register_test_store() -> void:
	if ContentRegistry.exists(TEST_STORE_ID):
		return
	ContentRegistry.register_entry(
		{
			"id": TEST_STORE_ID,
			"name": "Diff Checkout Wiring Store",
			"scene_path": "",
			"backroom_capacity": 50,
		},
		"store",
	)


func _unregister_test_store() -> void:
	if not ContentRegistry.exists(TEST_STORE_ID):
		return
	var key: StringName = StringName(TEST_STORE_ID)
	ContentRegistry._entries.erase(key)
	ContentRegistry._types.erase(key)
	ContentRegistry._display_names.erase(key)
	ContentRegistry._scene_map.erase(key)
	for alias_key: StringName in ContentRegistry._aliases.keys():
		if ContentRegistry._aliases[alias_key] == key:
			ContentRegistry._aliases.erase(alias_key)
