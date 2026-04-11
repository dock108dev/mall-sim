## Centered banner shown when a milestone is completed. Slides in and auto-dismisses.
class_name MilestonePopup
extends PanelContainer


const DISPLAY_DURATION: float = 3.0
const SLIDE_DURATION: float = 0.3
const SLIDE_OFFSET: float = -80.0

var _timer: float = 0.0
var _is_showing: bool = false
var _queue: Array[Dictionary] = []
var _rest_position_y: float = 0.0

@onready var _title_label: Label = $Margin/VBox/TitleLabel
@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _reward_label: Label = $Margin/VBox/RewardLabel


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	EventBus.milestone_completed.connect(_on_milestone_completed)


func _process(delta: float) -> void:
	if not _is_showing:
		return
	_timer -= delta
	if _timer <= 0.0:
		_dismiss()


func _on_gui_input(event: InputEvent) -> void:
	if not _is_showing:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_dismiss()


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
	_timer = DISPLAY_DURATION
	_is_showing = true
	visible = true

	_rest_position_y = position.y
	position.y = _rest_position_y + SLIDE_OFFSET
	modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		self, "position:y", _rest_position_y, SLIDE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(
		self, "modulate:a", 1.0, SLIDE_DURATION * 0.7
	)


func _dismiss() -> void:
	_is_showing = false
	var tween: Tween = create_tween()
	tween.tween_property(
		self, "modulate:a", 0.0, SLIDE_DURATION * 0.5
	)
	tween.tween_callback(_hide_and_show_next)


func _hide_and_show_next() -> void:
	visible = false
	modulate.a = 0.0
	if not _queue.is_empty():
		var next: Dictionary = _queue.pop_front()
		_show_popup(next)
