## Persistent moments-log panel — shows all witnessed ambient moments with
## day and phase context. Accessible from the mall hub via the Moments button.
class_name MomentsLogPanel
extends CanvasLayer


const PANEL_NAME: String = "moments_log"

const _PHASE_NAMES: Dictionary = {
	0: "Pre-Open",
	1: "Morning",
	2: "Midday",
	3: "Afternoon",
	4: "Evening",
}

var ambient_moments_system: AmbientMomentsSystem = null
var _is_open: bool = false
var _anim_tween: Tween
var _rest_x: float = 0.0

@onready var _panel: PanelContainer = $PanelRoot
@onready var _list: VBoxContainer = $PanelRoot/Margin/VBox/Scroll/List
@onready var _close_button: Button = $PanelRoot/Margin/VBox/Header/CloseButton
@onready var _empty_label: Label = $PanelRoot/Margin/VBox/Scroll/List/EmptyLabel


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_close_button.pressed.connect(close)
	EventBus.ambient_moment_delivered.connect(_on_moment_delivered)
	EventBus.panel_opened.connect(_on_panel_opened)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.is_action_pressed("ui_cancel") and _is_open:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_refresh_list()
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_open(_panel, _rest_x, false)
	EventBus.panel_opened.emit(PANEL_NAME)


func close(immediate: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	PanelAnimator.kill_tween(_anim_tween)
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(_panel, _rest_x, false)
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_moment_delivered(
	_moment_id: StringName,
	_display_type: StringName,
	_flavor_text: String,
	_audio_cue_id: StringName,
) -> void:
	if _is_open:
		_refresh_list()


func _refresh_list() -> void:
	for child: Node in _list.get_children():
		if child != _empty_label:
			_list.remove_child(child)
			child.queue_free()

	if not ambient_moments_system:
		_empty_label.visible = true
		return

	var log: Array[Dictionary] = ambient_moments_system.get_witnessed_log()
	if log.is_empty():
		_empty_label.visible = true
		return

	_empty_label.visible = false
	for i: int in range(log.size() - 1, -1, -1):
		_add_entry_row(log[i])


func _add_entry_row(entry: Dictionary) -> void:
	var day: int = int(entry.get("day", 0))
	var phase: int = int(entry.get("phase", 0))
	var flavor: String = String(entry.get("flavor_text", ""))
	var phase_name: String = _PHASE_NAMES.get(phase, "Day")
	var timestamp: String = "D%d %s" % [day, phase_name]

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var ts_label: Label = Label.new()
	ts_label.text = "[%s]" % timestamp
	ts_label.custom_minimum_size = Vector2(110.0, 0.0)
	ts_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	row.add_child(ts_label)

	var body: Label = Label.new()
	body.text = flavor
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)

	_list.add_child(row)


## Returns the number of rendered entry rows (excluding the empty placeholder).
func get_entry_count() -> int:
	return _list.get_child_count() - 1
