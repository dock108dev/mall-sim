## Top HUD milestone banner shown when a milestone unlocks.
class_name MilestoneBanner
extends PanelContainer


const BANNER_SLIDE_DURATION: float = 0.3
const BANNER_HOLD_DURATION: float = 3.0

var _is_showing: bool = false
var _queue: Array[Dictionary] = []
var _rest_position_y: float = 0.0
var _has_captured_rest: bool = false
var _tween: Tween

@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _description_label: Label = $Margin/VBox/DescriptionLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.milestone_unlocked.connect(_on_milestone_unlocked)


func _on_milestone_unlocked(
	milestone_id: StringName, _reward: Dictionary
) -> void:
	var entry: Dictionary = _build_banner_entry(milestone_id)
	if _is_showing:
		_queue.append(entry)
		return
	_show_banner(entry)


func _build_banner_entry(milestone_id: StringName) -> Dictionary:
	var definition: MilestoneDefinition = null
	if GameManager.data_loader:
		definition = GameManager.data_loader.get_milestone(
			String(milestone_id)
		)
	if definition:
		return {
			"name": definition.display_name,
			"description": definition.description,
		}
	var display_name: String = ContentRegistry.get_display_name(
		milestone_id
	)
	if display_name.is_empty():
		display_name = String(milestone_id).capitalize()
	return {
		"name": display_name,
		"description": "",
	}


func _show_banner(entry: Dictionary) -> void:
	_name_label.text = str(entry.get("name", ""))
	_description_label.text = str(entry.get("description", ""))
	_description_label.visible = not _description_label.text.is_empty()
	_is_showing = true

	if not _has_captured_rest:
		_rest_position_y = position.y
		_has_captured_rest = true

	visible = true
	modulate = Color.WHITE
	position.y = -size.y

	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(
		self, "position:y", _rest_position_y,
		BANNER_SLIDE_DURATION,
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_interval(BANNER_HOLD_DURATION)
	_tween.tween_property(
		self, "position:y", -size.y,
		BANNER_SLIDE_DURATION,
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(_on_banner_finished)


func _on_banner_finished() -> void:
	_is_showing = false
	visible = false
	if _queue.is_empty():
		return
	var next: Dictionary = _queue.pop_front()
	_show_banner(next)


func _kill_tween() -> void:
	PanelAnimator.kill_tween(_tween)
