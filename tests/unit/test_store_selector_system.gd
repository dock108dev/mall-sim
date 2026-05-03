## GUT tests for StoreSelectorSystem transition sequencing and rollback safety.
extends GutTest


class TestStoreSelectorSystem extends StoreSelectorSystem:
	var missing_store_id: StringName = &""
	var error_messages: Array[String] = []

	func _get_store_scene(store_id: StringName) -> PackedScene:
		if store_id == missing_store_id:
			return null
		return super._get_store_scene(store_id)

	func _push_system_error(message: String) -> void:
		error_messages.append(message)


const _STORE_ID: StringName = &"retro_games"
const _STORE_SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const _BROKEN_STORE_ID: StringName = &"broken_store"
const _BROKEN_SCENE_PATH: String = "res://game/scenes/stores/sports_memorabilia.tscn"
const _PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)

var _system: TestStoreSelectorSystem
var _store_state: StoreStateManager
var _hallway_node: Node3D
var _store_container: Node3D
var _hallway_camera: PlayerController
var _ui_layer: CanvasLayer
var _waypoint_graph: Node3D
var _storefront_marker: Marker3D

var _store_entered_ids: Array[StringName] = []
var _store_exited_ids: Array[StringName] = []
var _active_store_ids: Array[StringName] = []
var _active_cameras: Array[Camera3D] = []
var _hallway_visible_during_enter: bool = false
var _store_scene_loaded_during_enter: bool = false
var _saved_game_store_id: StringName = &""
var _zone_player: AudioStreamPlayer


func before_each() -> void:
	_saved_game_store_id = GameManager.current_store_id
	GameManager.current_store_id = &""
	ContentRegistry.clear_for_testing()
	ContentRegistry.register_entry(
		{
			"id": String(_STORE_ID),
			"name": "Retro Games",
			"scene_path": _STORE_SCENE_PATH,
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": String(_BROKEN_STORE_ID),
			"name": "Broken Store",
			"scene_path": _BROKEN_SCENE_PATH,
		},
		"store"
	)

	_store_state = StoreStateManager.new()
	add_child_autofree(_store_state)
	_store_state.lease_store(0, _STORE_ID, _STORE_ID)
	_store_state.lease_store(1, _BROKEN_STORE_ID, _BROKEN_STORE_ID)

	_hallway_node = Node3D.new()
	_hallway_node.name = "HallwayGeometry"
	add_child_autofree(_hallway_node)

	_store_container = Node3D.new()
	_store_container.name = "StoreContainer"
	add_child_autofree(_store_container)

	_hallway_camera = _PlayerControllerScene.instantiate() as PlayerController
	_hallway_camera.name = "HallwayCamera"
	add_child_autofree(_hallway_camera)

	_ui_layer = CanvasLayer.new()
	add_child_autofree(_ui_layer)

	_waypoint_graph = Node3D.new()
	_waypoint_graph.name = "WaypointGraph"
	add_child_autofree(_waypoint_graph)

	_storefront_marker = Marker3D.new()
	_storefront_marker.name = "StoreEntrance_0"
	_storefront_marker.position = Vector3(4.0, 0.0, 2.5)
	_waypoint_graph.add_child(_storefront_marker)

	_zone_player = AudioStreamPlayer.new()
	add_child_autofree(_zone_player)
	AudioManager.register_zone(String(_STORE_ID), _zone_player)

	_system = TestStoreSelectorSystem.new()
	_system.missing_store_id = _BROKEN_STORE_ID
	add_child_autofree(_system)
	_system.initialize(
		_store_state, _hallway_node, _store_container, _hallway_camera, _ui_layer
	)

	_store_entered_ids.clear()
	_store_exited_ids.clear()
	_active_store_ids.clear()
	_active_cameras.clear()
	_hallway_visible_during_enter = false
	_store_scene_loaded_during_enter = false

	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)
	EventBus.active_store_changed.connect(_on_active_store_changed)
	EventBus.active_camera_changed.connect(_on_active_camera_changed)


func after_each() -> void:
	_safe_disconnect(EventBus.store_entered, _on_store_entered)
	_safe_disconnect(EventBus.store_exited, _on_store_exited)
	_safe_disconnect(EventBus.active_store_changed, _on_active_store_changed)
	_safe_disconnect(EventBus.active_camera_changed, _on_active_camera_changed)
	AudioManager.unregister_zone(String(_STORE_ID))
	GameManager.current_store_id = _saved_game_store_id
	ContentRegistry.clear_for_testing()


func test_initial_state_is_hallway_only() -> void:
	assert_false(_system.is_inside_store())
	assert_null(_system.get_active_store_scene())
	assert_true(_hallway_node.visible)


func test_enter_store_requested_loads_scene_before_hiding_hallway() -> void:
	EventBus.enter_store_requested.emit(_STORE_ID)

	assert_true(_system.is_inside_store())
	assert_not_null(_system.get_active_store_scene())
	assert_eq(_store_state.active_store_id, _STORE_ID)
	assert_eq(_store_entered_ids, [_STORE_ID])
	assert_eq(_active_store_ids, [_STORE_ID])
	assert_true(
		_store_scene_loaded_during_enter,
		"store_entered should fire only after the interior scene is loaded"
	)
	assert_true(
		_hallway_visible_during_enter,
		"hallway should remain visible while store_entered listeners run"
	)
	assert_false(_hallway_node.visible)


func test_enter_store_moves_camera_to_store_entry_and_rebinds_camera_users() -> void:
	EventBus.enter_store_requested.emit(_STORE_ID)

	# `_move_store_camera_to_spawn` walks `_STORE_ENTRY_MARKER_NAMES`
	# (PlayerEntrySpawn → EntryPoint → OrbitPivot) and pivots the orbit camera
	# at the first match clamped to the camera's store bounds. retro_games
	# authors PlayerEntrySpawn at the storefront centerline so the orbit camera
	# pivots toward the entry-side of the room on entry.
	const MARKERS: Array[StringName] = [
		&"PlayerEntrySpawn",
		&"EntryPoint",
		&"OrbitPivot",
	]
	var entry_marker: Node3D = null
	var scene: Node3D = _system.get_active_store_scene()
	assert_not_null(scene)
	for marker_name: StringName in MARKERS:
		var found: Node = scene.find_child(String(marker_name), true, false)
		if found is Node3D:
			entry_marker = found as Node3D
			break
	assert_not_null(entry_marker)
	var expected_pivot: Vector3 = entry_marker.global_position.clamp(
		_system._store_camera.store_bounds_min,
		_system._store_camera.store_bounds_max
	)
	assert_eq(
		_system._store_camera.global_position,
		expected_pivot,
		"store camera should move to the entry spawn clamped to store bounds"
	)
	assert_true(
		_active_cameras.has(_system._store_camera.get_camera()),
		"entering should notify camera listeners about the store camera"
	)


func test_exit_store_requested_restores_hallway_and_clears_active_store() -> void:
	EventBus.enter_store_requested.emit(_STORE_ID)
	_store_exited_ids.clear()
	_active_store_ids.clear()
	_active_cameras.clear()

	EventBus.exit_store_requested.emit()

	assert_false(_system.is_inside_store())
	assert_null(_system.get_active_store_scene())
	assert_true(_hallway_node.visible)
	assert_eq(_store_exited_ids, [_STORE_ID])
	assert_eq(_active_store_ids, [&""])
	assert_eq(_store_state.active_store_id, &"")
	assert_eq(
		_hallway_camera.global_position,
		_storefront_marker.global_position,
		"exiting should return the hallway camera to the storefront exit marker"
	)
	assert_true(
		_active_cameras.has(_hallway_camera.get_camera()),
		"exiting should notify camera listeners about the hallway camera"
	)


func test_enter_store_aborts_cleanly_when_scene_load_fails() -> void:
	EventBus.enter_store_requested.emit(_BROKEN_STORE_ID)

	assert_false(_system.is_inside_store())
	assert_null(_system.get_active_store_scene())
	assert_true(_hallway_node.visible)
	assert_eq(_store_entered_ids.size(), 0)
	assert_eq(_active_store_ids.size(), 0)
	assert_eq(_store_state.active_store_id, &"")


func test_enter_store_clamps_camera_pivot_to_store_footprint() -> void:
	EventBus.enter_store_requested.emit(_STORE_ID)

	var store_camera: PlayerController = _system._store_camera
	assert_not_null(store_camera)
	assert_eq(
		store_camera.store_bounds_min,
		Vector3(-3.2, 0.0, -2.2),
		"store camera min bounds should match navigable floor"
	)
	assert_eq(
		store_camera.store_bounds_max,
		Vector3(3.2, 0.0, 2.2),
		"store camera max bounds should match navigable floor"
	)

	store_camera.set_pivot(Vector3(99.0, 0.0, 99.0))
	var clamped_max: Vector3 = store_camera._target_pivot
	assert_almost_eq(clamped_max.x, 3.2, 0.0001)
	assert_almost_eq(clamped_max.z, 2.2, 0.0001)

	store_camera.set_pivot(Vector3(-99.0, 0.0, -99.0))
	var clamped_min: Vector3 = store_camera._target_pivot
	assert_almost_eq(clamped_min.x, -3.2, 0.0001)
	assert_almost_eq(clamped_min.z, -2.2, 0.0001)


func test_enter_store_caps_camera_zoom_to_store_interior() -> void:
	EventBus.enter_store_requested.emit(_STORE_ID)

	var store_camera: PlayerController = _system._store_camera
	assert_not_null(store_camera)
	assert_almost_eq(
		store_camera.zoom_max,
		5.0,
		0.0001,
		"store camera zoom_max should be capped to fit the store interior"
	)
	assert_almost_eq(
		store_camera.zoom_min,
		2.0,
		0.0001,
		"store camera zoom_min should keep the camera off floor and fixtures"
	)

	store_camera.set_zoom_distance(99.0)
	assert_almost_eq(store_camera._zoom, 5.0, 0.0001)
	store_camera.set_zoom_distance(0.1)
	assert_almost_eq(store_camera._zoom, 2.0, 0.0001)


func _safe_disconnect(signal_ref: Signal, callable: Callable) -> void:
	if signal_ref.is_connected(callable):
		signal_ref.disconnect(callable)


func _on_store_entered(store_id: StringName) -> void:
	_store_entered_ids.append(store_id)
	_hallway_visible_during_enter = _hallway_node.visible
	_store_scene_loaded_during_enter = _system.get_active_store_scene() != null


func _on_store_exited(store_id: StringName) -> void:
	_store_exited_ids.append(store_id)


func _on_active_store_changed(store_id: StringName) -> void:
	_active_store_ids.append(store_id)


func _on_active_camera_changed(camera: Camera3D) -> void:
	_active_cameras.append(camera)
