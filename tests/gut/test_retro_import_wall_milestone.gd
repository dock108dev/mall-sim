## GUT tests for the Retro Games import-wall fixture milestone (ISSUE-014).
extends GutTest


const MILESTONE_ID: StringName = &"retro_import_wall_unlock"
const UNLOCK_ID: StringName = &"import_wall_display"
const REVENUE_THRESHOLD: float = 500.0


var _data_loader: DataLoader
var _economy_system: EconomySystem
var _milestone_system: MilestoneSystem
var _saved_unlock_valid_ids: Dictionary = {}
var _saved_unlock_granted: Dictionary = {}
var _saved_difficulty_tiers: Dictionary = {}
var _saved_difficulty_order: Array[StringName] = []
var _saved_difficulty_tier_id: StringName = &""


func before_each() -> void:
	_saved_unlock_valid_ids = UnlockSystemSingleton._valid_ids.duplicate(true)
	_saved_unlock_granted = UnlockSystemSingleton._granted.duplicate(true)
	_saved_difficulty_tiers = DifficultySystemSingleton._tiers.duplicate(true)
	_saved_difficulty_order = DifficultySystemSingleton._tier_order.duplicate()
	_saved_difficulty_tier_id = DifficultySystemSingleton._current_tier_id

	ContentRegistry.clear_for_testing()
	ContentRegistry.register_entry(
		{
			"id": String(UNLOCK_ID),
			"display_name": "Import Wall Display",
		},
		"unlock"
	)

	DifficultySystemSingleton._current_tier_id = &"normal"
	DifficultySystemSingleton._tiers = {
		&"normal": {
			"modifiers": {"starting_cash_multiplier": 1.0},
			"flags": {},
		},
	}
	DifficultySystemSingleton._tier_order = [&"normal"]

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)

	var milestone: MilestoneDefinition = MilestoneDefinition.new()
	milestone.id = String(MILESTONE_ID)
	milestone.display_name = "Signature Import Wall"
	milestone.description = "Retro sales crossed five hundred dollars."
	milestone.trigger_type = "revenue_total"
	milestone.trigger_stat_key = "cumulative_revenue"
	milestone.trigger_threshold = REVENUE_THRESHOLD
	milestone.reward_type = "fixture_unlock"
	milestone.reward_value = 0.0
	milestone.unlock_id = String(UNLOCK_ID)
	milestone.is_visible = true
	milestone.tier = "early"
	_data_loader._milestones[String(MILESTONE_ID)] = milestone

	GameManager.data_loader = _data_loader
	GameManager.current_store_id = &"retro_games"

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
	UnlockSystemSingleton._valid_ids = _saved_unlock_valid_ids.duplicate(true)
	UnlockSystemSingleton._granted = _saved_unlock_granted.duplicate(true)
	DifficultySystemSingleton._tiers = _saved_difficulty_tiers.duplicate(true)
	DifficultySystemSingleton._tier_order = _saved_difficulty_order.duplicate()
	DifficultySystemSingleton._current_tier_id = _saved_difficulty_tier_id


func test_milestone_fires_at_revenue_threshold_and_carries_unlock_id() -> void:
	watch_signals(EventBus)

	EventBus.transaction_completed.emit(499.0, true, "Sale")
	assert_signal_emit_count(
		EventBus, "milestone_unlocked", 0,
		"import-wall milestone must not fire under the $500 threshold"
	)

	EventBus.transaction_completed.emit(1.0, true, "Sale")
	assert_signal_emit_count(
		EventBus, "milestone_unlocked", 1,
		"import-wall milestone must fire once the $500 threshold is crossed"
	)

	var params: Array = get_signal_parameters(
		EventBus, "milestone_unlocked", 0
	)
	var fired_id: StringName = params[0] as StringName
	var reward: Dictionary = params[1] as Dictionary
	assert_eq(
		fired_id, MILESTONE_ID,
		"milestone_unlocked must carry the import-wall milestone id"
	)
	assert_eq(
		str(reward.get("reward_type", "")),
		"fixture_unlock",
		"import-wall milestone reward_type must be fixture_unlock"
	)
	assert_eq(
		StringName(str(reward.get("unlock_id", ""))),
		UNLOCK_ID,
		"import-wall milestone must reference the import_wall_display unlock id"
	)


func test_unlock_is_granted_through_unlock_system() -> void:
	EventBus.transaction_completed.emit(500.0, true, "Sale")

	assert_true(
		UnlockSystemSingleton.is_unlocked(UNLOCK_ID),
		"import_wall_display unlock must be granted after milestone fires"
	)


func test_milestone_completed_description_includes_unlock_target() -> void:
	var received_reward: Array = [""]
	var handler: Callable = func(
		_id: String, _name: String, reward: String
	) -> void:
		received_reward[0] = reward
	EventBus.milestone_completed.connect(handler, CONNECT_ONE_SHOT)

	EventBus.transaction_completed.emit(500.0, true, "Sale")

	assert_true(
		str(received_reward[0]).begins_with("Unlocked:"),
		"fixture_unlock reward_description must report what was unlocked"
	)
