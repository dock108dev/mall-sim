## Verifies the retro_games entrance glass door:
##  * door visual mesh present, semi-transparent, sized to fill the gap
##  * StaticBody3D collision blocks the FP CharacterBody3D (layer
##    store_fixtures = bit 2, which the player's mask=3 includes)
##  * Interactable child carries STOREFRONT type, "Exit to Mall" prompt,
##    and lives outside the customer NavigationMesh bounds so customer
##    pathfinding is not affected
##  * Pressing E on the door (simulated by emitting `interacted`) lands
##    the GameManager FSM in MALL_OVERVIEW and releases the cursor
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const DOOR_NODE_PATH: String = "EntranceDoor"
const DOOR_MESH_PATH: String = "EntranceDoor/DoorMesh"
const DOOR_BODY_PATH: String = "EntranceDoor/StaticBody3D"
const DOOR_INTERACTABLE_PATH: String = "EntranceDoor/Interactable"

const ENTRANCE_GAP_HALF_WIDTH: float = 1.5
const NAV_BOUNDS_Z_MAX: float = 9.7
const PLAYER_FIXTURE_LAYER_BIT: int = 2

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


func test_entrance_door_node_exists_at_root() -> void:
	var door: Node3D = _root.get_node_or_null(DOOR_NODE_PATH) as Node3D
	assert_not_null(
		door,
		"EntranceDoor must be a direct child of the retro_games root"
	)


func test_entrance_door_visual_fills_entrance_gap() -> void:
	var mesh_inst: MeshInstance3D = (
		_root.get_node_or_null(DOOR_MESH_PATH) as MeshInstance3D
	)
	assert_not_null(mesh_inst, "EntranceDoor/DoorMesh must exist")
	if mesh_inst == null:
		return
	var mesh: BoxMesh = mesh_inst.mesh as BoxMesh
	assert_not_null(mesh, "EntranceDoor/DoorMesh must use a BoxMesh")
	if mesh == null:
		return
	# Width must span the 2.9 m gap (2.8 m gives 5 cm clearance per side).
	assert_almost_eq(
		mesh.size.x, 2.8, 0.05,
		"DoorMesh width must fill the 2.9 m entrance gap"
	)
	assert_gte(
		mesh.size.y, 3.0,
		"DoorMesh must span the wall height (>=3.0 m)"
	)
	var mat: StandardMaterial3D = (
		mesh_inst.get_surface_override_material(0) as StandardMaterial3D
	)
	assert_not_null(mat, "DoorMesh must declare a glass material")
	if mat == null:
		return
	assert_lt(
		mat.albedo_color.a, 1.0,
		"Door material must be semi-transparent (alpha < 1.0)"
	)
	assert_ne(
		mat.transparency,
		BaseMaterial3D.TRANSPARENCY_DISABLED,
		"Door material must enable transparency for the glass look"
	)


func test_entrance_door_blocks_player_with_fixture_layer() -> void:
	var body: StaticBody3D = (
		_root.get_node_or_null(DOOR_BODY_PATH) as StaticBody3D
	)
	assert_not_null(body, "EntranceDoor/StaticBody3D must exist")
	if body == null:
		return
	# Player CharacterBody3D mask=3 (world+fixtures); door on bit 2 blocks it.
	assert_eq(
		body.collision_layer & PLAYER_FIXTURE_LAYER_BIT,
		PLAYER_FIXTURE_LAYER_BIT,
		"Door collision_layer must include the store_fixtures bit (2)"
	)
	assert_eq(
		body.collision_mask, 0,
		"Door StaticBody3D collision_mask must equal 0 — static geometry"
	)
	var col: CollisionShape3D = (
		body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	)
	assert_not_null(col, "Door StaticBody3D must own a CollisionShape3D")


func test_entrance_door_outside_customer_nav_bounds() -> void:
	# CustomerNavMesh bounds Z∈[−9.7, +9.7]; door at Z=10.0 must sit
	# outside that footprint so customer NavigationAgent3D pathfinding
	# is not affected by the door collider.
	var door: Node3D = _root.get_node_or_null(DOOR_NODE_PATH) as Node3D
	assert_not_null(door)
	if door == null:
		return
	assert_gt(
		door.global_position.z, NAV_BOUNDS_Z_MAX,
		"EntranceDoor must sit beyond the customer NavMesh max Z"
	)
	assert_almost_eq(
		door.global_position.x, 0.0, ENTRANCE_GAP_HALF_WIDTH,
		"EntranceDoor must be centred horizontally in the entrance gap"
	)


func test_entrance_door_interactable_is_storefront_with_exit_prompt() -> void:
	var interactable: Interactable = (
		_root.get_node_or_null(DOOR_INTERACTABLE_PATH) as Interactable
	)
	assert_not_null(interactable, "EntranceDoor/Interactable must exist")
	if interactable == null:
		return
	assert_eq(
		interactable.interaction_type,
		Interactable.InteractionType.STOREFRONT,
		"Door Interactable must be typed STOREFRONT"
	)
	assert_true(
		interactable.enabled,
		"Door Interactable must ship enabled so pressing E works"
	)
	# The HUD prompt builder lowercases the verb portion; verify the source
	# strings carry the "Exit to Mall" wording the player will see.
	var combined: String = "%s %s" % [
		interactable.display_name, interactable.prompt_text,
	]
	assert_string_contains(
		combined, "Exit to Mall",
		"Door must surface 'Exit to Mall' in display_name or prompt_text"
	)
	# The runtime InteractionArea must land on the interactable_triggers bit
	# so the FP InteractionRay can resolve it via reticle hit.
	var area: Area3D = interactable.get_interaction_area()
	assert_not_null(area, "Door Interactable must expose an InteractionArea")
	if area == null:
		return
	assert_eq(
		area.collision_layer,
		Interactable.INTERACTABLE_LAYER,
		"Door InteractionArea must sit on the interactable_triggers bit"
	)


func test_pressing_e_on_door_routes_to_mall_overview() -> void:
	var interactable: Interactable = (
		_root.get_node_or_null(DOOR_INTERACTABLE_PATH) as Interactable
	)
	assert_not_null(interactable)
	if interactable == null:
		return
	# Park the FSM in GAMEPLAY so the change_state(MALL_OVERVIEW) transition
	# is allowed (see _VALID_TRANSITIONS in game_manager.gd).
	var prior_state: int = GameManager.current_state
	GameManager.current_state = GameManager.State.GAMEPLAY
	# Lock the cursor so the handler's unlock_cursor() call has an observable
	# effect under headless tests where InputHelper tracks `_requested_mouse_mode`.
	InputHelper.lock_cursor()
	# Simulate Press E on the door — `interaction_ray.gd` calls
	# `_hovered_target.interact()`, which emits `interacted`; the controller
	# listens for that signal in `_connect_entrance_door`.
	interactable.interact()
	assert_eq(
		int(GameManager.current_state),
		int(GameManager.State.MALL_OVERVIEW),
		"Pressing E on the door must transition GameManager to MALL_OVERVIEW"
	)
	assert_false(
		InputHelper.is_cursor_locked(),
		"Door interaction must release the cursor before the transition"
	)
	GameManager.current_state = prior_state
