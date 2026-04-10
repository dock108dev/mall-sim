## Camera controller for the mall hallway that pans along the corridor.
class_name MallCameraController
extends Node3D

## Horizontal pan speed in world units per second.
@export var pan_speed: float = 8.0
## Camera height above the floor.
@export var camera_height: float = 3.5
## Camera distance from the storefront wall.
@export var camera_depth: float = 6.0
## Pitch angle in degrees (looking slightly downward).
@export var camera_pitch_deg: float = 15.0
## Minimum X position the camera can reach.
@export var bounds_min_x: float = -16.0
## Maximum X position the camera can reach.
@export var bounds_max_x: float = 16.0
## Interpolation weight per second for smooth movement.
@export var lerp_speed: float = 6.0

@onready var _camera: Camera3D = $Camera3D

var _target_x: float = 0.0
var _current_x: float = 0.0


func _ready() -> void:
	_current_x = 0.0
	_target_x = 0.0
	_update_camera_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_snap_to_nearest_storefront(-1)
	elif event.is_action_pressed("camera_zoom_out"):
		_snap_to_nearest_storefront(1)


func _process(delta: float) -> void:
	var input_dir: float = 0.0
	if Input.is_action_pressed("orbit_left"):
		input_dir -= 1.0
	if Input.is_action_pressed("orbit_right"):
		input_dir += 1.0

	if not is_zero_approx(input_dir):
		_target_x += input_dir * pan_speed * delta
		_target_x = clampf(_target_x, bounds_min_x, bounds_max_x)

	var weight: float = clampf(lerp_speed * delta, 0.0, 1.0)
	_current_x = lerpf(_current_x, _target_x, weight)
	_update_camera_transform()


## Moves the camera to focus on a specific world X position.
func focus_on_position(x_pos: float) -> void:
	_target_x = clampf(x_pos, bounds_min_x, bounds_max_x)


## Returns the Camera3D node for interaction ray setup.
func get_camera() -> Camera3D:
	return _camera


func _update_camera_transform() -> void:
	if not _camera:
		return
	global_position = Vector3(
		_current_x, camera_height, camera_depth
	)
	_camera.rotation_degrees = Vector3(-camera_pitch_deg, 0.0, 0.0)


func _snap_to_nearest_storefront(direction: int) -> void:
	var storefront_positions: Array[float] = [
		-14.0, -7.0, 0.0, 7.0, 14.0,
	]

	var best_x: float = _target_x
	var best_dist: float = INF

	for pos: float in storefront_positions:
		var diff: float = pos - _target_x
		if direction < 0 and diff >= -0.5:
			continue
		if direction > 0 and diff <= 0.5:
			continue
		var dist: float = absf(diff)
		if dist < best_dist:
			best_dist = dist
			best_x = pos

	_target_x = clampf(best_x, bounds_min_x, bounds_max_x)
