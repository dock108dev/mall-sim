## Integration test: DifficultySystem Hard mode lowers transaction success rate
## versus Normal mode via purchase_probability_multiplier in CheckoutSystem.
extends GutTest

const TEST_SIGNAL_UTILS: GDScript = preload("res://game/tests/signal_utils.gd")

const CHECKOUT_SCRIPT: GDScript = preload(
	"res://game/autoload/checkout_system.gd"
)
const CUSTOMER_SCENE: PackedScene = preload(
	"res://game/scenes/characters/customer.tscn"
)

const TEST_STORE_ID: String = "diff_prob_test_store"
const ITEM_BASE_PRICE: float = 10.0
const ITEM_ID: String = "diff_prob_test_item"
const TRIAL_COUNT: int = 100
const RNG_SEED: int = 42

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
	_item_def.item_name = "Diff Prob Test Item"
	_item_def.base_price = ITEM_BASE_PRICE
	_item_def.rarity = "common"
	_item_def.category = "test"
	_item_def.store_type = TEST_STORE_ID

	_item = ItemInstance.create_from_definition(_item_def, "good")

	_profile = CustomerTypeDefinition.new()
	_profile.id = "diff_prob_buyer"
	_profile.customer_name = "Diff Prob Buyer"
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
	TEST_SIGNAL_UTILS.safe_disconnect(
		EventBus.customer_purchased, _on_customer_purchased
	)
	TEST_SIGNAL_UTILS.safe_disconnect(
		EventBus.customer_left_mall, _on_customer_left_mall
	)
	_remove_test_tier()
	DifficultySystemSingleton.set_tier(_saved_tier)
	_unregister_test_store()


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
	var success_count: Array = [0]
	for _i: int in range(trial_count):
		_restock_item()
		var customer: Customer = _make_customer()
		var succeeded: bool = _checkout.process_transaction(customer)
		if succeeded:
			success_count[0] += 1
	return success_count[0]


func _inject_test_tier(modifier_value: float) -> void:
	DifficultySystemSingleton._tiers[&"diff_test_tier"] = {
		"id": "diff_test_tier",
		"display_name": "Test Tier",
		"modifiers": {
			"purchase_probability_multiplier": modifier_value,
		},
		"flags": {},
	}
	if not DifficultySystemSingleton._tier_order.has(&"diff_test_tier"):
		DifficultySystemSingleton._tier_order.append(&"diff_test_tier")
	DifficultySystemSingleton._current_tier_id = &"diff_test_tier"


func _remove_test_tier() -> void:
	if DifficultySystemSingleton._tiers.has(&"diff_test_tier"):
		DifficultySystemSingleton._tiers.erase(&"diff_test_tier")
	var idx: int = DifficultySystemSingleton._tier_order.find(&"diff_test_tier")
	if idx >= 0:
		DifficultySystemSingleton._tier_order.remove_at(idx)


# ── Structural: modifier values ──────────────────────────────────────────────


func test_normal_tier_purchase_probability_modifier_is_one() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	assert_almost_eq(
		DifficultySystemSingleton.get_modifier(&"purchase_probability_multiplier"),
		1.0,
		0.001,
		"Normal tier purchase_probability_multiplier must be 1.0"
	)


func test_hard_tier_purchase_probability_modifier_is_less_than_one() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	assert_true(
		DifficultySystemSingleton.get_modifier(&"purchase_probability_multiplier") < 1.0,
		"Hard tier purchase_probability_multiplier must be < 1.0"
	)


# ── Case A: Normal mode, seeded RNG, ≥ 95 of 100 succeed ────────────────────


func test_normal_mode_at_least_95_of_100_transactions_succeed() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	seed(RNG_SEED)
	var successes: int = _run_trials(TRIAL_COUNT)
	assert_gte(
		successes,
		95,
		"Normal mode (modifier=1.0, base=1.0): at least 95 of %d must succeed" \
			% TRIAL_COUNT
	)


# ── Case B: Hard mode, same seed, fewer than 95 of 100 succeed ───────────────


func test_hard_mode_fewer_than_95_of_100_transactions_succeed() -> void:
	DifficultySystemSingleton.set_tier(&"hard")
	seed(RNG_SEED)
	var successes: int = _run_trials(TRIAL_COUNT)
	assert_lt(
		successes,
		95,
		"Hard mode (modifier=0.70): fewer than 95 of %d must succeed" \
			% TRIAL_COUNT
	)


func test_hard_mode_success_count_lower_than_normal_mode() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	seed(RNG_SEED)
	var normal_successes: int = _run_trials(TRIAL_COUNT)

	DifficultySystemSingleton.set_tier(&"hard")
	seed(RNG_SEED)
	var hard_successes: int = _run_trials(TRIAL_COUNT)

	assert_lt(
		hard_successes,
		normal_successes,
		"Hard mode must produce fewer successes than Normal mode"
	)


# ── Failed transactions: customer_left_mall(npc, false) fires ────────────────


func test_failed_transaction_emits_customer_left_mall_unsatisfied() -> void:
	_inject_test_tier(0.0)

	_restock_item()
	var customer: Customer = _make_customer()
	_checkout.process_transaction(customer)

	assert_eq(
		_left_mall_signals.size(),
		1,
		"Zero-modifier transaction must emit customer_left_mall exactly once"
	)
	assert_false(
		bool(_left_mall_signals[0]["satisfied"]),
		"customer_left_mall satisfied must be false for failed transactions"
	)


func test_failed_transaction_does_not_emit_customer_purchased() -> void:
	_inject_test_tier(0.0)

	_restock_item()
	var customer: Customer = _make_customer()
	_checkout.process_transaction(customer)

	assert_eq(
		_purchased_signals.size(),
		0,
		"Zero-modifier transaction must not emit customer_purchased"
	)


# ── Mid-run difficulty switch takes effect immediately ───────────────────────


func test_mid_run_switch_normal_to_zero_fails_immediately() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	_restock_item()
	var customer1: Customer = _make_customer()
	var succeeded1: bool = _checkout.process_transaction(customer1)
	assert_true(
		succeeded1,
		"Normal mode (modifier=1.0, base=1.0): transaction must succeed"
	)

	_inject_test_tier(0.0)
	_restock_item()
	var customer2: Customer = _make_customer()
	var succeeded2: bool = _checkout.process_transaction(customer2)
	assert_false(
		succeeded2,
		"After switch to zero-modifier tier, next transaction must fail immediately"
	)


func test_mid_run_switch_zero_to_full_succeeds_immediately() -> void:
	_inject_test_tier(0.0)
	_restock_item()
	var customer1: Customer = _make_customer()
	var succeeded1: bool = _checkout.process_transaction(customer1)
	assert_false(succeeded1, "Zero-modifier: first transaction must fail")

	_inject_test_tier(2.0)
	_restock_item()
	var customer2: Customer = _make_customer()
	var succeeded2: bool = _checkout.process_transaction(customer2)
	assert_true(
		succeeded2,
		"After switch to 2.0-modifier tier (clamped to 1.0), transaction must succeed"
	)


# ── Modifier read at transaction time, not cached ────────────────────────────


func test_modifier_not_cached_reads_per_transaction() -> void:
	DifficultySystemSingleton.set_tier(&"normal")
	_restock_item()
	var customer1: Customer = _make_customer()
	var succeeded1: bool = _checkout.process_transaction(customer1)
	assert_true(
		succeeded1,
		"Normal mode: first transaction must succeed (p=1.0)"
	)

	_inject_test_tier(0.0)
	_restock_item()
	var customer2: Customer = _make_customer()
	var succeeded2: bool = _checkout.process_transaction(customer2)
	assert_false(
		succeeded2,
		"Modifier updated after first call: second transaction must fail without restart"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _register_test_store() -> void:
	if ContentRegistry.exists(TEST_STORE_ID):
		return
	ContentRegistry.register_entry(
		{
			"id": TEST_STORE_ID,
			"name": "Diff Prob Test Store",
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
