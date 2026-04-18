## Manages additive hallway/store scene transitions and related runtime signals.
class_name StoreSelectorSystem
extends Node

const _PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)
const _STORE_ENTRY_MARKER_NAMES: Array[StringName] = [
	&"PlayerEntrySpawn",
	&"EntryPoint",
	&"OrbitPivot",
]

var _store_state_manager: StoreStateManager
var _hallway_node: Node3D
var _store_container: Node3D
var _hallway_camera: PlayerController
var _ui_layer: CanvasLayer
var _active_store_scene: Node3D
var _store_camera: PlayerController
var _is_transitioning: bool = false
var _inside_store: bool = false
var _active_store_id: StringName = &""
var _preloaded_scenes: Dictionary = {}


func _ready() -> void:
	_active_store_id = _resolve_store_id(GameManager.get_active_store_id())
	_connect_signal(EventBus.store_entered, _on_store_entered)
	_connect_signal(EventBus.store_exited, _on_store_exited)
	_connect_signal(EventBus.active_store_changed, _on_active_store_changed)


## Injects runtime references. Must be called after construction, not in _ready.
func initialize(
	store_state_manager: StoreStateManager,
	hallway_node: Node3D,
	store_container: Node3D,
	hallway_camera: PlayerController,
	ui_layer: CanvasLayer
) -> void:
	_store_state_manager = store_state_manager
	_hallway_node = hallway_node
	_store_container = store_container
	_hallway_camera = hallway_camera
	_ui_layer = ui_layer
	_preload_store_scenes()
	_register_hallway_camera()
	_active_store_id = _resolve_store_id(GameManager.get_active_store_id())
	_connect_signal(EventBus.enter_store_requested, _on_enter_store_requested)
	_connect_signal(EventBus.exit_store_requested, _on_exit_store_requested)
	_connect_signal(EventBus.store_entered, _on_store_entered)
	_connect_signal(EventBus.store_exited, _on_store_exited)
	_connect_signal(EventBus.active_store_changed, _on_active_store_changed)


## Returns true when a store interior is currently loaded.
func is_inside_store() -> bool:
	return _inside_store


## Returns the currently loaded store interior scene, or null.
func get_active_store_scene() -> Node3D:
	return _active_store_scene


## Returns the canonical ID of the currently active store.
func get_active_store_id() -> StringName:
	return _active_store_id


## Returns the configured scene path for a store ID, or empty when missing.
func get_store_scene_path(store_id: StringName) -> String:
	return ContentRegistry.get_scene_path(store_id)


## Selects an owned store as the active store without triggering a scene
## transition. No-op when the same store is already active. Calls push_error
## and returns without emitting on ownership or validity failure.
func select_store(store_id: StringName) -> void:
	if store_id.is_empty():
		_push_system_error("StoreSelectorSystem: select_store called with empty id")
		return

	if _find_slot_for_store(store_id) < 0:
		_push_system_error(
			"StoreSelectorSystem: store '%s' is not owned" % store_id
		)
		return

	if _active_store_id == store_id:
		return

	if _store_state_manager:
		_store_state_manager.set_active_store(store_id)


## Enters the requested store interior and returns whether the transition ran.
func enter_store(store_id: StringName) -> bool:
	if _is_transitioning or _inside_store:
		return false

	var scene_path: String = get_store_scene_path(store_id)
	if scene_path.is_empty():
		_push_system_error(
			"StoreSelectorSystem: unknown store_id '%s'" % store_id
		)
		return false
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty():
		_push_system_error(
			"StoreSelectorSystem: unknown store_id '%s'" % store_id
		)
		return false

	var slot_index: int = _find_slot_for_store(canonical)

	var store_scene: PackedScene = _get_store_scene(canonical)
	if store_scene == null:
		_push_system_error(
			"StoreSelectorSystem: failed to load scene for '%s'"
			% canonical
		)
		return false

	var loaded_scene: Node3D = store_scene.instantiate() as Node3D
	if loaded_scene == null:
		_push_system_error(
			"StoreSelectorSystem: scene for '%s' did not instantiate as Node3D"
			% canonical
		)
		return false

	var loaded_camera: PlayerController = (
		_PlayerControllerScene.instantiate() as PlayerController
	)
	if loaded_camera == null:
		loaded_scene.queue_free()
		_push_system_error(
			"StoreSelectorSystem: failed to instantiate store camera for '%s'"
			% canonical
		)
		return false

	_is_transitioning = true
	_store_container.add_child(loaded_scene)
	loaded_camera.name = "StoreCamera"
	_store_container.add_child(loaded_camera)
	_move_store_camera_to_spawn(loaded_scene, loaded_camera)
	_register_store_camera(canonical, loaded_camera)

	_active_store_scene = loaded_scene
	_store_camera = loaded_camera
	_inside_store = true

	_set_active_store_for_transition(canonical)
	EventBus.store_entered.emit(canonical)
	EventBus.store_opened.emit(String(canonical))
	if slot_index >= 0:
		EventBus.storefront_entered.emit(slot_index, String(canonical))

	_hallway_node.visible = false
	_set_hallway_camera_enabled(false)
	_is_transitioning = false
	return true


## Exits the current store interior and returns whether the transition ran.
func exit_store() -> bool:
	if _is_transitioning or not _inside_store:
		return false

	var leaving_id: StringName = _active_store_id
	_is_transitioning = true

	if not leaving_id.is_empty() and _store_state_manager:
		_store_state_manager.save_store_state(String(leaving_id))

	EventBus.store_exited.emit(leaving_id)
	_hallway_node.visible = true
	_set_hallway_camera_enabled(true)
	_move_hallway_camera_to_storefront(leaving_id)
	_set_active_store_for_transition(&"")
	EventBus.store_closed.emit(String(leaving_id))
	EventBus.storefront_exited.emit()

	if _store_camera:
		_store_camera.queue_free()
		_store_camera = null
	if _active_store_scene:
		_active_store_scene.queue_free()
		_active_store_scene = null

	_inside_store = false
	_is_transitioning = false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _inside_store:
		return
	if event.is_action_pressed("ui_cancel"):
		EventBus.exit_store_requested.emit()
		get_viewport().set_input_as_handled()


func _on_enter_store_requested(store_id: StringName) -> void:
	enter_store(store_id)


func _on_exit_store_requested() -> void:
	exit_store()


func _on_store_entered(store_id: StringName) -> void:
	if _is_transitioning:
		return
	var scene_path: String = get_store_scene_path(store_id)
	if scene_path.is_empty():
		_push_system_error(
			"StoreSelectorSystem: unknown store_id '%s'" % store_id
		)
		return
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty() or _active_store_id == canonical:
		return
	_set_active_store_for_transition(canonical)


func _on_store_exited(store_id: StringName) -> void:
	if _is_transitioning or _active_store_id.is_empty():
		return
	var canonical: StringName = _resolve_store_id(store_id)
	if not canonical.is_empty() and canonical != _active_store_id:
		return
	_set_active_store_for_transition(&"")


func _move_store_camera_to_spawn(
	store_scene: Node3D,
	store_camera: PlayerController
) -> void:
	var spawn: Node3D = _find_store_entry_spawn(store_scene)
	if spawn == null:
		return
	store_camera.set_pivot(spawn.global_position)


func _move_hallway_camera_to_storefront(store_id: StringName) -> void:
	if _hallway_camera == null:
		return
	var slot_index: int = _find_slot_for_store(store_id)
	if slot_index < 0:
		return
	var marker: Marker3D = _find_hallway_storefront_marker(slot_index)
	if marker == null:
		return
	_hallway_camera.set_pivot(marker.global_position)


func _find_store_entry_spawn(store_scene: Node3D) -> Node3D:
	for marker_name: StringName in _STORE_ENTRY_MARKER_NAMES:
		var marker: Node = store_scene.find_child(
			String(marker_name), true, false
		)
		if marker is Node3D:
			return marker as Node3D
	return null


func _find_hallway_storefront_marker(slot_index: int) -> Marker3D:
	var hallway_root: Node = _get_hallway_root()
	if hallway_root == null:
		return null
	return hallway_root.get_node_or_null(
		"WaypointGraph/StoreEntrance_%d" % slot_index
	) as Marker3D


func _get_hallway_root() -> Node:
	if _hallway_node and _hallway_node.get_parent() != null:
		return _hallway_node.get_parent()
	if _hallway_camera and _hallway_camera.get_parent() != null:
		return _hallway_camera.get_parent()
	return null


func _set_active_store_for_transition(store_id: StringName) -> void:
	if _store_state_manager:
		_store_state_manager.set_active_store(store_id, false)
		return

	push_error(
		"StoreSelectorSystem: StoreStateManager is required for store transitions"
	)


func _set_hallway_camera_enabled(enabled: bool) -> void:
	if _hallway_camera == null:
		return
	_hallway_camera.set_process(enabled)
	_hallway_camera.set_process_unhandled_input(enabled)


func _find_slot_for_store(store_id: StringName) -> int:
	if not _store_state_manager:
		return -1
	for slot: int in _store_state_manager.owned_slots:
		if _store_state_manager.owned_slots[slot] == store_id:
			return slot
	return -1


func _preload_store_scenes() -> void:
	var store_ids: Array[StringName] = ContentRegistry.get_all_ids(
		"store"
	)
	for store_id: StringName in store_ids:
		var path: String = ContentRegistry.get_scene_path(store_id)
		if path.is_empty():
			continue
		if not ResourceLoader.exists(path):
			push_warning(
				"StoreSelectorSystem: failed to preload '%s'" % path
			)
			continue
		var scene: PackedScene = load(path) as PackedScene
		if scene:
			_preloaded_scenes[store_id] = scene
		else:
			push_warning(
				"StoreSelectorSystem: failed to preload '%s'" % path
			)


func _get_store_scene(store_id: StringName) -> PackedScene:
	if _preloaded_scenes.has(store_id):
		return _preloaded_scenes[store_id]
	var path: String = ContentRegistry.get_scene_path(store_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


func _register_hallway_camera() -> void:
	if _hallway_camera == null:
		return
	var hallway_view: Camera3D = _hallway_camera.get_camera()
	if hallway_view == null:
		return
	CameraManager.register_hallway_camera(hallway_view)


func _register_store_camera(
	store_id: StringName,
	store_camera: PlayerController
) -> void:
	if store_camera == null:
		return
	var store_view: Camera3D = store_camera.get_camera()
	if store_view == null:
		return
	CameraManager.register_store_camera(store_id, store_view)


func _on_active_store_changed(store_id: StringName) -> void:
	_active_store_id = store_id


func _resolve_store_id(raw_store_id: Variant) -> StringName:
	var raw_id: String = str(raw_store_id)
	if raw_id.is_empty():
		return &""
	var canonical: StringName = ContentRegistry.resolve(raw_id)
	if canonical.is_empty():
		return StringName(raw_id)
	return canonical


func _connect_signal(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


func _push_system_error(message: String) -> void:
	push_error(message)
