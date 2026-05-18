## Tests for `BetaObjectiveTargetHighlight` — the floating "▶ E" chip that
## marks the active Day-1 chain interactable.
##
## Covers the visual spec (green chip color matching `sign_backing_mat`
## neon), the looping alpha pulse, the modal-hide contract, the
## stage→target resolution, and the single-chip invariant.
extends GutTest


func before_each() -> void:
	InputFocus._reset_for_tests()
	BetaRunState.reset_new_run()


func _make_highlight() -> BetaObjectiveTargetHighlight:
	var highlight: BetaObjectiveTargetHighlight = (
		BetaObjectiveTargetHighlight.new()
	)
	add_child_autofree(highlight)
	return highlight


## Builds a bare Node3D root populated with the four chain interactable
## parents from `retro_games.tscn`, plus a child node added to the
## `beta_day_one_controller` group whose `current_stage()` returns a value
## set by the test. Lets tests exercise `_refresh_from_controller` without
## loading the full store scene.
func _make_store_root_with_stage(stage: StringName) -> Node3D:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	for child_name: String in [
		"BetaDayOneCustomer",
		"BetaBackroomPickup",
		"BetaRestockShelf",
		"BetaDayEndTrigger",
	]:
		var n: Node3D = Node3D.new()
		n.name = child_name
		root.add_child(n)
	var stub: _StageStub = _StageStub.new()
	stub.add_to_group("beta_day_one_controller")
	stub.stage = stage
	root.add_child(stub)
	return root


# ── visual spec ───────────────────────────────────────────────────────────

func test_chip_sits_on_canvas_layer_35() -> void:
	# Layer 35 places the chip below ObjectiveRail (40) and ModalDimOverlay
	# (49) so the rail and dim layer both render above the chip.
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	assert_eq(
		highlight.layer, BetaObjectiveTargetHighlight.LAYER_INDEX,
		"Highlight must sit on CanvasLayer %d"
		% BetaObjectiveTargetHighlight.LAYER_INDEX
	)


func test_chip_color_matches_sign_neon_palette() -> void:
	# AC: green Color(0.3, 1.0, 0.5) matching `sign_backing_mat` emission.
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	assert_eq(
		BetaObjectiveTargetHighlight.CHIP_COLOR, Color(0.3, 1.0, 0.5),
		"Chip color must echo the store sign neon palette"
	)
	var chip: PanelContainer = highlight.get_chip()
	assert_not_null(chip, "Chip must be built at _ready")
	var style: StyleBoxFlat = chip.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(style, "Chip panel must use a StyleBoxFlat")
	if style != null:
		assert_eq(
			style.border_color, Color(0.3, 1.0, 0.5),
			"Chip border must use the neon-green color"
		)


func test_chip_label_shows_pointer_and_key() -> void:
	# AC: chip displays "▶ E".
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	var chip: PanelContainer = highlight.get_chip()
	var label: Label = chip.get_node_or_null("Label") as Label
	assert_not_null(label, "Chip must own a Label child")
	if label != null:
		assert_eq(label.text, "▶ E", "Chip label must read '▶ E'")
		assert_eq(
			label.get_theme_color("font_color"), Color(0.3, 1.0, 0.5),
			"Chip label text must use the neon-green color"
		)


# ── default visibility ────────────────────────────────────────────────────

func test_chip_starts_hidden_with_no_target() -> void:
	# Without a BetaDayOneController in the tree, the highlight has no
	# stage to resolve and must keep the chip hidden.
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	var chip: PanelContainer = highlight.get_chip()
	assert_false(
		chip.visible,
		"Chip must be hidden when no chain stage is active"
	)
	assert_null(
		highlight.get_target_node(),
		"Target must be null without a controller"
	)


# ── pulse contract ────────────────────────────────────────────────────────

func test_pulse_tween_is_active_at_ready() -> void:
	# AC: chip pulses alpha 0.7→1.0 on a ~1.2s cycle. The tween starts at
	# _ready and loops, so it must be live without further action.
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	assert_true(
		highlight.is_pulse_active(),
		"Pulse tween must be running after _ready"
	)


func test_pulse_constants_match_spec() -> void:
	assert_almost_eq(
		BetaObjectiveTargetHighlight.PULSE_ALPHA_MIN, 0.7, 0.001,
		"Pulse min alpha must be 0.7"
	)
	assert_almost_eq(
		BetaObjectiveTargetHighlight.PULSE_ALPHA_MAX, 1.0, 0.001,
		"Pulse max alpha must be 1.0"
	)
	assert_almost_eq(
		BetaObjectiveTargetHighlight.PULSE_HALF_CYCLE_SECONDS * 2.0,
		1.2, 0.001,
		"Pulse full-cycle duration must be ~1.2 s"
	)


# ── modal hide contract ───────────────────────────────────────────────────

func test_chip_hides_under_ctx_modal() -> void:
	# AC: chip hides while CTX_MODAL is the top of the focus stack so it
	# does not fight with the morning-note / decision / summary panels.
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	var root: Node3D = _make_store_root_with_stage(&"talk_to_customer")
	highlight.set_active_stage_for_test(&"talk_to_customer", root)
	var chip: PanelContainer = highlight.get_chip()
	assert_true(
		chip.visible,
		"Chip must be visible once a stage target is resolved"
	)
	InputFocus.push_context(InputFocus.CTX_MODAL)
	await get_tree().process_frame
	assert_false(
		chip.visible,
		"Chip must hide while CTX_MODAL is on top of the focus stack"
	)
	InputFocus.pop_context()
	await get_tree().process_frame
	assert_true(
		chip.visible,
		"Chip must re-show when CTX_MODAL is popped"
	)


# ── stage → target resolution ─────────────────────────────────────────────

func test_talk_to_customer_targets_beta_customer_node() -> void:
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	var root: Node3D = _make_store_root_with_stage(&"talk_to_customer")
	highlight.set_active_stage_for_test(&"talk_to_customer", root)
	var expected: Node3D = root.get_node("BetaDayOneCustomer") as Node3D
	assert_eq(
		highlight.get_target_node(), expected,
		"TALK_TO_CUSTOMER must target the BetaDayOneCustomer node"
	)


func test_back_room_inventory_targets_backroom_pickup_node() -> void:
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	var root: Node3D = _make_store_root_with_stage(&"back_room_inventory")
	highlight.set_active_stage_for_test(&"back_room_inventory", root)
	var expected: Node3D = root.get_node("BetaBackroomPickup") as Node3D
	assert_eq(
		highlight.get_target_node(), expected,
		"BACK_ROOM_INVENTORY must target the BetaBackroomPickup node"
	)


func test_stock_shelf_targets_restock_shelf_node() -> void:
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	var root: Node3D = _make_store_root_with_stage(&"stock_shelf")
	BetaRunState.carrying_stock = true
	highlight.set_active_stage_for_test(&"stock_shelf", root)
	var expected: Node3D = root.get_node("BetaRestockShelf") as Node3D
	assert_eq(
		highlight.get_target_node(), expected,
		"STOCK_SHELF must target the BetaRestockShelf node"
	)


func test_stock_shelf_has_no_target_until_stock_is_carried() -> void:
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	var root: Node3D = _make_store_root_with_stage(&"stock_shelf")
	BetaRunState.carrying_stock = false
	highlight.set_active_stage_for_test(&"stock_shelf", root)
	assert_null(
		highlight.get_target_node(),
		"STOCK_SHELF must not highlight the shelf as actionable before pickup"
	)


func test_end_day_targets_day_end_trigger_node() -> void:
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	var root: Node3D = _make_store_root_with_stage(&"end_day")
	highlight.set_active_stage_for_test(&"end_day", root)
	var expected: Node3D = root.get_node("BetaDayEndTrigger") as Node3D
	assert_eq(
		highlight.get_target_node(), expected,
		"END_DAY must target the BetaDayEndTrigger node"
	)


func test_vic_note_stage_has_no_target() -> void:
	# VIC_NOTE is the pre-chain morning-note phase. The chip should not
	# point at any of the four chain interactables because none of them
	# is the active beat yet — the morning-note modal owns the screen.
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	var root: Node3D = _make_store_root_with_stage(&"vic_note")
	highlight.set_active_stage_for_test(&"vic_note", root)
	assert_null(
		highlight.get_target_node(),
		"VIC_NOTE phase must not resolve to any chain target"
	)
	var chip: PanelContainer = highlight.get_chip()
	assert_false(
		chip.visible,
		"Chip must stay hidden during VIC_NOTE"
	)


# ── controller-driven refresh ─────────────────────────────────────────────

func test_objective_changed_signal_refreshes_target_via_group() -> void:
	# AC: highlight subscribes to EventBus.objective_changed and resolves
	# the target by reading `current_stage()` on the controller registered
	# in the `beta_day_one_controller` group. Builds a fresh store-root
	# with the four chain interactable parents and a stub controller, then
	# fires the signal twice with the stub returning different stages.
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	for child_name: String in [
		"BetaDayOneCustomer",
		"BetaBackroomPickup",
		"BetaRestockShelf",
		"BetaDayEndTrigger",
	]:
		var n: Node3D = Node3D.new()
		n.name = child_name
		root.add_child(n)
	var stub: _StageStub = _StageStub.new()
	stub.add_to_group("beta_day_one_controller")
	stub.stage = &"vic_note"  # pre-chain phase resolves to no target
	root.add_child(stub)
	var highlight: BetaObjectiveTargetHighlight = (
		BetaObjectiveTargetHighlight.new()
	)
	root.add_child(highlight)
	assert_null(
		highlight.get_target_node(),
		"VIC_NOTE phase must seed an empty target at _ready"
	)
	stub.stage = &"talk_to_customer"
	EventBus.objective_changed.emit({})
	await get_tree().process_frame
	assert_eq(
		highlight.get_target_node(),
		root.get_node("BetaDayOneCustomer") as Node3D,
		"objective_changed must re-resolve to the new stage's target"
	)
	stub.stage = &"stock_shelf"
	stub.carrying = true
	EventBus.objective_changed.emit({})
	await get_tree().process_frame
	assert_eq(
		highlight.get_target_node(),
		root.get_node("BetaRestockShelf") as Node3D,
		"Subsequent objective_changed must overwrite the prior target"
	)


# ── single-chip invariant ─────────────────────────────────────────────────

func test_only_one_target_at_a_time_across_stage_transitions() -> void:
	# AC: only one chip is visible at a time — previous chip hidden before
	# new one shown on stage change. The highlight stores a single
	# `_target_node`, so swapping the active stage must overwrite the
	# prior target rather than tracking both.
	var highlight: BetaObjectiveTargetHighlight = _make_highlight()
	var root: Node3D = _make_store_root_with_stage(&"talk_to_customer")
	highlight.set_active_stage_for_test(&"talk_to_customer", root)
	var customer: Node3D = root.get_node("BetaDayOneCustomer") as Node3D
	assert_eq(highlight.get_target_node(), customer)

	highlight.set_active_stage_for_test(&"back_room_inventory", root)
	var pickup: Node3D = root.get_node("BetaBackroomPickup") as Node3D
	assert_eq(
		highlight.get_target_node(), pickup,
		"Stage advance must overwrite the prior target"
	)
	# Only one chip child exists on the highlight — verify there is no
	# second PanelContainer left over from the previous stage.
	var chip_count: int = 0
	for child: Node in highlight.get_children():
		if child is PanelContainer:
			chip_count += 1
	assert_eq(
		chip_count, 1,
		"Highlight must own exactly one chip across stage transitions"
	)


# ── y-offset spec (per-stage chip placement above geometry) ───────────────

func test_stage_y_offsets_are_positive_for_chain_stages() -> void:
	# The chip projects from `target.global_position + Vector3(0, y, 0)` so
	# y must be positive — otherwise the chip would render below the floor.
	for stage_name: String in [
		"talk_to_customer",
		"back_room_inventory",
		"stock_shelf",
		"end_day",
	]:
		var entry: Array = (
			BetaObjectiveTargetHighlight.STAGE_TARGETS[StringName(stage_name)]
			as Array
		)
		var y_offset: float = float(entry[1])
		assert_gt(
			y_offset, 0.0,
			"Stage %s must have a positive Y offset; got %.2f"
			% [stage_name, y_offset]
		)


# ── stub helper class ─────────────────────────────────────────────────────

## Minimal `BetaDayOneController` proxy: registers itself in the
## `beta_day_one_controller` group and exposes `current_stage()` so the
## highlight's `_refresh_from_controller` lookup walks through this stub.
## Used by tests that want to exercise the full resolution path without
## loading `retro_games.tscn` and the real controller's `_apply_beta_only_strip`.
class _StageStub:
	extends Node
	var stage: StringName = &""
	var carrying: bool = false

	func current_stage() -> StringName:
		return stage

	func can_interact_restock() -> bool:
		return carrying
