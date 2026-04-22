## Orbit camera controller with mouse-based interaction.
extends Node3D

## Horizontal orbit speed in radians per pixel of mouse drag.
@export var orbit_sensitivity: float = 0.005
## Keyboard orbit speed in radians per second.
@export var keyboard_orbit_speed: float = 2.0
## Minimum zoom distance from pivot.
@export var zoom_min: float = 3.0
## Maximum zoom distance from pivot.
@export var zoom_max: float = 12.0
## Zoom step per scroll tick.
@export var zoom_step: float = 0.5
## Minimum vertical angle in degrees (looking down).
@export var pitch_min_deg: float = -60.0
## Maximum vertical angle in degrees (looking up).
@export var pitch_max_deg: float = -15.0
## Vertical orbit sensitivity in radians per pixel.
@export var pitch_sensitivity: float = 0.003

var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-40.0)
var _zoom: float = 8.0
var _is_orbiting: bool = false
var _build_mode_active: bool = false

@onready var _camera: Camera3D = $Camera3D
@onready var _interaction_ray: Node = $InteractionRay


func _ready() -> void:
	InputHelper.unlock_cursor()
	_update_camera_transform()


func _unhandled_input(event: InputEvent) -> void:
	if _build_mode_active:
		return

	if event is InputEventMouseButton:
		var mb_event := event as InputEventMouseButton
		_handle_mouse_button(mb_event)

	if event is InputEventMouseMotion and _is_orbiting:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * orbit_sensitivity
		_pitch -= motion.relative.y * pitch_sensitivity
		_pitch = clampf(
			_pitch,
			deg_to_rad(pitch_min_deg),
			deg_to_rad(pitch_max_deg)
		)
		_update_camera_transform()


func _process(delta: float) -> void:
	if _build_mode_active:
		return

	var orbit_dir: float = InputHelper.get_axis_strength(
		&"orbit_left", &"orbit_right"
	)
	if orbit_dir != 0.0:
		_yaw -= orbit_dir * keyboard_orbit_speed * delta
		_update_camera_transform()


## Sets the InventorySystem on the interaction ray for tooltip lookups.
func set_inventory_system(inv: InventorySystem) -> void:
	_interaction_ray.set_inventory_system(inv)


## Enables or disables orbit controls for build mode.
func set_build_mode(active: bool) -> void:
	_build_mode_active = active
	_is_orbiting = false


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_is_orbiting = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom = clampf(_zoom - zoom_step, zoom_min, zoom_max)
				_update_camera_transform()
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom = clampf(_zoom + zoom_step, zoom_min, zoom_max)
				_update_camera_transform()


func _update_camera_transform() -> void:
	var offset := Vector3.ZERO
	offset.x = _zoom * cos(_pitch) * sin(_yaw)
	offset.y = -_zoom * sin(_pitch)
	offset.z = _zoom * cos(_pitch) * cos(_yaw)
	_camera.position = offset
	_camera.look_at(Vector3.ZERO)
