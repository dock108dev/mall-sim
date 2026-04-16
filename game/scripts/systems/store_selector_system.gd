## Manages the load/unload cycle for store interior scenes during transitions.
class_name StoreSelectorSystem
extends Node

const FADE_DURATION: float = 0.3
const _PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)

var _store_state_manager: StoreStateManager
var _hallway_node: Node3D
var _store_container: Node3D
var _hallway_camera: PlayerController
var _ui_layer: CanvasLayer
var _fade_rect: ColorRect
var _active_store_scene: Node3D
var _store_camera: PlayerController
var _is_transitioning: bool = false
var _inside_store: bool = false
var _active_store_id: StringName = &""
var _preloaded_scenes: Dictionary = {}


func _ready() -> void:
	_active_store_id = _resolve_store_id(GameManager.current_store_id)
	if not EventBus.active_store_changed.is_connected(_on_active_store_changed):
		EventBus.active_store_changed.connect(_on_active_store_changed)


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
	_setup_fade_rect()
	_preload_store_scenes()
	_active_store_id = _resolve_store_id(GameManager.current_store_id)
	EventBus.enter_store_requested.connect(_on_enter_store_requested)
	EventBus.exit_store_requested.connect(_on_exit_store_requested)
	if not EventBus.active_store_changed.is_connected(_on_active_store_changed):
		EventBus.active_store_changed.connect(_on_active_store_changed)


## Returns true when a store interior is currently loaded.
func is_inside_store() -> bool:
	return _inside_store


## Returns the currently loaded store interior scene, or null.
func get_active_store_scene() -> Node3D:
	return _active_store_scene


## Selects an owned store as the active store without triggering a scene
## transition. No-op when the same store is already active. Calls push_error
## and returns without emitting on ownership or validity failure.
func select_store(store_id: StringName) -> void:
	if store_id.is_empty():
		push_error("StoreSelectorSystem: select_store called with empty id")
		return

	if _find_slot_for_store(store_id) < 0:
		push_error(
			"StoreSelectorSystem: store '%s' is not owned" % store_id
		)
		return

	if _active_store_id == store_id:
		return

	if _store_state_manager:
		_store_state_manager.set_active_store(store_id)


func _unhandled_input(event: InputEvent) -> void:
	if not _inside_store:
		return
	if event.is_action_pressed("ui_cancel"):
		EventBus.exit_store_requested.emit()
		get_viewport().set_input_as_handled()


func _on_enter_store_requested(store_id: StringName) -> void:
	if _is_transitioning:
		return

	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty():
		push_error(
			"StoreSelectorSystem: unknown store_id '%s'" % store_id
		)
		return

	var store_scene: PackedScene = _get_store_scene(canonical)
	if not store_scene:
		push_error(
			"StoreSelectorSystem: failed to load scene for '%s'"
			% canonical
		)
		return

	_is_transitioning = true
	var old_store: String = GameManager.current_store_id
	if not old_store.is_empty() and _store_state_manager:
		_store_state_manager.save_store_state(old_store)

	await _fade_in()

	_active_store_scene = store_scene.instantiate()
	_store_container.add_child(_active_store_scene)

	_hallway_node.visible = false
	_hallway_camera.set_process(false)
	_hallway_camera.set_process_unhandled_input(false)

	_store_camera = (
		_PlayerControllerScene.instantiate() as PlayerController
	)
	_store_camera.name = "StoreCamera"
	_store_container.add_child(_store_camera)

	_move_camera_to_spawn()

	_inside_store = true
	GameManager.current_store_id = String(canonical)
	_store_state_manager.set_active_store(canonical)
	EventBus.store_opened.emit(String(canonical))

	var slot_index: int = _find_slot_for_store(canonical)
	EventBus.storefront_entered.emit(slot_index, String(canonical))
	if not old_store.is_empty():
		EventBus.store_switched.emit(old_store, String(canonical))

	await _fade_out()
	_is_transitioning = false


func _on_exit_store_requested() -> void:
	if _is_transitioning or not _inside_store:
		return

	var leaving_id: StringName = _active_store_id
	_is_transitioning = true

	if not leaving_id.is_empty() and _store_state_manager:
		_store_state_manager.save_store_state(String(leaving_id))

	await _fade_in()

	if _store_camera:
		_store_container.remove_child(_store_camera)
		_store_camera.queue_free()
		_store_camera = null

	if _active_store_scene:
		_store_container.remove_child(_active_store_scene)
		_active_store_scene.queue_free()
		_active_store_scene = null

	_hallway_node.visible = true
	_hallway_camera.set_process(true)
	_hallway_camera.set_process_unhandled_input(true)
	_inside_store = false

	GameManager.current_store_id = ""
	EventBus.store_closed.emit(String(leaving_id))
	_store_state_manager.set_active_store(&"")
	EventBus.storefront_exited.emit()

	await _fade_out()
	_is_transitioning = false


func _move_camera_to_spawn() -> void:
	if not _active_store_scene:
		return
	var orbit_pivot: Node3D = (
		_active_store_scene.find_child("OrbitPivot", true, false)
	)
	if orbit_pivot and _store_camera:
		_store_camera.set_pivot(orbit_pivot.global_position)


func _find_slot_for_store(store_id: StringName) -> int:
	if not _store_state_manager:
		return -1
	for slot: Variant in _store_state_manager.owned_slots:
		if _store_state_manager.owned_slots[slot] == store_id:
			return int(slot)
	return -1


func _preload_store_scenes() -> void:
	var store_ids: Array[StringName] = ContentRegistry.get_all_ids(
		"store"
	)
	for store_id: StringName in store_ids:
		var path: String = ContentRegistry.get_scene_path(store_id)
		if path.is_empty():
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
	if path.is_empty():
		return null
	return load(path) as PackedScene


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


func _setup_fade_rect() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.name = "StoreSelectorFadeRect"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_fade_rect)


func _fade_in() -> void:
	if not _fade_rect:
		return
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
	await tween.finished


func _fade_out() -> void:
	if not _fade_rect:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
	await tween.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
