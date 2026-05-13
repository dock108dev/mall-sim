## ModalDimOverlay autoload — verifies the dim ColorRect spec:
##   * layer 49 (below CTX_MODAL panels at 50+ band, above HUD/rail at ≤40)
##   * Color(0, 0, 0, 0.4) — calibrated against HUD._MODAL_DIM_ALPHA = 0.65
##     so the composed visible HUD opacity (0.65 × 0.6 = 0.39) reads as
##     clearly dimmed but legible. Both must move together; raising either
##     in isolation reproduces the double-dim near-black regression.
##   * fades in over 0.15s on CTX_MODAL push, fades out over 0.15s on pop
##   * single shared overlay — no stacking on nested modal pushes
##   * mouse events pass through (MOUSE_FILTER_IGNORE)
extends GutTest


var _focus: Node
var _overlay: Node


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	assert_not_null(_focus, "InputFocus autoload required")
	_overlay = get_tree().root.get_node_or_null("ModalDimOverlay")
	assert_not_null(_overlay, "ModalDimOverlay autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	if _overlay != null:
		_overlay._reset_for_tests()


func after_each() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay._reset_for_tests()
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func test_overlay_sits_on_layer_49() -> void:
	assert_eq(
		_overlay.layer, 49,
		"ModalDimOverlay must be on layer 49 (below CTX_MODAL panels at 50+ band, above HUD/rail at ≤40)"
	)


func test_overlay_color_is_specified_dim() -> void:
	# The ColorRect's color holds the spec alpha. modulate.a is the fade
	# multiplier on top of that. The alpha is paired with the HUD's
	# `_MODAL_DIM_ALPHA = 0.65`: the composed visible HUD opacity
	# (0.65 × (1 - 0.4) ≈ 0.39) reads as clearly dimmed but legible.
	var rect: ColorRect = _overlay.get_node("DimRect") as ColorRect
	assert_not_null(rect, "DimRect child must exist")
	assert_eq(rect.color, Color(0.0, 0.0, 0.0, 0.4),
		"DimRect color must be Color(0, 0, 0, 0.4) — calibrated against HUD modal-dim 0.65")
	assert_gte(rect.color.a, 0.3,
		"DimRect alpha must be ≥0.3 so the dim is perceptible at default store lighting")
	assert_lte(rect.color.a, 0.5,
		"DimRect alpha must stay ≤0.5 or the composed HUD opacity drops below the readable floor")


func test_overlay_passes_mouse_events_through() -> void:
	var rect: ColorRect = _overlay.get_node("DimRect") as ColorRect
	assert_eq(
		int(rect.mouse_filter), int(Control.MOUSE_FILTER_IGNORE),
		"DimRect must not capture mouse events; modal panels above it own input"
	)


func test_overlay_initially_invisible() -> void:
	var rect: ColorRect = _overlay.get_node("DimRect") as ColorRect
	assert_false(_overlay.is_dimmed(), "Pre-condition: not dimmed at start")
	assert_false(rect.visible, "Pre-condition: DimRect hidden at start")


func test_overlay_dims_when_ctx_modal_pushed() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_focus.push_context(InputFocus.CTX_MODAL)
	assert_true(
		_overlay.is_dimmed(),
		"is_dimmed() must flip true when CTX_MODAL is on top"
	)
	var rect: ColorRect = _overlay.get_node("DimRect") as ColorRect
	assert_true(
		rect.visible,
		"DimRect must become visible the moment CTX_MODAL pushes"
	)


func test_overlay_clears_when_ctx_modal_popped() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_focus.push_context(InputFocus.CTX_MODAL)
	assert_true(_overlay.is_dimmed(), "Pre-condition: dimmed under modal")
	_focus.pop_context()
	assert_false(
		_overlay.is_dimmed(),
		"is_dimmed() must clear once CTX_MODAL pops"
	)


func test_overlay_fade_tween_targets_full_opacity_on_push() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_focus.push_context(InputFocus.CTX_MODAL)
	# Speed up the tween so it lands inside the test window.
	if _overlay._tween != null and _overlay._tween.is_valid():
		_overlay._tween.set_speed_scale(100.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var rect: ColorRect = _overlay.get_node("DimRect") as ColorRect
	assert_almost_eq(
		rect.modulate.a, 1.0, 0.05,
		"DimRect modulate.a must settle at 1.0 after the fade-in completes"
	)


func test_overlay_fade_tween_zeroes_alpha_on_pop() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_focus.push_context(InputFocus.CTX_MODAL)
	if _overlay._tween != null and _overlay._tween.is_valid():
		_overlay._tween.set_speed_scale(100.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_focus.pop_context()
	if _overlay._tween != null and _overlay._tween.is_valid():
		_overlay._tween.set_speed_scale(100.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var rect: ColorRect = _overlay.get_node("DimRect") as ColorRect
	assert_almost_eq(
		rect.modulate.a, 0.0, 0.05,
		"DimRect modulate.a must drain to 0.0 after the fade-out completes"
	)


func test_overlay_does_not_stack_on_nested_modal_push() -> void:
	# Two modals layered on top of each other must not double-dim. The first
	# CTX_MODAL push fires the fade-in; subsequent context_changed events
	# where modal stays on top must not retrigger.
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_focus.push_context(InputFocus.CTX_MODAL)
	var first_tween: Tween = _overlay._tween
	# Simulate a second modal frame layering on top of the first (e.g. a
	# confirm dialog inside an already-open modal).
	_focus.push_context(InputFocus.CTX_MODAL)
	assert_eq(
		_overlay._tween, first_tween,
		"Nested CTX_MODAL push must not start a second fade tween"
	)


func test_overlay_only_listens_to_modal_context_transitions() -> void:
	# A non-modal context transition (gameplay → main_menu) must not dim the
	# overlay — only CTX_MODAL toggles the dim.
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_focus.push_context(InputFocus.CTX_MAIN_MENU)
	assert_false(
		_overlay.is_dimmed(),
		"Non-modal context transitions must not toggle the dim overlay"
	)
