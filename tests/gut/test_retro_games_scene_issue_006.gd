## Verifies ISSUE-006 acceptance criteria: PlayerController navigation,
## debug zone labels, shelf interaction wiring, and customer path markers.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"

var _root: Node3D = null


func before_all() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "Retro Games scene must load")
	if scene:
		_root = scene.instantiate() as Node3D
		add_child(_root)


func after_all() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null


# ── Camera / movement ─────────────────────────────────────────────────────────

func test_player_controller_exists_with_script() -> void:
	var pc: Node = _root.get_node_or_null("PlayerController")
	assert_not_null(pc, "PlayerController node must exist")
	if pc:
		assert_not_null(pc.get_script(), "PlayerController must have a script attached")


func test_player_controller_has_camera3d_child() -> void:
	var pc: Node = _root.get_node_or_null("PlayerController")
	assert_not_null(pc, "PlayerController must exist")
	if not pc:
		return
	var cam: Camera3D = pc.get_node_or_null("Camera3D") as Camera3D
	assert_not_null(cam, "PlayerController must have a Camera3D child named Camera3D")
	if cam:
		assert_true(cam.current, "Camera3D must have current = true in the scene definition")


func test_store_bounds_are_tighter_than_defaults() -> void:
	var pc: Node = _root.get_node_or_null("PlayerController")
	assert_not_null(pc, "PlayerController must exist")
	if not pc:
		return
	var max_b: Vector3 = pc.get("store_bounds_max")
	var min_b: Vector3 = pc.get("store_bounds_min")
	assert_lt(max_b.x, 7.0, "store_bounds_max.x must be tighter than default 7.0")
	assert_lt(max_b.z, 5.0, "store_bounds_max.z must be tighter than default 5.0")
	assert_gt(min_b.x, -7.0, "store_bounds_min.x must be tighter than default -7.0")
	assert_gt(min_b.z, -5.0, "store_bounds_min.z must be tighter than default -5.0")


func test_set_pivot_clamps_to_store_bounds() -> void:
	var pc: Node = _root.get_node_or_null("PlayerController")
	assert_not_null(pc, "PlayerController must exist")
	if not pc or not pc.has_method("set_pivot"):
		return
	var max_b: Vector3 = pc.get("store_bounds_max")
	pc.call("set_pivot", Vector3(100.0, 0.0, 100.0))
	var pos: Vector3 = pc.global_position
	assert_lte(pos.x, max_b.x + 0.001, "Pivot x clamped to store_bounds_max.x")
	assert_lte(pos.z, max_b.z + 0.001, "Pivot z clamped to store_bounds_max.z")

	var min_b: Vector3 = pc.get("store_bounds_min")
	pc.call("set_pivot", Vector3(-100.0, 0.0, -100.0))
	pos = pc.global_position
	assert_gte(pos.x, min_b.x - 0.001, "Pivot x clamped to store_bounds_min.x")
	assert_gte(pos.z, min_b.z - 0.001, "Pivot z clamped to store_bounds_min.z")


func test_no_second_camera_in_scene() -> void:
	var cameras: Array[Node] = []
	_collect_by_class(_root, "Camera3D", cameras)
	assert_eq(cameras.size(), 1, "Scene must have exactly one Camera3D (the PlayerController child)")


# ── Debug zone labels ─────────────────────────────────────────────────────────

func test_debug_labels_node_present() -> void:
	assert_not_null(
		_root.get_node_or_null("DebugLabels"),
		"DebugLabels Node3D must exist as a child of the scene root"
	)


func test_debug_labels_has_required_zones() -> void:
	var container: Node = _root.get_node_or_null("DebugLabels")
	assert_not_null(container, "DebugLabels must exist")
	if not container:
		return
	var texts: Array[String] = []
	for child: Node in container.get_children():
		if child is Label3D:
			texts.append((child as Label3D).text)
	var required: Array[String] = [
		"SHELF", "REGISTER", "CUSTOMER ENTRY", "BACKROOM", "DISPLAY TABLE"
	]
	for zone: String in required:
		var found: bool = false
		for t: String in texts:
			if t.contains(zone):
				found = true
				break
		assert_true(found, "DebugLabels must include a label containing '%s'" % zone)


func test_debug_labels_use_billboard_mode() -> void:
	var container: Node = _root.get_node_or_null("DebugLabels")
	if not container:
		return
	for child: Node in container.get_children():
		if child is Label3D:
			var lbl := child as Label3D
			assert_eq(
				lbl.billboard,
				BaseMaterial3D.BILLBOARD_ENABLED,
				"%s must use billboard mode so it faces camera" % lbl.name
			)


# ── Shelf slot interaction contract ──────────────────────────────────────────

func test_shelf_slots_present_and_in_group() -> void:
	var slots: Array[Node] = _root.get_tree().get_nodes_in_group("shelf_slot")
	assert_gt(slots.size(), 0, "Scene must have at least one node in 'shelf_slot' group")


func test_shelf_slots_have_collision_on_layer_2() -> void:
	var slots: Array[Node] = _root.get_tree().get_nodes_in_group("shelf_slot")
	for slot: Node in slots:
		# Interactable._ready() delegates collision to a child InteractionArea node on layer 2.
		# The parent Area3D's collision_layer is intentionally reset to 0 by Interactable._ready().
		var area: Area3D = slot.get_node_or_null("InteractionArea") as Area3D
		assert_not_null(area, "%s must have an InteractionArea child" % slot.name)
		if area:
			assert_eq(
				area.collision_layer, 2,
				"%s/InteractionArea.collision_layer must be 2 for InteractionRay" % slot.name
			)


func test_shelf_slots_have_interactable_script() -> void:
	var slots: Array[Node] = _root.get_tree().get_nodes_in_group("shelf_slot")
	assert_gt(slots.size(), 0, "Must have shelf slots to test")
	for slot: Node in slots:
		assert_not_null(slot.get_script(), "%s must have ShelfSlot script" % slot.name)
		assert_true(
			slot.has_method("place_item"),
			"%s must expose place_item method" % slot.name
		)


# ── Customer path markers ─────────────────────────────────────────────────────

func test_customer_spawn_marker_present() -> void:
	var spawn: Node = _root.get_node_or_null("CustomerSpawn")
	assert_not_null(spawn, "CustomerSpawn Marker3D must exist")
	if spawn:
		assert_true(spawn is Marker3D, "CustomerSpawn must be a Marker3D node")


func test_customer_exit_marker_present() -> void:
	var exit_node: Node = _root.get_node_or_null("CustomerExit")
	assert_not_null(exit_node, "CustomerExit Marker3D must exist")
	if exit_node:
		assert_true(exit_node is Marker3D, "CustomerExit must be a Marker3D node")


func test_customer_spawn_is_near_store_entrance() -> void:
	var spawn: Node = _root.get_node_or_null("CustomerSpawn")
	if not spawn or not spawn is Marker3D:
		return
	var pos: Vector3 = (spawn as Marker3D).global_position
	# Entrance is at z≈+2.5 in scene space; spawn should be beyond that
	assert_gt(pos.z, 2.0, "CustomerSpawn must be positioned near or outside the store entrance")


func test_customer_exit_is_farther_than_spawn() -> void:
	var spawn: Node = _root.get_node_or_null("CustomerSpawn")
	var exit_node: Node = _root.get_node_or_null("CustomerExit")
	if not spawn or not exit_node:
		return
	assert_gt(
		(exit_node as Marker3D).global_position.z,
		(spawn as Marker3D).global_position.z,
		"CustomerExit must be farther from store interior than CustomerSpawn"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _collect_by_class(node: Node, class_name_str: String, out: Array[Node]) -> void:
	if node.is_class(class_name_str):
		out.append(node)
	for child: Node in node.get_children():
		_collect_by_class(child, class_name_str, out)
