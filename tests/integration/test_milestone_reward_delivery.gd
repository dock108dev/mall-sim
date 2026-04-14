## Integration test: MilestoneSystem reward delivery — threshold crossed →
## cash reward credited to EconomySystem and unlock granted to UnlockSystemSingleton.
extends GutTest

var _data_loader: DataLoader
var _economy: EconomySystem
var _milestone: MilestoneSystem
var _unlock: UnlockSystem

var _first_sale_def: MilestoneDefinition
var _week_one_survivor_def: MilestoneDefinition

const UNLOCK_ID: StringName = &"order_catalog_expansion_1"
const WEEK_ONE_THRESHOLD: int = 100


func before_each() -> void:
	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_build_milestone_defs()

	GameManager.data_loader = _data_loader
	GameManager.current_store_id = &"test_store"

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(0.0)

	_milestone = MilestoneSystem.new()
	add_child_autofree(_milestone)
	_milestone.initialize()

	_unlock = UnlockSystem.new()
	add_child_autofree(_unlock)
	_unlock._valid_ids = {}
	_unlock._granted = {}
	_unlock._valid_ids[UNLOCK_ID] = true


func after_each() -> void:
	GameManager.current_store_id = &""
	GameManager.data_loader = null


# ── Cash reward delivery ───────────────────────────────────────────────────────


func test_cash_reward_emits_transaction_completed_with_reward_value() -> void:
	watch_signals(EventBus)

	EventBus.customer_purchased.emit(
		&"test_store", &"item_001", 0.0, &"cust_001"
	)

	assert_signal_emitted(
		EventBus, "transaction_completed",
		"transaction_completed should fire after first_sale milestone reward"
	)
	var params: Array = get_signal_parameters(
		EventBus, "transaction_completed"
	)
	assert_almost_eq(
		params[0] as float,
		_first_sale_def.reward_value,
		0.01,
		"transaction_completed amount must match cash_reward value"
	)
	assert_true(
		params[1] as bool,
		"transaction_completed success must be true for milestone reward"
	)


func test_cash_reward_increases_economy_player_cash() -> void:
	EventBus.customer_purchased.emit(
		&"test_store", &"item_001", 0.0, &"cust_001"
	)

	assert_almost_eq(
		_economy.get_cash(),
		_first_sale_def.reward_value,
		0.01,
		"Economy player_cash must increase by the milestone cash_reward amount"
	)


func test_cash_reward_marks_milestone_complete() -> void:
	EventBus.customer_purchased.emit(
		&"test_store", &"item_001", 0.0, &"cust_001"
	)

	assert_true(
		_milestone.is_complete(&"first_sale"),
		"first_sale must be marked complete after threshold crossed"
	)


# ── Unlock reward delivery ─────────────────────────────────────────────────────


func test_unlock_reward_grants_unlock_after_threshold() -> void:
	_emit_purchases(WEEK_ONE_THRESHOLD)

	assert_true(
		_unlock.is_unlocked(UNLOCK_ID),
		"is_unlocked must return true after week_one_survivor unlock reward"
	)


func test_unlock_reward_emits_unlock_granted_signal() -> void:
	watch_signals(EventBus)

	_emit_purchases(WEEK_ONE_THRESHOLD)

	assert_signal_emitted(
		EventBus, "unlock_granted",
		"unlock_granted must fire after week_one_survivor unlock reward"
	)
	var params: Array = get_signal_parameters(
		EventBus, "unlock_granted"
	)
	assert_eq(
		params[0] as StringName, UNLOCK_ID,
		"unlock_granted must carry order_catalog_expansion_1"
	)


# ── Idempotency (no double delivery) ──────────────────────────────────────────


func test_cash_reward_not_re_delivered_on_second_crossing() -> void:
	EventBus.customer_purchased.emit(
		&"test_store", &"item_001", 0.0, &"cust_001"
	)
	var cash_after_first: float = _economy.get_cash()

	EventBus.customer_purchased.emit(
		&"test_store", &"item_001", 0.0, &"cust_002"
	)

	assert_almost_eq(
		_economy.get_cash(),
		cash_after_first,
		0.01,
		"Economy cash must not increase again once milestone is already complete"
	)


func test_unlock_reward_granted_exactly_once() -> void:
	var grant_count: Array = [0]
	var _on_granted := func(uid: StringName) -> void:
		if uid == UNLOCK_ID:
			grant_count[0] += 1
	EventBus.unlock_granted.connect(_on_granted)

	_emit_purchases(WEEK_ONE_THRESHOLD)
	_emit_purchases(WEEK_ONE_THRESHOLD)

	assert_eq(
		grant_count[0], 1,
		"unlock_granted must fire exactly once even when threshold crossed twice"
	)
	EventBus.unlock_granted.disconnect(_on_granted)


func test_milestone_unlocked_fires_once_at_threshold() -> void:
	var unlock_count: Array = [0]
	var _on_unlocked := func(mid: StringName, _reward: Dictionary) -> void:
		if mid == &"week_one_survivor":
			unlock_count[0] += 1
	EventBus.milestone_unlocked.connect(_on_unlocked)

	_emit_purchases(WEEK_ONE_THRESHOLD)
	_emit_purchases(WEEK_ONE_THRESHOLD)

	assert_eq(
		unlock_count[0], 1,
		"milestone_unlocked must fire exactly once for week_one_survivor"
	)
	EventBus.milestone_unlocked.disconnect(_on_unlocked)


# ── Save / load invariant ─────────────────────────────────────────────────────


func test_save_load_preserves_unlock_state() -> void:
	_emit_purchases(WEEK_ONE_THRESHOLD)
	assert_true(
		_unlock.is_unlocked(UNLOCK_ID),
		"Unlock must be granted before save"
	)

	var unlock_save: Dictionary = _unlock.get_save_data()

	var fresh_unlock: UnlockSystem = UnlockSystem.new()
	add_child_autofree(fresh_unlock)
	fresh_unlock._valid_ids = {}
	fresh_unlock._granted = {}
	fresh_unlock._valid_ids[UNLOCK_ID] = true
	fresh_unlock.load_state(unlock_save)

	assert_true(
		fresh_unlock.is_unlocked(UNLOCK_ID),
		"Unlock must be preserved after load_state"
	)


func test_save_load_does_not_re_emit_unlock_granted() -> void:
	_emit_purchases(WEEK_ONE_THRESHOLD)

	var unlock_save: Dictionary = _unlock.get_save_data()

	var fresh_unlock: UnlockSystem = UnlockSystem.new()
	add_child_autofree(fresh_unlock)
	fresh_unlock._valid_ids = {}
	fresh_unlock._granted = {}
	fresh_unlock._valid_ids[UNLOCK_ID] = true

	watch_signals(EventBus)
	fresh_unlock.load_state(unlock_save)

	assert_signal_not_emitted(
		EventBus, "unlock_granted",
		"load_state must not re-emit unlock_granted for already-granted unlocks"
	)


func test_save_load_prevents_reward_re_delivery_after_crossing() -> void:
	_emit_purchases(WEEK_ONE_THRESHOLD)

	var milestone_save: Dictionary = _milestone.get_save_data()
	var economy_save: Dictionary = _economy.get_save_data()

	var fresh_economy: EconomySystem = EconomySystem.new()
	add_child_autofree(fresh_economy)
	fresh_economy.initialize(0.0)
	fresh_economy.load_save_data(economy_save)

	var fresh_milestone: MilestoneSystem = MilestoneSystem.new()
	add_child_autofree(fresh_milestone)
	fresh_milestone.initialize()
	fresh_milestone.load_state(milestone_save)

	var cash_after_load: float = fresh_economy.get_cash()

	# week_one_survivor is already complete in fresh_milestone after load_state —
	# these additional purchases must not re-trigger any reward.
	for i: int in range(WEEK_ONE_THRESHOLD):
		EventBus.customer_purchased.emit(
			&"test_store", &"item_001", 0.0,
			StringName("reload_cust_%d" % i)
		)

	assert_almost_eq(
		fresh_economy.get_cash(),
		cash_after_load,
		0.01,
		"Loaded milestone must not re-deliver reward on repeated threshold crossings"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _emit_purchases(count: int) -> void:
	for i: int in range(count):
		EventBus.customer_purchased.emit(
			&"test_store", &"item_001", 0.0,
			StringName("cust_%d" % i)
		)


func _build_milestone_defs() -> void:
	_first_sale_def = MilestoneDefinition.new()
	_first_sale_def.id = "first_sale"
	_first_sale_def.display_name = "First Sale"
	_first_sale_def.trigger_stat_key = "customer_purchased_count"
	_first_sale_def.trigger_threshold = 1.0
	_first_sale_def.reward_type = "cash"
	_first_sale_def.reward_value = 50.0
	_first_sale_def.unlock_id = ""
	_first_sale_def.is_visible = true
	_data_loader._milestones["first_sale"] = _first_sale_def

	_week_one_survivor_def = MilestoneDefinition.new()
	_week_one_survivor_def.id = "week_one_survivor"
	_week_one_survivor_def.display_name = "Week One Survivor"
	_week_one_survivor_def.trigger_stat_key = "customer_purchased_count"
	_week_one_survivor_def.trigger_threshold = float(WEEK_ONE_THRESHOLD)
	_week_one_survivor_def.reward_type = "unlock"
	_week_one_survivor_def.reward_value = 0.0
	_week_one_survivor_def.unlock_id = String(UNLOCK_ID)
	_week_one_survivor_def.is_visible = true
	_data_loader._milestones["week_one_survivor"] = _week_one_survivor_def
