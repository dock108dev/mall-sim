## Single dim overlay shown above gameplay/HUD whenever a modal owns InputFocus.
##
## Layer 49 sits below modal panels (which authorise themselves at layer 50+
## — see `BetaDecisionCardPanel` at 80 and `BetaDaySummaryPanel` at 81) and
## above all gameplay and HUD layers (HUD at 30, ObjectiveRail at 40). One
## ColorRect handles every modal depth level — the dim must not stack, so we
## fade only on the boolean transition `was_modal != is_modal_now`, never on
## intra-modal pushes.
##
## Driven by `InputFocus.context_changed`. Tweens in over 0.15s when the top
## frame becomes `CTX_MODAL`, tweens out over 0.15s when it leaves.
extends CanvasLayer

const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const FADE_DURATION: float = 0.15
const LAYER: int = 49

var _dim_rect: ColorRect
var _tween: Tween
var _is_modal_active: bool = false


func _ready() -> void:
	layer = LAYER
	_dim_rect = ColorRect.new()
	_dim_rect.name = "DimRect"
	_dim_rect.color = DIM_COLOR
	_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Mouse events must reach the modal panel above us, not stop here.
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_rect.modulate.a = 0.0
	_dim_rect.visible = false
	add_child(_dim_rect)
	# §EH-15 — `InputFocus` is registered as an autoload (project.godot:51)
	# and declares `context_changed` (input_focus.gd:15). The prior null /
	# has_signal guards were dead defensive code: a rename would silently
	# leave the dim overlay disconnected from focus changes, so modals would
	# render without dimming and the regression would only surface as a
	# "modals don't dim" UX bug. Connect unconditionally so signature drift
	# fails at parse time.
	InputFocus.context_changed.connect(_on_input_focus_changed)


func _on_input_focus_changed(new_ctx: StringName, _old_ctx: StringName) -> void:
	var modal_now: bool = (new_ctx == InputFocus.CTX_MODAL)
	if modal_now == _is_modal_active:
		return
	_is_modal_active = modal_now
	_fade_to(1.0 if modal_now else 0.0)


## True iff the dim overlay currently treats CTX_MODAL as the top frame.
## Public for the debug overlay and tests; mutating it from outside is a
## contract violation — drive it via `InputFocus.push_context(CTX_MODAL)`.
func is_dimmed() -> bool:
	return _is_modal_active


func _fade_to(target_alpha: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if target_alpha > 0.0:
		_dim_rect.visible = true
	_tween = create_tween()
	_tween.tween_property(
		_dim_rect, "modulate:a", target_alpha, FADE_DURATION
	)
	if target_alpha == 0.0:
		# Hide the rect after the fade-out finishes so it can never accidentally
		# block input even at modulate.a == 0 (some renderers still walk
		# zero-alpha controls when computing input order).
		_tween.tween_callback(_hide_after_fade_out)


func _hide_after_fade_out() -> void:
	if not _is_modal_active:
		_dim_rect.visible = false


## Test seam — collapses any in-flight tween, clears the modal flag, and
## restores the rect to its pre-modal state without going through
## InputFocus. Pair with `InputFocus._reset_for_tests()`.
func _reset_for_tests() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	_is_modal_active = false
	if _dim_rect != null:
		_dim_rect.modulate.a = 0.0
		_dim_rect.visible = false
