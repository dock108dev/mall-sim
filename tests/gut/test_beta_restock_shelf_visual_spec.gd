## Visual-spec contract for the beta restock shelf (Day 1).
##
## The before/after-stocking read is the core feedback for the chain's
## stock_shelf beat: the empty board must clearly say "items belong here"
## via 5 slot-marker outlines, the post-stock state must read as warm
## stocked product (warm-amber emission), and the toast notification must
## name the same destination ("used games shelf") that the objective rail
## and interaction prompt name. Each assertion below pins one of those
## pieces against the authored layout.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const SLOT_MARKER_NAMES: Array[String] = [
	"SlotMarker0", "SlotMarker1", "SlotMarker2", "SlotMarker3", "SlotMarker4",
]
const EXPECTED_SLOT_X: Array[float] = [-0.9, -0.45, 0.0, 0.45, 0.9]
const SHELFBOARD_TOP_Y: float = 1.15  # local Y=1.1 + half-thickness 0.05
const SLOT_MARKER_BRIGHTNESS_MAX: float = 0.8  # albedo channel cap (no white)
const SLOT_MARKER_WARMTH_MIN_DELTA: float = 0.05  # red − blue lower bound
const ITEM_EMISSION_WARM_HUE_MIN_DELTA: float = 0.2  # red − blue lower bound

var _root: Node3D = null


func before_each() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "retro_games.tscn must load for the visual-spec test")
	if scene == null:
		return
	_root = scene.instantiate() as Node3D
	add_child(_root)
	# Two frames so _ready / call_deferred(_open_day)
	# settle before the spawn-side assertions run their controller calls.
	await get_tree().process_frame
	await get_tree().process_frame
	# Day 1 starts directly at the customer beat. Keep this guarded dismiss
	# only for tests that explicitly switch to a later-day note gate.
	var controller: Node = _beta_controller()
	if controller != null:
		var panel: BetaManagerNotePanel = (
			controller.get("_vic_note_panel") as BetaManagerNotePanel
		)
		if panel != null and panel.visible:
			panel.close()
			panel.note_dismissed.emit()
			await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null


# ── Empty-shelf "before" state: 5 dark slot markers on the ShelfBoard ──────

func test_beta_restock_shelf_authors_five_slot_markers() -> void:
	var shelf: Node = _root.get_node_or_null("BetaRestockShelf")
	assert_not_null(shelf, "BetaRestockShelf must exist under the store root")
	if shelf == null:
		return
	for marker_name: String in SLOT_MARKER_NAMES:
		var marker: Node = shelf.get_node_or_null(marker_name)
		assert_not_null(
			marker,
			"BetaRestockShelf must author %s as a child slot marker so the "
			% marker_name + "empty shelf reads as 'items belong here'."
		)


func test_slot_markers_align_with_spawn_x_positions_on_board_top() -> void:
	# Markers must sit at the same X positions where _spawn_visible_shelf_items
	# places stocked items, so spawned items occlude them after the stock
	# interaction. They must also rest just above the ShelfBoard top face
	# (local Y = 1.15) so they read as flat marks on the shelf surface, not
	# floating tiles.
	var shelf: Node = _root.get_node_or_null("BetaRestockShelf")
	if shelf == null:
		return
	for i: int in range(SLOT_MARKER_NAMES.size()):
		var marker: Node3D = shelf.get_node_or_null(
			SLOT_MARKER_NAMES[i]
		) as Node3D
		assert_not_null(marker, "%s must be a Node3D" % SLOT_MARKER_NAMES[i])
		if marker == null:
			continue
		assert_almost_eq(
			marker.position.x, EXPECTED_SLOT_X[i], 0.01,
			"%s.x must match the BetaShelfItem spawn x (%.2f); got %.2f"
			% [SLOT_MARKER_NAMES[i], EXPECTED_SLOT_X[i], marker.position.x]
		)
		assert_gte(
			marker.position.y, SHELFBOARD_TOP_Y,
			"%s.y must sit on or just above the ShelfBoard top face "
			% SLOT_MARKER_NAMES[i]
			+ "(>= %.3f); got %.3f" % [SHELFBOARD_TOP_Y, marker.position.y]
		)
		assert_lt(
			marker.position.y, SHELFBOARD_TOP_Y + 0.05,
			"%s.y must hug the ShelfBoard surface " % SLOT_MARKER_NAMES[i]
			+ "(< top + 0.05 m); got %.3f" % marker.position.y
		)


func test_slot_marker_material_is_warm_tan_peg_label() -> void:
	var shelf: Node = _root.get_node_or_null("BetaRestockShelf")
	if shelf == null:
		return
	var marker: MeshInstance3D = shelf.get_node_or_null(
		SLOT_MARKER_NAMES[0]
	) as MeshInstance3D
	if marker == null:
		return
	var mat: StandardMaterial3D = marker.get_surface_override_material(
		0
	) as StandardMaterial3D
	assert_not_null(
		mat,
		"Slot markers must carry a StandardMaterial3D override so the "
		+ "peg-label color is authored, not inherited from the parent."
	)
	if mat == null:
		return
	var c: Color = mat.albedo_color
	# Warm tan peg-label color reads as an intentional retail label holder
	# against the medium-wood shelf rather than a shadow scuff. The cap
	# keeps the marker from washing out to white; the warmth delta keeps
	# it from drifting cool/grey.
	assert_lte(
		maxf(maxf(c.r, c.g), c.b), SLOT_MARKER_BRIGHTNESS_MAX,
		"Slot marker albedo (%.2f, %.2f, %.2f) must not wash out to white "
		% [c.r, c.g, c.b]
		+ "(max channel <= %.2f) so the marker reads as a peg label."
		% SLOT_MARKER_BRIGHTNESS_MAX
	)
	assert_gte(
		c.r - c.b, SLOT_MARKER_WARMTH_MIN_DELTA,
		"Slot marker albedo (%.2f, %.2f, %.2f) must be warm-hue "
		% [c.r, c.g, c.b]
		+ "(red − blue >= %.2f) so it reads as warm tan, not cool grey."
		% SLOT_MARKER_WARMTH_MIN_DELTA
	)


# ── Empty-state overlay: present when empty, hidden after stocking ─────────

func test_empty_overlay_visible_on_unstocked_shelf() -> void:
	var shelf: Node = _root.get_node_or_null("BetaRestockShelf")
	assert_not_null(shelf, "BetaRestockShelf must exist under the store root")
	if shelf == null:
		return
	var overlay: Node3D = shelf.get_node_or_null("EmptyOverlay") as Node3D
	assert_not_null(
		overlay,
		"BetaRestockShelf must author an EmptyOverlay child so the empty "
		+ "shelf reads as 'intentionally empty' from FP standing height."
	)
	if overlay == null:
		return
	assert_true(
		overlay.visible,
		"EmptyOverlay must start visible so the bare shelf has a clear "
		+ "before-state before the player stocks it."
	)


func test_backroom_pickup_label_names_delivery_quantity() -> void:
	var label: Label3D = (
		_root.get_node_or_null("BetaBackroomPickup/StockBoxLabel") as Label3D
	)
	assert_not_null(label, "BetaBackroomPickup must label the delivery crate")
	if label == null:
		return
	assert_string_contains(
		label.text, str(BetaDayOneController._BACKROOM_DELIVERY_QUANTITY),
		"Back-room delivery label must name the available item count"
	)


func test_empty_overlay_hidden_after_stocking() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	var shelf: Node = _root.get_node_or_null("BetaRestockShelf")
	if shelf == null:
		return
	var overlay: Node3D = shelf.get_node_or_null("EmptyOverlay") as Node3D
	if overlay == null:
		return
	assert_false(
		overlay.visible,
		"EmptyOverlay must be hidden after stocking so the shelf 'lights "
		+ "up' as items appear."
	)


# ── Stocking gate: shelf is locked until the back-room delivery is held ────

func test_restock_locked_when_not_carrying_stock() -> void:
	# Defensive guard: even if _stage somehow lands on STOCK_SHELF without
	# the player actually carrying the back-room delivery (e.g. a future
	# chain rewire, a save-load gap), the shelf must refuse interaction
	# and surface the explicit "go to the back room" copy. Force the edge
	# case directly so the gate is exercised regardless of chain order.
	var controller: Node = _beta_controller()
	if controller == null:
		return
	controller._stage = controller.STAGE_STOCK_SHELF
	BetaRunState.carrying_stock = false
	assert_false(
		controller.can_interact_restock(),
		"can_interact_restock() must return false at STOCK_SHELF when the "
		+ "player is not yet carrying the back-room delivery."
	)
	var reason: String = String(controller.restock_disabled_reason())
	assert_eq(
		reason, "Pick up the back room delivery first.",
		"restock_disabled_reason must explicitly point the player back to "
		+ "the back room when the shelf is the active stage but stock is "
		+ "not held."
	)


func test_restock_interaction_without_carrying_stock_is_blocked() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	controller._stage = controller.STAGE_STOCK_SHELF
	BetaRunState.carrying_stock = false
	watch_signals(EventBus)
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	assert_signal_not_emitted(
		EventBus, "beta_shelf_count_changed",
		"Restock must not flip shelf count when the player is not carrying stock"
	)
	assert_false(
		bool(controller.is_objective_completed(&"stock_shelf")),
		"Restock must not complete the shelf objective without carried stock"
	)
	assert_signal_emitted(
		EventBus, "notification_requested",
		"Blocked restock must tell the player to pick up the delivery"
	)
	assert_eq(
		get_signal_parameters(EventBus, "notification_requested"),
		["Pick up the back room delivery first."],
		"Blocked restock notification copy must name the delivery pickup"
	)


func test_restock_unlocks_after_backroom_pickup() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	assert_true(
		controller.can_interact_restock(),
		"can_interact_restock() must return true once the player is "
		+ "carrying the back-room delivery."
	)


func test_restock_visuals_reset_to_empty_state_between_days() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	var shelf: Node = _root.get_node_or_null("BetaRestockShelf")
	if shelf == null:
		return
	assert_gt(_count_beta_shelf_items(shelf), 0, "Pre-condition: shelf is stocked")
	controller._reset_scene_for_day(2)
	await get_tree().process_frame
	assert_eq(
		_count_beta_shelf_items(shelf), 0,
		"Beta-only shelf item meshes must not survive a day reset"
	)
	var overlay: Node3D = shelf.get_node_or_null("EmptyOverlay") as Node3D
	assert_not_null(overlay, "EmptyOverlay must still exist after reset")
	if overlay != null:
		assert_true(
			overlay.visible,
			"EmptyOverlay must return when beta restock visuals reset"
		)


# ── After-stock "after" state: warm amber emission on spawned items ────────

func test_spawned_shelf_items_emit_warm_amber_not_cool_blue() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	# Walk the chain into the stock_shelf stage and run the spawn.
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	var shelf: Node = _root.get_node_or_null("BetaRestockShelf")
	if shelf == null:
		return
	var checked_any: bool = false
	for child: Node in shelf.get_children():
		if not String(child.name).begins_with("BetaShelfItem"):
			continue
		var mesh_node: MeshInstance3D = child as MeshInstance3D
		if mesh_node == null:
			continue
		var mat: StandardMaterial3D = mesh_node.material_override as StandardMaterial3D
		assert_not_null(
			mat,
			"%s must carry a material_override so emission is authored."
			% mesh_node.name
		)
		if mat == null:
			continue
		assert_true(
			mat.emission_enabled,
			"%s emission must be enabled so the stocked shelf glows warm."
			% mesh_node.name
		)
		var e: Color = mat.emission
		assert_gte(
			e.r - e.b, ITEM_EMISSION_WARM_HUE_MIN_DELTA,
			(
				"%s emission (%.2f, %.2f, %.2f) must be warm-hue "
				+ "(red − blue >= %.2f) so the post-stock state reads as "
				+ "warm and inviting, not the cool blue of the empty shelf."
			) % [
				mesh_node.name, e.r, e.g, e.b,
				ITEM_EMISSION_WARM_HUE_MIN_DELTA,
			]
		)
		checked_any = true
	assert_true(
		checked_any,
		"At least one BetaShelfItem must spawn after stocking the shelf "
		+ "so the post-stock visual state has something to verify."
	)


# ── Spawned items are upright with the wide face toward the player ─────────

func test_spawned_shelf_items_are_upright_with_wide_face_forward() -> void:
	var controller: Node = _beta_controller()
	if controller == null:
		return
	controller._on_choice_selected(&"clean_exchange", {})
	await get_tree().process_frame
	controller.on_beta_backroom_pickup_interacted()
	await get_tree().process_frame
	controller.on_beta_restock_interacted()
	await get_tree().process_frame
	var shelf: Node = _root.get_node_or_null("BetaRestockShelf")
	if shelf == null:
		return
	for child: Node in shelf.get_children():
		if not String(child.name).begins_with("BetaShelfItem"):
			continue
		var mesh_node: MeshInstance3D = child as MeshInstance3D
		if mesh_node == null:
			continue
		var box: BoxMesh = mesh_node.mesh as BoxMesh
		assert_not_null(box, "%s must use a BoxMesh" % mesh_node.name)
		if box == null:
			continue
		# size = (X width, Y height, Z depth). Without rotation the +Z face
		# (player-facing) is X × Y = 0.18 × 0.22 — a portrait game-case face.
		# The 0.06 m thin edge sits along Z (into the shelf). The contract:
		# Y (height) must dominate Z (depth) so the box stands tall, not
		# laid flat.
		assert_gt(
			box.size.y, box.size.z,
			"%s box height (%.2f) must exceed its depth (%.2f) "
			% [mesh_node.name, box.size.y, box.size.z]
			+ "so the case stands upright on the shelf."
		)
		# Identity rotation on the local transform (basis ≈ Identity) keeps
		# the wide 0.18 × 0.22 face oriented toward +Z (player aisle).
		var basis: Basis = mesh_node.transform.basis
		assert_almost_eq(
			basis.x.length(), 1.0, 0.01,
			"%s must keep unit X scale so the box is not stretched."
			% mesh_node.name
		)
		assert_almost_eq(
			basis.y.length(), 1.0, 0.01,
			"%s must keep unit Y scale." % mesh_node.name
		)
		assert_almost_eq(
			basis.z.length(), 1.0, 0.01,
			"%s must keep unit Z scale." % mesh_node.name
		)


# ── Notification copy names the same destination as the objective rail ─────

func test_restock_toast_names_the_used_games_shelf() -> void:
	# The stock_shelf objective rail says "used games shelf"; the
	# interaction prompt's display_name says "used games shelf"; the
	# notification must name the same destination so the player closes
	# the loop on a consistent term, not three different phrasings.
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
	var emitted_any: bool = false
	for params: Array in get_signal_parameters_all(
		EventBus, "toast_requested"
	):
		if params.size() < 1:
			continue
		var msg: String = String(params[0])
		if msg.findn("used games shelf") >= 0:
			emitted_any = true
			break
	assert_true(
		emitted_any,
		"Restock toast must name 'used games shelf' to match the objective "
		+ "rail and interaction prompt copy."
	)


# ── Helpers ────────────────────────────────────────────────────────────────

func _beta_controller() -> Node:
	return get_tree().get_first_node_in_group("beta_day_one_controller")


func _count_beta_shelf_items(shelf: Node) -> int:
	var count: int = 0
	for child: Node in shelf.get_children():
		if String(child.name).begins_with("BetaShelfItem"):
			count += 1
	return count


## GUT's `get_signal_parameters` returns the params of one emission and
## crashes if the index runs past the end. Use `get_signal_emit_count`
## as the loop bound so the helper stays safe even when no emissions
## have been captured yet. Toast traffic during a single frame includes
## carry-state and outcome toasts as well as the stock toast — collect
## all matching emissions so the copy assertion can scan the whole batch
## instead of guessing which one is "the" stock toast by index.
func get_signal_parameters_all(emitter: Object, signal_name: String) -> Array:
	var out: Array = []
	var count: int = get_signal_emit_count(emitter, signal_name)
	for idx: int in range(count):
		var params: Variant = get_signal_parameters(emitter, signal_name, idx)
		if params != null:
			out.append(params)
	return out
