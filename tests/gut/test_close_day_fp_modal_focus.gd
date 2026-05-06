## ISSUE-014 — End-of-day flow from FP mode: the close-day path must release
## the FP cursor before any modal opens, and the cursor stays released across
## the CloseDayPreview → DaySummary hand-off.
##
## The preview pushes its own CTX_MODAL when shown, and DaySummary pushes its
## own again when `show_summary` runs. The StorePlayerBody `context_changed`
## listener flips MOUSE_MODE_CAPTURED → MOUSE_MODE_VISIBLE off the SSOT
## signal, so this test verifies the focus stack contract directly.
extends GutTest


const _HudScene: PackedScene = preload(
	"res://game/scenes/ui/hud.tscn"
)
const _PreviewScene: PackedScene = preload(
	"res://game/scenes/ui/close_day_preview.tscn"
)


var _focus: Node
var _saved_state: GameManager.State
var _saved_day: int
var _huds: Array[CanvasLayer] = []
var _previews: Array[CanvasLayer] = []


func before_all() -> void:
	DataLoaderSingleton.load_all_content()


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	assert_not_null(_focus, "InputFocus autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	_saved_state = GameManager.current_state
	_saved_day = GameManager.get_current_day()
	_huds.clear()
	_previews.clear()
	GameState.reset_new_game()
	GameManager.set_current_day(1)


## Clear ownership flags on every modal we instantiated BEFORE resetting the
## InputFocus stack. Without this, autofree-triggered `_exit_tree` paths see
## `_focus_pushed=true` on a stack we already wiped and fire the defensive
## push_error. Mirrors test_checkout_panel_focus.gd / test_inventory_panel_focus.gd.
func after_each() -> void:
	for hud: CanvasLayer in _huds:
		if is_instance_valid(hud):
			hud._reset_for_tests()
			var preview_child: CanvasLayer = (
				hud.get_node_or_null("CloseDayPreview") as CanvasLayer
			)
			if is_instance_valid(preview_child):
				preview_child._reset_for_tests()
	for preview: CanvasLayer in _previews:
		if is_instance_valid(preview):
			preview._reset_for_tests()
	_huds.clear()
	_previews.clear()
	GameManager.current_state = _saved_state
	GameManager.set_current_day(_saved_day)
	GameState.reset_new_game()
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func _make_hud() -> CanvasLayer:
	var hud: CanvasLayer = _HudScene.instantiate()
	add_child_autofree(hud)
	_huds.append(hud)
	return hud


func _make_preview() -> CanvasLayer:
	var preview: CanvasLayer = _PreviewScene.instantiate()
	preview.set_snapshot_callback(func() -> Array: return [])
	add_child_autofree(preview)
	_previews.append(preview)
	return preview


func test_close_day_press_pushes_preview_modal_focus() -> void:
	# Pressing Close Day opens the preview directly; the preview pushes its
	# own CTX_MODAL on show. Loop-completion gating now lives downstream in
	# DayCycleController + CloseDayConfirmationPanel (see
	# test_day_close_confirmation_gate.gd).
	var hud: CanvasLayer = _make_hud()
	var preview: CanvasLayer = hud.get_node("CloseDayPreview")
	preview.set_snapshot_callback(func() -> Array: return [])
	GameManager.current_state = GameManager.State.STORE_VIEW
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	hud._on_close_day_pressed()

	assert_eq(
		_focus.depth(), baseline + 1,
		"Close Day press must push exactly one CTX_MODAL frame (the preview)"
	)
	assert_eq(
		_focus.current(), InputFocus.CTX_MODAL,
		"Preview must own the top frame when opened directly"
	)
	assert_true(preview._focus_pushed, "Preview must remember it owns a frame")


func test_preview_cancel_pops_ctx_modal() -> void:
	var preview: CanvasLayer = _make_preview()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	preview.show_preview()

	preview._on_cancel_pressed()

	assert_eq(
		_focus.depth(), baseline,
		"Cancelling the preview must pop the CTX_MODAL frame"
	)
	assert_eq(
		_focus.current(), InputFocus.CTX_STORE_GAMEPLAY,
		"After cancel, store_gameplay context must be on top again"
	)
	assert_false(
		preview._focus_pushed, "Preview must release ownership flag"
	)


func test_preview_confirm_pops_ctx_modal() -> void:
	# The confirm path emits day_close_requested; the preview pops its frame
	# so DayCycleController's downstream state transition runs from the
	# gameplay context. DaySummary then pushes its own frame on `show_summary`
	# (covered by `test_day_summary_modal_focus.gd`).
	var preview: CanvasLayer = _make_preview()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	preview.show_preview()

	preview._on_confirm_pressed()

	assert_eq(
		_focus.depth(), baseline,
		"Confirming the preview must pop the CTX_MODAL frame"
	)
	assert_false(
		preview._focus_pushed, "Preview must release ownership flag"
	)


func test_repeated_show_preview_does_not_leak_frames() -> void:
	var preview: CanvasLayer = _make_preview()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	preview.show_preview()
	preview.show_preview()

	assert_eq(
		_focus.depth(), baseline + 1,
		"Repeated show_preview must not push duplicate frames"
	)


func test_cursor_release_signal_fires_on_close_day_press() -> void:
	# End-to-end FP contract: under store_gameplay context the cursor is
	# captured for mouse-look. Pressing Close Day must dispatch a
	# context_changed(CTX_MODAL) event so the StorePlayerBody listener
	# (and Crosshair, which hides outside CTX_STORE_GAMEPLAY) react.
	var hud: CanvasLayer = _make_hud()
	var preview: CanvasLayer = hud.get_node("CloseDayPreview")
	preview.set_snapshot_callback(func() -> Array: return [])
	GameManager.current_state = GameManager.State.STORE_VIEW
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var ctx_changes: Array[StringName] = []
	_focus.context_changed.connect(
		func(new_ctx: StringName, _old: StringName) -> void:
			ctx_changes.append(new_ctx)
	)

	hud._on_close_day_pressed()

	assert_true(
		ctx_changes.has(InputFocus.CTX_MODAL),
		"Pressing Close Day must emit context_changed with CTX_MODAL"
	)
