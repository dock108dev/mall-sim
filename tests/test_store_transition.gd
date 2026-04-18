## Integration test: store transition swaps environment, updates active store,
## and enables camera-driven interaction listeners without errors.
extends GutTest


class TestStoreSelectorSystem extends StoreSelectorSystem:
	var error_messages: Array[String] = []

	func _push_system_error(message: String) -> void:
		error_messages.append(message)


const _EnvironmentManagerScript: GDScript = preload(
	"res://game/autoload/environment_manager.gd"
)
const _InteractionRayScript: GDScript = preload(
	"res://game/scripts/player/interaction_ray.gd"
)
const _PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)
const _ENV_HALLWAY: Environment = preload(
	"res://game/resources/environments/env_hallway.tres"
)
const _ENV_RETRO_GAMES: Environment = preload(
	"res://game/resources/environments/env_retro_games.tres"
)
const _STORE_ID: StringName = &"retro_games"
const _TWEEN_WAIT: float = 0.6

var _env_manager: Node
var _store_selector: TestStoreSelectorSystem
var _store_state_manager: StoreStateManager
var _hallway_root: Node3D
var _hallway_node: Node3D
var _store_container: Node3D
var _hallway_camera: PlayerController
var _ui_layer: CanvasLayer
var _zone_player: AudioStreamPlayer
var _interaction_ray
var _active_store_changed_ids: Array[StringName] = []
var _saved_game_store_id: StringName = &""


func before_each() -> void:
	_saved_game_store_id = GameManager.current_store_id
	GameManager.current_store_id = &""
	CameraManager._store_cameras.clear()
	CameraManager.register_camera(null)
	CameraManager.register_hallway_camera(null)
	ContentRegistry.clear_for_testing()
	ContentRegistry.register_entry(
		{
			"id": String(_STORE_ID),
			"name": "Retro Games",
			"scene_path": "res://game/scenes/stores/retro_games.tscn",
			"environment_id": "retro_games",
		},
		"store"
	)

	_env_manager = _EnvironmentManagerScript.new()
	add_child_autofree(_env_manager)

	_store_state_manager = StoreStateManager.new()
	add_child_autofree(_store_state_manager)
	_store_state_manager.lease_store(0, _STORE_ID, _STORE_ID, false)

	_hallway_root = Node3D.new()
	_hallway_root.name = "HallwayRoot"
	add_child_autofree(_hallway_root)

	_hallway_node = Node3D.new()
	_hallway_node.name = "HallwayGeometry"
	_hallway_root.add_child(_hallway_node)

	var waypoint_graph := Node3D.new()
	waypoint_graph.name = "WaypointGraph"
	_hallway_root.add_child(waypoint_graph)

	var storefront_marker := Marker3D.new()
	storefront_marker.name = "StoreEntrance_0"
	waypoint_graph.add_child(storefront_marker)

	_store_container = Node3D.new()
	_store_container.name = "StoreContainer"
	_hallway_root.add_child(_store_container)

	_hallway_camera = _PlayerControllerScene.instantiate() as PlayerController
	_hallway_camera.name = "HallwayCamera"
	_hallway_root.add_child(_hallway_camera)

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UILayer"
	_hallway_root.add_child(_ui_layer)

	_zone_player = AudioStreamPlayer.new()
	_zone_player.name = "ZonePlayer"
	_hallway_root.add_child(_zone_player)
	AudioManager.register_zone(String(_STORE_ID), _zone_player)

	_store_selector = TestStoreSelectorSystem.new()
	_store_selector.name = "StoreSelectorSystem"
	_hallway_root.add_child(_store_selector)
	_store_selector.initialize(
		_store_state_manager,
		_hallway_node,
		_store_container,
		_hallway_camera,
		_ui_layer
	)

	_interaction_ray = _InteractionRayScript.new()
	_interaction_ray.name = "InteractionRay"
	_hallway_root.add_child(_interaction_ray)

	_active_store_changed_ids.clear()
	EventBus.active_store_changed.connect(_on_active_store_changed)


func after_each() -> void:
	if EventBus.active_store_changed.is_connected(_on_active_store_changed):
		EventBus.active_store_changed.disconnect(_on_active_store_changed)
	AudioManager.unregister_zone(String(_STORE_ID))
	CameraManager._store_cameras.clear()
	CameraManager.register_camera(null)
	CameraManager.register_hallway_camera(null)
	GameManager.current_store_id = _saved_game_store_id
	ContentRegistry.clear_for_testing()


func test_store_transition_updates_environment_store_state_and_camera_listeners() -> void:
	var hallway_env: Environment = _env_manager.get_world_environment().environment
	assert_eq(
		hallway_env,
		_ENV_HALLWAY,
		"EnvironmentManager should start on the hallway environment resource"
	)
	assert_eq(
		_env_manager.get_current_key(),
		&"hallway",
		"EnvironmentManager should start in the hallway zone"
	)
	assert_false(
		_interaction_ray.is_processing(),
		"InteractionRay should wait for an active camera before processing"
	)

	EventBus.store_entered.emit(_STORE_ID)

	assert_eq(
		_env_manager.get_current_key(),
		_STORE_ID,
		"store_entered should update the active environment zone immediately"
	)
	assert_eq(
		_active_store_changed_ids,
		[_STORE_ID],
		"store_entered should emit active_store_changed with retro_games"
	)
	assert_eq(
		_store_selector.get_active_store_id(),
		_STORE_ID,
		"StoreSelectorSystem should track retro_games as the active store after entry"
	)
	assert_eq(
		_store_state_manager.active_store_id,
		_STORE_ID,
		"StoreStateManager should receive the entered store id from StoreSelectorSystem"
	)

	await get_tree().create_timer(_TWEEN_WAIT).timeout

	assert_eq(
		_env_manager.get_world_environment().environment,
		_ENV_RETRO_GAMES,
		"EnvironmentManager should swap to the retro_games environment resource after entry"
	)
	assert_ne(
		_env_manager.get_world_environment().environment,
		hallway_env,
		"Store entry should replace the hallway environment resource"
	)

	var active_camera := Camera3D.new()
	add_child_autofree(active_camera)
	EventBus.active_camera_changed.emit(active_camera)

	assert_true(
		_interaction_ray.is_processing(),
		"InteractionRay should become active immediately after the camera update"
	)
	assert_same(
		_interaction_ray._camera,
		active_camera,
		"InteractionRay should bind to the camera carried by active_camera_changed"
	)
	assert_eq(
		_store_selector.error_messages,
		[],
		"Store transition should not record StoreSelectorSystem push_error messages"
	)

	EventBus.store_exited.emit(_STORE_ID)

	assert_eq(
		_env_manager.get_current_key(),
		&"hallway",
		"store_exited should restore the hallway zone immediately"
	)
	assert_eq(
		_store_selector.get_active_store_id(),
		&"",
		"StoreSelectorSystem should clear the active store after exit"
	)
	assert_eq(
		_store_state_manager.active_store_id,
		&"",
		"StoreStateManager should clear the active store after exit"
	)

	await get_tree().create_timer(_TWEEN_WAIT).timeout

	assert_eq(
		_env_manager.get_world_environment().environment,
		_ENV_HALLWAY,
		"EnvironmentManager should restore the hallway environment resource after exit"
	)
	assert_eq(
		_store_selector.error_messages,
		[],
		"Store exit should keep StoreSelectorSystem free of push_error messages"
	)


func _on_active_store_changed(store_id: StringName) -> void:
	_active_store_changed_ids.append(store_id)
