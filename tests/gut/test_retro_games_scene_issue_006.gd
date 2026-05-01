## Verifies retro_games.tscn scene contract: embedded PlayerController orbit
## camera (Path B), debug zone labels, shelf interaction wiring, and customer
## path markers. The orbit PlayerController plus its StoreCamera and
## InteractionRay are authored directly in this scene; the hub-mode injector
## falls through to `_activate_store_camera` because no `PlayerEntrySpawn`
## marker is present.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
# Navigable footprint authored into this scene's embedded PlayerController.
# The 10×7 m room half-extents (5×3.5) tightened to leave a 0.5 m wall margin.
# StoreSelectorSystem._STORE_PIVOT_BOUNDS_* (legacy orbit path) still uses the
# tighter shared 7×5 footprint for the other store interiors.
const _STORE_BOUNDS_MIN: Vector3 = Vector3(-4.5, 0.0, -3.0)
const _STORE_BOUNDS_MAX: Vector3 = Vector3(4.5, 0.0, 3.0)

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


# ── Camera / movement (embedded orbit controller, Path B) ────────────────────

func test_scene_embeds_player_controller() -> void:
	# Path B: the orbit PlayerController is authored directly in this scene so
	# the hub-mode injector falls through to `_activate_store_camera` and
	# activates the embedded StoreCamera through CameraAuthority.
	var controller: Node = _root.get_node_or_null("PlayerController")
	assert_not_null(
		controller,
		"retro_games.tscn must embed a PlayerController node for the orbit camera"
	)


func test_scene_ships_exactly_one_camera_3d_under_player_controller() -> void:
	# Exactly one Camera3D must exist (the StoreCamera child of
	# PlayerController) so CameraAuthority's single-active guarantee holds.
	var cameras: Array[Node] = []
	_collect_by_class(_root, "Camera3D", cameras)
	assert_eq(
		cameras.size(), 1,
		"Scene must ship exactly one Camera3D (the embedded StoreCamera)"
	)
	if cameras.size() != 1:
		return
	var cam := cameras[0] as Camera3D
	assert_eq(
		cam.name, &"StoreCamera",
		"The embedded camera must be named StoreCamera so PlayerController._resolve_camera binds it"
	)
	assert_true(
		cam.is_in_group(&"cameras"),
		"StoreCamera must be in the 'cameras' group for CameraAuthority lookups"
	)
	assert_false(
		cam.current,
		"StoreCamera must ship with current=false — CameraAuthority owns activation"
	)


func test_scene_has_no_player_entry_spawn() -> void:
	# Path B contract: removing PlayerEntrySpawn causes the hub injector
	# (game_world.gd._spawn_player_in_store) to fall through to
	# _activate_store_camera, which finds the embedded StoreCamera.
	assert_null(
		_root.get_node_or_null("PlayerEntrySpawn"),
		"retro_games.tscn must not author a PlayerEntrySpawn — Path B uses the embedded orbit camera"
	)


func test_player_controller_pivot_bounds_match_room_footprint() -> void:
	# The 10×7 room half-extents are 5.0 × 3.5; the bounds tighten that to
	# 4.5 × 3.0 so the pivot cannot exit through the front-entrance gap or
	# brush against the side walls.
	var controller: Node = _root.get_node_or_null("PlayerController")
	assert_not_null(controller, "PlayerController must be embedded for bounds check")
	if controller == null:
		return
	var min_bound: Vector3 = controller.get("store_bounds_min")
	var max_bound: Vector3 = controller.get("store_bounds_max")
	assert_eq(
		min_bound, Vector3(-4.5, 0.0, -3.0),
		"store_bounds_min must match the 10×7 room footprint with 0.5 m wall margin"
	)
	assert_eq(
		max_bound, Vector3(4.5, 0.0, 3.0),
		"store_bounds_max must clamp the pivot inside the front entrance gap (z<=3.0)"
	)


func test_interaction_ray_attached_to_store_camera() -> void:
	# InteractionRay must live under StoreCamera so its raycast samples the
	# active camera's transform every frame.
	var ray: Node = _root.get_node_or_null(
		"PlayerController/StoreCamera/InteractionRay"
	)
	assert_not_null(
		ray,
		"InteractionRay must be a child of PlayerController/StoreCamera"
	)
	if ray == null:
		return
	var script: Script = ray.get_script()
	assert_not_null(script, "InteractionRay must have a script attached")
	if script != null:
		assert_eq(
			script.resource_path,
			"res://game/scripts/player/interaction_ray.gd",
			"InteractionRay must use interaction_ray.gd"
		)


# ── Debug zone labels (removed — replaced by InteractionPrompt) ──────────────

func test_no_billboard_debug_labels_in_scene() -> void:
	# The DebugLabels Node3D + 5 billboard Label3D children were removed in
	# favor of the contextual InteractionPrompt CanvasLayer; verify they did
	# not regress back into the scene.
	assert_null(
		_root.get_node_or_null("DebugLabels"),
		"DebugLabels Node3D must not exist — giant floating world labels are removed"
	)
	var removed_texts: Array[String] = [
		"SHELF", "REGISTER", "CUSTOMER ENTRY", "BACKROOM", "DISPLAY TABLE"
	]
	var labels: Array[Node] = []
	_collect_by_class(_root, "Label3D", labels)
	for node: Node in labels:
		var lbl := node as Label3D
		# Allow storefront sign labels through; they are not the giant
		# yellow zone callouts the issue removed.
		var path: NodePath = _root.get_path_to(lbl)
		if String(path).begins_with("Storefront/"):
			continue
		for banned: String in removed_texts:
			assert_false(
				lbl.text.contains(banned),
				"Label3D '%s' must not contain banned debug text '%s'"
				% [lbl.name, banned]
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


# ── Ceiling visibility and camera defaults ───────────────────────────────────

func test_ceiling_visible_false() -> void:
	var ceiling: Node = _root.get_node_or_null("Ceiling")
	assert_not_null(ceiling, "Ceiling node must exist in scene")
	if ceiling:
		assert_false(
			(ceiling as VisualInstance3D).visible,
			"Ceiling.visible must be false so the orbit camera sees the interior"
		)


func test_camera_default_y_below_ceiling() -> void:
	# Camera framing now lives on the externally-instantiated PlayerController
	# (`game/scenes/player/player_controller.tscn`). Verify the script's
	# checked-in defaults still keep the camera below the ceiling bottom (3.0 m).
	var script: GDScript = load("res://game/scripts/player/player_controller.gd")
	var pc: Node = script.new()
	add_child_autofree(pc)
	var zoom: float = pc.get("zoom_default")
	var pitch_deg: float = pc.get("pitch_default_deg")
	var world_y: float = zoom * sin(deg_to_rad(pitch_deg))
	assert_lt(
		world_y,
		3.0,
		"Camera world Y at defaults must be below ceiling bottom (3.0 m); got %.3f" % world_y
	)


func test_camera_default_z_inside_front_wall() -> void:
	var script: GDScript = load("res://game/scripts/player/player_controller.gd")
	var pc: Node = script.new()
	add_child_autofree(pc)
	var zoom: float = pc.get("zoom_default")
	var pitch_deg: float = pc.get("pitch_default_deg")
	var world_z: float = zoom * cos(deg_to_rad(pitch_deg))
	assert_lt(
		world_z,
		2.55,
		"Camera world Z at defaults must be inside front wall (z < 2.55 m); got %.3f" % world_z
	)


# ── Nav zone structure (ISSUE-005) ───────────────────────────────────────────

func test_nav_zones_container_exists() -> void:
	assert_not_null(
		_root.get_node_or_null("NavZones"),
		"NavZones Node3D must be a direct child of the scene root"
	)


func test_five_nav_zone_nodes_exist() -> void:
	var zones: Array[Node] = _root.get_tree().get_nodes_in_group("nav_zone")
	assert_eq(zones.size(), 5, "Exactly five nav zone nodes must exist in the scene")


func test_nav_zones_have_unique_indices_one_to_five() -> void:
	var zones: Array[Node] = _root.get_tree().get_nodes_in_group("nav_zone")
	var indices: Array[int] = []
	for zone: Node in zones:
		var idx: int = int(zone.get("zone_index"))
		indices.append(idx)
	indices.sort()
	assert_eq(indices, [1, 2, 3, 4, 5], "Nav zones must have zone_index values 1 through 5")


func test_nav_zones_have_nav_zone_interactable_script() -> void:
	var zones: Array[Node] = _root.get_tree().get_nodes_in_group("nav_zone")
	for zone: Node in zones:
		assert_true(
			zone.has_method("interact"),
			"%s must have interact() from NavZoneInteractable" % zone.name
		)
		assert_true(
			zone.get("zone_index") != null,
			"%s must expose zone_index property" % zone.name
		)


func test_nav_zones_have_interaction_area_on_layer_2() -> void:
	var zones: Array[Node] = _root.get_tree().get_nodes_in_group("nav_zone")
	assert_gt(zones.size(), 0, "Must have nav zones to test")
	for zone: Node in zones:
		var area: Area3D = zone.get_node_or_null("InteractionArea") as Area3D
		assert_not_null(area, "%s must have an InteractionArea child" % zone.name)
		if area:
			assert_eq(
				area.collision_layer, 2,
				"%s/InteractionArea.collision_layer must be 2 for raycast" % zone.name
			)


func test_nav_zone_positions_within_store_bounds() -> void:
	var zones: Array[Node] = _root.get_tree().get_nodes_in_group("nav_zone")
	for zone: Node in zones:
		var pos: Vector3 = (zone as Node3D).global_position
		assert_gte(pos.x, _STORE_BOUNDS_MIN.x - 0.01,
			"%s.x must be within store bounds min" % zone.name)
		assert_lte(pos.x, _STORE_BOUNDS_MAX.x + 0.01,
			"%s.x must be within store bounds max" % zone.name)
		assert_gte(pos.z, _STORE_BOUNDS_MIN.z - 0.01,
			"%s.z must be within store bounds min" % zone.name)
		assert_lte(pos.z, _STORE_BOUNDS_MAX.z + 0.01,
			"%s.z must be within store bounds max" % zone.name)


# ── Navigation mesh boundary ─────────────────────────────────────────────────

func test_nav_mesh_front_z_covers_entry_area() -> void:
	var nav_region: NavigationRegion3D = _root.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	assert_not_null(nav_region, "NavigationRegion3D must exist in scene")
	if not nav_region:
		return
	var mesh: NavigationMesh = nav_region.navigation_mesh
	assert_not_null(mesh, "NavigationRegion3D must have a navigation_mesh")
	if not mesh:
		return
	var verts: PackedVector3Array = mesh.vertices
	assert_gt(verts.size(), 0, "Nav mesh must have vertices")
	var max_z: float = -INF
	for v: Vector3 in verts:
		if v.z > max_z:
			max_z = v.z
	# EntryArea is at Z=2.55; front boundary must provide at least 0.15 m margin
	assert_gte(
		max_z,
		2.50,
		"Nav mesh front Z boundary must be >= 2.50 to cover entry area at Z=2.55; got %.3f" % max_z
	)


# ── Storefront sign geometry ──────────────────────────────────────────────────

func test_sign_name_text_is_correct() -> void:
	var lbl: Label3D = _root.get_node_or_null("Storefront/SignName") as Label3D
	assert_not_null(lbl, "Storefront/SignName must exist")
	if lbl:
		assert_eq(lbl.text, "Retro Games", "SignName.text must be 'Retro Games'")


func test_sign_tagline_text_is_correct() -> void:
	var lbl: Label3D = _root.get_node_or_null("Storefront/SignTagline") as Label3D
	assert_not_null(lbl, "Storefront/SignTagline must exist")
	if lbl:
		assert_eq(lbl.text, "Consoles & Classics", "SignTagline.text must be 'Consoles & Classics'")


func test_sign_labels_have_adequate_vertical_separation() -> void:
	var sign_name: Label3D = _root.get_node_or_null("Storefront/SignName") as Label3D
	var sign_tagline: Label3D = _root.get_node_or_null("Storefront/SignTagline") as Label3D
	assert_not_null(sign_name, "Storefront/SignName must exist")
	assert_not_null(sign_tagline, "Storefront/SignTagline must exist")
	if not sign_name or not sign_tagline:
		return
	var gap: float = sign_name.global_position.y - sign_tagline.global_position.y
	assert_gte(
		gap,
		0.50,
		"SignName-to-SignTagline center gap must be >= 0.50 wu to prevent text overlap; got %.3f" % gap
	)


func test_sign_labels_have_z_clearance_above_backing() -> void:
	var sign_name: Label3D = _root.get_node_or_null("Storefront/SignName") as Label3D
	var sign_tagline: Label3D = _root.get_node_or_null("Storefront/SignTagline") as Label3D
	assert_not_null(sign_name, "Storefront/SignName must exist")
	assert_not_null(sign_tagline, "Storefront/SignTagline must exist")
	# SignBacking front face is at Z=2.625; labels must clear by at least 30 mm to avoid z-fighting.
	if sign_name:
		assert_gt(
			sign_name.global_position.z,
			2.65,
			"SignName Z must exceed 2.65 for z-fight-free clearance from SignBacking; got %.4f" % sign_name.global_position.z
		)
	if sign_tagline:
		assert_gt(
			sign_tagline.global_position.z,
			2.65,
			"SignTagline Z must exceed 2.65 for z-fight-free clearance from SignBacking; got %.4f" % sign_tagline.global_position.z
		)


func test_sign_labels_face_exterior_via_y_rotation() -> void:
	# The 180° Y rotation matrix is: basis.x = (-1,0,0), basis.y = (0,1,0), basis.z = (0,0,-1).
	var sign_name: Label3D = _root.get_node_or_null("Storefront/SignName") as Label3D
	var sign_tagline: Label3D = _root.get_node_or_null("Storefront/SignTagline") as Label3D
	for lbl: Label3D in [sign_name, sign_tagline]:
		if not lbl:
			continue
		assert_lt(
			lbl.transform.basis.x.x,
			0.0,
			"%s must have a 180-degree Y rotation (basis.x.x < 0)" % lbl.name
		)
		assert_lt(
			lbl.transform.basis.z.z,
			0.0,
			"%s must have a 180-degree Y rotation (basis.z.z < 0)" % lbl.name
		)


func test_storefront_hidden_during_interior_gameplay() -> void:
	# Storefront entrance geometry sits on the camera side at z>=2.55 and
	# fully obstructs the interior view from the orbit camera's default
	# outside-front position (0, 2.68, 4.55). The hallway camera uses its
	# own storefront.tscn, so this in-scene Storefront only matters from
	# inside the store — where it must stay hidden.
	var storefront: Node3D = _root.get_node_or_null("Storefront") as Node3D
	assert_not_null(storefront, "Storefront node must exist for visibility check")
	if storefront == null:
		return
	assert_false(
		storefront.visible,
		"Storefront must ship visible=false so entrance geometry "
		+ "(SilhouetteHeaderPanel, SignBacking, frame meshes) does not "
		+ "block the interior view"
	)
	for child_name: String in [
		"SilhouetteHeaderPanel",
		"SilhouetteLeftPanel",
		"SilhouetteRightPanel",
		"FrameLeft",
		"FrameRight",
		"FrameHeader",
		"SignBacking",
	]:
		var child: Node3D = storefront.get_node_or_null(child_name) as Node3D
		assert_not_null(child, "%s must exist under Storefront" % child_name)
		if child == null:
			continue
		assert_false(
			child.is_visible_in_tree(),
			"%s must not render during interior gameplay" % child_name
		)


# ── StoreReadyContract interface methods on retro_games root ─────────────────

func test_root_exposes_controller_initialized_after_ready() -> void:
	assert_true(
		_root.has_method("is_controller_initialized"),
		"retro_games root must expose StoreReadyContract method "
		+ "is_controller_initialized()"
	)
	assert_true(
		_root.is_controller_initialized(),
		"retro_games initialize() runs in _ready() so the root must report "
		+ "is_controller_initialized()=true once added to the tree"
	)


func test_root_exposes_get_input_context() -> void:
	assert_true(
		_root.has_method("get_input_context"),
		"retro_games root must expose StoreReadyContract method get_input_context()"
	)


func test_root_exposes_has_blocking_modal() -> void:
	assert_true(
		_root.has_method("has_blocking_modal"),
		"retro_games root must expose StoreReadyContract method has_blocking_modal()"
	)


func test_objective_matches_action_passes_for_day_one_text() -> void:
	# Day 1 objective from res://game/content/objectives.json. Verifies that at
	# least one registered Interactable in the live retro_games scene satisfies
	# StoreReadyContract invariant 10 against the canonical day-one text.
	_root.set_objective_text("Stock your first item and make a sale")
	assert_true(
		_root.objective_matches_action(),
		"Day 1 objective text must match at least one registered interactable; "
		+ "shelf slots ship with action_verb='Stock' and at least one slot "
		+ "carries an 'Item' display token"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _collect_by_class(node: Node, class_name_str: String, out: Array[Node]) -> void:
	if node.is_class(class_name_str):
		out.append(node)
	for child: Node in node.get_children():
		_collect_by_class(child, class_name_str, out)
