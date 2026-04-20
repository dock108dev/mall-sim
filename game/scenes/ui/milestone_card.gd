## Unified milestone display — notification banner or panel list row.
##
## Set notification_mode = true before add_child() to enable the sliding
## EventBus-driven notification. Leave false (default) for a static row
## that calls configure() with a data dict and emits clicked().
class_name MilestoneCard
extends PanelContainer


signal clicked(milestone_id: String)

const SLIDE_DURATION: float = 0.3
const HOLD_DURATION: float = 3.0

## true → sliding notification driven by EventBus.milestone_completed.
## false → static row; call configure() and listen to clicked.
@export var notification_mode: bool = false

var _milestone_id: String = ""
var _is_showing: bool = false
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


func _ready() -> void:
	if notification_mode:
		_setup_notification_mode()
	else:
		_setup_row_mode()


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
	_status_label.visible = false
	_right_vbox.visible = false
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EventBus.milestone_completed.connect(_on_milestone_completed)


func _setup_row_mode() -> void:
	_title_label.visible = false
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
	if _is_showing:
		_queue.append(entry)
	else:
		_show_notification(entry)


func _show_notification(entry: Dictionary) -> void:
	configure(entry)
	var reward: String = entry.get("reward", "")
	_right_vbox.visible = not reward.is_empty()
	_is_showing = true

	if not _has_captured_rest:
		_rest_position_y = position.y
		_has_captured_rest = true

	visible = true
	modulate = Color.WHITE
	position.y = -size.y

	PanelAnimator.kill_tween(_tween)
	_tween = create_tween()
	_tween.tween_property(
		self, "position:y", _rest_position_y, SLIDE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_interval(HOLD_DURATION)
	_tween.tween_property(
		self, "position:y", -size.y, SLIDE_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(_on_notification_finished)


func _on_notification_finished() -> void:
	_is_showing = false
	visible = false
	if not _queue.is_empty():
		_show_notification(_queue.pop_front())
