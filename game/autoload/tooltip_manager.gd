## Manages a single cursor-following tooltip panel for the entire UI.
extends Node


const HOVER_DELAY: float = PanelAnimator.TOOLTIP_HOVER_DELAY
const FADE_DURATION: float = PanelAnimator.TOOLTIP_FADE_DURATION
const MAX_WIDTH: int = 240
const SCREEN_MARGIN: int = 12
const TOOLTIP_OFFSET := Vector2(16, 16)
const BG_COLOR := Color(0.08, 0.08, 0.1, 0.9)

var _panel: PanelContainer
var _label: Label
var _delay_timer: float = -1.0
var _pending_text: String = ""
var _fade_tween: Tween
var _is_visible: bool = false


func _ready() -> void:
	_build_panel()
	EventBus.panel_opened.connect(_on_panel_opened)


func _unhandled_input(event: InputEvent) -> void:
	if _is_visible or _delay_timer >= 0.0:
		if event is InputEventKey and event.pressed:
			if (event as InputEventKey).keycode == KEY_ESCAPE:
				hide_tooltip()
				get_viewport().set_input_as_handled()
				return
		if event is InputEventMouseButton and event.pressed:
			hide_tooltip()


func _process(delta: float) -> void:
	if _delay_timer >= 0.0:
		_delay_timer -= delta
		if _delay_timer < 0.0 and not _pending_text.is_empty():
			_display_tooltip(_pending_text)
			_pending_text = ""
	if _is_visible:
		_follow_mouse()


## Shows a text tooltip after the standard hover delay.
func show_tooltip(text: String, _position: Vector2) -> void:
	if text.is_empty():
		hide_tooltip()
		return
	_pending_text = text
	_delay_timer = HOVER_DELAY


## Immediately hides the tooltip and cancels any pending delay.
func hide_tooltip() -> void:
	PanelAnimator.kill_tween(_fade_tween)
	_delay_timer = -1.0
	_pending_text = ""
	_is_visible = false
	_panel.visible = false
	_panel.modulate = Color.WHITE


func _display_tooltip(text: String) -> void:
	_label.custom_minimum_size = Vector2.ZERO
	_label.text = text
	_panel.reset_size()
	if _panel.size.x > float(MAX_WIDTH):
		_label.custom_minimum_size = Vector2(float(MAX_WIDTH), 0.0)
		_panel.reset_size()
	PanelAnimator.kill_tween(_fade_tween)
	_fade_tween = PanelAnimator.fade_in(_panel, FADE_DURATION)
	_is_visible = true
	_follow_mouse()


func _follow_mouse() -> void:
	var viewport: Viewport = get_viewport()
	if not viewport:
		return
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var screen_size: Vector2 = viewport.get_visible_rect().size
	var tooltip_size: Vector2 = _panel.size

	var pos: Vector2 = mouse_pos + TOOLTIP_OFFSET

	if pos.x + tooltip_size.x > screen_size.x - SCREEN_MARGIN:
		pos.x = mouse_pos.x - tooltip_size.x - TOOLTIP_OFFSET.x
	if pos.y + tooltip_size.y > screen_size.y - SCREEN_MARGIN:
		pos.y = mouse_pos.y - tooltip_size.y - TOOLTIP_OFFSET.y

	pos.x = maxf(SCREEN_MARGIN, pos.x)
	pos.y = maxf(SCREEN_MARGIN, pos.y)
	_panel.global_position = pos


func _on_panel_opened(_panel_name: String) -> void:
	hide_tooltip()


func _build_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
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
