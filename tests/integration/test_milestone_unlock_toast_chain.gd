## Integration test: full signal chain — milestone met → milestone_unlocked →
## grant_unlock → unlock_granted → toast_requested(category: unlock).
extends GutTest

const UNLOCK_ID: StringName = &"test_unlock_chain"
const UNLOCK_DISPLAY_NAME: String = "Test Chain Unlock"
const MILESTONE_ID: StringName = &"test_unlock_milestone"
const MILESTONE_THRESHOLD: int = 3

var _data_loader: DataLoader
var _milestone: MilestoneSystem
var _unlock: UnlockSystem
var _milestone_def: MilestoneDefinition

var _signal_order: Array[String] = []
var _toasts: Array[Dictionary] = []


func before_all() -> void:
	if not ContentRegistry.exists(String(UNLOCK_ID)):
		ContentRegistry.register_entry(
			{"id": String(UNLOCK_ID), "name": UNLOCK_DISPLAY_NAME},
			"unlock"
		)


func before_each() -> void:
	_signal_order = []
	_toasts = []

	EventBus.milestone_unlocked.connect(_capture_milestone_unlocked)
	EventBus.unlock_granted.connect(_capture_unlock_granted)
	EventBus.toast_requested.connect(_capture_toast)

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_build_milestone_def()

	GameManager.data_loader = _data_loader
	GameManager.current_store_id = &"test_store"

	_milestone = MilestoneSystem.new()
	add_child_autofree(_milestone)
	_milestone.initialize()

	_unlock = UnlockSystem.new()
	add_child_autofree(_unlock)
	_unlock._valid_ids = {}
	_unlock._granted = {}
	_unlock._valid_ids[UNLOCK_ID] = true


func after_each() -> void:
	if EventBus.milestone_unlocked.is_connected(_capture_milestone_unlocked):
		EventBus.milestone_unlocked.disconnect(_capture_milestone_unlocked)
	if EventBus.unlock_granted.is_connected(_capture_unlock_granted):
		EventBus.unlock_granted.disconnect(_capture_unlock_granted)
	if EventBus.toast_requested.is_connected(_capture_toast):
		EventBus.toast_requested.disconnect(_capture_toast)

	GameManager.current_store_id = &""
	GameManager.data_loader = null


# ── Chain: milestone met → unlock granted → toast emitted ─────────────────────


func test_milestone_unlocked_fires_with_correct_id() -> void:
	watch_signals(EventBus)

	_trigger_milestone()

	assert_signal_emitted(EventBus, "milestone_unlocked")
	var ms_params: Array = get_signal_parameters(EventBus, "milestone_unlocked")
	assert_eq(
		ms_params[0] as StringName, MILESTONE_ID,
		"milestone_unlocked must carry the expected milestone_id"
	)


func test_grant_unlock_called_for_unlock_reward() -> void:
	_trigger_milestone()

	assert_true(
		_unlock.is_unlocked(UNLOCK_ID),
		"UnlockSystem must have the unlock granted after milestone chain"
	)


func test_unlock_granted_fires_with_correct_unlock_id() -> void:
	watch_signals(EventBus)

	_trigger_milestone()

	assert_signal_emitted(EventBus, "unlock_granted")
	var params: Array = get_signal_parameters(EventBus, "unlock_granted")
	assert_eq(
		params[0] as StringName, UNLOCK_ID,
		"unlock_granted must carry the milestone's associated unlock_id"
	)


func test_toast_requested_fires_with_unlock_category() -> void:
	_trigger_milestone()

	var unlock_toast: Dictionary = _find_toast(&"unlock")
	assert_false(
		unlock_toast.is_empty(),
		"A toast with category 'unlock' must be emitted"
	)


func test_toast_requested_has_duration_five() -> void:
	_trigger_milestone()

	var unlock_toast: Dictionary = _find_toast(&"unlock")
	assert_false(unlock_toast.is_empty(), "Unlock toast must exist")
	assert_almost_eq(
		unlock_toast.get("duration", 0.0) as float,
		5.0,
		0.01,
		"Unlock toast duration must be 5.0"
	)


func test_toast_message_includes_display_name_from_registry() -> void:
	_trigger_milestone()

	var unlock_toast: Dictionary = _find_toast(&"unlock")
	assert_false(unlock_toast.is_empty(), "Unlock toast must exist")
	var message: String = unlock_toast.get("message", "") as String
	assert_true(
		message.contains(UNLOCK_DISPLAY_NAME),
		(
			"Toast message must contain display_name '%s' but got '%s'"
			% [UNLOCK_DISPLAY_NAME, message]
		)
	)


# ── Signal order: milestone_unlocked → unlock_granted → toast_requested ───────


func test_signals_fire_in_correct_order() -> void:
	_trigger_milestone()

	assert_eq(
		_signal_order.size(), 3,
		"Exactly three ordered signal events must be captured"
	)
	assert_eq(
		_signal_order[0], "milestone_unlocked",
		"milestone_unlocked must fire first"
	)
	assert_eq(
		_signal_order[1], "unlock_granted",
		"unlock_granted must fire second"
	)
	assert_eq(
		_signal_order[2], "toast_requested:unlock",
		"toast_requested(unlock) must fire third"
	)


# ── Idempotency: no double-fire on repeated threshold crossings ────────────────


func test_milestone_unlocked_fires_only_once() -> void:
	_trigger_milestone()
	_trigger_milestone()

	var count: int = 0
	for entry: String in _signal_order:
		if entry == "milestone_unlocked":
			count += 1
	assert_eq(count, 1, "milestone_unlocked must not fire again after milestone is complete")


func test_unlock_granted_fires_only_once() -> void:
	_trigger_milestone()
	_trigger_milestone()

	var count: int = 0
	for entry: String in _signal_order:
		if entry == "unlock_granted":
			count += 1
	assert_eq(count, 1, "unlock_granted must fire exactly once even when threshold crossed twice")


func test_toast_unlock_fires_only_once() -> void:
	_trigger_milestone()
	_trigger_milestone()

	var count: int = 0
	for entry: String in _signal_order:
		if entry == "toast_requested:unlock":
			count += 1
	assert_eq(count, 1, "Unlock toast must fire exactly once even when threshold crossed twice")


# ── Helpers ───────────────────────────────────────────────────────────────────


func _capture_milestone_unlocked(
	mid: StringName, _reward: Dictionary
) -> void:
	if mid == MILESTONE_ID:
		_signal_order.append("milestone_unlocked")


func _capture_unlock_granted(uid: StringName) -> void:
	if uid == UNLOCK_ID:
		_signal_order.append("unlock_granted")


func _capture_toast(
	message: String, category: StringName, duration: float
) -> void:
	_toasts.append(
		{"message": message, "category": category, "duration": duration}
	)
	if category == &"unlock":
		_signal_order.append("toast_requested:unlock")


func _trigger_milestone() -> void:
	for i: int in range(MILESTONE_THRESHOLD):
		EventBus.customer_purchased.emit(
			&"test_store", &"item_001", 1.0,
			StringName("cust_%d" % i)
		)


func _find_toast(category: StringName) -> Dictionary:
	for toast: Dictionary in _toasts:
		if toast.get("category", &"") as StringName == category:
			return toast
	return {}


func _build_milestone_def() -> void:
	_milestone_def = MilestoneDefinition.new()
	_milestone_def.id = String(MILESTONE_ID)
	_milestone_def.display_name = "Test Unlock Milestone"
	_milestone_def.trigger_stat_key = "customer_purchased_count"
	_milestone_def.trigger_threshold = float(MILESTONE_THRESHOLD)
	_milestone_def.reward_type = "unlock"
	_milestone_def.reward_value = 0.0
	_milestone_def.unlock_id = String(UNLOCK_ID)
	_milestone_def.is_visible = true
	_data_loader._milestones[String(MILESTONE_ID)] = _milestone_def
