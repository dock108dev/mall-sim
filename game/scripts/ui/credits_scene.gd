## Full-screen credits panel with auto-scrolling content and return-to-menu navigation.
class_name CreditsScene
extends CanvasLayer


signal return_to_menu_requested


const AUTO_SCROLL_SPEED: float = 60.0
const FADE_DURATION: float = 0.6

var _scrolling: bool = false
var _fade_tween: Tween
var _scroll_bar: VScrollBar

@onready var _overlay: Control = $Overlay
@onready var _scroll_container: ScrollContainer = $Overlay/Layout/ScrollContainer
@onready var _back_button: Button = $Overlay/Layout/BottomBar/BackToMenuButton


func _ready() -> void:
	visible = false
	_scroll_bar = _scroll_container.get_v_scroll_bar()
	_back_button.pressed.connect(_on_back_pressed)


func initialize() -> void:
	_scrolling = true
	_scroll_container.scroll_vertical = 0
	_animate_in()


func _process(delta: float) -> void:
	if not visible or not _scrolling:
		return
	_scroll_container.scroll_vertical += int(AUTO_SCROLL_SPEED * delta)
	var max_scroll: int = int(_scroll_bar.max_value - _scroll_bar.page)
	if _scroll_container.scroll_vertical >= max_scroll:
		_scrolling = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_menu()
		return
	if not _scrolling:
		return
	var is_mouse_press: bool = (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
	)
	var is_key_press: bool = (
		event is InputEventKey
		and (event as InputEventKey).pressed
	)
	if is_mouse_press or is_key_press:
		get_viewport().set_input_as_handled()
		_skip_to_end()


func _skip_to_end() -> void:
	_scrolling = false
	var max_scroll: int = int(_scroll_bar.max_value - _scroll_bar.page)
	_scroll_container.scroll_vertical = max_scroll


func _return_to_menu() -> void:
	return_to_menu_requested.emit()
	_fade_out_and(func() -> void: GameManager.go_to_main_menu())


func _animate_in() -> void:
	_overlay.modulate = Color(1, 1, 1, 0)
	visible = true
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(
		_overlay, "modulate:a", 1.0, FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _fade_out_and(callback: Callable) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(
		_overlay, "modulate:a", 0.0, FADE_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_fade_tween.tween_callback(
		func() -> void:
			visible = false
			_overlay.modulate = Color.WHITE
			callback.call()
	)


func _on_back_pressed() -> void:
	_return_to_menu()
