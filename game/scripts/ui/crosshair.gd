## Center-screen reticle shown during first-person store gameplay so the player
## can see where the InteractionRay is aiming before a shelf highlight kicks
## in. Visibility tracks `InputFocus.current()`: visible only when the topmost
## context is `&"store_gameplay"` (cursor locked, gameplay input active);
## hidden for modals, mall hub, and main menu.
extends CanvasLayer


func _ready() -> void:
	_refresh_visibility()
	if InputFocus != null:
		InputFocus.context_changed.connect(_on_input_focus_changed)


func _on_input_focus_changed(_new_ctx: StringName, _old_ctx: StringName) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	visible = _should_show()


## §F-44 — `InputFocus == null` returns false so the reticle stays hidden
## under unit-test isolation where the autoload tree is stubbed. Same
## test-seam contract as `InteractionPrompt._can_show`.
func _should_show() -> bool:
	if InputFocus == null:
		return false
	return InputFocus.current() == InputFocus.CTX_STORE_GAMEPLAY
