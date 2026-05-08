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
	# Wait one frame so _ready / call_deferred(_start_day) settle before tests
	# inspect controller state.
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null


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
