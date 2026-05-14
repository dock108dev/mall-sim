## Unified milestone display — notification banner or panel list row.
##
## Set notification_mode = true before add_child() to enable the sliding
## EventBus-driven notification. Leave false (default) for a static row
## that calls configure() with a data dict and emits clicked().
##
## In notification mode milestones auto-dismiss like toast banners. Avoid
## requiring a Continue click during the first-play opening sequence; the
## underlying unlock still fires through UnlockSystem.
class_name MilestoneCard
extends PanelContainer


signal clicked(milestone_id: String)

const SLIDE_DURATION: float = 0.3
const HOLD_DURATION: float = 3.0

## Milestones that demand a player read instead of an auto-dismiss toast.
## Empty by default so first-play unlocks never create an extra start gate.
## Keys are MilestoneDefinition ids; values are unused (set semantics).
const CONFIRM_REQUIRED_IDS: Dictionary = {}

## true → sliding notification driven by EventBus.milestone_completed.
## false → static row; call configure() and listen to clicked.
@export var notification_mode: bool = false

var _milestone_id: String = ""
var _is_showing: bool = false
var _is_confirm_active: bool = false
var _focus_pushed: bool = false
var _queue: Array[Dictionary] = []
var _rest_position_y: float = 0.0
var _has_captured_rest: bool = false
var _tween: Tween

@onready var _title_label: Label = $Margin/MainVBox/TitleLabel
@onready var _status_label: Label = $Margin/MainVBox/ContentHBox/StatusLabel
@onready var _name_label: Label = $Margin/MainVBox/ContentHBox/InfoVBox/NameLabel
@onready var _desc_label: Label = $Margin/MainVBox/ContentHBox/InfoVBox/DescriptionLabel
@onready var _right_vbox: VBoxContainer = $Margin/MainVBox/ContentHBox/RightVBox
@onready var _reward_label: Label = $Margin/MainVBox/ContentHBox/RightVBox/RewardLabel
@onready var _progress_label: Label = $Margin/MainVBox/ContentHBox/RightVBox/ProgressLabel
@onready var _done_label: Label = $Margin/MainVBox/ContentHBox/RightVBox/DoneLabel
@onready var _inline_reward_label: Label = $Margin/MainVBox/InlineRewardLabel
@onready var _continue_button: Button = $Margin/MainVBox/ContinueButton


func _ready() -> void:
	if notification_mode:
		_setup_notification_mode()
	else:
		_setup_row_mode()


func _exit_tree() -> void:
	if _focus_pushed:
		_pop_modal_focus()


## Populate display fields from a data dict.
## Keys: milestone_id, name, description, reward, is_completed (bool), progress (float 0-1).
func configure(data: Dictionary) -> void:
	_milestone_id = data.get("milestone_id", "")
	_name_label.text = data.get("name", "")
	var desc: String = data.get("description", "")
	_desc_label.text = desc
	_desc_label.visible = not desc.is_empty()
	var reward: String = data.get("reward", "")
	_reward_label.text = reward
	_reward_label.visible = not reward.is_empty()
	if not notification_mode:
		_configure_row_status(data)


func _configure_row_status(data: Dictionary) -> void:
	var is_done: bool = data.get("is_completed", false)
	_status_label.text = (
		tr("MILESTONE_CHECK_DONE") if is_done else tr("MILESTONE_CHECK_UNDONE")
	)
	if is_done:
		_done_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		_done_label.text = tr("MILESTONE_COMPLETED")
		_done_label.visible = true
		_progress_label.visible = false
	else:
		var pct: int = roundi(float(data.get("progress", 0.0)) * 100.0)
		_progress_label.text = tr("MILESTONE_PROGRESS") % pct
		_progress_label.visible = true
		_done_label.visible = false


func _setup_notification_mode() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hide the static "Milestone Complete!" header — the milestone NameLabel
	# carries the heading role in notification/confirm mode to remove the
	# duplicate-title look the prior layout produced.
	_title_label.visible = false
	_name_label.theme_type_variation = &"HeaderLabel"
	_status_label.visible = false
	_right_vbox.visible = false
	_inline_reward_label.visible = false
	_continue_button.visible = false
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_button.pressed.connect(_on_continue_pressed)
	EventBus.milestone_completed.connect(_on_milestone_completed)
	# Defer onto the internal queue while a ModalQueue panel is active, so
	# a milestone firing during the Vic-note spawn window does not slide in
	# on top of the note and push CTX_MODAL onto a stacked frame. When the
	# foreground modal closes (`active_panel == null`), drain whatever
	# milestones piled up while we were waiting.
	ModalQueue.active_changed.connect(_on_modal_queue_active_changed)


func _setup_row_mode() -> void:
	_title_label.visible = false
	_inline_reward_label.visible = false
	_continue_button.visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 50)
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(_milestone_id)


func _on_milestone_completed(
	milestone_id: String,
	milestone_name: String,
	reward_description: String,
) -> void:
	var desc: String = ""
	if GameManager.data_loader:
		var definition: MilestoneDefinition = (
			GameManager.data_loader.get_milestone(milestone_id)
		)
		if definition:
			desc = definition.description
	var entry: Dictionary = {
		"milestone_id": milestone_id,
		"name": milestone_name,
		"description": desc,
		"reward": reward_description,
	}
	# Brief: "there is at most one blocking modal open." A ModalQueue panel
	# in the active slot owns the foreground — even when it is a passive
	# overlay like the Vic note that does not push CTX_MODAL itself, a
	# milestone confirm card firing into the same window stacks two
	# surfaces over the player. Hold the entry until the queue drains.
	if _is_showing or ModalQueue.is_busy():
		_queue.append(entry)
	else:
		_show_notification(entry)


func _on_modal_queue_active_changed(active: ModalPanel) -> void:
	# Drain any milestones we deferred while the foreground modal was up.
	# Only fires the next one — `_on_notification_finished` continues the
	# chain after that, matching the existing intra-card queue contract.
	if active != null:
		return
	if _is_showing:
		return
	if _queue.is_empty():
		return
	_show_notification(_queue.pop_front())


func _show_notification(entry: Dictionary) -> void:
	configure(entry)
	var reward: String = entry.get("reward", "")
	# Right-column layout is row-mode only; in notification mode the reward
	# is shown inline (centered, below the description) when present.
	_right_vbox.visible = false
	_is_showing = true

	if not _has_captured_rest:
		_rest_position_y = position.y
		_has_captured_rest = true

	visible = true
	modulate = Color.WHITE
	position.y = -size.y

	var requires_confirm: bool = CONFIRM_REQUIRED_IDS.has(
		entry.get("milestone_id", "")
	)
	_inline_reward_label.text = reward
	_inline_reward_label.visible = requires_confirm and not reward.is_empty()
	_continue_button.visible = requires_confirm

	PanelAnimator.kill_tween(_tween)
	_tween = create_tween()
	_tween.tween_property(
		self, "position:y", _rest_position_y, SLIDE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	if requires_confirm:
		_open_confirm_modal()
	else:
		_tween.tween_interval(HOLD_DURATION)
		_tween.tween_property(
			self, "position:y", -size.y, SLIDE_DURATION
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		_tween.tween_callback(_on_notification_finished)


func _open_confirm_modal() -> void:
	_is_confirm_active = true
	_push_modal_focus()
	# Ensure focus lands on the Continue button on the same frame the modal
	# opens so keyboard players can press Enter without touching the mouse.
	_continue_button.grab_focus()


func _on_continue_pressed() -> void:
	if not _is_confirm_active:
		return
	_is_confirm_active = false
	_pop_modal_focus()
	PanelAnimator.kill_tween(_tween)
	_tween = create_tween()
	_tween.tween_property(
		self, "position:y", -size.y, SLIDE_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(_on_notification_finished)


func _on_notification_finished() -> void:
	_is_showing = false
	_is_confirm_active = false
	_continue_button.visible = false
	_inline_reward_label.visible = false
	visible = false
	if not _queue.is_empty():
		_show_notification(_queue.pop_front())


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
				"MilestoneCard: expected CTX_MODAL on top, got %s — "
				+ "leaving stack untouched to avoid corrupting sibling frame"
			)
			% String(InputFocus.current())
		)
		_focus_pushed = false
		return
	InputFocus.pop_context()
	_focus_pushed = false


## Test seam — clears _focus_pushed without calling pop_context.
func _reset_for_tests() -> void:
	_focus_pushed = false
