## Verifies the orthographic-mode contract on PlayerController:
## projection switch, suppressed orbit/pan, scroll-zoom routing through
## ortho_size, and retro_games scene defaults that frame the 10×7 m
## interior at default view.
extends GutTest

const PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)
const RetroGamesScene: PackedScene = preload(
	"res://game/scenes/stores/retro_games.tscn"
)

# Pitch the retro_games store ships with for its orthographic camera.
const _RETRO_PITCH_DEG: float = 52.0
# Inner-floor footprint exposed by retro_games store_bounds.
const _STORE_HALF_WIDTH: float = 4.5  # X extent: ±4.5
const _STORE_HALF_DEPTH: float = 3.0  # Z extent: ±3.0
# Wall positions and full height (10×7 footprint outer walls).
const _WALL_HALF_WIDTH: float = 5.05
const _WALL_HALF_DEPTH: float = 3.55
const _WALL_HEIGHT: float = 3.0
# 1080p reference aspect ratio (16:9). Godot's orthogonal `size` measures the
# vertical extent; horizontal extent = size * aspect.
const _ASPECT_16_9: float = 16.0 / 9.0

# Shared retro_games scene instance used by the three scene-level checks below.
# Instantiating retro_games.tscn is expensive (73 sub-resources); reusing one
# instance across the read-only assertions keeps this file well within the
# suite-wide test budget.
var _retro_root: Node3D = null


func before_all() -> void:
	_retro_root = RetroGamesScene.instantiate() as Node3D
	add_child(_retro_root)


func after_all() -> void:
	if is_instance_valid(_retro_root):
		_retro_root.free()
	_retro_root = null


func _make_controller(orthographic: bool) -> PlayerController:
	var controller: PlayerController = (
		PlayerControllerScene.instantiate() as PlayerController
	)
	controller.is_orthographic = orthographic
	add_child_autofree(controller)
	return controller


func test_is_orthographic_default_is_false() -> void:
	# The script default must stay false so legacy / future stores keep their
	# current perspective behavior unless they opt in explicitly.
	var script: GDScript = load(
		"res://game/scripts/player/player_controller.gd"
	)
	var fresh: Object = script.new()
	assert_false(
		bool(fresh.get("is_orthographic")),
		"is_orthographic must default to false on the script"
	)
	if fresh is Node:
		(fresh as Node).queue_free()


func test_orthographic_ready_sets_camera_projection() -> void:
	var controller: PlayerController = _make_controller(true)
	var cam: Camera3D = controller.get_camera()
	assert_not_null(cam, "StoreCamera must resolve")
	if cam == null:
		return
	assert_eq(
		int(cam.projection), int(Camera3D.PROJECTION_ORTHOGONAL),
		"Camera3D.projection must be PROJECTION_ORTHOGONAL when "
		+ "is_orthographic = true"
	)


func test_perspective_ready_keeps_camera_perspective() -> void:
	# The default Camera3D ships with PROJECTION_PERSPECTIVE; controller must
	# not flip projection unless explicitly set to orthographic.
	var controller: PlayerController = _make_controller(false)
	var cam: Camera3D = controller.get_camera()
	assert_not_null(cam)
	if cam == null:
		return
	assert_eq(
		int(cam.projection), int(Camera3D.PROJECTION_PERSPECTIVE),
		"Camera3D.projection must remain PROJECTION_PERSPECTIVE when "
		+ "is_orthographic = false"
	)


func test_orthographic_ready_sets_camera_size_to_default() -> void:
	var controller: PlayerController = _make_controller(true)
	var cam: Camera3D = controller.get_camera()
	if cam == null:
		fail_test("StoreCamera must resolve")
		return
	assert_almost_eq(
		cam.size, controller.ortho_size_default, 0.001,
		"Camera3D.size must initialize from ortho_size_default"
	)


func test_orthographic_mode_suppresses_orbit_press() -> void:
	var controller: PlayerController = _make_controller(true)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	controller._handle_mouse_button(event)
	assert_false(
		bool(controller.get("_is_orbiting")),
		"Right-mouse press must not start orbit while is_orthographic = true"
	)


func test_orthographic_mode_suppresses_pan_press() -> void:
	var controller: PlayerController = _make_controller(true)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_MIDDLE
	event.pressed = true
	controller._handle_mouse_button(event)
	assert_false(
		bool(controller.get("_is_panning")),
		"Middle-mouse press must not start pan while is_orthographic = true"
	)


func test_perspective_mode_still_arms_orbit_and_pan() -> void:
	# Regression guard: legacy perspective stores must still drive _is_orbiting
	# and _is_panning off the camera_orbit / camera_pan input actions.
	var controller: PlayerController = _make_controller(false)
	var orbit_event: InputEventMouseButton = InputEventMouseButton.new()
	orbit_event.button_index = MOUSE_BUTTON_RIGHT
	orbit_event.pressed = true
	controller._handle_mouse_button(orbit_event)
	assert_true(
		bool(controller.get("_is_orbiting")),
		"Right-mouse press must arm orbit when is_orthographic = false"
	)
	var pan_event: InputEventMouseButton = InputEventMouseButton.new()
	pan_event.button_index = MOUSE_BUTTON_MIDDLE
	pan_event.pressed = true
	controller._handle_mouse_button(pan_event)
	assert_true(
		bool(controller.get("_is_panning")),
		"Middle-mouse press must arm pan when is_orthographic = false"
	)


func test_retro_games_scene_uses_orthographic_camera() -> void:
	var controller: PlayerController = (
		_retro_root.get_node_or_null("PlayerController") as PlayerController
	)
	assert_not_null(
		controller,
		"retro_games.tscn must embed PlayerController"
	)
	if controller == null:
		return
	assert_true(
		controller.is_orthographic,
		"retro_games PlayerController must set is_orthographic = true"
	)
	var cam: Camera3D = controller.get_camera()
	assert_not_null(cam)
	if cam == null:
		return
	assert_eq(
		int(cam.projection), int(Camera3D.PROJECTION_ORTHOGONAL),
		"retro_games StoreCamera must render with PROJECTION_ORTHOGONAL"
	)


func test_retro_games_default_view_frames_full_floor() -> void:
	# At pitch 52° looking at the floor center (0,0,0), the camera-up vector
	# is (0, cos(52°), -sin(52°)). For an orthographic camera, a world point P
	# projects to screen_y = P.y * cos(pitch) - P.z * sin(pitch).
	# All four floor corners must satisfy |screen_x| ≤ size * aspect / 2 and
	# |screen_y| ≤ size / 2 at default ortho size on a 16:9 viewport.
	var controller: PlayerController = (
		_retro_root.get_node_or_null("PlayerController") as PlayerController
	)
	if controller == null:
		fail_test("retro_games must embed PlayerController")
		return
	var size_v: float = controller.ortho_size_default
	var pitch_rad: float = deg_to_rad(_RETRO_PITCH_DEG)
	var size_h: float = size_v * _ASPECT_16_9

	for sx: float in [-_STORE_HALF_WIDTH, _STORE_HALF_WIDTH]:
		for sz: float in [-_STORE_HALF_DEPTH, _STORE_HALF_DEPTH]:
			var screen_x: float = sx
			var screen_y: float = -sz * sin(pitch_rad)
			assert_lte(
				absf(screen_x), size_h * 0.5,
				"Floor corner X=%.2f must fit within horizontal extent %.2f"
				% [sx, size_h * 0.5]
			)
			assert_lte(
				absf(screen_y), size_v * 0.5,
				(
					"Floor corner Z=%.2f maps to screen_y=%.3f, must fit "
					+ "within vertical half-extent %.2f"
				) % [sz, screen_y, size_v * 0.5]
			)


func test_retro_games_default_view_frames_back_wall_top() -> void:
	# The back wall top (Z=-3.55, Y=3.0) is the highest world point that must
	# remain on-screen so all four walls are visible at default zoom.
	var controller: PlayerController = (
		_retro_root.get_node_or_null("PlayerController") as PlayerController
	)
	if controller == null:
		fail_test("retro_games must embed PlayerController")
		return
	var pitch_rad: float = deg_to_rad(_RETRO_PITCH_DEG)
	var screen_y: float = (
		_WALL_HEIGHT * cos(pitch_rad)
		- (-_WALL_HALF_DEPTH) * sin(pitch_rad)
	)
	assert_lte(
		screen_y, controller.ortho_size_default * 0.5,
		"Back wall top must project within half the orthogonal size; "
		+ "screen_y=%.3f, half-size=%.3f"
		% [screen_y, controller.ortho_size_default * 0.5]
	)


func test_orthographic_scroll_zoom_in_changes_ortho_size() -> void:
	var controller: PlayerController = _make_controller(true)
	var initial: float = float(controller.get("_target_ortho_size"))
	var initial_zoom: float = float(controller.get("_target_zoom"))
	var event: InputEventAction = InputEventAction.new()
	event.action = "camera_zoom_in"
	event.pressed = true
	controller._unhandled_input(event)
	var after: float = float(controller.get("_target_ortho_size"))
	var after_zoom: float = float(controller.get("_target_zoom"))
	assert_lt(
		after, initial,
		"Scroll-zoom-in must shrink _target_ortho_size in orthographic mode"
	)
	assert_almost_eq(
		after_zoom, initial_zoom, 0.001,
		"Scroll-zoom-in must NOT change _target_zoom in orthographic mode"
	)


func test_orthographic_scroll_zoom_out_changes_ortho_size() -> void:
	var controller: PlayerController = _make_controller(true)
	var initial: float = float(controller.get("_target_ortho_size"))
	var event: InputEventAction = InputEventAction.new()
	event.action = "camera_zoom_out"
	event.pressed = true
	controller._unhandled_input(event)
	assert_gt(
		float(controller.get("_target_ortho_size")), initial,
		"Scroll-zoom-out must grow _target_ortho_size in orthographic mode"
	)


func test_orthographic_scroll_zoom_clamps_to_min_max() -> void:
	var controller: PlayerController = _make_controller(true)
	# Drive zoom-in past the lower bound; verify clamp at ortho_size_min.
	var zoom_in_event: InputEventAction = InputEventAction.new()
	zoom_in_event.action = "camera_zoom_in"
	zoom_in_event.pressed = true
	for _i: int in range(50):
		controller._unhandled_input(zoom_in_event)
	assert_almost_eq(
		float(controller.get("_target_ortho_size")),
		controller.ortho_size_min, 0.001,
		"Repeated zoom-in must clamp _target_ortho_size at ortho_size_min"
	)
	# Drive zoom-out past the upper bound; verify clamp at ortho_size_max.
	var zoom_out_event: InputEventAction = InputEventAction.new()
	zoom_out_event.action = "camera_zoom_out"
	zoom_out_event.pressed = true
	for _i: int in range(100):
		controller._unhandled_input(zoom_out_event)
	assert_almost_eq(
		float(controller.get("_target_ortho_size")),
		controller.ortho_size_max, 0.001,
		"Repeated zoom-out must clamp _target_ortho_size at ortho_size_max"
	)


func test_perspective_scroll_zoom_still_changes_distance() -> void:
	# Regression guard: perspective stores must still drive _target_zoom on
	# scroll input.
	var controller: PlayerController = _make_controller(false)
	var initial_zoom: float = float(controller.get("_target_zoom"))
	var event: InputEventAction = InputEventAction.new()
	event.action = "camera_zoom_out"
	event.pressed = true
	controller._unhandled_input(event)
	assert_gt(
		float(controller.get("_target_zoom")), initial_zoom,
		"Scroll-zoom-out must grow _target_zoom in perspective mode"
	)
