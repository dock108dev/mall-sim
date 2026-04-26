## Manages a single cursor-following tooltip panel for the entire UI.
extends Node


const TOOLTIP_FADE_DURATION: float = PanelAnimator.TOOLTIP_FADE_DURATION
const MAX_WIDTH: float = 240.0
const SCREEN_MARGIN: int = 12
const TOOLTIP_OFFSET := Vector2(16, 16)
const BG_COLOR := Color(0.08, 0.08, 0.1, 0.9)
const PANEL_HORIZONTAL_PADDING: float = 16.0

var _panel: PanelContainer
var _label: Label
var _fade_tween: Tween
var _is_visible: bool = false
var _last_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_panel()
	EventBus.panel_opened.connect(_on_panel_opened)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_visible:
		return
	if event is InputEventKey and event.pressed:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			hide_tooltip()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		hide_tooltip()


func _process(_delta: float) -> void:
	if _is_visible:
		_follow_mouse()


## Shows a text tooltip at the supplied cursor position.
func show_tooltip(text: String, screen_position: Vector2) -> void:
	if text.is_empty():
		hide_tooltip()
		return
	_display_tooltip(text, screen_position)


## Immediately hides the tooltip.
func hide_tooltip() -> void:
	PanelAnimator.kill_tween(_fade_tween)
	_is_visible = false
	_panel.visible = false
	_panel.modulate = Color.WHITE


func _display_tooltip(text: String, screen_position: Vector2) -> void:
	_last_position = screen_position
	_label.custom_minimum_size = Vector2.ZERO
	_label.size = Vector2.ZERO
	_label.text = text
	_panel.reset_size()
	if _panel.size.x > MAX_WIDTH:
		_label.custom_minimum_size = Vector2(
			MAX_WIDTH - PANEL_HORIZONTAL_PADDING, 0.0
		)
		_panel.reset_size()
	PanelAnimator.kill_tween(_fade_tween)
	_fade_tween = PanelAnimator.fade_in(
		_panel, TOOLTIP_FADE_DURATION
	)
	_is_visible = true
	_position_tooltip(_last_position)


func _follow_mouse() -> void:
	var viewport: Viewport = get_viewport()
	if not viewport:
		return
	_last_position = viewport.get_mouse_position()
	_position_tooltip(_last_position)


func _position_tooltip(cursor_position: Vector2) -> void:
	var viewport: Viewport = get_viewport()
	if not viewport:
		return
	var screen_size: Vector2 = viewport.get_visible_rect().size
	var tooltip_size: Vector2 = _panel.size

	var pos: Vector2 = cursor_position + TOOLTIP_OFFSET

	if pos.x + tooltip_size.x > screen_size.x - SCREEN_MARGIN:
		pos.x = cursor_position.x - tooltip_size.x - TOOLTIP_OFFSET.x
	if pos.y + tooltip_size.y > screen_size.y - SCREEN_MARGIN:
		pos.y = cursor_position.y - tooltip_size.y - TOOLTIP_OFFSET.y

	pos.x = maxf(SCREEN_MARGIN, pos.x)
	pos.y = maxf(SCREEN_MARGIN, pos.y)
	_panel.global_position = pos


func _on_panel_opened(_panel_name: String) -> void:
	hide_tooltip()


func _build_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = UILayers.SYSTEM
	add_child(canvas)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(0, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(0, 0)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_panel.add_child(_label)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	canvas.add_child(_panel)
