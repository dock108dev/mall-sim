## Displays queued toast notifications from EventBus.toast_requested.
class_name ToastNotificationUI
extends Control


const SLIDE_IN_DURATION: float = 0.2
const SLIDE_OUT_DURATION: float = 0.15
const DEFAULT_DURATION: float = 3.0
const MAX_QUEUE_SIZE: int = 5
const TOAST_WIDTH: float = 300.0
const TOAST_OFFSET_RIGHT: float = 20.0
const TOAST_OFFSET_TOP: float = 60.0

const CATEGORY_COLORS: Dictionary = {
	&"milestone": Color(1.0, 0.84, 0.0),
	&"staff": Color(1.0, 0.6, 0.2),
	&"system": Color.WHITE,
	&"reputation_up": Color(1.0, 0.84, 0.0),
	&"reputation_down": Color(1.0, 0.4, 0.1),
	&"random_event": Color(1.0, 0.75, 0.1),
}
const DEFAULT_COLOR: Color = Color.WHITE

var _queue: Array[Dictionary] = []
var _is_showing: bool = false
var _active_panel: PanelContainer
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.toast_requested.connect(_on_toast_requested)


func _on_toast_requested(
	message: String, category: StringName, duration: float
) -> void:
	if message.is_empty():
		return
	var effective_duration: float = duration if duration > 0.0 else DEFAULT_DURATION
	var entry: Dictionary = {
		"message": message,
		"category": category,
		"duration": effective_duration,
	}
	if _is_showing:
		if _queue.size() >= MAX_QUEUE_SIZE:
			_queue.pop_front()
		_queue.append(entry)
		return
	_show_toast(entry)


func _show_toast(entry: Dictionary) -> void:
	_is_showing = true
	var panel: PanelContainer = _create_toast_panel(entry)
	_active_panel = panel
	add_child(panel)

	var viewport_width: float = get_viewport_rect().size.x
	var target_x: float = viewport_width - TOAST_WIDTH - TOAST_OFFSET_RIGHT
	var start_x: float = viewport_width + 10.0

	panel.position = Vector2(start_x, TOAST_OFFSET_TOP)

	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(
		panel, "position:x", target_x, SLIDE_IN_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_interval(entry.get("duration", DEFAULT_DURATION))
	_tween.tween_property(
		panel, "position:x", start_x, SLIDE_OUT_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(_on_toast_finished)


func dismiss() -> void:
	if not _is_showing or not is_instance_valid(_active_panel):
		return
	_kill_tween()
	var viewport_width: float = get_viewport_rect().size.x
	var offscreen_x: float = viewport_width + 10.0
	_tween = create_tween()
	_tween.tween_property(
		_active_panel, "position:x", offscreen_x, SLIDE_OUT_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(_on_toast_finished)


func _on_toast_finished() -> void:
	if is_instance_valid(_active_panel):
		_active_panel.queue_free()
		_active_panel = null
	_is_showing = false
	if not _queue.is_empty():
		var next: Dictionary = _queue.pop_front()
		_show_toast(next)


func _create_toast_panel(entry: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(TOAST_WIDTH, 40.0)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = entry.get("message", "")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var category: StringName = entry.get("category", &"")
	var tint: Color = CATEGORY_COLORS.get(category, DEFAULT_COLOR)
	label.add_theme_color_override("font_color", tint)

	margin.add_child(label)

	var click_area: Button = Button.new()
	click_area.flat = true
	click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	click_area.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	click_area.pressed.connect(dismiss)
	panel.add_child(click_area)

	return panel


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
