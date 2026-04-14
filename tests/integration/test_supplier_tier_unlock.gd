## Integration test: supplier tier unlock — reputation threshold met →
## supplier_tier_changed signal → Tier 2 catalog items available.
extends GutTest

var _ordering: OrderingSystem
var _reputation: ReputationSystem
var _inventory: InventorySystem

const STORE_ID: String = "test_store"
const TIER_1: int = 1
const TIER_2: int = 2
const TIER_2_REP_THRESHOLD: float = 25.0


func before_each() -> void:
	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_ID)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_ordering = OrderingSystem.new()
	add_child_autofree(_ordering)
	_ordering.initialize(_inventory, _reputation)

	GameManager.current_store_id = &"test_store"


func after_each() -> void:
	GameManager.current_store_id = &""


func test_starts_at_tier_one() -> void:
	assert_eq(
		_ordering.get_supplier_tier(), TIER_1,
		"OrderingSystem starts at Tier 1 with zero reputation"
	)


func test_tier_advances_to_two_when_reputation_threshold_met() -> void:
	_reputation.add_reputation(STORE_ID, TIER_2_REP_THRESHOLD)

	assert_eq(
		_ordering.get_supplier_tier(), TIER_2,
		"Tier advances to 2 when reputation reaches the Tier 2 threshold"
	)


func test_supplier_tier_changed_signal_emitted_on_tier_advance() -> void:
	watch_signals(EventBus)

	_reputation.add_reputation(STORE_ID, TIER_2_REP_THRESHOLD)

	assert_signal_emitted(
		EventBus, "supplier_tier_changed",
		"supplier_tier_changed signal fires when tier advances to 2"
	)
	var params: Array = get_signal_parameters(
		EventBus, "supplier_tier_changed"
	)
	assert_eq(
		params[0] as int, TIER_1,
		"supplier_tier_changed carries old_tier == 1"
	)
	assert_eq(
		params[1] as int, TIER_2,
		"supplier_tier_changed carries new_tier == 2"
	)


func test_rare_items_not_available_at_tier_one() -> void:
	var item_def: ItemDefinition = _create_item_definition("rare")

	assert_false(
		_ordering.is_item_available_at_tier(item_def),
		"Rare items are not accessible at Tier 1"
	)


func test_common_items_available_at_tier_one() -> void:
	var item_def: ItemDefinition = _create_item_definition("common")

	assert_true(
		_ordering.is_item_available_at_tier(item_def),
		"Common items are accessible at Tier 1"
	)


func test_rare_items_accessible_after_tier_two_unlock() -> void:
	var item_def: ItemDefinition = _create_item_definition("rare")

	_reputation.add_reputation(STORE_ID, TIER_2_REP_THRESHOLD)

	assert_true(
		_ordering.is_item_available_at_tier(item_def),
		"Rare items become accessible after reaching Tier 2"
	)


func test_uncommon_items_remain_accessible_after_tier_advance() -> void:
	var item_def: ItemDefinition = _create_item_definition("uncommon")

	_reputation.add_reputation(STORE_ID, TIER_2_REP_THRESHOLD)

	assert_true(
		_ordering.is_item_available_at_tier(item_def),
		"Uncommon items remain accessible after advancing to Tier 2"
	)


func test_tier_two_daily_limit_exceeds_tier_one() -> void:
	var tier_one_limit: float = _ordering.get_daily_order_limit()

	_reputation.add_reputation(STORE_ID, TIER_2_REP_THRESHOLD)
	var tier_two_limit: float = _ordering.get_daily_order_limit()

	assert_gt(
		tier_two_limit, tier_one_limit,
		"Tier 2 daily order limit is greater than Tier 1 limit"
	)


func test_tier_two_wholesale_multiplier_lower_than_tier_one() -> void:
	var tier_one_config: Dictionary = _ordering.get_supplier_tier_config()
	var tier_one_multiplier: float = tier_one_config["wholesale"]

	_reputation.add_reputation(STORE_ID, TIER_2_REP_THRESHOLD)
	var tier_two_config: Dictionary = _ordering.get_supplier_tier_config()
	var tier_two_multiplier: float = tier_two_config["wholesale"]

	assert_lt(
		tier_two_multiplier, tier_one_multiplier,
		"Tier 2 wholesale multiplier is lower, meaning better pricing"
	)


func test_no_signal_emitted_when_reputation_stays_below_threshold() -> void:
	watch_signals(EventBus)

	_reputation.add_reputation(STORE_ID, TIER_2_REP_THRESHOLD - 1.0)

	assert_signal_not_emitted(
		EventBus, "supplier_tier_changed",
		"supplier_tier_changed does not fire when reputation stays below Tier 2 threshold"
	)
	assert_eq(
		_ordering.get_supplier_tier(), TIER_1,
		"Tier remains 1 when reputation is below the Tier 2 threshold"
	)


func test_tier_does_not_downgrade_while_above_threshold() -> void:
	_reputation.add_reputation(STORE_ID, TIER_2_REP_THRESHOLD + 10.0)
	assert_eq(
		_ordering.get_supplier_tier(), TIER_2,
		"Tier is 2 after exceeding threshold"
	)

	# Reputation stays above threshold — tier must remain at 2.
	assert_eq(
		_ordering.get_supplier_tier(), TIER_2,
		"Tier does not downgrade when reputation remains above threshold"
	)


func test_signal_not_emitted_again_when_tier_is_already_two() -> void:
	_reputation.add_reputation(STORE_ID, TIER_2_REP_THRESHOLD)
	watch_signals(EventBus)

	# Adding more reputation while already at Tier 2 should not fire again.
	_reputation.add_reputation(STORE_ID, 5.0)

	assert_signal_not_emitted(
		EventBus, "supplier_tier_changed",
		"supplier_tier_changed does not fire again when tier is already 2"
	)


func _create_item_definition(rarity: String) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = "test_item_%s" % rarity
	def.item_name = "Test Item (%s)" % rarity
	def.category = "test"
	def.store_type = "test"
	def.base_price = 10.0
	def.rarity = rarity
	def.condition_range = PackedStringArray(["good"])
	return def
