## GUT tests for StoreSelectorSystem transition sequencing and rollback safety.
extends GutTest

const _STORE_ID: StringName = &"retro_games"
const _STORE_SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const _BROKEN_STORE_ID: StringName = &"broken_store"
const _BROKEN_SCENE_PATH: String = "res://game/scenes/stores/missing_store.tscn"
const _PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)

var _system: StoreSelectorSystem
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

	_system = StoreSelectorSystem.new()
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

	var entry_marker: Node3D = _system.get_active_store_scene().find_child(
		"EntryPoint", true, false
	) as Node3D
	assert_not_null(entry_marker)
	assert_eq(
		_system._store_camera.global_position,
		entry_marker.global_position,
		"store camera should move to the interior entry spawn"
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
