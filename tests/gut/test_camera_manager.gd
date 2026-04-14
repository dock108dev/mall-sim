## Tests CameraManager: active camera tracking and signal emission.
extends GutTest


var _manager: Node
var _received_camera: Camera3D = null
var _signal_count: int = 0


func before_each() -> void:
	_received_camera = null
	_signal_count = 0
	_manager = Node.new()
	_manager.set_script(
		preload("res://game/autoload/camera_manager.gd")
	)
	EventBus.active_camera_changed.connect(_on_camera_changed)
	add_child_autofree(_manager)


func after_each() -> void:
	if EventBus.active_camera_changed.is_connected(_on_camera_changed):
		EventBus.active_camera_changed.disconnect(_on_camera_changed)


func _on_camera_changed(camera: Camera3D) -> void:
	_received_camera = camera
	_signal_count += 1


func test_initial_active_camera_is_null() -> void:
	assert_null(
		_manager.active_camera,
		"Should start with null active camera"
	)


func test_active_camera_updates_on_process() -> void:
	var cam := Camera3D.new()
	cam.current = true
	add_child_autofree(cam)
	_manager._process(0.0)
	assert_eq(
		_manager.active_camera, cam,
		"Should detect new active camera after _process"
	)


func test_signal_emitted_on_camera_change() -> void:
	var cam := Camera3D.new()
	cam.current = true
	add_child_autofree(cam)
	_manager._process(0.0)
	assert_eq(
		_received_camera, cam,
		"Should emit active_camera_changed with correct camera"
	)
	assert_eq(
		_signal_count, 1,
		"Should emit exactly one signal"
	)


func test_no_signal_when_camera_unchanged() -> void:
	var cam := Camera3D.new()
	cam.current = true
	add_child_autofree(cam)
	_manager._process(0.0)
	_signal_count = 0
	_manager._process(0.0)
	assert_eq(
		_signal_count, 0,
		"Should not emit signal when camera has not changed"
	)


func test_detects_camera_switch() -> void:
	var cam1 := Camera3D.new()
	cam1.current = true
	add_child_autofree(cam1)
	_manager._process(0.0)

	var cam2 := Camera3D.new()
	cam2.current = true
	add_child_autofree(cam2)
	_manager._process(0.0)

	assert_eq(
		_manager.active_camera, cam2,
		"Should track the newly active camera"
	)
	assert_eq(
		_signal_count, 2,
		"Should emit signal for each camera change"
	)
