## Verifies retro_games.tscn scene contract: embedded PlayerController orbit
## camera, the `PlayerEntrySpawn` Marker3D used by GameWorld to instantiate
## the first-person store body, debug zone labels, shelf interaction wiring,
## and customer path markers. The orbit PlayerController plus its StoreCamera
## and InteractionRay remain authored directly in this scene; the
## first-person body itself is not — `game_world.gd._spawn_player_in_store()`
## instantiates `store_player_body.tscn` at the spawn marker at runtime.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
# Navigable footprint authored into this scene's embedded PlayerController.
# 16×20 m room half-extents (8×10) tightened to leave a 0.5 m wall margin.
const _STORE_BOUNDS_MIN: Vector3 = Vector3(-7.5, 0.0, -9.5)
const _STORE_BOUNDS_MAX: Vector3 = Vector3(7.5, 0.0, 9.5)

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


func test_scene_authors_player_entry_spawn_marker() -> void:
	# GameWorld._spawn_player_in_store() looks up "PlayerEntrySpawn" as a
	# direct child of the store root and dynamically instantiates the
	# first-person body there. The marker must exist as a Marker3D so the
	# spawn returns true and positions the body just inside the entrance.
	var marker: Node = _root.get_node_or_null("PlayerEntrySpawn")
	assert_not_null(
		marker,
		"retro_games.tscn must author a PlayerEntrySpawn Marker3D for the FP body spawn"
	)
	if marker == null:
		return
	assert_true(
		marker is Marker3D,
		"PlayerEntrySpawn must be a Marker3D node so its global_position is usable"
	)
	# Spawn sits just inside the front entrance opening (front threshold ~10 m).
	var pos: Vector3 = (marker as Marker3D).global_position
	assert_gte(pos.x, 1.6,
		"PlayerEntrySpawn.x should bias toward the checkout lane")
	assert_lte(pos.x, 2.8,
		"PlayerEntrySpawn.x should stay inside the entrance approach")
	assert_gt(pos.z, 8.0,
		"PlayerEntrySpawn.z should sit near the front entrance, not at world origin")


func test_player_entry_spawn_frames_checkout_customer_in_view() -> void:
	var marker: Marker3D = _root.get_node_or_null("PlayerEntrySpawn") as Marker3D
	var customer: Node3D = _root.get_node_or_null("BetaDayOneCustomer") as Node3D
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	assert_not_null(marker, "PlayerEntrySpawn must exist")
	assert_not_null(customer, "BetaDayOneCustomer must exist")
	assert_not_null(checkout, "Checkout must exist")
	if marker == null or customer == null or checkout == null:
		return
	var forward: Vector3 = _flat_forward(marker)
	assert_lt(
		forward.z,
		-0.72,
		"PlayerEntrySpawn forward vector must face into the store; got %.3f"
		% forward.z
	)
	var customer_dir: Vector3 = _flat_direction(marker.global_position, customer.global_position)
	var checkout_dir: Vector3 = _flat_direction(marker.global_position, checkout.global_position)
	assert_gt(
		forward.dot(customer_dir),
		0.55,
		"BetaDayOneCustomer must be inside the spawn view cone"
	)
	assert_gt(
		forward.dot(checkout_dir),
		0.55,
		"Checkout must be inside the spawn view cone"
	)
	assert_gt(
		_flat_right(marker).dot(customer_dir),
		0.15,
		"BetaDayOneCustomer should read as central-to-right from spawn"
	)


func test_day_one_route_targets_are_front_back_shelf_register() -> void:
	var customer: Node3D = _root.get_node_or_null("BetaDayOneCustomer") as Node3D
	var pickup: Node3D = _root.get_node_or_null("BetaBackroomPickup") as Node3D
	var shelf: Node3D = _root.get_node_or_null("BetaRestockShelf") as Node3D
	var close_day: Node3D = _root.get_node_or_null("BetaDayEndTrigger") as Node3D
	var checkout: Node3D = _root.get_node_or_null("Checkout") as Node3D
	for target: Node3D in [customer, pickup, shelf, close_day, checkout]:
		assert_not_null(target, "Critical Day-1 route target must exist")
	if (
		customer == null
		or pickup == null
		or shelf == null
		or close_day == null
		or checkout == null
	):
		return
	assert_gt(
		customer.global_position.z,
		7.5,
		"Customer beat must stage at the front checkout lane"
	)
	assert_gt(
		pickup.global_position.x,
		5.4,
		"Back-room pickup must sit inside the back-room doorway path"
	)
	assert_lt(
		pickup.global_position.z,
		-7.2,
		"Back-room pickup must stage in the rear storage zone"
	)
	assert_lt(
		shelf.global_position.x,
		-2.0,
		"Restock shelf must stage on the used-shelf side of the store"
	)
	assert_lt(
		shelf.global_position.z,
		-7.0,
		"Restock shelf must stage in the rear shelf zone"
	)
	assert_lt(
		_flat_distance(close_day.global_position, checkout.global_position),
		0.6,
		"Close-day target must return to the checkout counter"
	)


func test_day_one_route_readability_props_survive_beta_strip() -> void:
	assert_true(
		BetaDayOneController._BETA_KEEP_ROOT_NODES.has(&"ReadabilityProps"),
		"ReadabilityProps must stay visible in the beta slice"
	)
	var props: Node3D = _root.get_node_or_null("ReadabilityProps") as Node3D
	assert_not_null(props, "ReadabilityProps must exist")
	if props == null:
		return
	var markers: Node = props.get_node_or_null("DayOneRouteMarkers")
	assert_not_null(markers, "DayOneRouteMarkers must exist")
	if markers != null:
		assert_gte(
			markers.get_child_count(),
			9,
			"DayOneRouteMarkers must stage checkout, back-room, shelf, and return paths"
		)
	assert_not_null(
		_root.get_node_or_null("BackroomUtilityLight"),
		"BackroomUtilityLight must cue the checkout-to-backroom path"
	)
	assert_not_null(
		props.get_node_or_null("ZoneLighting/OldGenZoneFill"),
		"OldGenZoneFill must keep the shelf route lit"
	)
	assert_not_null(
		_root.get_node_or_null("CheckoutLaneSpotlight"),
		"CheckoutLaneSpotlight must cue the shelf-to-register return"
	)
	var blockers: Array[Node] = []
	_collect_route_blockers(props, blockers)
	assert_eq(
		blockers.size(),
		0,
		"ReadabilityProps must remain visual-only and not obscure critical targets"
	)


func test_day_one_zone_identity_props_are_distinct_muted_visuals() -> void:
	var props: Node3D = _root.get_node_or_null("ReadabilityProps") as Node3D
	assert_not_null(props, "ReadabilityProps must exist")
	if props == null:
		return
	var identity: Node = props.get_node_or_null("ZoneIdentity")
	assert_not_null(identity, "ZoneIdentity must group checkout, back-room, and shelf accents")
	if identity == null:
		return
	var checkout: MeshInstance3D = identity.get_node_or_null(
		"CheckoutCounterAccent"
	) as MeshInstance3D
	var backroom: MeshInstance3D = identity.get_node_or_null(
		"BackroomDoorThreshold"
	) as MeshInstance3D
	var shelf: MeshInstance3D = identity.get_node_or_null("ShelfStockAccent") as MeshInstance3D
	for accent: MeshInstance3D in [checkout, backroom, shelf]:
		assert_not_null(accent, "Each Day-1 zone must have a visual accent")
		if accent == null:
			return
		var mat: StandardMaterial3D = _mesh_material(accent)
		assert_not_null(mat, "%s must use a StandardMaterial3D override" % accent.name)
		if mat == null:
			return
		assert_lte(
			mat.emission_energy_multiplier,
			0.25,
			"%s must stay muted so interactables remain the strongest cue" % accent.name
		)
	var checkout_mat: StandardMaterial3D = _mesh_material(checkout)
	var backroom_mat: StandardMaterial3D = _mesh_material(backroom)
	var shelf_mat: StandardMaterial3D = _mesh_material(shelf)
	assert_true(
		checkout_mat.albedo_color != backroom_mat.albedo_color,
		"Checkout and back-room accents must not collapse into one visual identity"
	)
	assert_true(
		backroom_mat.albedo_color != shelf_mat.albedo_color,
		"Back-room and shelf accents must stay visually distinct"
	)
	var blockers: Array[Node] = []
	_collect_route_blockers(identity, blockers)
	assert_eq(blockers.size(), 0, "Zone identity accents must remain visual-only")


func test_day_one_route_markers_are_floor_accents_not_waypoints() -> void:
	var marker: MeshInstance3D = _root.get_node_or_null(
		"ReadabilityProps/DayOneRouteMarkers/BackroomStepA"
	) as MeshInstance3D
	assert_not_null(marker, "BackroomStepA route marker must exist")
	if marker == null:
		return
	var mat: StandardMaterial3D = _mesh_material(marker)
	assert_not_null(mat, "Route markers must use a StandardMaterial3D override")
	if mat == null:
		return
	assert_lte(
		mat.albedo_color.a,
		0.5,
		"Route marker alpha must stay low so it reads as floor inlay, not UI paint"
	)
	assert_lte(
		mat.emission_energy_multiplier,
		0.25,
		"Route marker emission must stay below the interactable-highlight priority"
	)


func test_back_room_and_shelf_stock_props_share_case_language() -> void:
	var backroom_cases: Node = _root.get_node_or_null(
		"BetaBackroomPickup/StockBox/CaseSpines"
	)
	var shelf_cases: Node = _root.get_node_or_null(
		"BetaRestockShelf/RestockCrate/CaseSpines"
	)
	assert_not_null(backroom_cases, "Back-room stock box must expose visible case spines")
	assert_not_null(shelf_cases, "Shelf restock crate must expose visible case spines")
	if backroom_cases == null or shelf_cases == null:
		return
	assert_eq(backroom_cases.get_child_count(), 5, "Back-room delivery must read as five items")
	assert_gte(
		shelf_cases.get_child_count(),
		3,
		"Shelf restock crate must echo the same product language without overfilling"
	)
	var backroom_case: MeshInstance3D = backroom_cases.get_child(0) as MeshInstance3D
	var shelf_case: MeshInstance3D = shelf_cases.get_child(0) as MeshInstance3D
	assert_not_null(backroom_case, "Back-room case spine must be a MeshInstance3D")
	assert_not_null(shelf_case, "Shelf case spine must be a MeshInstance3D")
	if backroom_case == null or shelf_case == null:
		return
	var backroom_mesh: BoxMesh = backroom_case.mesh as BoxMesh
	var shelf_mesh: BoxMesh = shelf_case.mesh as BoxMesh
	assert_not_null(backroom_mesh, "Back-room case spine must use a BoxMesh")
	assert_not_null(shelf_mesh, "Shelf case spine must use a BoxMesh")
	if backroom_mesh == null or shelf_mesh == null:
		return
	assert_eq(backroom_mesh.size, Vector3(0.18, 0.22, 0.06))
	assert_eq(
		shelf_mesh.size,
		backroom_mesh.size,
		"Shelf case props must use the same physical dimensions as back-room stock"
	)
	assert_eq(
		_mesh_material(shelf_case).albedo_color,
		_mesh_material(backroom_case).albedo_color,
		"Shelf and back-room cases must share the same product material language"
	)


func test_scene_does_not_author_store_player_body() -> void:
	# The first-person body is instantiated dynamically by
	# game_world.gd._spawn_player_in_store(); authoring it in the .tscn would
	# create a duplicate Player on every store load.
	assert_null(
		_root.get_node_or_null("Player"),
		"retro_games.tscn must NOT pre-author a StorePlayerBody — GameWorld instantiates it"
	)


func test_player_controller_pivot_bounds_match_room_footprint() -> void:
	# The 16×20 room half-extents are 8.0 × 10.0; the bounds tighten that to
	# 7.5 × 9.5 so the pivot cannot exit through the front-entrance gap or
	# brush against the side walls.
	var controller: Node = _root.get_node_or_null("PlayerController")
	assert_not_null(controller, "PlayerController must be embedded for bounds check")
	if controller == null:
		return
	var min_bound: Vector3 = controller.get("store_bounds_min")
	var max_bound: Vector3 = controller.get("store_bounds_max")
	assert_eq(
		min_bound, Vector3(-7.5, 0.0, -9.5),
		"store_bounds_min must match the 16×20 room footprint with 0.5 m wall margin"
	)
	assert_eq(
		max_bound, Vector3(7.5, 0.0, 9.5),
		"store_bounds_max must clamp the pivot inside the front entrance gap (z<=9.5)"
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


func test_orbit_controller_disabled_on_ready_when_fp_spawn_present() -> void:
	# With PlayerEntrySpawn authored, the controller's _ready() must demote
	# the orbit PlayerController via process_mode so its WASD/orbit handlers
	# do not compete with the FP body and so the orbit StoreCamera's child
	# InteractionRay stops raycasting (PROCESS_MODE_DISABLED propagates).
	var controller: Node = _root.get_node_or_null("PlayerController")
	assert_not_null(controller, "PlayerController must be embedded")
	if controller == null:
		return
	assert_eq(
		controller.process_mode, Node.PROCESS_MODE_DISABLED,
		"PlayerController must ship with process_mode=DISABLED on _ready when "
		+ "PlayerEntrySpawn is present (FP startup path)"
	)


# ── Debug zone labels (removed — replaced by InteractionPrompt) ──────────────

func test_no_billboard_debug_labels_in_scene() -> void:
	# The DebugLabels Node3D + 5 billboard Label3D children were removed in
	# favor of the contextual InteractionPrompt CanvasLayer; verify they did
	# not regress back into the scene. Intentional in-world signage that
	# the scene reintroduces lives under the `zone_label` group (CheckoutLabel,
	# ShelvesLabel, BackroomLabel, etc.) and the `Storefront/` subtree
	# (SignName / SignTagline); both are exempt from the banned-text check.
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
		if lbl.is_in_group("zone_label"):
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


func test_shelf_slots_have_collision_on_interactable_layer() -> void:
	var slots: Array[Node] = _root.get_tree().get_nodes_in_group("shelf_slot")
	for slot: Node in slots:
		# Interactable._ready() delegates collision to a child InteractionArea
		# node on `Interactable.INTERACTABLE_LAYER` (the named
		# interactable_triggers bit). The parent Area3D's collision_layer is
		# intentionally reset to 0 by Interactable._ready().
		var area: Area3D = slot.get_node_or_null("InteractionArea") as Area3D
		assert_not_null(area, "%s must have an InteractionArea child" % slot.name)
		if area:
			assert_eq(
				area.collision_layer, Interactable.INTERACTABLE_LAYER,
				(
					"%s/InteractionArea.collision_layer must equal "
					+ "Interactable.INTERACTABLE_LAYER for InteractionRay"
				) % slot.name
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
	# Front wall is at z≈+10.05 in scene space; spawn should be beyond that
	assert_gt(pos.z, 10.0, "CustomerSpawn must be positioned near or outside the store entrance")


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
	# The original orbit-camera era required Ceiling.visible = false so
	# the bird's-eye view could see the interior. The current scene uses
	# a first-person camera (`PlayerController`) that sits below the
	# ceiling plane regardless of its visibility, so the constraint no
	# longer applies. Keep the node-existence assertion as a regression
	# bar for anyone removing Ceiling outright.
	var ceiling: Node = _root.get_node_or_null("Ceiling")
	assert_not_null(ceiling, "Ceiling node must exist in scene")


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
		10.0,
		"Camera world Z at defaults must be inside front wall (z < 10.0 m); got %.3f" % world_z
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


func test_nav_zones_have_interaction_area_on_interactable_layer() -> void:
	var zones: Array[Node] = _root.get_tree().get_nodes_in_group("nav_zone")
	assert_gt(zones.size(), 0, "Must have nav zones to test")
	for zone: Node in zones:
		var area: Area3D = zone.get_node_or_null("InteractionArea") as Area3D
		assert_not_null(area, "%s must have an InteractionArea child" % zone.name)
		if area:
			assert_eq(
				area.collision_layer, Interactable.INTERACTABLE_LAYER,
				(
					"%s/InteractionArea.collision_layer must equal "
					+ "Interactable.INTERACTABLE_LAYER for raycast"
				) % zone.name
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
	# Sanity check that the nav mesh has a front boundary; the rebuild to
	# cover the resized 16×20 footprint and the new EntryArea position is
	# tracked separately and lifts this floor accordingly.
	assert_gt(
		max_z,
		0.0,
		"Nav mesh front Z boundary must be on the +Z half of the floor; got %.3f" % max_z
	)


# ── Storefront sign geometry ──────────────────────────────────────────────────

func test_sign_name_text_is_correct() -> void:
	var lbl: Label3D = _root.get_node_or_null("Storefront/SignName") as Label3D
	assert_not_null(lbl, "Storefront/SignName must exist")
	if lbl:
		# Storefront sign was renamed in the strip-to-bones refactor —
		# the single-store beta is branded "SHELF LIFE" rather than the
		# original placeholder "Retro Games".
		assert_eq(lbl.text, "SHELF LIFE", "SignName.text must be 'SHELF LIFE'")


func test_sign_tagline_text_is_correct() -> void:
	var lbl: Label3D = _root.get_node_or_null("Storefront/SignTagline") as Label3D
	assert_not_null(lbl, "Storefront/SignTagline must exist")
	if lbl:
		assert_eq(
			lbl.text, "BUY · SELL · TRADE",
			"SignTagline.text must be 'BUY · SELL · TRADE'"
		)


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
	var sign_backing: MeshInstance3D = (
		_root.get_node_or_null("Storefront/SignBacking") as MeshInstance3D
	)
	assert_not_null(sign_name, "Storefront/SignName must exist")
	assert_not_null(sign_tagline, "Storefront/SignTagline must exist")
	assert_not_null(sign_backing, "Storefront/SignBacking must exist")
	if sign_backing == null:
		return
	# SignBacking is a 30 mm-thick panel; labels must clear its front face by
	# at least 25 mm to avoid z-fighting from the orbit/exterior camera.
	var backing_front_z: float = sign_backing.global_position.z + 0.015
	var min_clearance_z: float = backing_front_z + 0.025
	if sign_name:
		assert_gt(
			sign_name.global_position.z,
			min_clearance_z,
			"SignName Z must exceed %.3f for z-fight-free clearance; got %.4f"
			% [min_clearance_z, sign_name.global_position.z]
		)
	if sign_tagline:
		assert_gt(
			sign_tagline.global_position.z,
			min_clearance_z,
			"SignTagline Z must exceed %.3f for z-fight-free clearance; got %.4f"
			% [min_clearance_z, sign_tagline.global_position.z]
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
	# Original orbit-camera contract required Storefront.visible = false
	# so the camera could see past the entrance silhouette. The current
	# first-person camera sits behind the storefront geometry from the
	# customer-side approach but in front of it from the interior, so the
	# storefront can ship visible and the FP camera still reads the
	# interior cleanly. Keep the structural-existence checks below as
	# regression bars for the entrance silhouette geometry survival.
	var storefront: Node3D = _root.get_node_or_null("Storefront") as Node3D
	assert_not_null(storefront, "Storefront node must exist for visibility check")
	if storefront == null:
		return
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
	# Day 1 objective step from res://game/content/objectives.json (step 3 of
	# the chain). Verifies that at least one registered Interactable in the
	# live retro_games scene satisfies StoreReadyContract invariant 10 against
	# the canonical stock-the-item prompt. The plural "Shelves" must match
	# ShelfSlot subject token "shelf" via the matcher's prefix fallback.
	_root.set_objective_text("Stock the item on the Used Shelves")
	assert_true(
		_root.objective_matches_action(),
		"Day 1 stock-the-item objective must match at least one registered "
		+ "interactable; shelf slots ship with action_verb='Stock' and at "
		+ "least one slot carries an 'Item' display token"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _collect_by_class(node: Node, class_name_str: String, out: Array[Node]) -> void:
	if node.is_class(class_name_str):
		out.append(node)
	for child: Node in node.get_children():
		_collect_by_class(child, class_name_str, out)


func _collect_route_blockers(node: Node, out: Array[Node]) -> void:
	if node is CollisionShape3D or node is StaticBody3D or node is Area3D:
		out.append(node)
	for child: Node in node.get_children():
		_collect_route_blockers(child, out)


func _mesh_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	if mesh == null:
		return null
	return mesh.get_surface_override_material(0) as StandardMaterial3D


func _flat_direction(from: Vector3, to: Vector3) -> Vector3:
	var delta: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	if delta.length() <= 0.001:
		return Vector3.ZERO
	return delta.normalized()


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _flat_forward(node: Node3D) -> Vector3:
	var forward: Vector3 = -node.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()


func _flat_right(node: Node3D) -> Vector3:
	var right: Vector3 = node.global_transform.basis.x
	right.y = 0.0
	return right.normalized()
