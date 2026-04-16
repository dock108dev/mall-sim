## GUT unit tests for CameraManager — register_camera, get_active_camera,
## active_camera_changed signal, null-camera guard, and store transition rebind.
extends GutTest

const CameraManagerScript: GDScript = preload("res://game/autoload/camera_manager.gd")

const _STORE_ID: StringName = &"retro_games"

var _manager: Node
var _received_cameras: Array[Camera3D] = []
var _signal_count: int = 0
var _autoload_store_entered_connected: bool = false
var _autoload_store_exited_connected: bool = false


func before_each() -> void:
	_received_cameras.clear()
	_signal_count = 0
	_disconnect_autoload_store_handlers()
	_manager = Node.new()
	_manager.set_script(CameraManagerScript)
	add_child_autofree(_manager)
	EventBus.active_camera_changed.connect(_on_camera_changed)


func after_each() -> void:
	_safe_disconnect(EventBus.active_camera_changed, _on_camera_changed)
	_safe_disconnect(EventBus.store_entered, _manager._on_store_entered)
	_safe_disconnect(EventBus.store_exited, _manager._on_store_exited)
	_reconnect_autoload_store_handlers()


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _disconnect_autoload_store_handlers() -> void:
	_autoload_store_entered_connected = EventBus.store_entered.is_connected(
		CameraManager._on_store_entered
	)
	_autoload_store_exited_connected = EventBus.store_exited.is_connected(
		CameraManager._on_store_exited
	)
	_safe_disconnect(EventBus.store_entered, CameraManager._on_store_entered)
	_safe_disconnect(EventBus.store_exited, CameraManager._on_store_exited)


func _reconnect_autoload_store_handlers() -> void:
	if _autoload_store_entered_connected:
		if not EventBus.store_entered.is_connected(
			CameraManager._on_store_entered
		):
			EventBus.store_entered.connect(CameraManager._on_store_entered)
	if _autoload_store_exited_connected:
		if not EventBus.store_exited.is_connected(
			CameraManager._on_store_exited
		):
			EventBus.store_exited.connect(CameraManager._on_store_exited)


func _on_camera_changed(camera: Camera3D) -> void:
	_received_cameras.append(camera)
	_signal_count += 1


# ── 1. Initial state ──────────────────────────────────────────────────────────


func test_get_active_camera_returns_null_before_any_registration() -> void:
	assert_null(
		_manager.get_active_camera(),
		"get_active_camera() must return null before any camera is registered"
	)


func test_active_camera_property_is_null_before_any_registration() -> void:
	assert_null(
		_manager.active_camera,
		"active_camera property must be null before any camera is registered"
	)


# ── 2. register_camera — stores camera ───────────────────────────────────────


func test_register_camera_sets_active_camera() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	_manager.register_camera(cam)
	assert_eq(
		_manager.get_active_camera(),
		cam,
		"get_active_camera() must return the camera passed to register_camera()"
	)


func test_register_camera_emits_active_camera_changed() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	_manager.register_camera(cam)
	assert_eq(
		_signal_count, 1,
		"register_camera() must emit active_camera_changed exactly once"
	)


func test_register_camera_emits_signal_with_correct_camera() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	_manager.register_camera(cam)
	assert_eq(
		_received_cameras.size(), 1,
		"Exactly one active_camera_changed signal should have been received"
	)
	if _received_cameras.size() > 0:
		assert_eq(
			_received_cameras[0], cam,
			"active_camera_changed must carry the registered camera"
		)


# ── 3. Double-register — second camera replaces first ────────────────────────


func test_registering_second_camera_replaces_first() -> void:
	var cam_a: Camera3D = Camera3D.new()
	var cam_b: Camera3D = Camera3D.new()
	add_child_autofree(cam_a)
	add_child_autofree(cam_b)
	_manager.register_camera(cam_a)
	_manager.register_camera(cam_b)
	assert_eq(
		_manager.get_active_camera(),
		cam_b,
		"get_active_camera() must return cam_b after registering it over cam_a"
	)


func test_registering_second_camera_emits_signal_twice() -> void:
	var cam_a: Camera3D = Camera3D.new()
	var cam_b: Camera3D = Camera3D.new()
	add_child_autofree(cam_a)
	add_child_autofree(cam_b)
	_manager.register_camera(cam_a)
	_manager.register_camera(cam_b)
	assert_eq(
		_signal_count, 2,
		"active_camera_changed must be emitted once per register_camera() call"
	)


func test_registering_second_camera_emits_with_new_camera() -> void:
	var cam_a: Camera3D = Camera3D.new()
	var cam_b: Camera3D = Camera3D.new()
	add_child_autofree(cam_a)
	add_child_autofree(cam_b)
	_manager.register_camera(cam_a)
	_manager.register_camera(cam_b)
	assert_eq(
		_received_cameras[-1], cam_b,
		"The last active_camera_changed emission must carry cam_b"
	)


# ── 4. Null-camera guard ──────────────────────────────────────────────────────


func test_register_camera_null_does_not_crash() -> void:
	_manager.register_camera(null)
	assert_true(true, "register_camera(null) must not crash")


func test_register_camera_null_sets_active_camera_to_null() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	_manager.register_camera(cam)
	_manager.register_camera(null)
	assert_null(
		_manager.get_active_camera(),
		"get_active_camera() must return null after register_camera(null)"
	)


func test_register_camera_null_emits_signal() -> void:
	_signal_count = 0
	_manager.register_camera(null)
	assert_eq(
		_signal_count, 1,
		"register_camera(null) must still emit active_camera_changed"
	)


# ── 5. store_entered signal — store camera becomes active ────────────────────


func test_store_entered_activates_registered_store_camera() -> void:
	var store_cam: Camera3D = Camera3D.new()
	add_child_autofree(store_cam)
	_manager.register_store_camera(_STORE_ID, store_cam)
	EventBus.store_entered.emit(_STORE_ID)
	assert_eq(
		_manager.get_active_camera(),
		store_cam,
		"store_entered must activate the camera registered for that store_id"
	)


func test_store_entered_emits_active_camera_changed_with_store_camera() -> void:
	var store_cam: Camera3D = Camera3D.new()
	add_child_autofree(store_cam)
	_manager.register_store_camera(_STORE_ID, store_cam)
	_signal_count = 0
	_received_cameras.clear()
	EventBus.store_entered.emit(_STORE_ID)
	assert_eq(
		_signal_count, 1,
		"store_entered must emit active_camera_changed exactly once"
	)
	if _received_cameras.size() > 0:
		assert_eq(
			_received_cameras[0], store_cam,
			"active_camera_changed must carry the store's camera on store_entered"
		)


func test_store_entered_unknown_store_does_not_change_camera() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	_manager.register_camera(cam)
	_signal_count = 0
	EventBus.store_entered.emit(&"unknown_store")
	assert_eq(
		_manager.get_active_camera(), cam,
		"store_entered with unregistered store_id must not change the active camera"
	)
	assert_eq(
		_signal_count, 0,
		"store_entered with unregistered store_id must not emit active_camera_changed"
	)


# ── 6. store_exited signal — hallway camera becomes active ───────────────────


func test_store_exited_activates_hallway_camera() -> void:
	var hallway_cam: Camera3D = Camera3D.new()
	var store_cam: Camera3D = Camera3D.new()
	add_child_autofree(hallway_cam)
	add_child_autofree(store_cam)
	_manager.register_hallway_camera(hallway_cam)
	_manager.register_store_camera(_STORE_ID, store_cam)
	EventBus.store_entered.emit(_STORE_ID)
	EventBus.store_exited.emit(_STORE_ID)
	assert_eq(
		_manager.get_active_camera(),
		hallway_cam,
		"store_exited must activate the registered hallway camera"
	)


func test_store_exited_emits_active_camera_changed_with_hallway_camera() -> void:
	var hallway_cam: Camera3D = Camera3D.new()
	var store_cam: Camera3D = Camera3D.new()
	add_child_autofree(hallway_cam)
	add_child_autofree(store_cam)
	_manager.register_hallway_camera(hallway_cam)
	_manager.register_store_camera(_STORE_ID, store_cam)
	EventBus.store_entered.emit(_STORE_ID)
	_signal_count = 0
	_received_cameras.clear()
	EventBus.store_exited.emit(_STORE_ID)
	assert_eq(
		_signal_count, 1,
		"store_exited must emit active_camera_changed exactly once"
	)
	if _received_cameras.size() > 0:
		assert_eq(
			_received_cameras[0], hallway_cam,
			"active_camera_changed must carry the hallway camera on store_exited"
		)


func test_store_exited_without_hallway_camera_emits_null() -> void:
	_signal_count = 0
	_received_cameras.clear()
	EventBus.store_exited.emit(_STORE_ID)
	assert_eq(
		_signal_count, 1,
		"store_exited must emit active_camera_changed even when no hallway camera is registered"
	)
	assert_null(
		_manager.get_active_camera(),
		"get_active_camera() must return null when no hallway camera is registered and store exits"
	)
