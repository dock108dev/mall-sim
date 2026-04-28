## Context-sensitive interaction prompt overlay shown when aiming at interactables.
## Visibility is gated by GameManager.State (hidden in MAIN_MENU and DAY_SUMMARY)
## and by the InputFocus modal context (hidden when a modal is on top of the
## stack) so the prompt cannot linger over the main menu, day summary, or modals.
extends CanvasLayer


const FADE_DURATION: float = 0.15

var _fade_tween: Tween
var _has_focus_target: bool = false

@onready var _panel: PanelContainer = $PanelContainer
@onready var _label: Label = $PanelContainer/Label


func _ready() -> void:
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_panel.visible = false
	EventBus.interactable_focused.connect(_on_interactable_focused)
	EventBus.interactable_unfocused.connect(_on_interactable_unfocused)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	if InputFocus != null:
		InputFocus.context_changed.connect(_on_input_focus_changed)


func _on_interactable_focused(action_label: String) -> void:
	_label.text = action_label
	_has_focus_target = true
	if not _can_show():
		return
	_panel.visible = true
	_fade_to(1.0)


func _on_interactable_unfocused() -> void:
	_has_focus_target = false
	_fade_to(0.0)


func _on_game_state_changed(_old_state: int, _new_state: int) -> void:
	_refresh_visibility()


func _on_input_focus_changed(_new_ctx: StringName, _old_ctx: StringName) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	if not _has_focus_target:
		return
	if _can_show():
		_panel.visible = true
		_fade_to(1.0)
	else:
		_fade_to(0.0)


## §F-44 — `InputFocus == null` returns true (i.e. no modal is blocking) on
## purpose: the autoload is registered in production boot, so the null arm
## only fires under unit-test isolation where the autoload tree is stubbed.
## Same test-seam contract as `StoreController.has_blocking_modal` (§F-42).
func _can_show() -> bool:
	var state: GameManager.State = GameManager.current_state
	if state == GameManager.State.MAIN_MENU or state == GameManager.State.DAY_SUMMARY:
		return false
	if InputFocus != null and InputFocus.current() == InputFocus.CTX_MODAL:
		return false
	return true


func _fade_to(target_alpha: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = _panel.create_tween()
	_fade_tween.tween_property(
		_panel, "modulate:a", target_alpha, FADE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if is_zero_approx(target_alpha):
		_fade_tween.tween_callback(_panel.hide)
