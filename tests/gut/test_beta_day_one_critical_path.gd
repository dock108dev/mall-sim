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
	# Reset InputFocus and ModalQueue between tests so a leaked frame /
	# active-queue entry from a prior test (e.g. a freed summary panel
	# whose `_exit_tree` auto-popped but ran after this test's scene was
	# already mid-load) doesn't bleed into the assertions below.
	InputFocus._reset_for_tests()
	ModalQueue._reset_for_tests()
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load for the smoke test")
	if scene == null:
		return
	_root = scene.instantiate() as Node3D
	add_child(_root)
	# Wait one frame so _ready / call_deferred(_open_day)
	# settle before tests inspect controller state.
	await get_tree().process_frame
	await get_tree().process_frame
	# Compatibility no-op for older fixtures: Day 1 now starts directly at
	# the customer beat, but keep this helper guarded so the same fixture works
	# if a test explicitly switches to a later-day note gate.
	_dismiss_vic_note_for_test()
	await get_tree().process_frame


## Dismisses a visible Vic note panel when a test explicitly enters a later-day
## note gate. Day 1 normally has no note to dismiss.
func _dismiss_vic_note_for_test() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var panel: BetaManagerNotePanel = (
		controller.get("_vic_note_panel") as BetaManagerNotePanel
	)
	if panel == null:
		return
	if not panel.visible:
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
	# Reset the autoload focus/queue stacks BEFORE freeing the scene, so
	# each panel's `_exit_tree` sees an empty CTX_MODAL frame and skips
	# the safety-net push_error. Reversing this order (free first, reset
	# second) produces a cascade of `[ModalPanel] ... freed with
	# unreleased InputFocus push` lines at suite teardown that GUT counts
	# as errors — see `modal_panel.gd::_exit_tree`.
	ModalQueue._reset_for_tests()
	InputFocus._reset_for_tests()
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


func test_state_snapshot_exposes_stage_and_completed_growing_through_chain() -> void:
	var controller: Node = _beta_controller()
	assert_not_null(controller)
	if controller == null:
		return

	var snap_start: Dictionary = controller.get_state_snapshot()
	assert_eq(
		String(snap_start.get("stage", "")), String(controller.get("_stage")),
		"Snapshot stage must match controller._stage as a String"
	)
	var completed_start: Dictionary = snap_start.get("completed_objectives", {}) as Dictionary
	assert_eq(
		completed_start.size(), 0,
		"completed_objectives must start empty before any chain step"
	)

	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	var completed_after_customer: Dictionary = (
		controller.get_state_snapshot().get("completed_objectives", {}) as Dictionary
	)
	assert_true(
		completed_after_customer.has(&"talk_to_customer"),
		"completed_objectives must contain talk_to_customer after the customer step"
	)

	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	var completed_after_backroom: Dictionary = (
		controller.get_state_snapshot().get("completed_objectives", {}) as Dictionary
	)
	assert_eq(
		completed_after_backroom.size(), completed_after_customer.size() + 1,
		"completed_objectives must grow by one after the back-room step"
	)
	assert_true(completed_after_backroom.has(&"back_room_inventory"))

	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	var snap_end: Dictionary = controller.get_state_snapshot()
	var completed_after_stock: Dictionary = (
		snap_end.get("completed_objectives", {}) as Dictionary
	)
	assert_eq(
		completed_after_stock.size(), completed_after_backroom.size() + 1,
		"completed_objectives must grow by one after the stock-shelf step"
	)
	assert_true(completed_after_stock.has(&"stock_shelf"))
	assert_eq(
		String(snap_end.get("stage", "")), "end_day",
		"Snapshot stage must reach end_day after all required objectives complete"
	)


func test_state_snapshot_mirrors_beta_run_state_fields() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var snap: Dictionary = controller.get_state_snapshot()
	assert_eq(
		int(snap.get("day", -1)), BetaRunState.day,
		"Snapshot day must mirror BetaRunState.day"
	)
	assert_eq(
		int(snap.get("cash", -1)), BetaRunState.cash,
		"Snapshot cash must mirror BetaRunState.cash"
	)
	assert_eq(
		bool(snap.get("carrying_stock", true)), BetaRunState.carrying_stock,
		"Snapshot carrying_stock must mirror BetaRunState.carrying_stock"
	)


func test_state_snapshot_is_json_serializable() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	# Walk the chain so completed_objectives is non-empty when serializing.
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	var snap: Dictionary = controller.get_state_snapshot()
	var encoded: String = JSON.stringify(snap)
	assert_ne(encoded, "", "Snapshot must JSON-encode to a non-empty string")
	var parsed: Variant = JSON.parse_string(encoded)
	assert_true(
		parsed is Dictionary,
		"JSON-encoded snapshot must round-trip back to a Dictionary"
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


## Back-room pickup must surface a "Shipment checked" toast that names the
## actual delivery quantity, so the player gets an explicit textual cue
## both that the back-room beat resolved AND how many items they just
## uncovered. The numeric token must match the runtime count emitted on
## `beta_backroom_count_changed`, not a hardcoded literal. Pickup is a
## transient event confirmation — it routes through `toast_requested`
## (auto-dismissing card on layer 45), not the persistent HUD label
## channel. The persistent carry *state* is driven separately by
## `beta_carry_changed`.
func test_backroom_pickup_emits_shipment_checked_toast() -> void:
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
	# The toast must name (a) the "Shipment checked" beat phrasing and
	# (b) the runtime delivery quantity, taken from the same const that
	# drives `beta_backroom_count_changed`. Match both so a future copy
	# tweak can rephrase the surrounding sentence without dropping either
	# half of the contract.
	# `_BACKROOM_DELIVERY_QUANTITY` is a class-level const on
	# `BetaDayOneController` — `Object.get()` only resolves properties, so
	# read the const directly through the class symbol instead.
	var expected_count: int = BetaDayOneController._BACKROOM_DELIVERY_QUANTITY
	var found_shipment_message: bool = false
	for params: Array in get_signal_parameters_all(
		EventBus, "toast_requested"
	):
		if params.is_empty():
			continue
		var msg: String = String(params[0])
		if (
			msg.contains("Shipment checked")
			and msg.contains(str(expected_count))
		):
			found_shipment_message = true
			break
	assert_true(
		found_shipment_message,
		(
			"toast_requested must include a 'Shipment checked. %d ...' "
			+ "message naming the runtime delivery quantity"
		) % expected_count
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


# ── Objective rail multi-step payload contract ────────────────────────────
# `_update_objective_rail()` emits `EventBus.objective_changed` with a
# `steps` array describing every entry in `_OBJECTIVES`. Each step is
# {text, state} where state is 'completed' | 'active' | 'future'. This is
# the data side of the multi-step rail render (the rendering side is the
# follow-on ObjectiveRail change).

const _EXPECTED_STEP_LABELS: Array[String] = [
	"Talk to the customer at the register.",
	"Check the back room delivery.",
	"Stock the Retro Games shelf.",
	"Close the day at the register.",
]


func _latest_steps_payload(controller: Node) -> Array:
	watch_signals(EventBus)
	controller._update_objective_rail()
	var emissions: Array = get_signal_parameters_all(
		EventBus, "objective_changed"
	)
	if emissions.is_empty():
		return []
	var payload: Dictionary = emissions[emissions.size() - 1][0] as Dictionary
	return payload.get("steps", []) as Array


func _step_states(steps: Array) -> Array:
	var out: Array = []
	for step: Dictionary in steps:
		out.append(String(step.get("state", "")))
	return out


func _step_texts(steps: Array) -> Array:
	var out: Array = []
	for step: Dictionary in steps:
		out.append(String(step.get("text", "")))
	return out


func test_steps_payload_present_with_four_entries() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	var steps: Array = _latest_steps_payload(controller)
	assert_eq(
		steps.size(), 4,
		"objective_changed payload must carry a 4-entry steps array"
	)
	assert_eq(
		_step_texts(steps), _EXPECTED_STEP_LABELS,
		"steps[].text must mirror the _OBJECTIVES labels in chain order"
	)


func test_steps_active_state_tracks_current_stage() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	# Day starts at STAGE_TALK_TO_CUSTOMER after the Vic note dismiss.
	var steps: Array = _latest_steps_payload(controller)
	assert_eq(
		_step_states(steps),
		["active", "future", "future", "future"],
		"At day start, only the customer step must be 'active'"
	)


func test_steps_completed_state_tracks_completed_objectives() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	# Complete the customer beat → step 0 'completed', step 1 'active'.
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	var steps: Array = _latest_steps_payload(controller)
	assert_eq(
		_step_states(steps),
		["completed", "active", "future", "future"],
		"After the customer beat, only the back-room step must be 'active'"
	)
	# Complete the back-room and stock beats → only close_day stays active.
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	steps = _latest_steps_payload(controller)
	assert_eq(
		_step_states(steps),
		["completed", "completed", "completed", "active"],
		"At STAGE_END_DAY every required predecessor must be 'completed'"
	)


func test_steps_all_future_during_vic_note_phase() -> void:
	# Force the controller back into the pre-chain Vic-note phase and
	# re-emit the rail. Pre-chain has no completed objectives and no chain
	# row active, so every entry must read 'future'.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	controller.set("_stage", BetaDayOneController.STAGE_VIC_NOTE)
	(controller.get("_completed_objectives") as Dictionary).clear()
	var steps: Array = _latest_steps_payload(controller)
	assert_eq(
		_step_states(steps),
		["future", "future", "future", "future"],
		"During STAGE_VIC_NOTE every step must read 'future'"
	)


# ── Shift-note derived from completion state ──────────────────────────────
# `_on_day_close_confirmed` reads `_completed_objectives` to decide which
# narrative variant goes into the summary's shift_note. If every required
# step was completed the baseline "you made it through" copy fires; when any
# required step is missing the note must clearly name the skipped work
# (BRAINDUMP rule: closing early must surface what the player skipped).

func _mark_all_required_complete(controller: Node) -> void:
	var completed: Dictionary = (
		controller.get("_completed_objectives") as Dictionary
	)
	completed[&"talk_to_customer"] = true
	completed[&"back_room_inventory"] = true
	completed[&"stock_shelf"] = true


func test_shift_note_uses_baseline_when_all_required_complete() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	(controller.get("_completed_objectives") as Dictionary).clear()
	_mark_all_required_complete(controller)
	var note: String = String(controller._build_shift_note())
	assert_true(
		note.contains("made it through"),
		"All-complete day must use the baseline 'made it through' copy; got: '%s'"
		% note
	)
	assert_false(
		note.begins_with("You closed without"),
		"Baseline note must not name skipped work; got: '%s'" % note
	)


func test_shift_note_names_skipped_backroom() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	(controller.get("_completed_objectives") as Dictionary).clear()
	var completed: Dictionary = (
		controller.get("_completed_objectives") as Dictionary
	)
	completed[&"talk_to_customer"] = true
	completed[&"stock_shelf"] = true
	var note: String = String(controller._build_shift_note())
	assert_true(
		note.contains("back room delivery"),
		"Skipped back-room must be named in the shift note; got: '%s'" % note
	)
	assert_true(
		note.begins_with("You closed without"),
		"Skip-branch copy must begin with 'You closed without'; got: '%s'" % note
	)


func test_shift_note_names_skipped_customer() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	(controller.get("_completed_objectives") as Dictionary).clear()
	var completed: Dictionary = (
		controller.get("_completed_objectives") as Dictionary
	)
	completed[&"back_room_inventory"] = true
	completed[&"stock_shelf"] = true
	var note: String = String(controller._build_shift_note())
	assert_true(
		note.contains("customer at the register"),
		"Skipped customer must be named in the shift note; got: '%s'" % note
	)


func test_shift_note_joins_multiple_skipped_steps() -> void:
	# All three required steps skipped — the note must enumerate every one
	# so the summary cannot read as a clean wrap-up.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	(controller.get("_completed_objectives") as Dictionary).clear()
	var note: String = String(controller._build_shift_note())
	assert_true(
		note.contains("customer at the register"),
		"Multi-skip note must name the customer step; got: '%s'" % note
	)
	assert_true(
		note.contains("back room delivery"),
		"Multi-skip note must name the back-room step; got: '%s'" % note
	)
	assert_true(
		note.contains("used shelf"),
		"Multi-skip note must name the stock-shelf step; got: '%s'" % note
	)


func test_on_day_close_confirmed_spawns_summary_only_once() -> void:
	# BRAINDUMP modal-discipline rule: a re-emit of `day_close_confirmed`
	# (production `DayCycleController` listener firing alongside the beta
	# controller, or a stray double-press) must not produce a second
	# summary modal. The controller's `_summary_spawned` guard plus
	# ModalQueue's panel-instance dedup are the two layers being verified.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	# Walk the chain to END_DAY so the close-day gate is satisfied.
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	# First confirm — spawns the summary modal.
	controller._on_day_close_confirmed()
	await get_tree().process_frame
	var panel: BetaDaySummaryPanel = (
		controller.get("_summary_panel") as BetaDaySummaryPanel
	)
	assert_not_null(panel, "Summary panel must be spawned on first confirm")
	if panel == null:
		return
	var depth_after_first: int = InputFocus.depth()
	# Second confirm — must early-out, leaving the modal stack untouched.
	controller._on_day_close_confirmed()
	await get_tree().process_frame
	assert_eq(
		InputFocus.depth(), depth_after_first,
		"Repeat _on_day_close_confirmed must not push a second CTX_MODAL frame"
	)
	assert_eq(
		ModalQueue.pending_count(), 0,
		"Repeat _on_day_close_confirmed must not enqueue a second summary"
	)


func test_close_day_summary_uses_dynamic_shift_note() -> void:
	# Drive the full chain to END_DAY, confirm close, and verify the summary
	# payload's shift_note tracks `_completed_objectives` rather than the
	# legacy hardcoded literal.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	controller.on_beta_day_end_requested()
	await get_tree().process_frame
	_press_close_day_confirm(controller)
	await get_tree().process_frame
	var panel: BetaDaySummaryPanel = (
		controller.get("_summary_panel") as BetaDaySummaryPanel
	)
	assert_not_null(panel, "Summary panel must be spawned")
	if panel == null:
		return
	var note_label: Label = panel.get("_note_label") as Label
	assert_not_null(note_label, "Summary panel must own a _note_label")
	if note_label == null:
		return
	assert_true(
		note_label.text.contains("made it through"),
		"Completed-chain summary must render the baseline shift_note; got: '%s'"
		% note_label.text
	)


# ── ModalQueue depth invariant during the full Day-1 chain ────────────────
# Walks the chain through every modal open/close the player triggers
# (decision card → close-day confirm → summary) and asserts the
# `one blocking modal at a time` invariant via the panel-local
# `_focus_pushed` field and ModalQueue's own bookkeeping.
#
# We deliberately avoid absolute `InputFocus.depth()` / CTX_MODAL-frame
# count assertions: BetaDayOneController parents its modal panels under
# `_ui_root()`, which falls back to `/root` in headless tests. The in-
# process GUT runner does not garbage-collect panels created by prior
# tests' (now-freed) controllers, so leaked listeners can push extra
# CTX_MODAL frames onto a globally-shared stack while still leaving the
# *current* controller's modal contract intact. Mirrors the existing
# `test_summary_continue_pops_modal_focus_before_starting_next_day` choice
# to assert against panel-local invariants for the same reason.

func test_modal_queue_depth_never_exceeds_one_during_day1() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return

	# Day starts at TALK_TO_CUSTOMER. ModalQueue must be idle from this
	# controller's perspective — `before_each` resets it.
	assert_eq(
		ModalQueue.pending_count(), 0,
		"[day_start] ModalQueue must start with no pending entries"
	)

	# Player E on customer → BetaDecisionCardPanel enqueues at DAY_SUMMARY
	# priority and dispatches synchronously (queue was idle).
	controller.on_beta_customer_interacted()
	await get_tree().process_frame
	var decision_panel: BetaDecisionCardPanel = (
		controller.get("_decision_panel") as BetaDecisionCardPanel
	)
	assert_not_null(decision_panel, "Controller must own _decision_panel")
	if decision_panel == null:
		return
	assert_same(
		ModalQueue.active_panel(), decision_panel,
		"[decision_card_open] Decision card must be the active ModalQueue entry"
	)
	assert_true(
		bool(decision_panel.get("_focus_pushed")),
		"[decision_card_open] Decision card must own a CTX_MODAL frame"
	)
	assert_eq(
		ModalQueue.pending_count(), 0,
		"[decision_card_open] No panel may be queued behind the decision card"
	)

	# Pick a choice via the panel's button handler so the runtime
	# emit+close sequence runs: emits choice_selected (controller advances
	# the chain) then calls close() (panel pops its own CTX_MODAL frame and
	# notifies ModalQueue).
	decision_panel._on_choice_pressed(&"clean_exchange", {})
	await get_tree().process_frame
	assert_false(
		bool(decision_panel.get("_focus_pushed")),
		"[after_choice] Decision card must release its CTX_MODAL frame on close"
	)
	assert_null(
		ModalQueue.active_panel(),
		"[after_choice] ModalQueue must drain to idle after the decision card closes"
	)
	assert_eq(
		ModalQueue.pending_count(), 0,
		"[after_choice] ModalQueue pending must stay at 0"
	)

	# Back-room and restock are non-modal interactions; queue stays idle.
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	assert_null(
		ModalQueue.active_panel(),
		"[after_backroom] ModalQueue must remain idle through back-room pickup"
	)
	assert_eq(
		ModalQueue.pending_count(), 0,
		"[after_backroom] ModalQueue pending must stay at 0"
	)

	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	assert_null(
		ModalQueue.active_panel(),
		"[after_restock] ModalQueue must remain idle through restocking"
	)
	assert_eq(
		ModalQueue.pending_count(), 0,
		"[after_restock] ModalQueue pending must stay at 0"
	)

	# Player E on the day-end trigger → CloseDayConfirmationPanel uses the
	# direct-open path (not ModalQueue), so it claims CTX_MODAL via its
	# own _focus_pushed bookkeeping. ModalQueue stays idle.
	controller.on_beta_day_end_requested()
	await get_tree().process_frame
	var close_day_panel: CanvasLayer = (
		controller.get("_close_day_panel") as CanvasLayer
	)
	assert_not_null(close_day_panel, "Controller must own _close_day_panel")
	if close_day_panel == null:
		return
	assert_true(
		bool(close_day_panel.get("_focus_pushed")),
		"[close_day_open] Close-day confirmation panel must own a CTX_MODAL frame"
	)
	assert_null(
		ModalQueue.active_panel(),
		"[close_day_open] Close-day confirm uses direct-open; ModalQueue stays idle"
	)

	# Confirm → close-day panel pops its frame, then BetaDaySummaryPanel
	# enqueues at DAY_SUMMARY priority and dispatches synchronously. The
	# hand-off must end with summary as the sole active modal — the
	# close-day frame released before the summary's push.
	_press_close_day_confirm(controller)
	await get_tree().process_frame
	assert_false(
		bool(close_day_panel.get("_focus_pushed")),
		"[summary_open] Close-day panel must have released its frame after confirm"
	)
	var summary_panel: BetaDaySummaryPanel = (
		controller.get("_summary_panel") as BetaDaySummaryPanel
	)
	assert_not_null(summary_panel, "Controller must own _summary_panel after confirm")
	if summary_panel == null:
		return
	assert_true(
		bool(summary_panel.get("_focus_pushed")),
		"[summary_open] Summary panel must own the CTX_MODAL frame after confirm"
	)
	assert_same(
		ModalQueue.active_panel(), summary_panel,
		"[summary_open] Summary panel must be the active ModalQueue entry"
	)


# ── HUD snapshot golden path ───────────────────────────────────────────────
# Captures `get_state_snapshot()` at each of the 4 chain phases and asserts
# the fields the HUD view-model reads (stage, completed_objectives,
# carrying_stock, can_close_day) match the expected progression. Locks the
# snapshot contract so a refactor of the underlying private fields cannot
# silently shift HUD readings.

func test_hud_snapshot_golden_path() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return

	# Phase 1 — TALK_TO_CUSTOMER.
	var snap_1: Dictionary = controller.get_state_snapshot()
	assert_eq(
		String(snap_1.get("stage", "")), "talk_to_customer",
		"Phase 1 stage must be talk_to_customer"
	)
	var completed_1: Dictionary = snap_1.get("completed_objectives", {}) as Dictionary
	assert_eq(
		completed_1.size(), 0,
		"Phase 1 completed_objectives must be empty"
	)
	assert_false(
		bool(snap_1.get("carrying_stock", true)),
		"Phase 1 carrying_stock must be false at day start"
	)
	assert_false(
		bool(snap_1.get("can_close_day", true)),
		"Phase 1 can_close_day must be false (chain not started)"
	)

	# Phase 2 — BACK_ROOM_INVENTORY (after customer beat).
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	var snap_2: Dictionary = controller.get_state_snapshot()
	assert_eq(
		String(snap_2.get("stage", "")), "back_room_inventory",
		"Phase 2 stage must be back_room_inventory"
	)
	var completed_2: Dictionary = snap_2.get("completed_objectives", {}) as Dictionary
	assert_true(
		completed_2.has(&"talk_to_customer"),
		"Phase 2 completed_objectives must include talk_to_customer"
	)
	assert_eq(
		completed_2.size(), 1,
		"Phase 2 completed_objectives must contain exactly one entry"
	)
	assert_false(
		bool(snap_2.get("carrying_stock", true)),
		"Phase 2 carrying_stock must remain false before pickup"
	)
	assert_false(
		bool(snap_2.get("can_close_day", true)),
		"Phase 2 can_close_day must be false"
	)

	# Phase 3 — STOCK_SHELF (after back-room pickup; carry flag flips).
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	var snap_3: Dictionary = controller.get_state_snapshot()
	assert_eq(
		String(snap_3.get("stage", "")), "stock_shelf",
		"Phase 3 stage must be stock_shelf"
	)
	var completed_3: Dictionary = snap_3.get("completed_objectives", {}) as Dictionary
	assert_true(
		completed_3.has(&"talk_to_customer"),
		"Phase 3 completed_objectives must keep talk_to_customer"
	)
	assert_true(
		completed_3.has(&"back_room_inventory"),
		"Phase 3 completed_objectives must include back_room_inventory"
	)
	assert_true(
		bool(snap_3.get("carrying_stock", false)),
		"Phase 3 carrying_stock must flip true after back-room pickup"
	)
	assert_false(
		bool(snap_3.get("can_close_day", true)),
		"Phase 3 can_close_day must still be false (shelf not stocked)"
	)

	# Phase 4 — END_DAY (after restock; carry clears, close-day unlocks).
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	var snap_4: Dictionary = controller.get_state_snapshot()
	assert_eq(
		String(snap_4.get("stage", "")), "end_day",
		"Phase 4 stage must be end_day"
	)
	var completed_4: Dictionary = snap_4.get("completed_objectives", {}) as Dictionary
	assert_true(
		completed_4.has(&"talk_to_customer"),
		"Phase 4 completed_objectives must keep talk_to_customer"
	)
	assert_true(
		completed_4.has(&"back_room_inventory"),
		"Phase 4 completed_objectives must keep back_room_inventory"
	)
	assert_true(
		completed_4.has(&"stock_shelf"),
		"Phase 4 completed_objectives must include stock_shelf"
	)
	assert_false(
		bool(snap_4.get("carrying_stock", true)),
		"Phase 4 carrying_stock must clear after stocking the shelf"
	)
	assert_true(
		bool(snap_4.get("can_close_day", false)),
		"Phase 4 can_close_day must be true once every required objective is done at end_day"
	)
