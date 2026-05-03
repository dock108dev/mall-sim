## Unit tests for StorePlayerBody.
## Verifies that `interact_pressed` is suppressed under a non-gameplay focus
## (e.g. modal) and fires once the store_gameplay context is restored, and
## that the embedded FP camera, mouse-look clamp, and sprint multiplier behave
## as documented.
extends GutTest

const StorePlayerScene: PackedScene = preload(
	"res://game/scenes/player/store_player_body.tscn"
)


class MockStoreRoot:
	extends Node3D
	func get_store_id() -> StringName:
		return &"unit_test_store"


class MockInteractable:
	extends Node


var _root: Node
var _player: StorePlayerBody
var _interactable: Node
var _received: Array[Node] = []


func before_each() -> void:
	InputFocus._reset_for_tests()
	CameraAuthority._reset_for_tests()
	_received.clear()

	_root = MockStoreRoot.new()
	add_child_autofree(_root)

	_player = StorePlayerScene.instantiate() as StorePlayerBody
	_root.add_child(_player)

	# Production: StoreController pushes CTX_STORE_GAMEPLAY on
	# EventBus.store_entered. The mock store root above does not extend
	# StoreController, so we simulate that push here so input gating tests
	# observe the same focus state as a live store.
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	_interactable = MockInteractable.new()
	add_child_autofree(_interactable)
	_player.current_interactable = _interactable

	_player.interact_pressed.connect(_on_interact)


func after_each() -> void:
	InputFocus._reset_for_tests()
	CameraAuthority._reset_for_tests()


func _on_interact(node: Node) -> void:
	_received.append(node)


func _make_interact_event() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	return ev


func test_interact_fires_when_focus_is_store_gameplay() -> void:
	_player._unhandled_input(_make_interact_event())
	assert_eq(_received.size(), 1,
		"interact should fire when InputFocus.current == store_gameplay")
	assert_same(_received[0], _interactable)


func test_interact_suppressed_when_modal_on_top() -> void:
	InputFocus.push_context(&"modal")
	_player._unhandled_input(_make_interact_event())
	assert_eq(_received.size(), 0,
		"interact must NOT fire while a modal holds focus")


func test_interact_resumes_after_modal_pops() -> void:
	InputFocus.push_context(&"modal")
	_player._unhandled_input(_make_interact_event())
	assert_eq(_received.size(), 0, "blocked under modal")

	InputFocus.pop_context()
	_player._unhandled_input(_make_interact_event())
	assert_eq(_received.size(), 1,
		"interact should fire once gameplay focus is restored")


func test_interact_suppressed_when_no_interactable_hovered() -> void:
	_player.current_interactable = null
	_player._unhandled_input(_make_interact_event())
	assert_eq(_received.size(), 0,
		"interact must NOT fire when current_interactable is null")


# ── Store-footprint clamp (defense-in-depth fallback) ────────────────────────


func test_clamp_pulls_back_when_position_exceeds_max_z() -> void:
	# Simulate a wall-collision miss: teleport past the front bound, run a
	# physics step, and expect the post-clamp position to sit at the bound.
	_player.global_position = Vector3(0.0, 0.0, 12.0)
	_player._physics_process(0.016)
	assert_almost_eq(
		_player.global_position.z, _player.bounds_max.z, 0.0001,
		"forward overshoot must be clamped back to bounds_max.z"
	)


func test_clamp_pulls_back_when_position_exceeds_min_z() -> void:
	_player.global_position = Vector3(0.0, 0.0, -12.0)
	_player._physics_process(0.016)
	assert_almost_eq(
		_player.global_position.z, _player.bounds_min.z, 0.0001,
		"backward overshoot must be clamped to bounds_min.z"
	)


func test_clamp_pulls_back_when_position_exceeds_x_bounds() -> void:
	_player.global_position = Vector3(10.0, 0.0, 0.0)
	_player._physics_process(0.016)
	assert_almost_eq(
		_player.global_position.x, _player.bounds_max.x, 0.0001,
		"sideways overshoot must be clamped to bounds_max.x"
	)
	_player.global_position = Vector3(-10.0, 0.0, 0.0)
	_player._physics_process(0.016)
	assert_almost_eq(
		_player.global_position.x, _player.bounds_min.x, 0.0001,
		"sideways overshoot must be clamped to bounds_min.x"
	)


func test_clamp_leaves_in_bounds_position_untouched() -> void:
	# A position safely inside the footprint must not be moved by the clamp;
	# only the velocity-zeroing modal-focus path should affect it (and we are
	# under store_gameplay focus here).
	var before := Vector3(1.0, 0.0, 0.5)
	_player.global_position = before
	_player._physics_process(0.016)
	assert_almost_eq(_player.global_position.x, before.x, 0.0001,
		"in-bounds X must not be modified by the clamp")
	assert_almost_eq(_player.global_position.z, before.z, 0.0001,
		"in-bounds Z must not be modified by the clamp")


# ── First-person camera, mouse-look, sprint ─────────────────────────────────


func test_ready_registers_fp_camera_with_camera_authority() -> void:
	var cam: Camera3D = _player.get_node("StoreCamera")
	assert_eq(
		CameraAuthority.current(), cam,
		"_ready must call CameraAuthority.request_current with the FP camera"
	)
	assert_eq(
		CameraAuthority.current_source(), &"player_fp",
		"FP camera registration must use the &\"player_fp\" source token"
	)


func test_mouse_motion_yaws_body_and_pitches_camera() -> void:
	var cam: Camera3D = _player.get_node("StoreCamera")
	var initial_yaw: float = _player.rotation.y
	var initial_pitch: float = cam.rotation.x

	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(100.0, 50.0)
	_player._unhandled_input(ev)

	# Horizontal mouse delta yaws the body (negative because right-look
	# applies a clockwise yaw on the body Y axis).
	assert_almost_eq(
		_player.rotation.y, initial_yaw - 100.0 * _player.mouse_sensitivity,
		0.0001,
		"horizontal mouse motion should yaw the body by -dx * sensitivity"
	)
	# Vertical mouse delta pitches the camera (downward look = negative pitch).
	assert_almost_eq(
		cam.rotation.x, initial_pitch - 50.0 * _player.mouse_sensitivity,
		0.0001,
		"vertical mouse motion should pitch the camera by -dy * sensitivity"
	)


func test_pitch_clamped_to_eighty_degrees() -> void:
	var cam: Camera3D = _player.get_node("StoreCamera")
	var ev := InputEventMouseMotion.new()
	# A huge negative dy would otherwise drive pitch past +90° and flip view.
	ev.relative = Vector2(0.0, -100000.0)
	_player._unhandled_input(ev)
	assert_almost_eq(
		cam.rotation.x, deg_to_rad(80.0), 0.0001,
		"pitch must clamp at +80° (looking up)"
	)
	ev = InputEventMouseMotion.new()
	ev.relative = Vector2(0.0, 100000.0)
	_player._unhandled_input(ev)
	assert_almost_eq(
		cam.rotation.x, deg_to_rad(-80.0), 0.0001,
		"pitch must clamp at -80° (looking down)"
	)


func test_mouse_motion_ignored_when_modal_steals_focus() -> void:
	var cam: Camera3D = _player.get_node("StoreCamera")
	var initial_yaw: float = _player.rotation.y
	var initial_pitch: float = cam.rotation.x
	InputFocus.push_context(&"modal")
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(100.0, 50.0)
	_player._unhandled_input(ev)
	assert_eq(
		_player.rotation.y, initial_yaw,
		"yaw must NOT change while a modal owns focus"
	)
	assert_eq(
		cam.rotation.x, initial_pitch,
		"pitch must NOT change while a modal owns focus"
	)


func test_sprint_multiplier_lands_in_target_run_band() -> void:
	# 4.0 m/s walk × 1.5 sprint = 6.0 m/s, comfortably inside 5.5–7.0.
	var run_speed: float = _player.move_speed * _player.sprint_multiplier
	assert_gte(run_speed, 5.5, "sprint speed must be >= 5.5 m/s")
	assert_lte(run_speed, 7.0, "sprint speed must be <= 7.0 m/s")


func test_player_node_in_player_group() -> void:
	assert_true(
		_player.is_in_group(&"player"),
		"StorePlayerBody scene must add the root to the 'player' group"
	)


func test_gravity_accumulates_when_airborne() -> void:
	# Without a floor under the test body `is_on_floor()` stays false, so the
	# gravity term must drag velocity.y negative each physics step.
	_player.global_position = Vector3(0.0, 5.0, 0.0)
	_player.velocity = Vector3.ZERO
	_player._physics_process(0.1)
	assert_lt(
		_player.velocity.y, 0.0,
		"gravity must drive velocity.y negative each step when airborne"
	)


func test_gravity_zeroed_under_modal_focus() -> void:
	# The early-return path when focus is stolen must wipe velocity.y as well
	# so a paused player does not silently gain falling speed.
	InputFocus.push_context(&"modal")
	_player.velocity = Vector3(0.0, -3.0, 0.0)
	_player._physics_process(0.1)
	assert_eq(
		_player.velocity, Vector3.ZERO,
		"velocity must be fully cleared while a modal owns focus"
	)


func test_cursor_relocks_on_gameplay_resume() -> void:
	# Simulate the pause-menu flow: cursor unlocked while paused, then a state
	# transition back to GAMEPLAY (PauseMenu close) must recapture it.
	InputHelper.unlock_cursor()
	_player._on_game_state_changed(
		GameManager.State.PAUSED, GameManager.State.GAMEPLAY
	)
	assert_true(
		InputHelper.is_cursor_locked(),
		"cursor must recapture when gameplay resumes under store_gameplay focus"
	)


func test_cursor_does_not_relock_on_non_gameplay_state() -> void:
	InputHelper.unlock_cursor()
	_player._on_game_state_changed(
		GameManager.State.GAMEPLAY, GameManager.State.PAUSED
	)
	assert_false(
		InputHelper.is_cursor_locked(),
		"cursor must not lock on transitions away from GAMEPLAY"
	)


func test_cursor_does_not_relock_when_modal_still_active() -> void:
	# If a modal still owns focus when the FSM happens to flip to GAMEPLAY, the
	# body must not silently steal the cursor back from the modal.
	InputFocus.push_context(&"modal")
	InputHelper.unlock_cursor()
	_player._on_game_state_changed(
		GameManager.State.PAUSED, GameManager.State.GAMEPLAY
	)
	assert_false(
		InputHelper.is_cursor_locked(),
		"cursor must stay free while a modal still owns focus"
	)


func test_player_has_navigation_obstacle_for_customer_avoidance() -> void:
	# Customers route via NavigationAgent3D RVO avoidance. The FP body is a
	# CharacterBody3D and not itself an agent, so without a NavigationObstacle3D
	# child the agents plan paths through the player and oscillate against the
	# capsule collider. The obstacle radius should match the capsule footprint.
	var obstacle: NavigationObstacle3D = (
		_player.get_node_or_null("NavigationObstacle3D") as NavigationObstacle3D
	)
	assert_not_null(
		obstacle,
		"StorePlayerBody scene must include a NavigationObstacle3D child"
	)
	assert_true(
		obstacle.avoidance_enabled,
		"NavigationObstacle3D must have avoidance_enabled=true"
	)
	assert_almost_eq(
		obstacle.radius, 0.4, 0.05,
		"NavigationObstacle3D radius should match the capsule footprint (~0.4)"
	)


## ── F1 debug-camera dev toggle ──────────────────────────────────────────────


func _attach_mock_orbit_controller() -> Node3D:
	# Sibling of the FP body under `_root`, named `PlayerController`, with a
	# child `StoreCamera`. Mirrors the retro_games scene shape so the body's
	# `^"../PlayerController"` lookup resolves.
	var orbit: Node3D = Node3D.new()
	orbit.name = &"PlayerController"
	orbit.process_mode = Node.PROCESS_MODE_DISABLED
	var orbit_cam: Camera3D = Camera3D.new()
	orbit_cam.name = &"StoreCamera"
	orbit.add_child(orbit_cam)
	_root.add_child(orbit)
	return orbit


func _make_toggle_debug_camera_event() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"toggle_debug_camera"
	ev.pressed = true
	return ev


func test_default_view_is_first_person() -> void:
	# Acceptance: "Default on game start is FP mode (orbit debug is opt-in)."
	assert_false(
		_player._debug_view,
		"new StorePlayerBody must start in FP mode (_debug_view = false)"
	)


func test_f1_swaps_fp_to_orbit_debug_view() -> void:
	# Acceptance: F1 in FP store mode switches to orbit/top-down debug view,
	# the cursor is released, and CameraAuthority flips to the orbit camera.
	var orbit: Node3D = _attach_mock_orbit_controller()
	var orbit_cam: Camera3D = orbit.get_node("StoreCamera") as Camera3D
	InputHelper.lock_cursor()

	_player._unhandled_input(_make_toggle_debug_camera_event())

	assert_true(_player._debug_view, "F1 in FP must enable _debug_view")
	assert_eq(
		orbit.process_mode, Node.PROCESS_MODE_INHERIT,
		"orbit PlayerController must be process-enabled in debug view"
	)
	assert_eq(
		CameraAuthority.current(), orbit_cam,
		"CameraAuthority must point at the orbit StoreCamera in debug view"
	)
	assert_eq(
		CameraAuthority.current_source(), &"debug_overhead",
		"orbit camera registration must use the &\"debug_overhead\" source token"
	)
	assert_false(
		InputHelper.is_cursor_locked(),
		"F1 must release the cursor when entering debug view"
	)


func test_f1_again_returns_to_first_person() -> void:
	# Acceptance: F1 again switches back to FP mode; mouse capture, camera,
	# and orbit-controller state all reverse.
	var orbit: Node3D = _attach_mock_orbit_controller()
	var fp_cam: Camera3D = _player.get_node("StoreCamera") as Camera3D

	_player._unhandled_input(_make_toggle_debug_camera_event())  # FP → debug
	_player._unhandled_input(_make_toggle_debug_camera_event())  # debug → FP

	assert_false(_player._debug_view, "second F1 must clear _debug_view")
	assert_eq(
		orbit.process_mode, Node.PROCESS_MODE_DISABLED,
		"returning to FP must disable the orbit PlayerController"
	)
	assert_eq(
		CameraAuthority.current(), fp_cam,
		"CameraAuthority must point at the FP StoreCamera after F1 returns"
	)
	assert_eq(
		CameraAuthority.current_source(), &"player_fp",
		"FP camera re-registration must use the &\"player_fp\" source token"
	)
	assert_true(
		InputHelper.is_cursor_locked(),
		"second F1 must recapture the cursor when returning to FP"
	)


func test_movement_suspended_in_debug_view() -> void:
	# While the orbit controller drives input, the FP body must not
	# accumulate velocity from gravity or WASD.
	_attach_mock_orbit_controller()
	_player._unhandled_input(_make_toggle_debug_camera_event())
	_player.global_position = Vector3(0.0, 5.0, 0.0)
	_player.velocity = Vector3(2.0, -3.0, 1.0)
	_player._physics_process(0.1)
	assert_eq(
		_player.velocity, Vector3.ZERO,
		"velocity must be zeroed every physics step while in debug view"
	)


func test_mouse_look_suppressed_in_debug_view() -> void:
	# Mouse motion must not yaw the FP body or pitch its camera while the
	# orbit dev view owns input.
	_attach_mock_orbit_controller()
	var cam: Camera3D = _player.get_node("StoreCamera")
	_player._unhandled_input(_make_toggle_debug_camera_event())
	var initial_yaw: float = _player.rotation.y
	var initial_pitch: float = cam.rotation.x

	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(100.0, 50.0)
	_player._unhandled_input(ev)

	assert_eq(
		_player.rotation.y, initial_yaw,
		"yaw must NOT change while the orbit debug view owns input"
	)
	assert_eq(
		cam.rotation.x, initial_pitch,
		"pitch must NOT change while the orbit debug view owns input"
	)


func test_f1_silent_no_op_when_orbit_controller_missing() -> void:
	# Stores without a sibling orbit `PlayerController` must not crash on F1
	# and must stay in FP mode (the dev toggle is opt-in per scene shape).
	_player._unhandled_input(_make_toggle_debug_camera_event())
	assert_false(
		_player._debug_view,
		"missing orbit controller must leave _debug_view unchanged"
	)


func test_focus_listener_does_not_relock_cursor_in_debug_view() -> void:
	# A modal closing on top of the debug view must not steal the unlocked
	# cursor back; the orbit dev view continues to own mouse mode.
	_attach_mock_orbit_controller()
	_player._unhandled_input(_make_toggle_debug_camera_event())
	assert_false(InputHelper.is_cursor_locked(), "debug view unlocks cursor")

	# Simulate a modal pushing then popping focus while in debug view.
	_player._on_input_focus_changed(&"modal", InputFocus.CTX_STORE_GAMEPLAY)
	_player._on_input_focus_changed(InputFocus.CTX_STORE_GAMEPLAY, &"modal")
	assert_false(
		InputHelper.is_cursor_locked(),
		"focus restoring to store_gameplay must NOT relock the cursor while debug view is active"
	)


func test_clamp_bounds_match_retro_games_footprint() -> void:
	# The defaults must keep the body inside the 16×20 retro_games floor with a
	# safety margin from the wall surface (walls at ±8.0 X, ±10.0 Z). When
	# room geometry is resized the defaults must be updated alongside.
	assert_lte(_player.bounds_max.x, 8.0,
		"bounds_max.x must sit inside the right wall surface (8.0)")
	assert_gte(_player.bounds_min.x, -8.0,
		"bounds_min.x must sit inside the left wall surface (-8.0)")
	assert_lte(_player.bounds_max.z, 10.0,
		"bounds_max.z must sit inside the front wall surface (10.0)")
	assert_gte(_player.bounds_min.z, -10.0,
		"bounds_min.z must sit inside the back wall surface (-10.0)")
	# Bounds within 0.5 m of the wall surface, no further inward (no invisible
	# wall snap inside the visible room).
	assert_gte(_player.bounds_max.x, 7.5,
		"bounds_max.x must reach within 0.5 m of the right wall (7.5)")
	assert_lte(_player.bounds_min.x, -7.5,
		"bounds_min.x must reach within 0.5 m of the left wall (-7.5)")
	assert_gte(_player.bounds_max.z, 9.5,
		"bounds_max.z must reach within 0.5 m of the front wall (9.5)")
	assert_lte(_player.bounds_min.z, -9.5,
		"bounds_min.z must reach within 0.5 m of the back wall (-9.5)")
