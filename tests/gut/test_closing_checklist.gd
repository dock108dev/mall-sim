## Tests the pre-summary closing-checklist panel: opens for a day, advances on
## task button presses, gates the discrepancy-flag affordance behind tasks 3
## and 4, emits inventory_discrepancy_flagged exactly once per eligible task,
## and emits closing_checklist_completed once all four tasks are resolved.
extends GutTest


var _checklist: ClosingChecklist
var _completed_signals: Array[int] = []
var _discrepancy_signals: int = 0


func before_each() -> void:
	_completed_signals = []
	_discrepancy_signals = 0
	_checklist = preload(
		"res://game/scenes/ui/closing_checklist.tscn"
	).instantiate() as ClosingChecklist
	add_child_autofree(_checklist)
	_checklist.completed.connect(
		func(day: int) -> void: _completed_signals.append(day)
	)
	EventBus.inventory_discrepancy_flagged.connect(
		_on_discrepancy_flagged
	)


func after_each() -> void:
	if EventBus.inventory_discrepancy_flagged.is_connected(
		_on_discrepancy_flagged
	):
		EventBus.inventory_discrepancy_flagged.disconnect(
			_on_discrepancy_flagged
		)
	_checklist._reset_for_tests()


func _on_discrepancy_flagged(
	_item_id: String, _expected: int, _actual: int
) -> void:
	_discrepancy_signals += 1


func test_open_for_day_resets_state_and_shows_panel() -> void:
	_checklist.open_for_day(7)
	assert_true(_checklist.visible)
	assert_eq(_checklist._current_day, 7)
	for resolved: bool in _checklist._task_resolved:
		assert_false(resolved)
	assert_true(_checklist._flag_discrepancy_button.disabled)


func test_completing_all_four_tasks_emits_completed() -> void:
	_checklist.open_for_day(2)
	_checklist._on_task_pressed(ClosingChecklist.TASK_REGISTER)
	_checklist._on_task_pressed(ClosingChecklist.TASK_HOLDS)
	_checklist._on_task_pressed(ClosingChecklist.TASK_SHELF)
	_checklist._on_task_pressed(ClosingChecklist.TASK_SIGN_OFF)
	assert_eq(_completed_signals.size(), 1)
	assert_eq(_completed_signals[0], 2)
	assert_false(_checklist.visible)


func test_partial_progress_does_not_complete() -> void:
	_checklist.open_for_day(3)
	_checklist._on_task_pressed(ClosingChecklist.TASK_REGISTER)
	_checklist._on_task_pressed(ClosingChecklist.TASK_HOLDS)
	assert_eq(_completed_signals.size(), 0)
	assert_true(_checklist.visible)


func test_flag_button_disabled_until_task_3_or_4_resolved() -> void:
	_checklist.open_for_day(1)
	assert_true(_checklist._flag_discrepancy_button.disabled)
	_checklist._on_task_pressed(ClosingChecklist.TASK_REGISTER)
	assert_true(_checklist._flag_discrepancy_button.disabled)
	_checklist._on_task_pressed(ClosingChecklist.TASK_SHELF)
	assert_false(_checklist._flag_discrepancy_button.disabled)


func test_flag_button_emits_one_discrepancy_per_eligible_task() -> void:
	_checklist.open_for_day(1)
	_checklist._on_task_pressed(ClosingChecklist.TASK_SHELF)
	_checklist._on_flag_discrepancy_pressed()
	# Spamming the flag button while only task 3 is resolved must not
	# inflate the count.
	_checklist._on_flag_discrepancy_pressed()
	assert_eq(_discrepancy_signals, 1)
	_checklist._on_task_pressed(ClosingChecklist.TASK_SIGN_OFF)
	_checklist._on_flag_discrepancy_pressed()
	assert_eq(_discrepancy_signals, 2)


func test_repeating_a_resolved_task_is_a_no_op() -> void:
	_checklist.open_for_day(1)
	_checklist._on_task_pressed(ClosingChecklist.TASK_HOLDS)
	_checklist._on_task_pressed(ClosingChecklist.TASK_HOLDS)
	# Only one task is resolved — the repeat must not advance the
	# completion contract.
	assert_eq(_completed_signals.size(), 0)
