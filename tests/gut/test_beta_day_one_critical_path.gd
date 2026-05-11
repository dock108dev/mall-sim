## Day-1 critical-path smoke test for the Shelf Life beta.
##
## Covers the linear objective chain enforced by `BetaDayOneController`:
##   TALK_TO_CUSTOMER → INSPECT_CLUE → CHECK_SHELF → END_DAY
## Each stage enables exactly one critical-path interactable; close-day
## remains gated until every required predecessor is complete.
##
## Also enforces the layout/alignment guarantees needed for the proximity
## prompt to fire from a normal conversational distance: Interactable
## Area3Ds anchored to their parent Node3D, customer reachable from open
## floor near the counter, day-end trigger sitting on the register.
##
## NOTE: tests instantiate retro_games.tscn directly without the wider
## autoload tree (GameManager scene swap, GameWorld systems). The
## BetaDayOneController's `_apply_beta_only_strip` runs in `_ready()` and
## fires `EventBus.objective_changed`, which is routed via the autoload
## EventBus, not the parent StoreController — so we exercise the controller
## state directly rather than driving signals through the full HUD.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
# Maximum allowed offset between an Interactable's authored origin and its
# parent Node3D origin. Anything past this is treated as visible-vs-trigger
# drift, which the prompt-alignment fix is supposed to eliminate.
const _ALIGNMENT_THRESHOLD_M: float = 0.05

var _root: Node3D = null


func before_each() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load for the smoke test")
	if scene == null:
		return
	_root = scene.instantiate() as Node3D
	add_child(_root)
	# Wait one frame so _ready / call_deferred(_open_vic_note_and_then_start_day)
	# settle before tests inspect controller state.
	await get_tree().process_frame
	await get_tree().process_frame
	# Day-1 opens with Vic's note as a pre-chain modal gate; dismiss it so
	# `_start_day` runs and the chain inspection below sees the populated
	# stage / gating / objective rail state.
	_dismiss_vic_note_for_test()
	await get_tree().process_frame


## Dismisses the Day-1 opening note panel so `_start_day` fires. Mirrors
## the runtime "player presses Got it" path without driving the button via
## input simulation.
func _dismiss_vic_note_for_test() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var panel: BetaManagerNotePanel = (
		controller.get("_vic_note_panel") as BetaManagerNotePanel
	)
	if panel == null:
		return
	panel.close()
	panel.note_dismissed.emit()


## Mirrors the runtime "player presses Close Day" path. Calls the panel's
## confirm handler so it closes (popping its CTX_MODAL frame) and emits
## `day_close_confirmed` in the same call — the controller's listener
## then advances the day exactly as it would in gameplay.
func _press_close_day_confirm(controller: Node) -> void:
	var panel: CanvasLayer = controller.get("_close_day_panel") as CanvasLayer
	if panel == null:
		EventBus.day_close_confirmed.emit()
		return
	panel.call("_on_confirm_pressed")


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null
	# BetaRunState is a global autoload that persists across tests; without
	# this reset the summary-continue test below leaves day=2 behind and
	# subsequent tests see an empty `_active_event` for day 2 (day_02.json
	# has no customer events), which causes the chain-advance early-return
	# to fire and the chain stage to never leave talk_to_customer.
	BetaRunState.reset_new_run()


# ── Layout: customer is at the register, day-end is on the counter ──────────

func test_customer_is_staged_at_the_register() -> void:
	var customer: Node3D = _root.get_node_or_null("BetaDayOneCustomer") as Node3D
	assert_not_null(customer, "BetaDayOneCustomer must be authored under the store root")
	if customer == null:
		return
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	assert_not_null(
		checkout,
		"Checkout fixture must be present so the customer can stand at it"
	)
	if checkout == null:
		return
	var horiz_distance: float = (
		Vector2(customer.global_position.x, customer.global_position.z)
		.distance_to(Vector2(checkout.global_position.x, checkout.global_position.z))
	)
	# Threshold sized for "at the left end of the counter" placement: the
	# customer is offset off-axis from the counter so the player has clear
	# walking space on every side, but still reads as part of the checkout
	# zone visually.
	assert_lt(
		horiz_distance, 2.5,
		"Customer must be within 2.5 m of the Checkout counter (got %.2f m)"
		% horiz_distance
	)


func test_day_end_trigger_sits_on_the_register_counter() -> void:
	var trigger: Node3D = _root.get_node_or_null("BetaDayEndTrigger") as Node3D
	assert_not_null(trigger, "BetaDayEndTrigger must be authored under the store root")
	if trigger == null:
		return
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	if checkout == null:
		return
	var horiz_distance: float = (
		Vector2(trigger.global_position.x, trigger.global_position.z)
		.distance_to(Vector2(checkout.global_position.x, checkout.global_position.z))
	)
	assert_lt(
		horiz_distance, 0.5,
		"BetaDayEndTrigger must sit at the Checkout counter (got %.2f m)"
		% horiz_distance
	)


# ── Alignment: every beta Interactable is anchored to its parent root ───────

func test_beta_interactables_have_aligned_trigger_volumes() -> void:
	for parent_name: String in [
		"BetaDayOneCustomer",
		"BetaBackroomPickup",
		"BetaRestockShelf",
		"BetaDayEndTrigger",
		"BetaHiddenClue",
	]:
		var parent: Node3D = _root.get_node_or_null(parent_name) as Node3D
		assert_not_null(parent, "%s must exist under the store root" % parent_name)
		if parent == null:
			continue
		var interactable: Node3D = parent.get_node_or_null("Interactable") as Node3D
		assert_not_null(
			interactable, "%s must own an Interactable child" % parent_name
		)
		if interactable == null:
			continue
		var drift: float = parent.global_position.distance_to(
			interactable.global_position
		)
		assert_lt(
			drift, _ALIGNMENT_THRESHOLD_M,
			(
				"%s/Interactable must share its parent's world position (drift "
				+ "%.3f m exceeds %.2f m threshold)"
			) % [parent_name, drift, _ALIGNMENT_THRESHOLD_M]
		)


# ── Stage gating: only the active stage's target is enabled ─────────────────

func test_stage_talk_to_customer_enables_only_the_customer() -> void:
	# At day start the customer is the active beat. The console-stack
	# flavor object is also enabled (always-on ambient flavor — see
	# `_apply_objective_gating`), but it's not on the critical path,
	# so the helper filters it out and we still expect a singleton list.
	var enabled: PackedStringArray = _stage_critical_path_targets()
	assert_eq(
		Array(enabled), ["BetaDayOneCustomer"],
		"On day start, only the customer must be the active critical-path beat"
	)


func test_chain_walks_customer_then_back_room_then_stock_then_close() -> void:
	# Linear chain: TALK_TO_CUSTOMER → BACK_ROOM_INVENTORY → STOCK_SHELF
	# → END_DAY. After each step's interaction completes, exactly one
	# downstream interactable should be the active critical-path beat —
	# never skipping ahead, never overlapping. Close-day is the last
	# link: it stays disabled until every required predecessor is done
	# AND the time gate has cleared, so the player cannot close the day
	# at 9 AM by walking straight to the register.
	var controller: Node = _beta_controller()
	assert_not_null(controller)
	if controller == null:
		return

	# Customer step → completes talk_to_customer, advances to BACK_ROOM_INVENTORY.
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	assert_eq(
		Array(_stage_critical_path_targets()), ["BetaBackroomPickup"],
		"After resolving the customer, the back-room beat must be active"
	)
	assert_true(
		bool(controller.is_objective_completed(&"talk_to_customer")),
		"talk_to_customer must be marked complete"
	)

	# Back-room step → completes back_room_inventory, advances to STOCK_SHELF.
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	assert_eq(
		Array(_stage_critical_path_targets()), ["BetaRestockShelf"],
		"After the back-room check, the stock-shelf beat must be active"
	)
	assert_true(bool(controller.is_objective_completed(&"back_room_inventory")))

	# Stock step → completes stock_shelf, advances to END_DAY. In the test
	# environment there is no TimeSystem, so the auto-jump-to-close-time
	# is a no-op and the day-end trigger becomes the next valid E-press.
	# Production play has the chain's accumulated time costs (30+30+60 =
	# 120 min) finish at ~11 AM and `_jump_to_close_time_if_early` advances
	# the clock to 17:00 so the close-day prompt is immediately reachable.
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	assert_eq(
		Array(_stage_critical_path_targets()), ["BetaDayEndTrigger"],
		"After stocking the shelf, the day-end trigger must be active"
	)
	assert_true(bool(controller.is_objective_completed(&"stock_shelf")))
	assert_eq(
		String(controller.get("_stage")), "end_day",
		"Stage must end at STAGE_END_DAY after all required objectives"
	)


func test_console_stack_is_ambient_flavor_not_a_chain_step() -> void:
	# Tone rule: the console stack is not the mystery objective. It is
	# always interactable (until inspected), and inspecting it never
	# advances the active chain. Inspecting at TALK_TO_CUSTOMER stage
	# leaves the stage on TALK_TO_CUSTOMER.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var pre_stage: String = String(controller.get("_stage"))
	controller.on_beta_hidden_clue_interacted()
	await get_tree().process_frame
	assert_eq(
		String(controller.get("_stage")), pre_stage,
		"Inspecting the console stack must not advance the chain"
	)
	assert_false(
		bool(controller.is_objective_completed(&"talk_to_customer")),
		"Inspecting the console stack must not flip a chain objective complete"
	)


func test_close_day_is_locked_at_day_start() -> void:
	# Belt-and-suspenders: the day-end trigger must be disabled at fresh
	# day start regardless of where the player walks. The 9 AM
	# close-day bug fired because the FSM jumped to END_DAY on
	# single-event days; this test fails fast if that regression returns.
	var enabled: PackedStringArray = _enabled_beta_critical_path_targets()
	assert_false(
		Array(enabled).has("BetaDayEndTrigger"),
		"Day-end trigger must be disabled at day start (not enabled until "
		+ "all required objectives complete). Enabled list: %s" % str(enabled)
	)


func test_state_snapshot_reports_close_day_blocked_until_chain_done() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var snap: Dictionary = controller.get_state_snapshot()
	assert_false(
		bool(snap.get("can_close_day", true)),
		"Snapshot must report can_close_day=false at day start"
	)
	assert_ne(
		String(snap.get("close_day_reason", "")), "",
		"Snapshot must surface a non-empty close_day_reason while blocked"
	)


# ── Helpers ─────────────────────────────────────────────────────────────────

func _beta_controller() -> Node:
	return get_tree().get_first_node_in_group("beta_day_one_controller")


## GUT's `get_signal_parameters` returns the params of one emission and
## crashes if the index runs past the end. Use `get_signal_emit_count` as
## the loop bound so the helper stays safe even when no emissions have
## been captured yet. Multiple emits land on the same channel during a
## single frame (rail updates, toasts, etc.) — collect all matching
## emissions so message-content assertions can scan the whole batch.
func get_signal_parameters_all(emitter: Object, signal_name: String) -> Array:
	var out: Array = []
	var count: int = get_signal_emit_count(emitter, signal_name)
	for idx: int in range(count):
		var params: Variant = get_signal_parameters(emitter, signal_name, idx)
		if params != null:
			out.append(params)
	return out


## Returns the names of the beta day-1 critical-path parents whose
## Interactable child is currently enabled. Stable across iterations so an
## `assert_eq(Array(...), [...])` matches predictably. Includes the
## ambient-flavor BetaHiddenClue, which is always-on until inspected.
func _enabled_beta_critical_path_targets() -> PackedStringArray:
	var out: PackedStringArray = []
	for parent_name: String in [
		"BetaDayOneCustomer",
		"BetaHiddenClue",
		"BetaBackroomPickup",
		"BetaRestockShelf",
		"BetaDayEndTrigger",
	]:
		var parent: Node = _root.get_node_or_null(parent_name)
		if parent == null:
			continue
		var interactable: Node = parent.get_node_or_null("Interactable")
		if interactable is Interactable and (interactable as Interactable).enabled:
			out.append(parent_name)
	return out


## Like `_enabled_beta_critical_path_targets`, but filters out the
## always-on BetaHiddenClue flavor object so chain-progression assertions
## can match a singleton list against the active stage's target.
func _stage_critical_path_targets() -> PackedStringArray:
	var out: PackedStringArray = []
	for parent_name: String in _enabled_beta_critical_path_targets():
		if parent_name == "BetaHiddenClue":
			continue
		out.append(parent_name)
	return out


# ── Stock-shelf label and carry-state contract ─────────────────────────────
# The stock_shelf objective copy must name the specific destination ("used
# games shelf"), not a generic plural. Generic copy ("the shelves") drove
# players toward unrelated meshes (ConsoleShelf etc.) that have no
# interactable, where the disabled-reason then echoed the same generic
# label and read as nonsense. The carry flag on BetaRunState lets the rail
# suppress its right-side chip while the player is navigating to the shelf
# without an interactable in focus.

func test_stock_shelf_label_names_the_retro_games_shelf() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var stock_entry: Dictionary = {}
	for entry: Dictionary in controller.get("_OBJECTIVES"):
		if String(entry.get("stage", "")) == "stock_shelf":
			stock_entry = entry
			break
	assert_false(
		stock_entry.is_empty(),
		"stock_shelf entry must exist in _OBJECTIVES"
	)
	var label: String = String(stock_entry.get("label", ""))
	assert_string_contains(
		label, "Retro Games shelf",
		"stock_shelf label must name the specific destination "
		+ "('Retro Games shelf'); got: '%s'" % label
	)
	assert_false(
		label.contains("the shelves"),
		"stock_shelf label must not use the generic plural 'the shelves'"
	)


func test_carrying_flag_clear_at_day_start() -> void:
	# Fresh day starts with the carry flag clear so the rail does not
	# suppress the action chip before the player has done anything.
	assert_false(
		BetaRunState.carrying_stock,
		"BetaRunState.carrying_stock must be false at fresh day start"
	)


func test_carrying_flag_set_after_backroom_pickup() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	# Walk the chain to the back-room beat first.
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	assert_true(
		BetaRunState.carrying_stock,
		"carrying_stock must flip true after the back-room pickup"
	)


func test_stock_box_visually_disappears_after_pickup_fade() -> void:
	# Phase Theme contract: the back room must not look identical before
	# and after pickup. The pickup branch fades over ~0.4 s and then flips
	# `visible = false`; this test waits past the fade window and asserts
	# the StockBox + StockBoxLabel are no longer visible.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var pickup: Node = _root.get_node_or_null("BetaBackroomPickup")
	assert_not_null(pickup, "BetaBackroomPickup must exist")
	var stock_box: Node3D = pickup.get_node_or_null("StockBox") as Node3D
	var stock_label: Node3D = pickup.get_node_or_null("StockBoxLabel") as Node3D
	assert_not_null(stock_box, "BetaBackroomPickup/StockBox must exist")
	assert_not_null(stock_label, "BetaBackroomPickup/StockBoxLabel must exist")
	assert_true(
		stock_box.visible and stock_label.visible,
		"Pre-condition: StockBox + label visible at day start"
	)
	# Walk through the customer beat so the back-room stage is active.
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	# Wait past the 0.4 s fade so the tween-completion callback runs and
	# the visible flag flips. Use a real scene-tree timer so the test
	# advances tween state on the same beat as runtime gameplay.
	await get_tree().create_timer(0.6).timeout
	assert_false(
		stock_box.visible,
		"StockBox must be invisible after the pickup fade completes"
	)
	assert_false(
		stock_label.visible,
		"StockBoxLabel must be invisible after the pickup fade completes"
	)


## Back-room pickup must surface a "Picked up" toast with the item type so
## the player gets an explicit textual cue that the box transferred to
## their carry state. Pickup is a transient event confirmation — it routes
## through `toast_requested` (auto-dismissing card on layer 45), not the
## persistent HUD label channel. The persistent carry *state* is driven
## separately by `beta_carry_changed`.
func test_backroom_pickup_emits_picked_up_toast() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	# Walk to the back-room beat first so the pickup actually fires.
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	watch_signals(EventBus)
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	assert_signal_emitted(
		EventBus, "toast_requested",
		"Back-room pickup must emit toast_requested for the player feedback card"
	)
	var found_pickup_message: bool = false
	for params: Array in get_signal_parameters_all(
		EventBus, "toast_requested"
	):
		if params.is_empty():
			continue
		var msg: String = String(params[0])
		# Match the BRAINDUMP-named beat: "Picked up" + an item-type token
		# ("console") so a future copy tweak can still satisfy the contract
		# without locking the literal.
		if msg.contains("Picked up") and msg.to_lower().contains("console"):
			found_pickup_message = true
			break
	assert_true(
		found_pickup_message,
		"toast_requested must include a 'Picked up: ... console ...' "
		+ "message naming the item type"
	)


## Acceptance: the pickup toast AND the carry HUD signal must fire on the
## same call stack as the pickup interaction so there is no visible gap
## between the back-room item disappearing and the carry indicator appearing.
func test_pickup_toast_and_carry_changed_emit_in_same_call() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	watch_signals(EventBus)
	controller.on_beta_backroom_pickup_interacted()
	# No `await` here — both signals must have fired synchronously inside
	# `on_beta_backroom_pickup_interacted` before the test returns control
	# to the scene tree.
	assert_signal_emitted(
		EventBus, "toast_requested",
		"toast_requested must fire synchronously on pickup, not deferred"
	)
	assert_signal_emitted(
		EventBus, "beta_carry_changed",
		"beta_carry_changed must fire synchronously on pickup so the carry "
		+ "indicator appears in the same frame as the pickup toast"
	)


func test_carrying_flag_cleared_after_stocking_shelf() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	assert_true(
		BetaRunState.carrying_stock,
		"Pre-condition: carrying after backroom pickup"
	)
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	assert_false(
		BetaRunState.carrying_stock,
		"carrying_stock must clear after the player stocks the shelf"
	)


# ── Today checklist signal contract ────────────────────────────────────────
# Every chain advance must emit `EventBus.beta_objective_completed(id)` so
# the BetaTodayChecklist can flip the matching row to ✓ and collapse it.

func test_completing_customer_step_emits_beta_objective_completed() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	watch_signals(EventBus)
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	assert_signal_emitted_with_parameters(
		EventBus, "beta_objective_completed", [&"talk_to_customer"],
		"Customer step completion must emit beta_objective_completed(talk_to_customer)"
	)


func test_completing_back_room_step_emits_beta_objective_completed() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	watch_signals(EventBus)
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	assert_signal_emitted_with_parameters(
		EventBus, "beta_objective_completed", [&"back_room_inventory"],
		"Back-room pickup must emit beta_objective_completed(back_room_inventory)"
	)


func test_completing_stock_shelf_step_emits_beta_objective_completed() -> void:
	var controller: Node = _beta_controller()
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
		EventBus, "beta_objective_completed", [&"stock_shelf"],
		"Restock interact must emit beta_objective_completed(stock_shelf)"
	)


func test_close_day_request_emits_beta_objective_completed() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	# Walk the chain to END_DAY first so the close-day gate is satisfied.
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	watch_signals(EventBus)
	# E-press now opens the CloseDayConfirmationPanel via the EventBus
	# signal contract; the close-day objective ticks only after the player
	# presses "Close Day" (which emits day_close_confirmed). Drive the
	# confirm side through the panel so CTX_MODAL push/pop stays balanced.
	controller.on_beta_day_end_requested()
	await get_tree().process_frame
	_press_close_day_confirm(controller)
	await get_tree().process_frame
	assert_signal_emitted_with_parameters(
		EventBus, "beta_objective_completed", [&"close_day"],
		"Close-day confirm must emit beta_objective_completed(close_day)"
	)


# ── Close-time watcher fires through the toast channel ─────────────────────
# AC: closing time is a time-limited alert that auto-dismisses, so it routes
# through `toast_requested` (top-right card with auto-fade), not the
# persistent `notification_requested` HUD label. The persistent rail copy
# ("Close the day at the register.") is what stays on screen until the
# player closes out — the toast only needs to land once.

func test_entering_end_day_emits_close_time_toast() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	# Advance through customer + back room first, then watch signals so
	# only the stock_shelf -> end_day transition's toast is captured.
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	watch_signals(EventBus)
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	assert_eq(
		String(controller.get("_stage")), "end_day",
		"Pre-condition: stage advances to end_day after stocking the shelf"
	)
	var found_close_time_toast: bool = false
	for params: Array in get_signal_parameters_all(
		EventBus, "toast_requested"
	):
		if params.size() < 1:
			continue
		var msg: String = String(params[0])
		if msg.to_lower().contains("closing time"):
			found_close_time_toast = true
			break
	assert_true(
		found_close_time_toast,
		"Entering end_day must emit a toast_requested whose message names "
		+ "'closing time' so the player knows the day's wrap-up is ready."
	)


func test_objective_rail_uses_specified_copy_for_each_chain_stage() -> void:
	# AC: every chain entry's rail label matches the BRAINDUMP-specified
	# copy. This test reads the controller's _OBJECTIVES table directly so
	# a copy regression fails fast without having to walk the chain.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var expected: Dictionary = {
		"talk_to_customer": "Talk to the customer at the register.",
		"back_room_inventory": "Check the back room delivery.",
		"stock_shelf": "Stock the Retro Games shelf.",
		"end_day": "Close the day at the register.",
	}
	for entry: Dictionary in controller.get("_OBJECTIVES"):
		var stage_id: String = String(entry.get("stage", ""))
		if not expected.has(stage_id):
			continue
		assert_eq(
			String(entry.get("label", "")), String(expected[stage_id]),
			"Rail label for stage '%s' must match the BRAINDUMP copy" % stage_id
		)


func test_current_stage_getter_reports_active_stage() -> void:
	# Public read-only accessor used by debug overlay + audits. Must track
	# the private `_stage` field one-for-one.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	assert_eq(
		String(controller.current_stage()),
		String(controller.get("_stage")),
		"current_stage() must mirror the private _stage field"
	)
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	assert_eq(
		String(controller.current_stage()), "back_room_inventory",
		"current_stage() must reflect the chain advance after the customer beat"
	)


# ── Day-summary continue: close before advance_day ─────────────────────────
# `_on_summary_continue` must pop CTX_MODAL via `_summary_panel.close()`
# *before* it calls `BetaRunState.advance_day()` and `_start_day()`. If the
# pop is deferred (or absent), CTX_MODAL leaks into Day 2 and gameplay
# input — gated on `InputFocus.current() == CTX_STORE_GAMEPLAY` — stays
# blocked permanently.

func test_summary_continue_pops_modal_focus_before_starting_next_day() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	# Walk the full chain so close-day is unlocked, then open the summary.
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	# E-press now opens the close-day confirmation modal; the summary
	# panel only renders after the player confirms via day_close_confirmed.
	# Drive the confirm side through the panel so the CTX_MODAL frame the
	# panel pushed in show_with_reason() pops cleanly before the summary
	# panel pushes its own frame.
	controller.on_beta_day_end_requested()
	await get_tree().process_frame
	_press_close_day_confirm(controller)
	await get_tree().process_frame

	var panel: BetaDaySummaryPanel = (
		controller.get("_summary_panel") as BetaDaySummaryPanel
	)
	assert_not_null(panel, "Summary panel must be spawned by the controller")
	if panel == null:
		return
	assert_true(
		bool(panel.get("_focus_pushed")),
		"Pre-condition: summary panel owns the CTX_MODAL frame after open"
	)

	controller._on_summary_continue()
	await get_tree().process_frame

	# `_focus_pushed` is the panel-local invariant: false iff close() has
	# popped the CTX_MODAL frame this panel owns. Checking the global
	# InputFocus.current() here would be flaky against frames leaked by
	# other tests in the suite (those get auto-popped on _exit_tree but
	# may still be on the stack mid-test).
	assert_false(
		bool(panel.get("_focus_pushed")),
		"_on_summary_continue must pop the panel's CTX_MODAL frame so the "
		+ "next day starts with gameplay input unblocked"
	)


# ── Today checklist spawn ───────────────────────────────────────────────────

func test_beta_controller_spawns_today_checklist_on_ready() -> void:
	# The controller's _ensure_panels must add a BetaTodayChecklist into the
	# UI tree so the bottom-right corner has a glanceable progress tracker
	# in place of the suppressed MomentsTray.
	var checklist: Node = get_tree().get_first_node_in_group("beta_today_checklist")
	assert_not_null(
		checklist,
		"BetaDayOneController must spawn a BetaTodayChecklist into the UI tree"
	)


## ── Sale-signal emission contract ──────────────────────────────────────────
## The HUD's "Sold Today" and "Customers Served" counters increment only on
## EventBus.item_sold and EventBus.customer_purchased respectively. The beta
## decision-card path bypasses the production checkout pipeline, so the
## controller has to emit those signals itself when the chosen effect carries
## a positive cash delta. Refunds and no-sale outcomes (cash_delta ≤ 0) must
## not tick the counters.

func test_sale_choice_emits_item_sold_with_cash_price() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	watch_signals(EventBus)
	controller._on_choice_selected(&"upsell_bundle", {"cash": 18})
	await get_tree().process_frame
	# 4th positional arg of GUT's assert_signal_emitted_with_parameters is
	# `index` (int), not a message — passing a string here would crash inside
	# the signal watcher's `index == -1` comparison.
	assert_signal_emitted_with_parameters(
		EventBus, "item_sold", ["used_game", 18.0, "used_games"]
	)


func test_sale_choice_emits_customer_purchased_with_cash_price() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	watch_signals(EventBus)
	controller._on_choice_selected(&"upsell_bundle", {"cash": 18})
	await get_tree().process_frame
	assert_signal_emitted_with_parameters(
		EventBus, "customer_purchased",
		[&"beta_store", &"used_game", 18.0, &"beta_customer_01"]
	)


func test_zero_cash_choice_does_not_emit_sale_signals() -> void:
	# clean_exchange has cash: 0 in the day-1 event JSON. No sale happened —
	# the HUD counters must not tick.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	watch_signals(EventBus)
	controller._on_choice_selected(&"clean_exchange", {"cash": 0})
	await get_tree().process_frame
	assert_signal_not_emitted(EventBus, "item_sold")
	assert_signal_not_emitted(EventBus, "customer_purchased")


func test_negative_cash_choice_does_not_emit_sale_signals() -> void:
	# Refund-style outcomes (negative cash delta) are not sales.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	watch_signals(EventBus)
	controller._on_choice_selected(&"refuse_return", {"cash": -5})
	await get_tree().process_frame
	assert_signal_not_emitted(EventBus, "item_sold")
	assert_signal_not_emitted(EventBus, "customer_purchased")


func test_disabled_reason_at_stock_shelf_does_not_echo_generic_shelves() -> void:
	# AC 3: the disabled-reason for wrong interactable presses while the
	# player is on the stock_shelf stage must not echo a legacy generic
	# 'on the shelves' copy. Walking to the stock_shelf stage and asking
	# for any other beat's disabled reason returns the controller's
	# "Working on: <stock label>" — the post-fix label should name the
	# specific shelf destination.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	# Advance through customer + back room so the active stage is stock_shelf.
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	assert_eq(
		String(controller.get("_stage")), "stock_shelf",
		"Pre-condition: stage is stock_shelf"
	)
	# Asking for the customer beat's disabled reason while in stock_shelf
	# routes through `_disabled_reason_for_stage` and returns "Working on:
	# <stock label>". The post-fix copy must name the specific shelf.
	var reason: String = String(controller.customer_disabled_reason())
	assert_string_contains(
		reason, "Retro Games shelf",
		"Disabled-reason must name the specific destination; got: '%s'" % reason
	)
	assert_false(
		reason.contains("on the shelves"),
		"Disabled-reason must not echo the legacy generic plural 'on the shelves'"
	)


# ── Register status indicator: stage-aware passive hint ────────────────────
# A raycast-only Interactable on the checkout counter that returns false from
# can_interact() and surfaces a muted disabled-reason during the back-room
# and stocking phases. BetaDayOneCustomer and BetaDayEndTrigger keep owning
# their stages — the indicator stays empty during STAGE_TALK_TO_CUSTOMER and
# STAGE_END_DAY so the active interactable's prompt is what the player sees.

func _register_status_indicator() -> Interactable:
	if _root == null:
		return null
	return (
		_root.get_node_or_null("checkout_counter/RegisterStatusIndicator")
		as Interactable
	)


func test_register_status_indicator_is_authored_under_checkout_counter() -> void:
	var indicator: Interactable = _register_status_indicator()
	assert_not_null(
		indicator,
		"checkout_counter/RegisterStatusIndicator must exist in retro_games.tscn"
	)
	if indicator == null:
		return
	assert_true(
		indicator is RegisterStatusIndicator,
		"checkout_counter/RegisterStatusIndicator must use the "
		+ "RegisterStatusIndicator script"
	)


func test_register_status_indicator_never_lets_e_fire() -> void:
	# Acceptance: passive hint only — E never resolves on this node, so the
	# customer/back-room/stock/close beats keep their existing dispatchers.
	var indicator: Interactable = _register_status_indicator()
	if indicator == null:
		return
	assert_false(
		indicator.can_interact(),
		"RegisterStatusIndicator.can_interact() must always return false"
	)


func test_register_status_indicator_is_raycast_only() -> void:
	# proximity_radius = 0 prevents the indicator from competing with
	# BetaDayEndTrigger's 2.25 m proximity zone; the player must aim at the
	# register face to see the hint, not just walk near the counter.
	var indicator: Interactable = _register_status_indicator()
	if indicator == null:
		return
	assert_eq(
		indicator.proximity_radius, 0.0,
		"RegisterStatusIndicator must be raycast-only (proximity_radius == 0)"
	)


func test_register_status_indicator_silent_during_talk_to_customer() -> void:
	# Day 1 opens on STAGE_TALK_TO_CUSTOMER — BetaDayOneCustomer owns that
	# beat. The indicator returns "" so the HUD does not double up a hint
	# alongside the customer's "Help the customer" prompt.
	var controller: Node = _beta_controller()
	var indicator: Interactable = _register_status_indicator()
	if controller == null or indicator == null:
		return
	assert_eq(
		String(controller.current_stage()), "talk_to_customer",
		"Pre-condition: day starts at STAGE_TALK_TO_CUSTOMER"
	)
	assert_eq(
		indicator.get_disabled_reason(), "",
		"Indicator must be silent while BetaDayOneCustomer owns the beat"
	)


func test_register_status_indicator_hints_back_room_during_back_room_stage() -> void:
	# Acceptance: during STAGE_BACK_ROOM_INVENTORY, aiming at the register
	# shows 'Check the back room first.'
	var controller: Node = _beta_controller()
	var indicator: Interactable = _register_status_indicator()
	if controller == null or indicator == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	assert_eq(
		String(controller.current_stage()), "back_room_inventory",
		"Pre-condition: stage is back_room_inventory after the customer beat"
	)
	assert_eq(
		indicator.get_disabled_reason(), "Check the back room first.",
		"Indicator must point the player at the back room during the "
		+ "back-room stage"
	)


func test_register_status_indicator_hints_shelf_during_stock_stage() -> void:
	# Acceptance: during STAGE_STOCK_SHELF, aiming at the register shows
	# 'Stock the shelf before closing up.'
	var controller: Node = _beta_controller()
	var indicator: Interactable = _register_status_indicator()
	if controller == null or indicator == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	assert_eq(
		String(controller.current_stage()), "stock_shelf",
		"Pre-condition: stage is stock_shelf after the back-room beat"
	)
	assert_eq(
		indicator.get_disabled_reason(),
		"Stock the shelf before closing up.",
		"Indicator must point the player at the shelf during the stock stage"
	)


func test_register_status_indicator_silent_during_end_day() -> void:
	# Acceptance: during STAGE_END_DAY the indicator shows nothing —
	# BetaDayEndTrigger's "Close the day" prompt is the active beat.
	var controller: Node = _beta_controller()
	var indicator: Interactable = _register_status_indicator()
	if controller == null or indicator == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	assert_eq(
		String(controller.current_stage()), "end_day",
		"Pre-condition: stage is end_day after the chain completes"
	)
	assert_eq(
		indicator.get_disabled_reason(), "",
		"Indicator must be silent so BetaDayEndTrigger owns the close-day beat"
	)


func test_register_status_indicator_stays_enabled_across_stages() -> void:
	# The objective gating sweep disables every Interactable in the store
	# before re-enabling the active stage's target. The indicator must
	# survive that sweep on every stage, otherwise the InteractionRay
	# raycast would skip the disabled node and the hint would never
	# render. Walks the chain and asserts enabled at each stop.
	var controller: Node = _beta_controller()
	var indicator: Interactable = _register_status_indicator()
	if controller == null or indicator == null:
		return
	assert_true(
		indicator.enabled,
		"Indicator must be enabled at STAGE_TALK_TO_CUSTOMER"
	)
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	assert_true(
		indicator.enabled,
		"Indicator must stay enabled at STAGE_BACK_ROOM_INVENTORY"
	)
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	assert_true(
		indicator.enabled,
		"Indicator must stay enabled at STAGE_STOCK_SHELF"
	)
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	assert_true(
		indicator.enabled,
		"Indicator must stay enabled at STAGE_END_DAY"
	)


func test_register_status_indicator_does_not_break_close_day_path() -> void:
	# Regression guard: BetaDayEndTrigger must keep working with the
	# indicator added. Walk the chain and assert close-day still resolves
	# without a phantom block from the new node.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	var trigger: Interactable = (
		_root.get_node_or_null("BetaDayEndTrigger/Interactable")
		as Interactable
	)
	assert_not_null(trigger, "BetaDayEndTrigger/Interactable must still exist")
	if trigger == null:
		return
	assert_true(
		trigger.enabled,
		"BetaDayEndTrigger must be enabled at STAGE_END_DAY"
	)
	assert_true(
		trigger.can_interact(),
		"BetaDayEndTrigger.can_interact() must still gate true at STAGE_END_DAY"
	)
