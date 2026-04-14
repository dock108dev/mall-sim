## Top-anchored banner that slides down on milestone completion and auto-dismisses.
class_name MilestonePopup
extends PanelContainer


const SLIDE_DURATION: float = 0.3
const HOLD_DURATION: float = 3.0

var _is_showing: bool = false
var _queue: Array[Dictionary] = []
var _rest_position_y: float = 0.0
var _has_captured_rest: bool = false
var _tween: Tween

@onready var _title_label: Label = $Margin/VBox/TitleLabel
@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _reward_label: Label = $Margin/VBox/RewardLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.milestone_completed.connect(_on_milestone_completed)


func _on_milestone_completed(
	_milestone_id: String,
	milestone_name: String,
	reward_description: String
) -> void:
	var entry: Dictionary = {
		"name": milestone_name,
		"reward": reward_description,
	}
	if _is_showing:
		_queue.append(entry)
		return
	_show_popup(entry)


func _show_popup(entry: Dictionary) -> void:
	_title_label.text = tr("MILESTONE_COMPLETE")
	_name_label.text = entry.get("name", "")
	_reward_label.text = entry.get("reward", "")
	_is_showing = true

	if not _has_captured_rest:
		_rest_position_y = position.y
		_has_captured_rest = true

	visible = true
	modulate.a = 1.0
	position.y = -size.y

	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(
		self, "position:y", _rest_position_y, SLIDE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_interval(HOLD_DURATION)
	_tween.tween_property(
		self, "position:y", -size.y, SLIDE_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(_on_banner_finished)


func _on_banner_finished() -> void:
	_is_showing = false
	visible = false
	if not _queue.is_empty():
		var next: Dictionary = _queue.pop_front()
		_show_popup(next)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
