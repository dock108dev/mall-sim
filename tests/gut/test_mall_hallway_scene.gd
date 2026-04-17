## Tests mall hallway scene structure and ISSUE-138 acceptance criteria.
extends GutTest


const EXPECTED_SLOT_COUNT: int = 5
const EXPECTED_SPACING: float = 8.0

var _lease_results: Array[Dictionary] = []
var _saved_owned_stores: Array[StringName] = []


func before_each() -> void:
	_lease_results.clear()
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	GameManager.owned_stores = []
	if not EventBus.lease_completed.is_connected(_on_lease_completed):
		EventBus.lease_completed.connect(_on_lease_completed)


func after_each() -> void:
	if EventBus.lease_completed.is_connected(_on_lease_completed):
		EventBus.lease_completed.disconnect(_on_lease_completed)
	GameManager.owned_stores = _saved_owned_stores
	ContentRegistry.clear_for_testing()


func test_scene_has_storefront_slots_container() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	assert_not_null(scene, "Mall hallway scene should load")
	var state: SceneState = scene.get_state()
	var found: Array = [false]
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"StorefrontSlots":
			found[0] = true
			break
	assert_true(found[0], "Scene should have StorefrontSlots node")


func test_scene_has_five_storefront_slots() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var slot_count: Array = [0]
	for i: int in range(state.get_node_count()):
		var name: StringName = state.get_node_name(i)
		if name.begins_with("Slot_"):
			slot_count[0] += 1
	assert_eq(
		slot_count[0], EXPECTED_SLOT_COUNT,
		"Scene should have exactly 5 storefront slots"
	)


func test_scene_has_player_spawn() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var found: Array = [false]
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"PlayerSpawn":
			found[0] = true
			break
	assert_true(found[0], "Scene should have PlayerSpawn Marker3D")


func test_scene_has_navigation_region() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var found: Array = [false]
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"NavigationRegion3D":
			found[0] = true
			break
	assert_true(
		found[0], "Scene should have NavigationRegion3D"
	)


func test_scene_has_waypoint_graph() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var found: Array = [false]
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == &"WaypointGraph":
			found[0] = true
			break
	assert_true(found[0], "Scene should have WaypointGraph node")


func test_scene_has_lighting_nodes() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var found_key: Array = [false]
	var found_fill: Array = [false]
	var found_accent: Array = [false]
	for i: int in range(state.get_node_count()):
		var name: StringName = state.get_node_name(i)
		if name == &"KeyLight":
			found_key[0] = true
		elif name == &"FillLight":
			found_fill[0] = true
		elif name == &"AccentNeonStrip":
			found_accent[0] = true
	assert_true(found_key[0], "Should have KeyLight")
	assert_true(found_fill[0], "Should have FillLight")
	assert_true(found_accent[0], "Should have AccentNeonStrip")


func test_scene_hallway_omni_light_budget_is_seven_or_less() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var omni_count: int = 0
	var accent_count: int = 0
	for i: int in range(state.get_node_count()):
		if state.get_node_type(i) != &"OmniLight3D":
			continue
		omni_count += 1
		if String(state.get_node_name(i)).begins_with("NeonAccent_"):
			accent_count += 1
	assert_lte(
		omni_count, 7,
		"Hallway should keep to a single key, a single fill, and a small neon accent set"
	)
	assert_eq(accent_count, 5, "Each storefront should have one neon accent light")


func test_scene_hallway_neon_accents_are_colored_and_not_plain_white() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var saw_warm: bool = false
	var saw_cool: bool = false
	for i: int in range(state.get_node_count()):
		var name: String = String(state.get_node_name(i))
		if not name.begins_with("NeonAccent_"):
			continue
		var light_color: Color = _get_scene_color_property(state, i, &"light_color")
		var contrast: float = (
			max(light_color.r, max(light_color.g, light_color.b))
			- min(light_color.r, min(light_color.g, light_color.b))
		)
		assert_gt(
			contrast, 0.18,
			"%s should stay colored instead of drifting to white" % name
		)
		if light_color.r > light_color.b:
			saw_warm = true
		if light_color.b > light_color.r:
			saw_cool = true
	assert_true(saw_warm, "Accent rig should include warm storefront splashes")
	assert_true(saw_cool, "Accent rig should include cool storefront splashes")


func test_scene_hallway_omni_energy_budget_avoids_washout() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	var total_energy: float = 0.0
	var key_energy: float = 0.0
	var fill_energy: float = 0.0
	for i: int in range(state.get_node_count()):
		if state.get_node_type(i) != &"OmniLight3D":
			continue
		var energy: float = _get_scene_float_property(state, i, &"light_energy")
		total_energy += energy
		if state.get_node_name(i) == &"KeyLight":
			key_energy = energy
		elif state.get_node_name(i) == &"FillLight":
			fill_energy = energy
	assert_lte(total_energy, 1.2, "Combined omni energy should leave headroom for ambient and spots")
	assert_lte(key_energy, 0.45, "Key light should stay below the old washout-heavy energy")
	assert_lte(fill_energy, 0.15, "Fill light should remain gentle enough to preserve contrast")


func test_scene_has_no_world_environment() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var state: SceneState = scene.get_state()
	for i: int in range(state.get_node_count()):
		var type: StringName = state.get_node_type(i)
		assert_ne(
			type, &"WorldEnvironment",
			"Scene must not contain WorldEnvironment"
		)


func test_storefront_spacing_constant() -> void:
	assert_eq(
		MallHallway.STOREFRONT_SPACING, EXPECTED_SPACING,
		"Storefront spacing should be 8m"
	)


func test_storefront_count_constant() -> void:
	assert_eq(
		MallHallway.STOREFRONT_COUNT, EXPECTED_SLOT_COUNT,
		"Storefront count should be 5"
	)


func test_waypoint_graph_store_entrances_match_storefront_spacing() -> void:
	var hallway: MallHallway = _instantiate_hallway()
	var x_positions: Array[float] = []
	for waypoint: MallWaypoint in _get_scene_waypoints(hallway):
		if waypoint.waypoint_type != MallWaypoint.WaypointType.STORE_ENTRANCE:
			continue
		x_positions.append(waypoint.position.x)
	x_positions.sort()
	assert_eq(x_positions.size(), EXPECTED_SLOT_COUNT)
	for i: int in range(x_positions.size() - 1):
		assert_almost_eq(
			x_positions[i + 1] - x_positions[i],
			EXPECTED_SPACING,
			0.01,
			"Store entrance spacing should match storefront spacing"
		)


func test_scene_waypoint_graph_covers_required_destinations() -> void:
	var hallway: MallHallway = _instantiate_hallway()
	var waypoints: Array[MallWaypoint] = _get_scene_waypoints(hallway)

	var exits: int = 0
	var hallways: int = 0
	var store_entrances: int = 0
	var registers: int = 0
	var benches: int = 0
	var food_seats: int = 0

	for waypoint: MallWaypoint in waypoints:
		match waypoint.waypoint_type:
			MallWaypoint.WaypointType.EXIT:
				exits += 1
			MallWaypoint.WaypointType.HALLWAY:
				hallways += 1
			MallWaypoint.WaypointType.STORE_ENTRANCE:
				store_entrances += 1
			MallWaypoint.WaypointType.REGISTER:
				registers += 1
			MallWaypoint.WaypointType.BENCH:
				benches += 1
			MallWaypoint.WaypointType.FOOD_COURT_SEAT:
				food_seats += 1

	assert_eq(exits, 2, "Scene should include both mall exits")
	assert_true(hallways >= 6, "Scene should include hallway junctions and entrances")
	assert_eq(
		store_entrances, EXPECTED_SLOT_COUNT,
		"Scene should include one store entrance per storefront"
	)
	assert_eq(
		registers, EXPECTED_SLOT_COUNT,
		"Scene should include one register waypoint per storefront"
	)
	assert_true(benches >= 2, "Scene should include at least two bench waypoints")
	assert_true(food_seats >= 3, "Scene should include a food court seating cluster")
	assert_not_null(
		hallway.get_node_or_null("WaypointGraph/Entrance_A"),
		"Scene should include Entrance_A"
	)
	assert_not_null(
		hallway.get_node_or_null("WaypointGraph/Entrance_B"),
		"Scene should include Entrance_B"
	)


func test_scene_waypoint_graph_connections_are_bidirectional() -> void:
	var hallway: MallHallway = _instantiate_hallway()
	for waypoint: MallWaypoint in _get_scene_waypoints(hallway):
		for neighbor: MallWaypoint in waypoint.connected_waypoints:
			assert_true(
				neighbor.connected_waypoints.has(waypoint),
				"Connection from %s to %s should be bidirectional"
				% [waypoint.name, neighbor.name]
			)


func test_slots_1_to_4_have_lease_marker_and_interactable_nodes() -> void:
	var hallway: MallHallway = _instantiate_hallway()
	for slot_index: int in range(1, EXPECTED_SLOT_COUNT):
		var storefront: Storefront = hallway.get_storefront(slot_index)
		assert_not_null(
			storefront.find_child("LeaseMarker", true, false),
			"Slot %d should have a lease marker mesh" % slot_index
		)
		assert_not_null(
			storefront.find_child("DoorInteractable", true, false),
			"Slot %d should have a lease interactable" % slot_index
		)


func test_store_slot_unlock_switches_lease_marker_material() -> void:
	var hallway: MallHallway = _instantiate_hallway()
	var storefront: Storefront = hallway.get_storefront(1)
	assert_eq(
		storefront.get_lease_marker_state(),
		&"locked",
		"Locked storefront should start with the locked lease marker material"
	)

	hallway._on_store_slot_unlocked(1)

	assert_eq(
		storefront.get_lease_marker_state(),
		&"available",
		"Unlocked storefront should switch to the available lease marker material"
	)


func test_owned_slots_restore_updates_storefront_visuals() -> void:
	ContentRegistry.clear_for_testing()
	_register_store_catalog_for_restore()

	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var hallway: MallHallway = scene.instantiate() as MallHallway
	add_child_autofree(hallway)

	hallway._on_owned_slots_restored({
		0: &"retro_games",
		2: &"electronics",
	})

	var retro: Storefront = hallway.get_storefront(0)
	var electronics: Storefront = hallway.get_storefront(2)
	var retro_status: Label3D = retro.find_child(
		"StatusSign", true, false
	) as Label3D
	var retro_door: Interactable = retro.find_child(
		"DoorInteractable", true, false
	) as Interactable
	var electronics_door: Interactable = electronics.find_child(
		"DoorInteractable", true, false
	) as Interactable

	assert_true(retro.is_owned, "Slot 0 should be marked owned")
	assert_eq(retro.store_id, "retro_games")
	assert_eq(retro.store_name, "Retro Games")
	assert_eq(retro_status.text, "CLOSED")
	assert_eq(retro_door.interaction_prompt, "Enter")

	assert_true(electronics.is_owned, "Slot 2 should be marked owned")
	assert_eq(electronics.store_id, "electronics")
	assert_eq(electronics.store_name, "Consumer Electronics")
	assert_eq(electronics_door.interaction_prompt, "Enter")

	ContentRegistry.clear_for_testing()


func test_lease_request_failure_keeps_cash_and_slot_unchanged() -> void:
	_register_store_catalog_for_restore()
	GameManager.owned_stores = [&"unknown_store"]

	var hallway: MallHallway = _instantiate_hallway()
	var economy := EconomySystem.new()
	add_child_autofree(economy)
	economy.load_save_data({"player_cash": 100.0})
	var store_state := StoreStateManager.new()
	add_child_autofree(store_state)
	store_state.initialize(null, economy)

	hallway.set_systems(
		economy,
		null,
		null,
		null,
		store_state
	)
	hallway._on_lease_requested(&"retro_games", 1, "Retro Replay")

	assert_eq(
		economy.get_cash(), 100.0,
		"Cash should remain unchanged after a failed lease"
	)
	assert_false(
		store_state.owned_slots.has(1),
		"Failed lease should not assign ownership"
	)
	assert_false(
		hallway.get_storefront(1).is_owned,
		"Failed lease should not update storefront visuals"
	)
	assert_eq(
		_lease_results.back()["success"], false,
		"Failed lease should emit a failure result"
	)


func test_lease_request_success_updates_cash_and_ownership_atomically() -> void:
	_register_store_catalog_for_restore()
	GameManager.owned_stores = [&"unknown_store"]

	var hallway: MallHallway = _instantiate_hallway()
	var economy := EconomySystem.new()
	add_child_autofree(economy)
	economy.load_save_data({"player_cash": 1500.0})
	var store_state := StoreStateManager.new()
	add_child_autofree(store_state)
	store_state.initialize(null, economy)

	hallway.set_systems(
		economy,
		null,
		null,
		null,
		store_state
	)
	hallway._on_lease_requested(&"retro_games", 1, "Retro Replay")

	assert_eq(
		economy.get_cash(), 1000.0,
		"Successful lease should deduct the setup fee once"
	)
	assert_eq(
		store_state.owned_slots.get(1, &""),
		&"retro_games",
		"Successful lease should register the owned slot"
	)
	assert_eq(
		store_state.get_store_name(&"retro_games"),
		"Retro Replay",
		"Successful lease should persist the custom store name"
	)
	assert_true(
		hallway.get_storefront(1).is_owned,
		"Successful lease should update storefront visuals"
	)
	assert_eq(
		_lease_results.back()["success"], true,
		"Successful lease should emit a success result"
	)


func _on_lease_completed(
	store_id: StringName,
	success: bool,
	message: String
) -> void:
	_lease_results.append(
		{
			"store_id": store_id,
			"success": success,
			"message": message,
		}
	)


func _instantiate_hallway() -> MallHallway:
	var scene: PackedScene = load(
		"res://game/scenes/world/mall_hallway.tscn"
	)
	var hallway: MallHallway = scene.instantiate() as MallHallway
	add_child_autofree(hallway)
	return hallway


func _get_scene_waypoints(hallway: MallHallway) -> Array[MallWaypoint]:
	var result: Array[MallWaypoint] = []
	var graph: Node3D = hallway.get_node("WaypointGraph") as Node3D
	for child: Node in graph.get_children():
		var waypoint: MallWaypoint = child as MallWaypoint
		if waypoint != null:
			result.append(waypoint)
	return result


func _register_store_catalog_for_restore() -> void:
	ContentRegistry.register_entry(
		{
			"id": "sports",
			"aliases": ["sports_memorabilia"],
			"name": "Sports Memorabilia",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "retro_games",
			"name": "Retro Games",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "rentals",
			"aliases": ["video_rental"],
			"name": "Video Rental",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "pocket_creatures",
			"name": "Pocket Creatures",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "electronics",
			"aliases": ["consumer_electronics"],
			"name": "Consumer Electronics",
		},
		"store"
	)


func _get_scene_color_property(
	state: SceneState,
	node_index: int,
	property_name: StringName
) -> Color:
	for prop_idx: int in range(state.get_node_property_count(node_index)):
		if state.get_node_property_name(node_index, prop_idx) == property_name:
			return state.get_node_property_value(node_index, prop_idx) as Color
	return Color.WHITE


func _get_scene_float_property(
	state: SceneState,
	node_index: int,
	property_name: StringName
) -> float:
	for prop_idx: int in range(state.get_node_property_count(node_index)):
		if state.get_node_property_name(node_index, prop_idx) == property_name:
			return float(state.get_node_property_value(node_index, prop_idx))
	return 0.0
