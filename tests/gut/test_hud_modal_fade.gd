## HUD modal-fade contract — verifies the spec from ISSUE-002:
##   * On CTX_MODAL push, every direct CanvasItem child of the HUD CanvasLayer
##     tweens its modulate.a to 0.3 over 0.15s.
##   * On CTX_MODAL pop, the children restore to 1.0 over 0.15s.
##   * The fade is boolean-transition gated — nested CTX_MODAL context_changed
##     events do not retrigger the tween.
##   * The plane separation is preserved: HUD at 0.3 sits between the
##     full-screen dim (0.45 alpha) and the modal panel (1.0).
extends GutTest


const _HudScene: PackedScene = preload("res://game/scenes/ui/hud.tscn")


var _hud: CanvasLayer
var _saved_state: GameManager.State


func before_each() -> void:
	_saved_state = GameManager.current_state
	GameManager.current_state = GameManager.State.STORE_VIEW
	InputFocus._reset_for_tests()
	_hud = _HudScene.instantiate()
	add_child_autofree(_hud)
	_hud._reset_for_tests()


func after_each() -> void:
	GameManager.current_state = _saved_state
	InputFocus._reset_for_tests()


func _flush_tween() -> void:
	if _hud._modal_dim_tween != null and _hud._modal_dim_tween.is_valid():
		_hud._modal_dim_tween.set_speed_scale(100.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func test_dim_flag_clear_at_start() -> void:
	assert_false(
		_hud.is_modal_dim_active(),
		"HUD must not start in modal-dim state"
	)


func test_dim_flag_flips_on_modal_push() -> void:
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	InputFocus.push_context(InputFocus.CTX_MODAL)
	assert_true(
		_hud.is_modal_dim_active(),
		"is_modal_dim_active must flip true when CTX_MODAL pushes"
	)


func test_dim_flag_clears_on_modal_pop() -> void:
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	InputFocus.push_context(InputFocus.CTX_MODAL)
	InputFocus.pop_context()
	assert_false(
		_hud.is_modal_dim_active(),
		"is_modal_dim_active must clear when CTX_MODAL pops"
	)


func test_canvas_item_children_dim_to_modal_alpha_under_modal() -> void:
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	InputFocus.push_context(InputFocus.CTX_MODAL)
	await _flush_tween()
	var any_dimmed: bool = false
	for child: Node in _hud.get_children():
		if child is CanvasItem:
			var alpha: float = (child as CanvasItem).modulate.a
			# Tolerate small drift for tween settle: ≤ 0.4 confirms the dim landed.
			if alpha <= 0.4:
				any_dimmed = true
			else:
				assert_lte(
					alpha, 0.4,
					"HUD child %s did not dim under CTX_MODAL (alpha=%.2f)"
					% [child.name, alpha]
				)
	assert_true(
		any_dimmed,
		"At least one CanvasItem child must dim under CTX_MODAL"
	)


func test_canvas_item_children_restore_full_alpha_on_modal_pop() -> void:
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	InputFocus.push_context(InputFocus.CTX_MODAL)
	await _flush_tween()
	InputFocus.pop_context()
	await _flush_tween()
	for child: Node in _hud.get_children():
		if child is CanvasItem:
			var alpha: float = (child as CanvasItem).modulate.a
			assert_almost_eq(
				alpha, 1.0, 0.05,
				"HUD child %s must restore to alpha 1.0 after CTX_MODAL pops"
				% child.name
			)


func test_dim_does_not_retrigger_on_intra_modal_context_change() -> void:
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	InputFocus.push_context(InputFocus.CTX_MODAL)
	var first_tween: Tween = _hud._modal_dim_tween
	# A nested context change where modal stays on top must not start a
	# second tween.
	_hud._on_input_focus_changed(InputFocus.CTX_MODAL, InputFocus.CTX_MODAL)
	assert_eq(
		_hud._modal_dim_tween, first_tween,
		"Repeated modal-active context_changed must not restart the dim tween"
	)


func test_non_modal_context_does_not_dim_hud() -> void:
	# Pushing a non-modal context (e.g. main_menu) must not toggle the HUD
	# fade — only CTX_MODAL drives it.
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	InputFocus.push_context(InputFocus.CTX_MAIN_MENU)
	assert_false(
		_hud.is_modal_dim_active(),
		"Non-modal contexts must not toggle the HUD modal-dim flag"
	)
