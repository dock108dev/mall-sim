## Tracks the active Camera3D and emits EventBus.active_camera_changed on
## transitions. When it detects a new active camera, it mirrors it into
## CameraAuthority (ISSUE-010, ownership.md row 4) so the single-writer
## contract is satisfied regardless of how the camera became current
## (explicit `make_current()`, Godot auto-current on tree-add, etc.).
extends Node

const _AUTHORITY_SOURCE: StringName = &"camera_manager"

var active_camera: Camera3D = null

var _hallway_camera: Camera3D = null
var _store_cameras: Dictionary = {}


func _ready() -> void:
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	_refresh_active_camera.call_deferred()


func _process(_delta: float) -> void:
	_refresh_active_camera()


## Explicitly sets the active camera and emits active_camera_changed.
func register_camera(camera: Variant) -> void:
	_set_active_camera(_coerce_camera(camera), true)


## Returns the currently active camera, or null if none is registered.
func get_active_camera() -> Camera3D:
	return active_camera


## Stores the hallway camera for use when a store is exited.
func register_hallway_camera(camera: Variant) -> void:
	_hallway_camera = _coerce_camera(camera)


## Associates a camera with a store_id for use when that store is entered.
func register_store_camera(store_id: StringName, camera: Variant) -> void:
	var resolved: Camera3D = _coerce_camera(camera)
	if resolved == null:
		_store_cameras.erase(store_id)
		return
	_store_cameras[store_id] = resolved


func _refresh_active_camera() -> void:
	var viewport: Viewport = get_viewport()
	if not viewport:
		return
	var current: Camera3D = viewport.get_camera_3d()
	if current != null and not is_instance_valid(current):
		current = null
	_set_active_camera(current, false)


func _set_active_camera(camera: Camera3D, force_emit: bool) -> void:
	if camera != null and not is_instance_valid(camera):
		camera = null
	if not force_emit and camera == active_camera:
		return
	active_camera = camera
	_sync_to_camera_authority(camera)
	EventBus.active_camera_changed.emit(active_camera)


func _sync_to_camera_authority(camera: Camera3D) -> void:
	if camera == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var authority: Node = tree.root.get_node_or_null("CameraAuthority")
	if authority == null or not authority.has_method("request_current"):
		return
	# §F-63 — CameraAuthority is the SSOT for the active-camera source label.
	# Skip the mirror when it already tracks this exact camera so an explicit
	# caller (e.g. StorePlayerBody.request_current(_camera, &"player_fp")) keeps
	# its source token. Without this guard, the next CameraManager._process
	# tick overwrites the source to &"camera_manager" and Day1ReadinessAudit
	# rejects the entry as off-allowlist.
	if authority.has_method("current") and authority.call("current") == camera:
		return
	authority.request_current(camera, _AUTHORITY_SOURCE)


func _on_node_added(node: Node) -> void:
	if node is Camera3D:
		_refresh_active_camera.call_deferred()


func _on_node_removed(node: Node) -> void:
	if node == active_camera:
		_set_active_camera(null, false)


func _on_store_entered(store_id: StringName) -> void:
	if not _store_cameras.has(store_id):
		return
	var store_camera: Camera3D = _coerce_camera(_store_cameras.get(store_id))
	if store_camera == null:
		_store_cameras.erase(store_id)
		return
	register_camera(store_camera)


func _on_store_exited(_store_id: StringName) -> void:
	register_camera(_hallway_camera)


func _coerce_camera(camera: Variant) -> Camera3D:
	if camera == null:
		return null
	if not is_instance_valid(camera):
		return null
	if not camera is Camera3D:
		return null
	return camera as Camera3D
