## Tracks the active Camera3D and emits EventBus.active_camera_changed on transitions.
extends Node

var active_camera: Camera3D = null

var _hallway_camera: Camera3D = null
var _store_cameras: Dictionary = {}


func _ready() -> void:
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)


func _process(_delta: float) -> void:
	var viewport: Viewport = get_viewport()
	if not viewport:
		return
	var current: Camera3D = viewport.get_camera_3d()
	if current == active_camera:
		return
	if not is_instance_valid(active_camera) and active_camera != null:
		active_camera = null
	if current == active_camera:
		return
	active_camera = current
	EventBus.active_camera_changed.emit(active_camera)


## Explicitly sets the active camera and emits active_camera_changed.
func register_camera(camera: Camera3D) -> void:
	active_camera = camera
	EventBus.active_camera_changed.emit(active_camera)


## Returns the currently active camera, or null if none is registered.
func get_active_camera() -> Camera3D:
	return active_camera


## Stores the hallway camera for use when a store is exited.
func register_hallway_camera(camera: Camera3D) -> void:
	_hallway_camera = camera


## Associates a camera with a store_id for use when that store is entered.
func register_store_camera(store_id: StringName, camera: Camera3D) -> void:
	_store_cameras[store_id] = camera


func _on_store_entered(store_id: StringName) -> void:
	if not _store_cameras.has(store_id):
		return
	register_camera(_store_cameras[store_id])


func _on_store_exited(_store_id: StringName) -> void:
	register_camera(_hallway_camera)
