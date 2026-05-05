## Pre-summary closing checklist gated by the `employee_closing_certified`
## unlock. The player works through four button-driven tasks against live
## state; each click resolves the task. Completed checklists emit
## `EventBus.closing_checklist_completed(day)`; the day cycle controller
## opens `DaySummary` once that signal fires.
##
## Discrepancies flagged during tasks 3 and 4 emit
## `EventBus.inventory_discrepancy_flagged` so PerformanceReportSystem can
## roll them into the day's `discrepancies_flagged` count.
class_name ClosingChecklist
extends CanvasLayer


signal completed(day: int)

const TASK_COUNT: int = 4
const TASK_REGISTER: int = 0
const TASK_HOLDS: int = 1
const TASK_SHELF: int = 2
const TASK_SIGN_OFF: int = 3

var _focus_pushed: bool = false
var _current_day: int = 0
var _task_buttons: Array[Button] = []
var _task_status_labels: Array[Label] = []
var _task_resolved: Array[bool] = []
var _flagged_task_3: bool = false
var _flagged_task_4: bool = false

@onready var _root: Control = $Root
@onready var _overlay: ColorRect = $Root/Overlay
@onready var _panel: PanelContainer = $Root/Panel
@onready var _title_label: Label = $Root/Panel/Margin/VBox/Title
@onready var _task_register_button: Button = (
	$Root/Panel/Margin/VBox/TaskRow1/TaskRegisterButton
)
@onready var _task_register_status: Label = (
	$Root/Panel/Margin/VBox/TaskRow1/TaskRegisterStatus
)
@onready var _task_holds_button: Button = (
	$Root/Panel/Margin/VBox/TaskRow2/TaskHoldsButton
)
@onready var _task_holds_status: Label = (
	$Root/Panel/Margin/VBox/TaskRow2/TaskHoldsStatus
)
@onready var _task_shelf_button: Button = (
	$Root/Panel/Margin/VBox/TaskRow3/TaskShelfButton
)
@onready var _task_shelf_status: Label = (
	$Root/Panel/Margin/VBox/TaskRow3/TaskShelfStatus
)
@onready var _task_sign_off_button: Button = (
	$Root/Panel/Margin/VBox/TaskRow4/TaskSignOffButton
)
@onready var _task_sign_off_status: Label = (
	$Root/Panel/Margin/VBox/TaskRow4/TaskSignOffStatus
)
@onready var _flag_discrepancy_button: Button = (
	$Root/Panel/Margin/VBox/FlagRow/FlagDiscrepancyButton
)


func _ready() -> void:
	visible = false
	_task_buttons = [
		_task_register_button,
		_task_holds_button,
		_task_shelf_button,
		_task_sign_off_button,
	]
	_task_status_labels = [
		_task_register_status,
		_task_holds_status,
		_task_shelf_status,
		_task_sign_off_status,
	]
	_task_register_button.pressed.connect(
		_on_task_pressed.bind(TASK_REGISTER)
	)
	_task_holds_button.pressed.connect(_on_task_pressed.bind(TASK_HOLDS))
	_task_shelf_button.pressed.connect(_on_task_pressed.bind(TASK_SHELF))
	_task_sign_off_button.pressed.connect(
		_on_task_pressed.bind(TASK_SIGN_OFF)
	)
	_flag_discrepancy_button.pressed.connect(_on_flag_discrepancy_pressed)
	_flag_discrepancy_button.disabled = true


## Opens the checklist for the given day. Resets task state so a re-entered
## checklist starts blank.
func open_for_day(day: int) -> void:
	_current_day = day
	_task_resolved = []
	_flagged_task_3 = false
	_flagged_task_4 = false
	_task_resolved.resize(TASK_COUNT)
	for i: int in TASK_COUNT:
		_task_resolved[i] = false
		if is_instance_valid(_task_buttons[i]):
			_task_buttons[i].disabled = false
		if is_instance_valid(_task_status_labels[i]):
			_task_status_labels[i].text = ""
	_flag_discrepancy_button.disabled = true
	_title_label.text = "Closing Checklist — Day %d" % day
	visible = true
	_overlay.visible = true
	_panel.visible = true
	_push_modal_focus()


func _on_task_pressed(task_index: int) -> void:
	# §F-138 — task_index out-of-bounds is unreachable from the production
	# wiring at lines 77-84 (each task button binds to one of the four
	# TASK_REGISTER / TASK_HOLDS / TASK_SHELF / TASK_SIGN_OFF constants);
	# the guard exists so a future direct caller can't desync the resolved
	# array. _task_resolved[task_index] true is a normal idempotency case
	# (player double-clicks a completed task), not an error path.
	if task_index < 0 or task_index >= TASK_COUNT:
		return
	if _task_resolved[task_index]:
		return
	_task_resolved[task_index] = true
	if is_instance_valid(_task_buttons[task_index]):
		_task_buttons[task_index].disabled = true
	if is_instance_valid(_task_status_labels[task_index]):
		_task_status_labels[task_index].text = "✓ Done"
	# Tasks 3 and 4 enable the discrepancy-flag affordance — those tasks
	# compare live data against the manifest and the sign-off ledger; either
	# one might surface a mismatch.
	if task_index == TASK_SHELF or task_index == TASK_SIGN_OFF:
		_flag_discrepancy_button.disabled = false
	if _all_tasks_resolved():
		_finish()


func _on_flag_discrepancy_pressed() -> void:
	# Idempotent per task: a player can only contribute one discrepancy per
	# eligible task so spamming the button doesn't inflate the count.
	var added: bool = false
	if _task_resolved[TASK_SHELF] and not _flagged_task_3:
		_flagged_task_3 = true
		EventBus.inventory_discrepancy_flagged.emit(
			"shelf_vs_manifest", 0, 0
		)
		added = true
	elif _task_resolved[TASK_SIGN_OFF] and not _flagged_task_4:
		_flagged_task_4 = true
		EventBus.inventory_discrepancy_flagged.emit(
			"sign_off_ledger", 0, 0
		)
		added = true
	if added and _flagged_task_3 and _flagged_task_4:
		_flag_discrepancy_button.disabled = true


func _all_tasks_resolved() -> bool:
	for resolved: bool in _task_resolved:
		if not resolved:
			return false
	return true


func _finish() -> void:
	_pop_modal_focus()
	visible = false
	_overlay.visible = false
	_panel.visible = false
	completed.emit(_current_day)
	EventBus.closing_checklist_completed.emit(_current_day)


func _push_modal_focus() -> void:
	if _focus_pushed:
		return
	InputFocus.push_context(InputFocus.CTX_MODAL)
	_focus_pushed = true


func _pop_modal_focus() -> void:
	if not _focus_pushed:
		return
	if InputFocus.current() != InputFocus.CTX_MODAL:
		push_error(
			(
				"ClosingChecklist._finish: expected CTX_MODAL on top, got %s — "
				+ "leaving stack untouched to avoid corrupting sibling frame"
			)
			% String(InputFocus.current())
		)
		_focus_pushed = false
		return
	InputFocus.pop_context()
	_focus_pushed = false


func _exit_tree() -> void:
	if _focus_pushed:
		_pop_modal_focus()


## Test seam — clears modal-focus tracking so test harnesses that wipe the
## focus stack do not strand a frame on InputFocus.
func _reset_for_tests() -> void:
	_focus_pushed = false
