## ISSUE-014 — DaySummary is the third modal in the close-day chain
## (CloseDayConfirmDialog → CloseDayPreview → DaySummary). It must push
## CTX_MODAL when shown so the FP cursor stays released across the
## preview→summary hand-off, and pop on hide so the cursor recapture (or
## mall-overview cursor mode) fires the moment the player clicks Continue.
##
## This test mirrors the InventoryPanel / CheckoutPanel / CloseDayPreview
## modal-focus contract directly — depth round-trips on every dismiss path
## (Continue button, Mall Overview button, Review Inventory button).
extends GutTest


var _focus: Node
var _panel: DaySummary


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	assert_not_null(_focus, "InputFocus autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	_panel = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_panel)


## Clear DaySummary's ownership flag BEFORE resetting the InputFocus stack so
## the autofree-triggered `_exit_tree` doesn't see `_focus_pushed=true` on a
## wiped stack and fire the defensive push_error. Mirrors
## test_checkout_panel_focus.gd / test_inventory_panel_focus.gd.
func after_each() -> void:
	if is_instance_valid(_panel):
		_panel._reset_for_tests()
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func test_show_summary_pushes_ctx_modal() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	_panel.show_summary(1, 100.0, 40.0, 60.0, 3)

	assert_eq(
		_focus.depth(), baseline + 1,
		"show_summary must push exactly one CTX_MODAL frame"
	)
	assert_eq(
		_focus.current(), InputFocus.CTX_MODAL,
		"DaySummary must own the top frame while it is on screen"
	)
	assert_true(
		_panel._focus_pushed,
		"DaySummary must remember it owns a frame"
	)


func test_hide_summary_pops_ctx_modal() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	_panel.show_summary(1, 100.0, 40.0, 60.0, 3)

	_panel.hide_summary()

	assert_eq(
		_focus.depth(), baseline,
		"hide_summary must pop the CTX_MODAL frame"
	)
	assert_eq(
		_focus.current(), InputFocus.CTX_STORE_GAMEPLAY,
		"After dismissal, the prior context must own the stack again"
	)
	assert_false(
		_panel._focus_pushed,
		"DaySummary must release ownership flag on hide"
	)


func test_continue_pressed_pops_ctx_modal() -> void:
	# Player clicks the primary Continue (Next Day) button — same dismiss
	# path as hide_summary, exercised through the public button signal.
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	_panel.show_summary(1, 100.0, 40.0, 60.0, 3)

	_panel._on_continue_pressed()

	assert_eq(
		_focus.depth(), baseline,
		"Continue (Next Day) must pop the CTX_MODAL frame"
	)


func test_mall_overview_pressed_pops_ctx_modal() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	_panel.show_summary(1, 100.0, 40.0, 60.0, 3)

	_panel._on_mall_overview_pressed()

	assert_eq(
		_focus.depth(), baseline,
		"Return-to-Mall must pop the CTX_MODAL frame"
	)


func test_review_inventory_pressed_pops_ctx_modal() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	_panel.show_summary(1, 100.0, 40.0, 60.0, 3)

	_panel._on_review_inventory_pressed()

	assert_eq(
		_focus.depth(), baseline,
		"Review Inventory must pop the CTX_MODAL frame"
	)


func test_repeated_show_summary_does_not_leak_frames() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	_panel.show_summary(1, 100.0, 40.0, 60.0, 3)
	_panel.show_summary(2, 200.0, 40.0, 160.0, 5)

	assert_eq(
		_focus.depth(), baseline + 1,
		"Repeated show_summary must not push duplicate frames"
	)


func test_repeated_hide_summary_is_idempotent() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()
	_panel.show_summary(1, 100.0, 40.0, 60.0, 3)

	_panel.hide_summary()
	_panel.hide_summary()

	assert_eq(
		_focus.depth(), baseline,
		"hide_summary must not double-pop"
	)


func test_cursor_release_signal_fires_on_show_summary() -> void:
	# End-to-end FP contract: when the player confirms close-day from FP
	# play, DaySummary opens and CTX_MODAL is pushed so the StorePlayerBody
	# context_changed listener keeps the cursor released across the
	# preview→summary hand-off.
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var ctx_changes: Array[StringName] = []
	_focus.context_changed.connect(
		func(new_ctx: StringName, _old: StringName) -> void:
			ctx_changes.append(new_ctx)
	)

	_panel.show_summary(1, 100.0, 40.0, 60.0, 3)

	assert_true(
		ctx_changes.has(InputFocus.CTX_MODAL),
		"show_summary must emit context_changed with CTX_MODAL"
	)


func test_canvas_layer_at_modal_band() -> void:
	# Z-order regression: DaySummary must render above the FP HUD so its
	# corner labels and crosshair don't punch through the modal during the
	# end-of-day flow. The canonical placement is `UILayers.MODAL`.
	assert_eq(
		_panel.layer, UILayers.MODAL,
		"DaySummary must live at the canonical MODAL band"
	)
	assert_gt(
		_panel.layer, UILayers.HUD,
		"DaySummary CanvasLayer must render above the HUD layer"
	)
