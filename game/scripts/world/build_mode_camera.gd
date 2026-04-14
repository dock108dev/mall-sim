## Handles camera transitions between orbit and top-down orthographic for build mode.
class_name BuildModeCamera
extends Node

const TRANSITION_DURATION: float = 0.4
const TOP_DOWN_HEIGHT: float = 12.0
const ORTHO_SIZE: float = 6.0
const ZOOM_MIN: float = 3.0
const ZOOM_MAX: float = 15.0
const ZOOM_STEP: float = 1.0
const PAN_SPEED: float = 0.02

var _camera: Camera3D = null
var _tween: Tween = null

var _saved_position: Vector3 = Vector3.ZERO
var _saved_rotation: Vector3 = Vector3.ZERO
var _saved_projection: Camera3D.ProjectionType = Camera3D.PROJECTION_PERSPECTIVE
var _saved_fov: float = 75.0
var _saved_ortho_size: float = 6.0

var _target_center: Vector3 = Vector3.ZERO
var _store_bounds_min: Vector3 = Vector3.ZERO
var _store_bounds_max: Vector3 = Vector3.ZERO
var is_transitioning: bool = false
var _is_top_down: bool = false


## Stores the look target; camera is obtained from CameraManager.
func initialize(look_target: Vector3) -> void:
	_target_center = look_target
	if CameraManager.active_camera:
		_camera = CameraManager.active_camera


## Sets the store floor bounds for pan clamping.
func set_store_bounds(
	bounds_min: Vector3, bounds_max: Vector3
) -> void:
	_store_bounds_min = bounds_min
	_store_bounds_max = bounds_max


## Updates the camera reference when the active camera changes.
func update_camera(camera: Camera3D) -> void:
	if is_transitioning:
		return
	_camera = camera


## Zooms in the top-down camera by one step.
func zoom_in() -> void:
	if not _is_top_down or not is_instance_valid(_camera):
		return
	var new_height: float = clampf(
		_camera.global_position.y - ZOOM_STEP,
		ZOOM_MIN, ZOOM_MAX
	)
	_camera.global_position.y = new_height


## Zooms out the top-down camera by one step.
func zoom_out() -> void:
	if not _is_top_down or not is_instance_valid(_camera):
		return
	var new_height: float = clampf(
		_camera.global_position.y + ZOOM_STEP,
		ZOOM_MIN, ZOOM_MAX
	)
	_camera.global_position.y = new_height


## Pans the camera by a screen-space delta (middle-mouse drag).
func pan(mouse_delta: Vector2) -> void:
	if not _is_top_down or not is_instance_valid(_camera):
		return
	var offset_x: float = -mouse_delta.x * PAN_SPEED
	var offset_z: float = -mouse_delta.y * PAN_SPEED
	var pos: Vector3 = _camera.global_position
	pos.x = clampf(
		pos.x + offset_x,
		_store_bounds_min.x, _store_bounds_max.x
	)
	pos.z = clampf(
		pos.z + offset_z,
		_store_bounds_min.z, _store_bounds_max.z
	)
	_camera.global_position = pos


## Tweens from current orbit view to top-down orthographic.
func transition_to_top_down() -> void:
	if not is_instance_valid(_camera) or is_transitioning:
		return
	is_transitioning = true

	_saved_position = _camera.global_position
	_saved_rotation = _camera.global_rotation
	_saved_projection = _camera.projection
	_saved_fov = _camera.fov
	_saved_ortho_size = _camera.size

	_kill_tween()
	_tween = _camera.create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)

	var top_pos := Vector3(
		_target_center.x,
		TOP_DOWN_HEIGHT,
		_target_center.z
	)
	var top_rot := Vector3(deg_to_rad(-90.0), 0.0, 0.0)

	_tween.tween_property(
		_camera, "global_position", top_pos, TRANSITION_DURATION
	)
	_tween.tween_property(
		_camera, "global_rotation", top_rot, TRANSITION_DURATION
	)
	_tween.tween_property(
		_camera, "fov", 1.0, TRANSITION_DURATION * 0.5
	)

	_tween.chain().tween_callback(_apply_orthographic)
	_tween.chain().tween_callback(_on_top_down_complete)


## Tweens from top-down orthographic back to saved orbit position.
func transition_to_orbit() -> void:
	if not is_instance_valid(_camera) or is_transitioning:
		return
	is_transitioning = true
	_is_top_down = false

	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 1.0

	_kill_tween()
	_tween = _camera.create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)

	_tween.tween_property(
		_camera, "global_position",
		_saved_position, TRANSITION_DURATION
	)
	_tween.tween_property(
		_camera, "global_rotation",
		_saved_rotation, TRANSITION_DURATION
	)
	_tween.tween_property(
		_camera, "fov", _saved_fov, TRANSITION_DURATION
	)

	_tween.chain().tween_callback(_on_transition_complete)


func _apply_orthographic() -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = ORTHO_SIZE


func _on_top_down_complete() -> void:
	is_transitioning = false
	_is_top_down = true


func _on_transition_complete() -> void:
	is_transitioning = false


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
