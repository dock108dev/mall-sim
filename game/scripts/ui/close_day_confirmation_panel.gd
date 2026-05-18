## Confirmation modal shown when the player requests day-close before the
## day's stock-to-sell loop has been completed.
##
## Listens to `EventBus.day_close_confirmation_requested(reason)`. When the
## player accepts the prompt the panel emits `EventBus.day_close_confirmed`
## which `DayCycleController._on_day_close_confirmed` routes through to the
## standard close path. Cancel is a no-op — the gate stays in place.
##
## Inherits the `ModalPanel` open/close → push/pop CTX_MODAL contract so the
## FP cursor releases for button clicks and the focus stack stays balanced
## across cancel / confirm hand-offs.
class_name CloseDayConfirmationPanel
extends ModalPanel

const PANEL_SIZE: Vector2 = Vector2(560, 260)

@onready var _root: Control = $Root
@onready var _overlay: ColorRect = $Root/Overlay
@onready var _panel: PanelContainer = $Root/Panel
@onready var _reason_label: Label = $Root/Panel/Margin/VBox/ReasonLabel
@onready var _cancel_button: Button = (
	$Root/Panel/Margin/VBox/ButtonRow/CancelButton
)
@onready var _confirm_button: Button = (
	$Root/Panel/Margin/VBox/ButtonRow/ConfirmButton
)

var _answered: bool = false


func _ready() -> void:
	visible = false
	_apply_modal_style()
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	if not EventBus.day_close_confirmation_requested.is_connected(
		_on_close_confirmation_requested
	):
		EventBus.day_close_confirmation_requested.connect(
			_on_close_confirmation_requested
		)


func _exit_tree() -> void:
	if EventBus.day_close_confirmation_requested.is_connected(
		_on_close_confirmation_requested
	):
		EventBus.day_close_confirmation_requested.disconnect(
			_on_close_confirmation_requested
		)
	super._exit_tree()


func _on_close_confirmation_requested(reason: String) -> void:
	show_with_reason(reason)


## Shows the panel with the supplied reason copy. Routes through ModalQueue so
## it cannot overlap another blocking panel; repeated calls while visible just
## refresh the reason text.
func show_with_reason(reason: String) -> void:
	if visible and _focus_pushed:
		_reason_label.text = reason
		_focus_default_button()
		return
	enqueue(ModalQueue.Priority.DAY_SUMMARY, {"reason": reason})


func _on_queued_open(payload: Dictionary) -> void:
	_reason_label.text = str(payload.get("reason", ""))
	_answered = false
	if _root != null:
		_root.visible = true
	_register_modal_focusables([_cancel_button, _confirm_button])
	_focus_default_button()


func _focus_default_button() -> void:
	_focus_modal_control_deferred(_cancel_button)


func _apply_modal_style() -> void:
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.color = BetaModalTheme.COLOR_BLOCKER
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.offset_left = -PANEL_SIZE.x * 0.5
	_panel.offset_top = -PANEL_SIZE.y * 0.5
	_panel.offset_right = PANEL_SIZE.x * 0.5
	_panel.offset_bottom = PANEL_SIZE.y * 0.5
	_panel.add_theme_stylebox_override("panel", BetaModalTheme.make_panel_style())
	_reason_label.add_theme_color_override(
		"font_color", BetaModalTheme.COLOR_TEXT_PRIMARY
	)
	BetaModalTheme.apply_button_theme(_cancel_button)
	BetaModalTheme.apply_button_theme(_confirm_button)


func _on_cancel_pressed() -> void:
	if _answered or not visible:
		return
	_answered = true
	close()


func _on_confirm_pressed() -> void:
	if _answered or not visible:
		return
	_answered = true
	close()
	EventBus.day_close_confirmed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _modal_can_handle_input():
		return
	if event.is_action_pressed(&"ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_accept"):
		if _activate_focused_modal_button():
			get_viewport().set_input_as_handled()
		return
	if _is_modal_focus_previous_event(event):
		if _cycle_modal_focus(false):
			get_viewport().set_input_as_handled()
		return
	if _is_modal_focus_next_event(event):
		if _cycle_modal_focus(true):
			get_viewport().set_input_as_handled()


## Direct-open compatibility for tests and any non-queued fatal path. Normal
## gameplay callers use `show_with_reason()` so ModalQueue serializes panels.
func open() -> void:
	super.open()
	_answered = false
	if _root != null:
		_root.visible = true
	_register_modal_focusables([_cancel_button, _confirm_button])
	_focus_default_button()


func close() -> void:
	if _root != null:
		_root.visible = false
	_modal_focusables.clear()
	super.close()
