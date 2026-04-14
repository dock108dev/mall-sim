## Integration test: milestone-driven SupplierTierSystem unlock chain —
## milestone_unlocked (supplier_tier reward) → supplier_tier_changed signal →
## previously locked Tier 2 catalog items become orderable.
extends GutTest

const STORE_ID: String = "test_store"
const TIER_1: int = 1
const TIER_2: int = 2
const TIER_2_REP_THRESHOLD: float = 25.0
const MILESTONE_ID: StringName = &"test_supplier_tier_milestone"
const UNLOCK_MILESTONE_ID: StringName = &"test_supplier_catalog_unlock_milestone"
const UNLOCK_ID: StringName = &"test_supplier_catalog_unlock"
const UNLOCK_DISPLAY_NAME: String = "Supplier Catalog Unlock"

var _data_loader: DataLoader
var _milestone: MilestoneSystem
var _ordering: OrderingSystem
var _reputation: ReputationSystem
var _inventory: InventorySystem
var _unlock: UnlockSystem

var _supplier_tier_changed_calls: Array[Dictionary] = []
var _milestone_fire_count: int = 0


func before_all() -> void:
	if not ContentRegistry.exists(String(UNLOCK_ID)):
		ContentRegistry.register_entry(
			{"id": String(UNLOCK_ID), "name": UNLOCK_DISPLAY_NAME},
			"unlock"
		)


func before_each() -> void:
	_supplier_tier_changed_calls = []
	_milestone_fire_count = 0

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_ID)
	_reputation.add_reputation(STORE_ID, -100.0)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_ordering = OrderingSystem.new()
	add_child_autofree(_ordering)
	_ordering.initialize(_inventory, _reputation)

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_build_supplier_tier_milestone()
	_build_unlock_milestone()

	GameManager.data_loader = _data_loader
	GameManager.current_store_id = StringName(STORE_ID)

	_milestone = MilestoneSystem.new()
	add_child_autofree(_milestone)
	_milestone.initialize()

	_unlock = UnlockSystem.new()
	add_child_autofree(_unlock)
	_unlock._valid_ids = {}
	_unlock._granted = {}
	_unlock._valid_ids[UNLOCK_ID] = true

	EventBus.supplier_tier_changed.connect(_capture_supplier_tier_changed)
	EventBus.milestone_unlocked.connect(_capture_milestone_fire_count)


func after_each() -> void:
	if EventBus.supplier_tier_changed.is_connected(_capture_supplier_tier_changed):
		EventBus.supplier_tier_changed.disconnect(_capture_supplier_tier_changed)
	if EventBus.milestone_unlocked.is_connected(_capture_milestone_fire_count):
		EventBus.milestone_unlocked.disconnect(_capture_milestone_fire_count)

	GameManager.current_store_id = &""
	GameManager.data_loader = null


# ── Pre-unlock: Tier 2 items rejected at Tier 1 ────────────────────────────────


func test_ordering_starts_at_tier_one_with_zero_reputation() -> void:
	assert_eq(
		_ordering.get_supplier_tier(), TIER_1,
		"OrderingSystem must report Tier 1 when reputation is below the Tier 2 threshold"
	)


func test_tier_two_item_unavailable_at_tier_one() -> void:
	var rare_item: ItemDefinition = _create_item_definition("rare")
	assert_false(
		_ordering.is_item_available_at_tier(rare_item),
		"Rare-rarity items (Tier 2) must be rejected when the ordering system is at Tier 1"
	)


# ── Unlock chain: milestone_unlocked → supplier_tier_changed ──────────────────


func test_milestone_unlocked_fires_for_supplier_tier_reward() -> void:
	watch_signals(EventBus)

	_trigger_supplier_tier_milestone()

	assert_signal_emitted(
		EventBus, "milestone_unlocked",
		"milestone_unlocked must fire when the supplier_tier milestone condition is met"
	)


func test_supplier_tier_changed_emitted_on_supplier_tier_milestone() -> void:
	watch_signals(EventBus)

	_trigger_supplier_tier_milestone()

	assert_signal_emitted(
		EventBus, "supplier_tier_changed",
		"supplier_tier_changed must fire when a milestone with supplier_tier reward is applied"
	)


func test_supplier_tier_changed_carries_correct_new_tier() -> void:
	_trigger_supplier_tier_milestone()

	assert_eq(
		_supplier_tier_changed_calls.size(), 1,
		"Exactly one supplier_tier_changed signal must fire from the milestone reward"
	)
	var params: Dictionary = _supplier_tier_changed_calls[0]
	assert_eq(
		params["new_tier"] as int, TIER_2,
		"supplier_tier_changed new_tier must match the milestone's reward_value"
	)


# ── Post-unlock: catalog items accessible at Tier 2 ───────────────────────────


func test_tier_two_item_available_after_reputation_reaches_threshold() -> void:
	_reputation.add_reputation(STORE_ID, TIER_2_REP_THRESHOLD)

	var rare_item: ItemDefinition = _create_item_definition("rare")
	assert_true(
		_ordering.is_item_available_at_tier(rare_item),
		"Rare-rarity items must be orderable once reputation advances to Tier 2"
	)


# ── Catalog availability: rarity gates per tier ───────────────────────────────


func test_catalog_common_available_at_tier_one() -> void:
	assert_true(
		SupplierTierSystem.is_rarity_available("common", TIER_1),
		"Common rarity must be in the Tier 1 catalog"
	)


func test_catalog_uncommon_available_at_tier_one() -> void:
	assert_true(
		SupplierTierSystem.is_rarity_available("uncommon", TIER_1),
		"Uncommon rarity must be in the Tier 1 catalog"
	)


func test_catalog_rare_not_available_at_tier_one() -> void:
	assert_false(
		SupplierTierSystem.is_rarity_available("rare", TIER_1),
		"Rare rarity must not be in the Tier 1 catalog"
	)


func test_catalog_rare_available_at_tier_two() -> void:
	assert_true(
		SupplierTierSystem.is_rarity_available("rare", TIER_2),
		"Rare rarity must be in the Tier 2 catalog"
	)


# ── Signal contract: unlock_granted fires for unlock-type milestone reward ─────


func test_unlock_granted_fires_for_unlock_reward_milestone() -> void:
	watch_signals(EventBus)

	_trigger_unlock_milestone()

	assert_signal_emitted(
		EventBus, "unlock_granted",
		"unlock_granted must fire when a milestone with reward_type 'unlock' is completed"
	)


func test_unlock_granted_carries_correct_unlock_id() -> void:
	watch_signals(EventBus)

	_trigger_unlock_milestone()

	var params: Array = get_signal_parameters(EventBus, "unlock_granted")
	assert_eq(
		params[0] as StringName, UNLOCK_ID,
		"unlock_granted must carry the unlock_id specified in the milestone reward"
	)


func test_unlock_system_marks_unlock_as_granted_after_milestone_chain() -> void:
	_trigger_unlock_milestone()

	assert_true(
		_unlock.is_unlocked(UNLOCK_ID),
		"UnlockSystem must record the unlock as granted after processing the milestone reward"
	)


# ── Idempotency: milestone fires exactly once on repeated triggers ─────────────


func test_supplier_tier_milestone_fires_only_once() -> void:
	_trigger_supplier_tier_milestone()
	_trigger_supplier_tier_milestone()

	assert_eq(
		_milestone_fire_count, 1,
		"milestone_unlocked must not fire a second time when milestone condition is re-crossed"
	)


func test_supplier_tier_changed_fires_once_on_repeated_milestone_triggers() -> void:
	_trigger_supplier_tier_milestone()
	_trigger_supplier_tier_milestone()

	assert_eq(
		_supplier_tier_changed_calls.size(), 1,
		"supplier_tier_changed must fire exactly once even when the milestone trigger fires multiple times"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _capture_supplier_tier_changed(old_tier: int, new_tier: int) -> void:
	_supplier_tier_changed_calls.append({"old_tier": old_tier, "new_tier": new_tier})


func _capture_milestone_fire_count(
	milestone_id: StringName, _reward: Dictionary
) -> void:
	if milestone_id == MILESTONE_ID:
		_milestone_fire_count += 1


func _trigger_supplier_tier_milestone() -> void:
	EventBus.store_leased.emit(0, "test_type")


func _trigger_unlock_milestone() -> void:
	EventBus.customer_purchased.emit(
		StringName(STORE_ID), &"item_001", 1.0, &"cust_1"
	)


func _build_supplier_tier_milestone() -> void:
	var def: MilestoneDefinition = MilestoneDefinition.new()
	def.id = String(MILESTONE_ID)
	def.display_name = "Test Supplier Tier Milestone"
	def.trigger_stat_key = "owned_store_count"
	def.trigger_threshold = 1.0
	def.reward_type = "supplier_tier"
	def.reward_value = float(TIER_2)
	def.unlock_id = ""
	def.is_visible = true
	_data_loader._milestones[String(MILESTONE_ID)] = def


func _build_unlock_milestone() -> void:
	var def: MilestoneDefinition = MilestoneDefinition.new()
	def.id = String(UNLOCK_MILESTONE_ID)
	def.display_name = "Test Supplier Catalog Unlock Milestone"
	def.trigger_stat_key = "customer_purchased_count"
	def.trigger_threshold = 1.0
	def.reward_type = "unlock"
	def.reward_value = 0.0
	def.unlock_id = String(UNLOCK_ID)
	def.is_visible = true
	_data_loader._milestones[String(UNLOCK_MILESTONE_ID)] = def


func _create_item_definition(rarity: String) -> ItemDefinition:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "test_item_%s" % rarity
	def.item_name = "Test Item (%s)" % rarity
	def.category = "test"
	def.store_type = "test"
	def.base_price = 10.0
	def.rarity = rarity
	def.condition_range = PackedStringArray(["good"])
	return def
