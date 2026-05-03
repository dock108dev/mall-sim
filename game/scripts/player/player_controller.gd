## Fixed-frame store/hub camera with WASD pivot locomotion.
class_name PlayerController
extends Node3D

## Minimum zoom distance from pivot in meters.
@export var zoom_min: float = 3.0
## Maximum zoom distance from pivot in meters.
@export var zoom_max: float = 15.0
## Minimum pitch angle in degrees from horizontal.
@export var pitch_min_deg: float = 10.0
## Maximum pitch angle in degrees from horizontal.
@export var pitch_max_deg: float = 80.0
## Movement speed in world units per second for WASD locomotion.
@export var move_speed: float = 6.0
## Interpolation weight per second for smooth pivot movement.
@export var lerp_speed: float = 12.0
## Store boundary min corner for pivot clamping.
@export var store_bounds_min: Vector3 = Vector3(-7.0, 0.0, -5.0)
## Store boundary max corner for pivot clamping.
@export var store_bounds_max: Vector3 = Vector3(7.0, 0.0, 5.0)
## Starting zoom distance from pivot in meters. Overridable per store.
@export var zoom_default: float = 3.5
## Starting pitch angle in degrees from horizontal. Overridable per store.
@export var pitch_default_deg: float = 50.0
## When true, the camera renders with PROJECTION_ORTHOGONAL with the
## orthogonal view size pinned to `ortho_size_default`. The legacy orbit /
## pan / scroll-zoom inputs are gone; the camera frames a fixed angled view
## of the store interior.
@export var is_orthographic: bool = false
## Orthogonal view size in world units (vertical extent).
@export var ortho_size_default: float = 10.0
## Collision mask used when probing fixture bodies during pivot movement.
## Defaults to layers 1+2 (`world_geometry` + `store_fixtures`) so the pivot
## probe rejects positions that would embed inside walls or interior
## fixtures. See `project.godot [layer_names]` for the canonical scheme.
@export_flags_3d_physics var fixture_collision_mask: int = 3
## Half-extent of the box probe used to test whether the next pivot position
## would embed inside a fixture body. Sized so the probe sits between the
## floor top (Y≈0.05) and the lowest fixture top (GlassCase ≈ Y=0.85).
@export var fixture_probe_extents: Vector3 = Vector3(0.25, 0.25, 0.25)
## Vertical offset applied to the probe so it sits above the floor body and
## inside the fixture bodies. Floor StaticBody3D occupies Y∈[-0.05, 0.05];
## probe centered at Y=0.4 keeps it clear of the floor while overlapping all
## standing fixtures.
@export var fixture_probe_y_offset: float = 0.4

var _yaw: float = 0.0
var _pitch: float = 0.0
var _zoom: float = 0.0
var _ortho_size: float = 0.0
var _pivot: Vector3 = Vector3.ZERO
var _target_pivot: Vector3 = Vector3.ZERO
var _build_mode_active: bool = false
var _input_listening: bool = true

@onready var _camera: Camera3D = _resolve_camera()


func _ready() -> void:
	_pitch = deg_to_rad(pitch_default_deg)
	_zoom = zoom_default
	_ortho_size = ortho_size_default
	InputHelper.unlock_cursor()
	if _camera != null and is_orthographic:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = _ortho_size
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

	for i: int in range(1, 6):
		if event.is_action_pressed("nav_zone_%d" % i):
			_jump_to_nav_zone(i)
			return


func _process(delta: float) -> void:
	if _build_mode_active:
		return

	_apply_keyboard_movement(delta)

	var weight: float = clampf(lerp_speed * delta, 0.0, 1.0)
	_pivot = _pivot.lerp(_target_pivot, weight)
	_update_camera_transform()


## Toggles whether this controller listens for unhandled input. Owners must
## route through this method instead of calling `set_process_unhandled_input`
## directly (enforced by `tests/validate_input_focus.sh`). Process tick is
## left to the caller via `set_process(...)`.
func set_input_listening(listening: bool) -> void:
	_input_listening = listening


## Suspends pivot updates while build mode is active.
func set_build_mode(active: bool) -> void:
	_build_mode_active = active


## Exposes the controlled camera for interaction ray and build mode wiring.
func get_camera() -> Camera3D:
	if _camera:
		return _camera
	return _resolve_camera()


## Resolves the controller's own child `StoreCamera` (the only convention
## any shipping scene authors).
##
## §F-36 — returning null when the child is missing is silent on purpose:
## CameraAuthority asserts exactly one current camera at every `store_ready`
## (per docs/architecture/ownership.md), and the StoreReadyContract
## `camera_current` invariant fails loudly if no Camera2D/3D under the scene
## reports `current=true`. Adding a `push_error` here would double-fire on
## the same contract violation.
func _resolve_camera() -> Camera3D:
	return get_node_or_null("StoreCamera") as Camera3D


## Teleports camera pivot and smoothing target to the same position.
func set_pivot(pivot_position: Vector3) -> void:
	_target_pivot = pivot_position.clamp(store_bounds_min, store_bounds_max)
	_pivot = _target_pivot
	_update_camera_transform()


## Sets yaw and pitch in degrees for startup camera framing.
func set_camera_angles(yaw_deg: float, pitch_deg: float) -> void:
	_yaw = deg_to_rad(yaw_deg)
	_pitch = deg_to_rad(
		clampf(pitch_deg, pitch_min_deg, pitch_max_deg)
	)
	_update_camera_transform()


## Sets zoom immediately and clamps to camera limits.
func set_zoom_distance(zoom_distance: float) -> void:
	_zoom = clampf(zoom_distance, zoom_min, zoom_max)
	_update_camera_transform()


## Returns the current pivot world position for diagnostic reads.
func get_pivot() -> Vector3:
	return _pivot


## Returns true when movement input is currently allowed by InputFocus.
func can_move() -> bool:
	return _input_focus_allows_gameplay()


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
		-sin(_yaw),
		0.0,
		-cos(_yaw)
	).normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var movement_dir: Vector3 = (
		right * movement_input.x
		+ forward * -movement_input.y
	).normalized()
	var step: Vector3 = movement_dir * move_speed * delta
	_target_pivot = _resolve_pivot_step(_target_pivot, step)


## Returns the next pivot position after applying `step`, sliding around
## fixture bodies if a full move would embed the pivot inside one. Falls back
## to single-axis slides (Z then X) when the combined move is blocked, then
## refuses the move outright if both axes are blocked. Always clamps to the
## configured store bounds. Public for tests; not part of the input flow.
func resolve_pivot_step(current: Vector3, step: Vector3) -> Vector3:
	return _resolve_pivot_step(current, step)


func _resolve_pivot_step(current: Vector3, step: Vector3) -> Vector3:
	var full: Vector3 = (current + step).clamp(
		store_bounds_min, store_bounds_max
	)
	if not _pivot_blocked(full):
		return full
	var slide_z: Vector3 = Vector3(current.x, current.y, full.z).clamp(
		store_bounds_min, store_bounds_max
	)
	if not _pivot_blocked(slide_z):
		return slide_z
	var slide_x: Vector3 = Vector3(full.x, current.y, current.z).clamp(
		store_bounds_min, store_bounds_max
	)
	if not _pivot_blocked(slide_x):
		return slide_x
	return current


## Returns true when a probe box at `candidate` overlaps any StaticBody3D on
## `fixture_collision_mask`. Returns false when no World3D / space state is
## available (e.g. unit tests without a physics scene), so headless tests
## without a physics tree see no false-positive blocking.
func _pivot_blocked(candidate: Vector3) -> bool:
	var world: World3D = get_world_3d()
	if world == null:
		return false
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return false
	var shape := BoxShape3D.new()
	shape.size = fixture_probe_extents * 2.0
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(
		Basis.IDENTITY,
		candidate + Vector3(0.0, fixture_probe_y_offset, 0.0)
	)
	params.collision_mask = fixture_collision_mask
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return not space.intersect_shape(params, 1).is_empty()


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
	if is_orthographic:
		_camera.size = _ortho_size
	global_position = _pivot
