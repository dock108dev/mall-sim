## Non-blocking toast panel that displays onboarding hints with auto-dismiss.
##
## Modal coexistence: hints never share the screen with a blocking modal. Two
## paths are closed — (1) if a modal pushes CTX_MODAL while a hint is visible,
## `_on_input_focus_changed` dismisses it within the same frame; (2) if a hint
## fires while CTX_MODAL is already on top, `_on_hint_shown` returns early at
## the show-time guard. OnboardingSystem dedupes by hint id, so a suppressed
## hint is not re-fired after the modal closes.
class_name HintOverlayUI
extends PanelContainer


const FADE_IN_DURATION: float = 0.3
const FADE_OUT_DURATION: float = 0.2
const DISPLAY_DURATION: float = 5.0

var _is_showing: bool = false
var _tween: Tween
var _dismiss_timer: Timer

@onready var _message_label: Label = $Margin/MessageLabel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_timer()
	EventBus.onboarding_hint_shown.connect(_on_hint_shown)
	EventBus.onboarding_disabled.connect(_on_onboarding_disabled)
	# `InputFocus` is an autoload (project.godot) and owns `context_changed`
	# (input_focus.gd). Connect unconditionally — a rename would otherwise
	# silently drop modal-suppression and the hint would render over modals.
	InputFocus.context_changed.connect(_on_input_focus_changed)


func _gui_input(event: InputEvent) -> void:
	if not _is_showing:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_dismiss()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_showing:
		return
	if event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()


func _on_hint_shown(
	_hint_id: StringName,
	message: String,
	position_hint: String
) -> void:
	# Show-time guard — if a modal is already on top of InputFocus, suppress the
	# hint entirely. `context_changed` would not re-fire here (context did not
	# change), so this is the only place that catches the "hint emits during an
	# already-open modal" path. OnboardingSystem._shown_hints already marked
	# this hint as shown, so it will not re-trigger after the modal closes.
	if InputFocus.current() == InputFocus.CTX_MODAL:
		return
	_kill_tween()
	_dismiss_timer.stop()
	_apply_position(position_hint)
	_message_label.text = message
	_is_showing = true
	visible = true
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	_tween.tween_callback(_dismiss_timer.start.bind(DISPLAY_DURATION))


## Dismiss any visible hint as soon as a modal takes the top of InputFocus.
## Path 1 of the modal-coexistence contract — covers the "modal opens while a
## hint is already animating" case. The show-time guard in `_on_hint_shown`
## covers the inverse ordering.
func _on_input_focus_changed(new_ctx: StringName, _old_ctx: StringName) -> void:
	if new_ctx != InputFocus.CTX_MODAL:
		return
	if _is_showing:
		_dismiss()


func _dismiss() -> void:
	if not _is_showing:
		return
	_is_showing = false
	_dismiss_timer.stop()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	_tween.tween_callback(_on_dismiss_finished)


func _on_dismiss_finished() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_onboarding_disabled() -> void:
	_dismiss()


func _apply_position(hint: String) -> void:
	match hint:
		"top_center":
			set_anchors_preset(Control.PRESET_TOP_WIDE)
			offset_top = 60.0
			offset_bottom = 120.0
			offset_left = 0.0
			offset_right = 0.0
		"bottom_left":
			set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			offset_left = 20.0
			offset_right = 340.0
			offset_top = -80.0
			offset_bottom = -20.0
		"bottom_right":
			set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			offset_left = -340.0
			offset_right = -20.0
			offset_top = -80.0
			offset_bottom = -20.0
		"center":
			set_anchors_preset(Control.PRESET_CENTER)
			offset_left = -160.0
			offset_right = 160.0
			offset_top = -30.0
			offset_bottom = 30.0
		_:
			set_anchors_preset(Control.PRESET_TOP_WIDE)
			offset_top = 60.0
			offset_bottom = 120.0
			offset_left = 0.0
			offset_right = 0.0


func _setup_timer() -> void:
	_dismiss_timer = Timer.new()
	_dismiss_timer.one_shot = true
	_dismiss_timer.timeout.connect(_dismiss)
	add_child(_dismiss_timer)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
