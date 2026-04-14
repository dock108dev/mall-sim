## Tests that StaffManager.quit_staff emits toast_requested via EventBus.
extends GutTest


var _toast_messages: Array[String] = []
var _toast_categories: Array[StringName] = []
var _toast_durations: Array[float] = []


func before_each() -> void:
	_toast_messages.clear()
	_toast_categories.clear()
	_toast_durations.clear()
	EventBus.toast_requested.connect(_on_toast_requested)


func after_each() -> void:
	if EventBus.toast_requested.is_connected(_on_toast_requested):
		EventBus.toast_requested.disconnect(_on_toast_requested)


func test_toast_requested_signal_exists() -> void:
	assert_true(
		EventBus.has_signal("toast_requested"),
		"EventBus should declare toast_requested signal"
	)


func test_quit_staff_emits_toast_requested() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.staff_id = "toast_test_001"
	staff.display_name = "Jane Doe"
	staff.assigned_store_id = "retro_games"
	staff.role = StaffDefinition.StaffRole.CASHIER
	staff.skill_level = 1

	StaffManager._staff_registry["toast_test_001"] = staff
	watch_signals(EventBus)
	StaffManager.quit_staff("toast_test_001")

	assert_signal_emitted(
		EventBus, "staff_quit",
		"staff_quit should fire on quit"
	)
	assert_eq(
		_toast_messages.size(), 1,
		"Exactly one toast should be emitted on staff quit"
	)
	assert_true(
		_toast_messages[0].contains("Jane Doe"),
		"Toast message should include the staff display name"
	)
	assert_eq(
		_toast_durations[0], 4.0,
		"Toast duration should be 4 seconds"
	)


func test_quit_nonexistent_staff_no_toast() -> void:
	StaffManager.quit_staff("nonexistent_id_xyz")
	assert_eq(
		_toast_messages.size(), 0,
		"No toast should fire for nonexistent staff"
	)


func _on_toast_requested(
	message: String, category: StringName, duration: float
) -> void:
	_toast_messages.append(message)
	_toast_categories.append(category)
	_toast_durations.append(duration)
