## Center-screen reticle shown during first-person store gameplay so the player
## can see where the InteractionRay is aiming before a shelf highlight kicks
## in. Visibility tracks `InputFocus.current()`: visible only when the topmost
## context is `&"store_gameplay"` (cursor locked, gameplay input active);
## hidden for modals, mall hub, and main menu.
##
## Hover state mirrors `EventBus.interactable_focused/unfocused` so the glyph
## brightens to a saturated accent color when the InteractionRay is aimed at
## an interactable, restoring the parchment idle tint when focus clears.
extends CanvasLayer


const _IDLE_COLOR := Color(0.957, 0.914, 0.831, 0.85)
const _HOVER_COLOR := Color(1.0, 0.804, 0.31, 1.0)

var _hovering: bool = false

@onready var _label: Label = $CenterContainer/Label


func _ready() -> void:
	_apply_hover_color()
	_refresh_visibility()
	if InputFocus != null:
		InputFocus.context_changed.connect(_on_input_focus_changed)
	EventBus.interactable_focused.connect(_on_interactable_focused)
	# The reticle brightens whenever the InteractionRay is aimed at *any*
	# interactable, even one whose `can_interact()` is currently false —
	# the player still gets aim feedback so they can read the disabled
	# reason in the prompt overlay without wondering whether they were on
	# target. Same handler as the active path.
	EventBus.interactable_focused_disabled.connect(_on_interactable_focused)
	EventBus.interactable_unfocused.connect(_on_interactable_unfocused)


func _on_input_focus_changed(_new_ctx: StringName, _old_ctx: StringName) -> void:
	_refresh_visibility()


func _on_interactable_focused(_action_label: String) -> void:
	_hovering = true
	_apply_hover_color()


func _on_interactable_unfocused() -> void:
	_hovering = false
	_apply_hover_color()


func _refresh_visibility() -> void:
	visible = _should_show()


## §F-44 — `InputFocus == null` returns false so the reticle stays hidden
## under unit-test isolation where the autoload tree is stubbed. Same
## test-seam contract as `InteractionPrompt._can_show`.
func _should_show() -> bool:
	if InputFocus == null:
		return false
	return InputFocus.current() == InputFocus.CTX_STORE_GAMEPLAY


func _apply_hover_color() -> void:
	if _label == null:
		return
	_label.add_theme_color_override(
		&"font_color", _HOVER_COLOR if _hovering else _IDLE_COLOR
	)
