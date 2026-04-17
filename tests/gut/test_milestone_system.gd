## GUT tests for MilestoneSystem unlock payloads, reward delivery, and idempotency.
extends GutTest


const CASH_MILESTONE_ID: StringName = &"first_sale"
const CASH_REWARD_AMOUNT: float = 50.0
const UNLOCK_MILESTONE_ID: StringName = &"week_one_survivor"
const UNLOCK_ID: StringName = &"order_catalog_expansion_1"
const UNLOCK_THRESHOLD: int = 3

var _data_loader: DataLoader
var _economy_system: EconomySystem
var _milestone_system: MilestoneSystem
var _saved_difficulty_tiers: Dictionary = {}
var _saved_difficulty_order: Array[StringName] = []
var _saved_difficulty_tier_id: StringName = &""
var _saved_unlock_valid_ids: Dictionary = {}
var _saved_unlock_granted: Dictionary = {}


func before_each() -> void:
	_saved_difficulty_tiers = DifficultySystemSingleton._tiers.duplicate(true)
	_saved_difficulty_order = DifficultySystemSingleton._tier_order.duplicate()
	_saved_difficulty_tier_id = DifficultySystemSingleton._current_tier_id
	_saved_unlock_valid_ids = UnlockSystemSingleton._valid_ids.duplicate(true)
	_saved_unlock_granted = UnlockSystemSingleton._granted.duplicate(true)

	ContentRegistry.clear_for_testing()
	ContentRegistry.register_entry(
		{
			"id": String(UNLOCK_ID),
			"display_name": "Order Catalog Expansion 1",
		},
		"unlock"
	)
	_seed_difficulty_tier()

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_milestone_definitions()

	GameManager.data_loader = _data_loader
	GameManager.current_store_id = &"test_store"

	_economy_system = EconomySystem.new()
	add_child_autofree(_economy_system)
	_economy_system.initialize(0.0)

	_milestone_system = MilestoneSystem.new()
	add_child_autofree(_milestone_system)
	_milestone_system.initialize()

	UnlockSystemSingleton._valid_ids = {UNLOCK_ID: true}
	UnlockSystemSingleton._granted = {}


func after_each() -> void:
	GameManager.data_loader = null
	GameManager.current_store_id = &""
	ContentRegistry.clear_for_testing()
	DifficultySystemSingleton._tiers = _saved_difficulty_tiers.duplicate(true)
	DifficultySystemSingleton._tier_order = _saved_difficulty_order.duplicate()
	DifficultySystemSingleton._current_tier_id = _saved_difficulty_tier_id
	UnlockSystemSingleton._valid_ids = _saved_unlock_valid_ids.duplicate(true)
	UnlockSystemSingleton._granted = _saved_unlock_granted.duplicate(true)


func test_milestone_unlocked_emits_expected_reward_data() -> void:
	watch_signals(EventBus)

	_emit_purchase_events(1)

	assert_signal_emit_count(
		EventBus,
		"milestone_unlocked",
		1,
		"first milestone should emit milestone_unlocked exactly once"
	)
	var params: Array = get_signal_parameters(EventBus, "milestone_unlocked", 0)
	var milestone_id: StringName = params[0] as StringName
	var reward: Dictionary = params[1] as Dictionary

	assert_eq(
		milestone_id,
		CASH_MILESTONE_ID,
		"milestone_unlocked must carry the earned milestone id"
	)
	assert_eq(
		str(reward.get("reward_type", "")),
		"cash",
		"milestone_unlocked must expose the reward type"
	)
	assert_almost_eq(
		float(reward.get("reward_value", 0.0)),
		CASH_REWARD_AMOUNT,
		0.01,
		"milestone_unlocked must expose the reward amount"
	)
	assert_eq(
		StringName(str(reward.get("unlock_id", ""))),
		&"",
		"cash milestone payload should not include an unlock id"
	)


func test_cash_reward_is_applied_to_player_funds_after_unlock() -> void:
	_emit_purchase_events(1)

	assert_almost_eq(
		_economy_system.get_cash(),
		CASH_REWARD_AMOUNT,
		0.01,
		"cash reward should increase player funds by the reward amount"
	)
	assert_true(
		_milestone_system.is_complete(CASH_MILESTONE_ID),
		"cash milestone should be marked complete after unlocking"
	)


func test_unlock_reward_grants_expected_unlock() -> void:
	watch_signals(EventBus)

	_emit_purchase_events(UNLOCK_THRESHOLD)

	assert_true(
		UnlockSystemSingleton.is_unlocked(UNLOCK_ID),
		"unlock reward should grant the configured unlock id"
	)
	assert_signal_emit_count(
		EventBus,
		"unlock_granted",
		1,
		"unlock reward should grant exactly one unlock"
	)
	var params: Array = get_signal_parameters(EventBus, "unlock_granted", 0)
	assert_eq(
		params[0] as StringName,
		UNLOCK_ID,
		"unlock_granted must carry the configured unlock id"
	)


func test_duplicate_milestone_trigger_does_not_refire_signal_or_regrant_reward() -> void:
	watch_signals(EventBus)

	_emit_purchase_events(1)
	var cash_after_first_unlock: float = _economy_system.get_cash()
	_emit_purchase_events(1)

	assert_signal_emit_count(
		EventBus,
		"milestone_unlocked",
		1,
		"duplicate cash milestone trigger must not emit milestone_unlocked again"
	)
	assert_almost_eq(
		_economy_system.get_cash(),
		cash_after_first_unlock,
		0.01,
		"duplicate cash milestone trigger must not re-grant the reward"
	)

	_emit_purchase_events(UNLOCK_THRESHOLD)

	assert_signal_emit_count(
		EventBus,
		"unlock_granted",
		1,
		"duplicate unlock milestone trigger must not re-grant the unlock"
	)
	assert_true(
		UnlockSystemSingleton.is_unlocked(UNLOCK_ID),
		"unlock should remain granted after repeated milestone triggers"
	)


func _emit_purchase_events(count: int) -> void:
	for index: int in range(count):
		EventBus.customer_purchased.emit(
			&"test_store",
			&"item_001",
			0.0,
			StringName("customer_%d" % index)
		)


func _seed_difficulty_tier() -> void:
	DifficultySystemSingleton._current_tier_id = &"normal"
	DifficultySystemSingleton._tiers = {
		&"normal": {
			"modifiers": {
				"starting_cash_multiplier": 1.0,
			},
			"flags": {},
		},
	}
	DifficultySystemSingleton._tier_order = [&"normal"]


func _register_milestone_definitions() -> void:
	var cash_milestone: MilestoneDefinition = MilestoneDefinition.new()
	cash_milestone.id = String(CASH_MILESTONE_ID)
	cash_milestone.display_name = "First Sale"
	cash_milestone.trigger_stat_key = "customer_purchased_count"
	cash_milestone.trigger_threshold = 1.0
	cash_milestone.reward_type = "cash"
	cash_milestone.reward_value = CASH_REWARD_AMOUNT
	_data_loader._milestones[String(CASH_MILESTONE_ID)] = cash_milestone

	var unlock_milestone: MilestoneDefinition = MilestoneDefinition.new()
	unlock_milestone.id = String(UNLOCK_MILESTONE_ID)
	unlock_milestone.display_name = "Week One Survivor"
	unlock_milestone.trigger_stat_key = "customer_purchased_count"
	unlock_milestone.trigger_threshold = float(UNLOCK_THRESHOLD)
	unlock_milestone.reward_type = "unlock"
	unlock_milestone.reward_value = 0.0
	unlock_milestone.unlock_id = String(UNLOCK_ID)
	_data_loader._milestones[String(UNLOCK_MILESTONE_ID)] = unlock_milestone
