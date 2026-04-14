## Integration test: staff morale quit chain — morale hits threshold →
## staff_quit emitted → roster decremented → toast notification fired.
extends GutTest

const STORE_ID: String = "test_quit_store"
const STAFF_ID: String = "test_quit_staff_001"
const HIGH_MORALE_STAFF_ID: String = "test_quit_staff_002"

var _staff_def: StaffDefinition = null
var _original_store_id: StringName = &""
var _saved_difficulty: StringName = &""


func before_each() -> void:
	_original_store_id = GameManager.current_store_id
	_saved_difficulty = DifficultySystemSingleton.get_current_tier_id()
	GameManager.current_store_id = STORE_ID
	DifficultySystemSingleton.set_tier(&"normal")

	_staff_def = _make_pre_quit_staff(STAFF_ID, STORE_ID)
	StaffManager._staff_registry[STAFF_ID] = _staff_def


func after_each() -> void:
	if StaffManager._staff_registry.has(STAFF_ID):
		StaffManager._staff_registry.erase(STAFF_ID)
	if StaffManager._staff_registry.has(HIGH_MORALE_STAFF_ID):
		StaffManager._staff_registry.erase(HIGH_MORALE_STAFF_ID)
	GameManager.current_store_id = _original_store_id
	DifficultySystemSingleton.set_tier(_saved_difficulty)


# ── Scenario A — staff_quit signal fires with the correct staff_id ────────────


func test_staff_quit_signal_emitted() -> void:
	watch_signals(EventBus)

	StaffManager._check_quit_triggers()

	assert_signal_emitted(
		EventBus, "staff_quit",
		"staff_quit should fire when morale is below threshold for the required consecutive days"
	)


func test_staff_quit_signal_carries_correct_staff_id() -> void:
	watch_signals(EventBus)

	StaffManager._check_quit_triggers()

	var params: Array = get_signal_parameters(EventBus, "staff_quit")
	assert_eq(
		params[0] as String,
		STAFF_ID,
		"staff_quit should carry the correct staff_id for the member who quit"
	)


# ── Scenario B — roster no longer contains the quit staff member ──────────────


func test_roster_excludes_quit_staff_after_trigger() -> void:
	StaffManager._check_quit_triggers()

	var roster: Array[StaffDefinition] = StaffManager.get_staff_for_store(STORE_ID)
	var still_present: bool = false
	for member: StaffDefinition in roster:
		if member.staff_id == STAFF_ID:
			still_present = true
			break
	assert_false(
		still_present,
		"Quit staff member should not appear in get_staff_for_store after quitting"
	)


func test_registry_does_not_contain_quit_staff() -> void:
	StaffManager._check_quit_triggers()

	assert_false(
		StaffManager._staff_registry.has(STAFF_ID),
		"StaffManager registry should not contain the staff_id after the member quits"
	)


# ── Scenario C — toast_requested fires after staff_quit ───────────────────────


func test_toast_requested_emitted_after_quit() -> void:
	watch_signals(EventBus)

	StaffManager._check_quit_triggers()

	assert_signal_emitted(
		EventBus, "toast_requested",
		"toast_requested should be emitted after a staff member quits"
	)


func test_toast_category_is_staff() -> void:
	watch_signals(EventBus)

	StaffManager._check_quit_triggers()

	var params: Array = get_signal_parameters(EventBus, "toast_requested")
	assert_eq(
		params[1] as StringName,
		&"staff",
		"toast_requested category should be 'staff' for a staff quit notification"
	)


# ── Scenario D — staff with high morale does not quit ────────────────────────


func test_high_morale_staff_does_not_quit() -> void:
	var healthy_def: StaffDefinition = StaffDefinition.new()
	healthy_def.staff_id = HIGH_MORALE_STAFF_ID
	healthy_def.display_name = "Motivated Worker"
	healthy_def.role = StaffDefinition.StaffRole.GREETER
	healthy_def.skill_level = 2
	healthy_def.daily_wage = 0.0
	healthy_def.assigned_store_id = STORE_ID
	healthy_def.morale = StaffDefinition.DEFAULT_MORALE
	healthy_def.consecutive_low_morale_days = 0
	StaffManager._staff_registry[HIGH_MORALE_STAFF_ID] = healthy_def

	watch_signals(EventBus)
	StaffManager._check_quit_triggers()

	var roster: Array[StaffDefinition] = StaffManager.get_staff_for_store(STORE_ID)
	var found: bool = false
	for member: StaffDefinition in roster:
		if member.staff_id == HIGH_MORALE_STAFF_ID:
			found = true
			break
	assert_true(
		found,
		"A staff member with healthy morale should remain on the roster after the quit check"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


## Creates a StaffDefinition with morale at zero and consecutive_low_morale_days
## at one less than the quit threshold so that a single _check_quit_triggers()
## call increments the counter to the threshold and fires the quit.
func _make_pre_quit_staff(
	staff_id: String, store_id: String
) -> StaffDefinition:
	var def: StaffDefinition = StaffDefinition.new()
	def.staff_id = staff_id
	def.display_name = "Quitting Tester"
	def.role = StaffDefinition.StaffRole.CASHIER
	def.skill_level = 1
	def.daily_wage = 0.0
	def.assigned_store_id = store_id
	def.morale = 0.0
	def.consecutive_low_morale_days = (
		StaffManager.MORALE_QUIT_CONSECUTIVE_DAYS - 1
	)
	return def
