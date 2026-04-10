## Floating orbit camera centered on store interior with zoom and pan.
class_name PlayerController
extends Node3D

## Orbit sensitivity in radians per pixel of mouse drag.
@export var orbit_sensitivity: float = 0.005
## Vertical orbit sensitivity in radians per pixel.
@export var pitch_sensitivity: float = 0.003
## Zoom step per scroll tick in meters.
@export var zoom_step: float = 0.5
## Minimum zoom distance from pivot in meters.
@export var zoom_min: float = 3.0
## Maximum zoom distance from pivot in meters.
@export var zoom_max: float = 15.0
## Minimum pitch angle in degrees from horizontal.
@export var pitch_min_deg: float = 10.0
## Maximum pitch angle in degrees from horizontal.
@export var pitch_max_deg: float = 80.0
## Pan speed in world units per pixel of mouse drag.
@export var pan_speed: float = 0.02
## Interpolation weight per second for smooth camera movement.
@export var lerp_speed: float = 12.0
## Store boundary min corner for pivot clamping.
@export var store_bounds_min: Vector3 = Vector3(-7.0, 0.0, -5.0)
## Store boundary max corner for pivot clamping.
@export var store_bounds_max: Vector3 = Vector3(7.0, 0.0, 5.0)

@onready var _camera: Camera3D = $Camera3D

var _yaw: float = 0.0
var _pitch: float = deg_to_rad(40.0)
var _zoom: float = 8.0
var _target_yaw: float = 0.0
var _target_pitch: float = deg_to_rad(40.0)
var _target_zoom: float = 8.0
var _pivot: Vector3 = Vector3.ZERO
var _target_pivot: Vector3 = Vector3.ZERO
var _is_orbiting: bool = false
var _is_panning: bool = false
var _build_mode_active: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_camera_transform()


func _unhandled_input(event: InputEvent) -> void:
	if _build_mode_active:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _is_orbiting:
			_handle_orbit(motion)
		elif _is_panning:
			_handle_pan(motion)

	if event.is_action_pressed("camera_zoom_in"):
		_target_zoom = clampf(_target_zoom - zoom_step, zoom_min, zoom_max)

	if event.is_action_pressed("camera_zoom_out"):
		_target_zoom = clampf(_target_zoom + zoom_step, zoom_min, zoom_max)


func _process(delta: float) -> void:
	if _build_mode_active:
		return

	var weight: float = clampf(lerp_speed * delta, 0.0, 1.0)
	_yaw = lerp_angle(_yaw, _target_yaw, weight)
	_pitch = lerpf(_pitch, _target_pitch, weight)
	_zoom = lerpf(_zoom, _target_zoom, weight)
	_pivot = _pivot.lerp(_target_pivot, weight)
	_update_camera_transform()


## Enables or disables orbit controls for build mode.
func set_build_mode(active: bool) -> void:
	_build_mode_active = active
	_is_orbiting = false
	_is_panning = false


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.is_action("camera_orbit"):
		_is_orbiting = event.pressed
	elif event.is_action("camera_pan"):
		_is_panning = event.pressed


func _handle_orbit(motion: InputEventMouseMotion) -> void:
	_target_yaw -= motion.relative.x * orbit_sensitivity
	_target_pitch += motion.relative.y * pitch_sensitivity
	_target_pitch = clampf(
		_target_pitch,
		deg_to_rad(pitch_min_deg),
		deg_to_rad(pitch_max_deg)
	)


func _handle_pan(motion: InputEventMouseMotion) -> void:
	var right: Vector3 = _camera.global_transform.basis.x
	var forward: Vector3 = Vector3(sin(_yaw), 0.0, cos(_yaw))
	var pan_offset: Vector3 = (
		-right * motion.relative.x * pan_speed
		+ forward * motion.relative.y * pan_speed
	)
	_target_pivot += pan_offset
	_target_pivot = _target_pivot.clamp(store_bounds_min, store_bounds_max)


func _update_camera_transform() -> void:
	if not _camera:
		return
	var offset := Vector3.ZERO
	offset.x = _zoom * cos(_pitch) * sin(_yaw)
	offset.y = _zoom * sin(_pitch)
	offset.z = _zoom * cos(_pitch) * cos(_yaw)
	_camera.position = offset
	_camera.look_at(_pivot)
	global_position = _pivot
