## Handles camera transitions between orbit and top-down orthographic for build mode.
class_name BuildModeCamera
extends Node

const TRANSITION_DURATION: float = 0.4
const TOP_DOWN_HEIGHT: float = 12.0
const ORTHO_SIZE: float = 6.0

var _camera: Camera3D = null
var _tween: Tween = null

var _saved_position: Vector3 = Vector3.ZERO
var _saved_rotation: Vector3 = Vector3.ZERO
var _saved_projection: Camera3D.ProjectionType = Camera3D.PROJECTION_PERSPECTIVE
var _saved_fov: float = 75.0
var _saved_ortho_size: float = 6.0

var _target_center: Vector3 = Vector3.ZERO
var is_transitioning: bool = false


## Stores a reference to the camera to transition.
func initialize(camera: Camera3D, look_target: Vector3) -> void:
	_camera = camera
	_target_center = look_target


## Tweens from current orbit view to top-down orthographic.
func transition_to_top_down() -> void:
	if not _camera or is_transitioning:
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
	_tween.set_ease(Tween.EASE_IN_OUT)
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
	_tween.chain().tween_callback(_on_transition_complete)


## Tweens from top-down orthographic back to saved orbit position.
func transition_to_orbit() -> void:
	if not _camera or is_transitioning:
		return
	is_transitioning = true

	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 1.0

	_kill_tween()
	_tween = _camera.create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_IN_OUT)
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


func _on_transition_complete() -> void:
	is_transitioning = false


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
