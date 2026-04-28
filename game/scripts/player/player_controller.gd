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
## Movement speed in world units per second for WASD locomotion.
@export var move_speed: float = 6.0
## Interpolation weight per second for smooth camera movement.
@export var lerp_speed: float = 12.0
## Store boundary min corner for pivot clamping.
@export var store_bounds_min: Vector3 = Vector3(-7.0, 0.0, -5.0)
## Store boundary max corner for pivot clamping.
@export var store_bounds_max: Vector3 = Vector3(7.0, 0.0, 5.0)
## Starting zoom distance from pivot in meters. Overridable per store.
@export var zoom_default: float = 3.5
## Starting pitch angle in degrees from horizontal. Overridable per store.
@export var pitch_default_deg: float = 50.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var _zoom: float = 0.0
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _target_zoom: float = 0.0
var _pivot: Vector3 = Vector3.ZERO
var _target_pivot: Vector3 = Vector3.ZERO
var _is_orbiting: bool = false
var _is_panning: bool = false
var _build_mode_active: bool = false
var _input_listening: bool = true

@onready var _camera: Camera3D = _resolve_camera()


func _ready() -> void:
	_pitch = deg_to_rad(pitch_default_deg)
	_target_pitch = _pitch
	_zoom = zoom_default
	_target_zoom = _zoom
	InputHelper.unlock_cursor()
	_update_camera_transform()
	if _camera:
		_camera.current = false
	add_to_group(&"player_controller")
	var eb: Node = _get_event_bus()
	if eb != null and eb.has_signal("nav_zone_selected"):
		eb.nav_zone_selected.connect(_on_nav_zone_selected)


func _unhandled_input(event: InputEvent) -> void:
	if _build_mode_active:
		return
	if not _input_listening:
		return
	if not _input_focus_allows_gameplay():
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

	for i: int in range(1, 6):
		if event.is_action_pressed("nav_zone_%d" % i):
			_jump_to_nav_zone(i)
			return


func _process(delta: float) -> void:
	if _build_mode_active:
		return

	_apply_keyboard_movement(delta)

	var weight: float = clampf(lerp_speed * delta, 0.0, 1.0)
	_yaw = lerp_angle(_yaw, _target_yaw, weight)
	_pitch = lerpf(_pitch, _target_pitch, weight)
	_zoom = lerpf(_zoom, _target_zoom, weight)
	_pivot = _pivot.lerp(_target_pivot, weight)
	_update_camera_transform()


## Toggles whether this controller listens for unhandled input. Owners must
## route through this method instead of calling `set_process_unhandled_input`
## directly (enforced by `tests/validate_input_focus.sh`). Process tick is
## left to the caller via `set_process(...)`.
func set_input_listening(listening: bool) -> void:
	_input_listening = listening
	if not listening:
		_is_orbiting = false
		_is_panning = false


## Enables or disables orbit controls for build mode.
func set_build_mode(active: bool) -> void:
	_build_mode_active = active
	_is_orbiting = false
	_is_panning = false


## Exposes the controlled camera for interaction ray and build mode wiring.
func get_camera() -> Camera3D:
	if _camera:
		return _camera
	return _resolve_camera()


## Resolves the controller's own child Camera3D — `StoreCamera` is the
## established convention; legacy scenes still ship a default `Camera3D`,
## resolve either in that order.
##
## §F-36 — returning null when neither child exists is silent on purpose:
## CameraAuthority asserts exactly one current camera at every `store_ready`
## (per docs/architecture/ownership.md), and the StoreReadyContract
## `camera_current` invariant fails loudly if no Camera2D/3D under the scene
## reports `current=true`. Adding a `push_error` here would double-fire on
## the same contract violation.
func _resolve_camera() -> Camera3D:
	var cam: Camera3D = get_node_or_null("StoreCamera") as Camera3D
	if cam != null:
		return cam
	return get_node_or_null("Camera3D") as Camera3D


## Teleports camera pivot and smoothing target to the same position.
func set_pivot(pivot_position: Vector3) -> void:
	_target_pivot = pivot_position.clamp(store_bounds_min, store_bounds_max)
	_pivot = _target_pivot
	_update_camera_transform()


## Sets yaw and pitch in degrees for startup camera framing.
func set_camera_angles(yaw_deg: float, pitch_deg: float) -> void:
	_target_yaw = deg_to_rad(yaw_deg)
	_target_pitch = deg_to_rad(
		clampf(pitch_deg, pitch_min_deg, pitch_max_deg)
	)
	_yaw = _target_yaw
	_pitch = _target_pitch
	_update_camera_transform()


## Sets zoom immediately and clamps to camera limits.
func set_zoom_distance(zoom_distance: float) -> void:
	_target_zoom = clampf(zoom_distance, zoom_min, zoom_max)
	_zoom = _target_zoom
	_update_camera_transform()


## Returns the current pivot world position for diagnostic reads.
func get_pivot() -> Vector3:
	return _pivot


## Returns true when movement input is currently allowed by InputFocus.
func can_move() -> bool:
	return _input_focus_allows_gameplay()


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


func _apply_keyboard_movement(delta: float) -> void:
	if not _input_focus_allows_gameplay():
		return
	var movement_input: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back",
	)
	if movement_input.is_zero_approx():
		return

	var forward: Vector3 = Vector3(
		-sin(_target_yaw),
		0.0,
		-cos(_target_yaw)
	).normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var movement_dir: Vector3 = (
		right * movement_input.x
		+ forward * -movement_input.y
	).normalized()
	_target_pivot += movement_dir * move_speed * delta
	_target_pivot = _target_pivot.clamp(store_bounds_min, store_bounds_max)


## Returns true when the InputFocus autoload either is absent (test/unit
## context) or reports `&"store_gameplay"`. Any other context (modal, mall
## hub, menu) suppresses gameplay input — see ownership.md row 5.
func _input_focus_allows_gameplay() -> bool:
	var ifocus: Node = _get_input_focus()
	if ifocus == null or not ifocus.has_method("current"):
		return true
	var ctx: StringName = ifocus.call("current")
	if ctx == &"":
		return true
	return ctx == &"store_gameplay"


func _get_input_focus() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("InputFocus")


func _get_event_bus() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("EventBus")


## Snaps pivot to zone_position when nav_zone_selected fires on the EventBus.
func _on_nav_zone_selected(zone_position: Vector3) -> void:
	set_pivot(zone_position)


## Finds the nav zone with the given index (1–5) in the "nav_zone" group and
## teleports the camera pivot there. No-op when no matching zone exists.
func _jump_to_nav_zone(index: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var zones: Array[Node] = tree.get_nodes_in_group(&"nav_zone")
	for zone: Node in zones:
		if int(zone.get("zone_index")) == index:
			set_pivot(zone.global_position)
			return


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
