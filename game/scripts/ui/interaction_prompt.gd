## Context-sensitive interaction prompt overlay shown when aiming at interactables.
## Visibility is gated by GameManager.State (hidden in MAIN_MENU and DAY_SUMMARY)
## and by the InputFocus modal context (hidden when a modal is on top of the
## stack) so the prompt cannot linger over the main menu, day summary, or modals.
##
## Renders two visually distinct states for the same focus event:
##   * Active   — `Interactable.can_interact()` is true. The "E" key badge is
##                shown alongside a full-opacity action label
##                ("Counter — Press E to use"). Driven by
##                `EventBus.interactable_focused`.
##   * Disabled — `can_interact()` is false. The badge is suppressed
##                (`visible = false` so it does not occupy any horizontal
##                space) and the disabled-reason text is rendered muted.
##                Driven by `EventBus.interactable_focused_disabled`.
##
## Both states render inside the same bottom-anchored PanelContainer so the
## panel's screen position stays fixed when the player crosses an
## interactable's interaction-range boundary.
extends CanvasLayer


const FADE_DURATION: float = 0.15
## Muted modulate applied to the action label when the focused interactable
## is in the disabled-reason state. Reduced alpha + neutral grey keeps the
## informational text legible without competing for attention with active
## "Press E" prompts that may sit nearby in sequence.
const _DISABLED_LABEL_MODULATE := Color(0.78, 0.78, 0.78, 0.7)
const _ACTIVE_LABEL_MODULATE := Color(1.0, 1.0, 1.0, 1.0)

var _fade_tween: Tween
var _has_focus_target: bool = false

@onready var _panel: PanelContainer = $PanelContainer
@onready var _key_badge: PanelContainer = $PanelContainer/HBox/KeyBadge
@onready var _label: Label = $PanelContainer/HBox/Label


func _ready() -> void:
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_panel.visible = false
	_apply_active_styling()
	EventBus.interactable_focused.connect(_on_interactable_focused)
	EventBus.interactable_focused_disabled.connect(
		_on_interactable_focused_disabled
	)
	EventBus.interactable_unfocused.connect(_on_interactable_unfocused)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	if InputFocus != null:
		InputFocus.context_changed.connect(_on_input_focus_changed)


func _on_interactable_focused(action_label: String) -> void:
	_apply_active_styling()
	_label.text = action_label
	_has_focus_target = true
	if not _can_show():
		return
	_panel.visible = true
	_fade_to(1.0)


## Disabled-state focus path: the interactable is in range but
## `can_interact()` returned false. Hide the E-key badge entirely (so the
## player can tell at a glance E will not do anything) and render the
## reason text muted. An empty reason produces no visible prompt — listeners
## that want a silent disabled state simply return "" from
## `get_disabled_reason()`.
func _on_interactable_focused_disabled(reason: String) -> void:
	_apply_disabled_styling()
	_label.text = reason
	if reason.is_empty():
		_has_focus_target = false
		_fade_to(0.0)
		return
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


## Restores the active-state visuals: E-key badge visible, action label at
## full opacity. Called on every active focus so a previous disabled state
## can never carry over to a fresh active prompt.
func _apply_active_styling() -> void:
	if _key_badge != null:
		_key_badge.visible = true
	if _label != null:
		_label.modulate = _ACTIVE_LABEL_MODULATE


## Hides the E-key badge and mutes the action label. The badge uses
## `visible = false` (not `modulate.a = 0`) so it drops out of the HBox
## layout entirely — the disabled-reason text re-centers within the
## bottom-anchored PanelContainer, which itself never moves on screen.
func _apply_disabled_styling() -> void:
	if _key_badge != null:
		_key_badge.visible = false
	if _label != null:
		_label.modulate = _DISABLED_LABEL_MODULATE
