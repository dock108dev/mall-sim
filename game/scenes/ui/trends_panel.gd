## Panel displaying active market trends (hot and cold categories/tags).
class_name TrendsPanel
extends CanvasLayer


const PANEL_NAME: String = "trends"
const HOT_COLOR := Color(0.9, 0.3, 0.2)
const COLD_COLOR := Color(0.3, 0.5, 0.9)
const ANNOUNCED_COLOR := Color(0.7, 0.7, 0.5)

var trend_system: TrendSystem
var _is_open: bool = false
var _anim_tween: Tween
var _rest_x: float = 0.0

@onready var _panel: PanelContainer = $PanelRoot
@onready var _grid: VBoxContainer = (
	$PanelRoot/Margin/VBox/Scroll/Grid
)
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_close_button.pressed.connect(close)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.trend_changed.connect(_on_trend_changed)
	EventBus.active_store_changed.connect(_on_active_store_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_T:
		_toggle()
		get_viewport().set_input_as_handled()
	elif key_event.is_action_pressed("ui_cancel") and _is_open:
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
		_anim_tween = PanelAnimator.slide_close(
			_panel, _rest_x, false
		)
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _refresh_list() -> void:
	_clear_list()
	if not trend_system:
		_add_empty_label()
		return
	var trends: Array[Dictionary] = trend_system.get_active_trends()
	if trends.is_empty():
		_add_empty_label()
		return
	for trend: Dictionary in trends:
		_create_trend_row(trend)


func _clear_list() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()


func _add_empty_label() -> void:
	var label := Label.new()
	label.text = tr("TRENDS_NO_ACTIVE")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grid.add_child(label)


func _create_trend_row(trend: Dictionary) -> void:
	var target: String = trend.get("target", "unknown")
	var target_type: String = trend.get("target_type", "category")
	var trend_type: int = trend.get("trend_type", 0) as int
	var multiplier: float = trend.get("multiplier", 1.0) as float
	var announced_day: int = trend.get("announced_day", 0) as int
	var active_day: int = trend.get("active_day", 0) as int
	var end_day: int = trend.get("end_day", 0) as int
	var fade_end: int = trend.get("fade_end_day", 0) as int
	var current_day: int = GameManager.current_day

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 40)

	var icon_label := Label.new()
	icon_label.custom_minimum_size = Vector2(30, 0)
	var is_hot: bool = trend_type == TrendSystem.TrendType.HOT
	icon_label.text = "^" if is_hot else "v"
	icon_label.add_theme_color_override(
		"font_color", HOT_COLOR if is_hot else COLD_COLOR
	)
	row.add_child(icon_label)

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = "%s (%s)" % [target, target_type]
	info_box.add_child(name_label)

	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 12)
	var status_text: String = _get_status_text(
		current_day, active_day, end_day, fade_end
	)
	status_label.text = status_text
	if current_day < active_day:
		status_label.add_theme_color_override(
			"font_color", ANNOUNCED_COLOR
		)
	info_box.add_child(status_label)

	row.add_child(info_box)

	var mult_label := Label.new()
	mult_label.custom_minimum_size = Vector2(80, 0)
	mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mult_label.text = "x%.2f" % multiplier
	mult_label.add_theme_color_override(
		"font_color", HOT_COLOR if is_hot else COLD_COLOR
	)
	row.add_child(mult_label)

	_grid.add_child(row)

	var sep := HSeparator.new()
	_grid.add_child(sep)


func _get_status_text(
	current_day: int,
	active_day: int,
	end_day: int,
	fade_end: int,
) -> String:
	if current_day < active_day:
		return tr("TRENDS_ANNOUNCED") % (
			active_day - current_day
		)
	if current_day < end_day:
		return tr("TRENDS_ACTIVE") % (end_day - current_day)
	if current_day < fade_end:
		return tr("TRENDS_FADING") % (fade_end - current_day)
	return tr("TRENDS_EXPIRING")


func _on_active_store_changed(new_store_id: StringName) -> void:
	if _is_open:
		if new_store_id.is_empty():
			close(true)
		else:
			_refresh_list()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_trend_changed(
	_trending: Array, _cold: Array
) -> void:
	if _is_open:
		_refresh_list()
