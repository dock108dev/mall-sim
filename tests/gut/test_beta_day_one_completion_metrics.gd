## Day-1 completion-metrics regression suite.
##
## Closes the validation gaps that the broader Day-1 critical-path tests
## leave open: explicit value asserts on the back-room / shelf count
## signals and the `_build_shift_note` skipped-objective copy contract.
##
## Most existing Day-1 tests sit in `test_beta_day_one_critical_path.gd`
## (chain walking, alignment, signals firing). This file covers the
## orthogonal "after the interaction, what does the data say?" surface.
## Replay/reset assertions for BetaRunState fields live alongside the
## GameState flag clears in `test_day_one_replay_state_reset.gd`.
extends GutTest


const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"

var _root: Node3D = null


func before_each() -> void:
	InputFocus._reset_for_tests()
	ModalQueue._reset_for_tests()
	BetaRunState.reset_new_run()
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load")
	if scene == null:
		return
	_root = scene.instantiate() as Node3D
	add_child(_root)
	await get_tree().process_frame
	await get_tree().process_frame
	_dismiss_vic_note()
	await get_tree().process_frame


func after_each() -> void:
	# Reset autoload state BEFORE freeing the scene so each panel's
	# `_exit_tree` sees an empty CTX_MODAL stack and skips the safety-net
	# push_error in `modal_panel.gd::_exit_tree`. Reversed ordering
	# produces a teardown cascade GUT treats as failures.
	ModalQueue._reset_for_tests()
	InputFocus._reset_for_tests()
	if is_instance_valid(_root):
		_root.free()
	_root = null
	BetaRunState.reset_new_run()


func _controller() -> Node:
	return get_tree().get_first_node_in_group("beta_day_one_controller")


func _dismiss_vic_note() -> void:
	var controller: Node = _controller()
	if controller == null:
		return
	var panel: BetaManagerNotePanel = (
		controller.get("_vic_note_panel") as BetaManagerNotePanel
	)
	if panel == null:
		return
	panel.close()
	panel.note_dismissed.emit()


# ── Inventory count signal value contract ──────────────────────────────────────
# The HUD's `Back Room` / `Shelf` readouts are driven exclusively by
# `EventBus.beta_backroom_count_changed` / `beta_shelf_count_changed`. The
# critical-path tests assert these signals fire; this file pins the *value*
# emitted on each so a copy-paste bug that emits a stale literal cannot slip
# past CI.

func test_backroom_pickup_emits_count_changed_with_delivery_quantity() -> void:
	var controller: Node = _controller()
	if controller == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	watch_signals(EventBus)
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	var expected: int = BetaDayOneController._BACKROOM_DELIVERY_QUANTITY
	assert_signal_emitted_with_parameters(
		EventBus, "beta_backroom_count_changed", [expected],
		(
			"Back-room pickup must emit beta_backroom_count_changed(%d) so"
			+ " the HUD's Back Room readout ticks to the day's delivery quantity"
		) % expected
	)


func test_restock_emits_shelf_count_matching_delivery_quantity() -> void:
	var controller: Node = _controller()
	if controller == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	watch_signals(EventBus)
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	var expected: int = BetaDayOneController._BACKROOM_DELIVERY_QUANTITY
	assert_signal_emitted_with_parameters(
		EventBus, "beta_shelf_count_changed", [expected],
		(
			"Restocking the shelf must emit beta_shelf_count_changed(%d)"
			+ " — same count the back room just drained"
		) % expected
	)


func test_restock_drains_backroom_count_to_zero() -> void:
	# Complementarity contract: stocking flips the delivery from the back
	# room onto the shelf, so the back-room counter must drain in the same
	# call as the shelf counter ticks up.
	var controller: Node = _controller()
	if controller == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	watch_signals(EventBus)
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	assert_signal_emitted_with_parameters(
		EventBus, "beta_backroom_count_changed", [0],
		"Restock must emit beta_backroom_count_changed(0) so the Back Room readout drains"
	)


# ── shift_note derivation: skipped vs all-complete copy ────────────────────────
# `_build_shift_note` is the single source of truth for the day-summary
# Mark line. The close-day gate normally prevents skipping required work,
# but the function is contracted to produce a "you closed without …" copy
# if any required objective is missing — this guards against the gate
# being relaxed without the summary copy following.

func test_shift_note_baseline_when_all_objectives_complete() -> void:
	var controller: Node = _controller()
	if controller == null:
		return
	var completed: Dictionary = (
		controller.get("_completed_objectives") as Dictionary
	)
	completed.clear()
	completed[&"talk_to_customer"] = true
	completed[&"back_room_inventory"] = true
	completed[&"stock_shelf"] = true
	controller.set("_completed_objectives", completed)
	var note: String = controller.call("_build_shift_note") as String
	assert_string_contains(
		note, "You made it through your first shift",
		"All-complete shift note must use the baseline positive copy"
	)
	assert_false(
		note.begins_with("You closed without"),
		"All-complete shift note must not include a skipped-objective phrase"
	)


func test_shift_note_names_back_room_when_skipped() -> void:
	var controller: Node = _controller()
	if controller == null:
		return
	var completed: Dictionary = (
		controller.get("_completed_objectives") as Dictionary
	)
	completed.clear()
	# Customer + shelf done; back-room intentionally skipped.
	completed[&"talk_to_customer"] = true
	completed[&"stock_shelf"] = true
	controller.set("_completed_objectives", completed)
	var note: String = controller.call("_build_shift_note") as String
	assert_string_contains(
		note, "back room",
		"Skipping back-room must name the back-room delivery in the shift note"
	)
	assert_true(
		note.begins_with("You closed without"),
		"Skipped-objective shift note must lead with 'You closed without'"
	)


func test_shift_note_names_stock_shelf_when_skipped() -> void:
	var controller: Node = _controller()
	if controller == null:
		return
	var completed: Dictionary = (
		controller.get("_completed_objectives") as Dictionary
	)
	completed.clear()
	completed[&"talk_to_customer"] = true
	completed[&"back_room_inventory"] = true
	controller.set("_completed_objectives", completed)
	var note: String = controller.call("_build_shift_note") as String
	assert_string_contains(
		note, "used shelf",
		"Skipping stock_shelf must name the used shelf in the shift note"
	)


func test_shift_note_joins_multiple_skipped_with_and() -> void:
	var controller: Node = _controller()
	if controller == null:
		return
	var completed: Dictionary = (
		controller.get("_completed_objectives") as Dictionary
	)
	completed.clear()
	# Only customer done; back-room and stock both skipped.
	completed[&"talk_to_customer"] = true
	controller.set("_completed_objectives", completed)
	var note: String = controller.call("_build_shift_note") as String
	assert_string_contains(
		note, " and ",
		"Two skipped objectives must join with ' and ' to read as a sentence"
	)


