## Unit tests for BuildModeCamera idle drift (ISSUE-003 Model A).
## Verifies orbit radius, bob amplitude, time advancement, stop behaviour,
## and CameraAuthority activation.
extends GutTest


func _make_cam(name_str: String) -> Camera3D:
	var cam: Camera3D = Camera3D.new()
	cam.name = name_str
	add_child_autofree(cam)
	return cam


func _make_ctrl() -> BuildModeCamera:
	var ctrl: BuildModeCamera = BuildModeCamera.new()
	add_child_autofree(ctrl)
	return ctrl


func test_drift_constants_are_within_spec() -> void:
	assert_eq(BuildModeCamera.DRIFT_PERIOD, 20.0, "period must be 20s")
	assert_between(
		BuildModeCamera.DRIFT_RADIUS, 0.5, 1.0,
		"radius must be 0.5–1.0 m"
	)
	assert_lte(
		BuildModeCamera.DRIFT_BOB_AMP, 0.2,
		"bob amplitude must be ≤ 0.2 m"
	)


func test_start_idle_drift_positions_camera_at_orbit_radius() -> void:
	var cam: Camera3D = _make_cam("Cam")
	var ctrl: BuildModeCamera = _make_ctrl()
	var pivot := Vector3(0.0, 1.2, 0.0)
	ctrl.start_idle_drift(pivot, cam, &"test")
	var dist_xz: float = Vector2(
		cam.global_position.x - pivot.x,
		cam.global_position.z - pivot.z
	).length()
	assert_almost_eq(
		dist_xz, BuildModeCamera.DRIFT_RADIUS, 0.001,
		"initial XZ distance from pivot must equal DRIFT_RADIUS"
	)


func test_start_idle_drift_activates_camera_via_authority() -> void:
	var cam: Camera3D = _make_cam("Cam")
	var ctrl: BuildModeCamera = _make_ctrl()
	ctrl.start_idle_drift(Vector3(0.0, 1.2, 0.0), cam, &"test_source")
	assert_true(cam.current, "camera must be current after start_idle_drift")


func test_process_advances_camera_position() -> void:
	var cam: Camera3D = _make_cam("Cam")
	var ctrl: BuildModeCamera = _make_ctrl()
	var pivot := Vector3(0.0, 1.2, 0.0)
	ctrl.start_idle_drift(pivot, cam, &"test")
	var initial_pos: Vector3 = cam.global_position
	ctrl._process(5.0)
	assert_ne(
		cam.global_position, initial_pos,
		"drift must move camera after advancing time"
	)


func test_stop_idle_drift_halts_movement() -> void:
	var cam: Camera3D = _make_cam("Cam")
	var ctrl: BuildModeCamera = _make_ctrl()
	ctrl.start_idle_drift(Vector3(0.0, 1.2, 0.0), cam, &"test")
	ctrl._process(1.0)
	ctrl.stop_idle_drift()
	var stopped_pos: Vector3 = cam.global_position
	ctrl._process(5.0)
	assert_eq(
		cam.global_position, stopped_pos,
		"camera must not move after stop_idle_drift"
	)


func test_vertical_bob_stays_within_amplitude() -> void:
	var cam: Camera3D = _make_cam("Cam")
	var ctrl: BuildModeCamera = _make_ctrl()
	var pivot := Vector3(0.0, 1.2, 0.0)
	ctrl.start_idle_drift(pivot, cam, &"test")
	var max_y_delta: float = 0.0
	for _i: int in range(100):
		ctrl._process(0.2)
		var y_delta: float = abs(cam.global_position.y - pivot.y)
		if y_delta > max_y_delta:
			max_y_delta = y_delta
	assert_lte(
		max_y_delta, BuildModeCamera.DRIFT_BOB_AMP + 0.001,
		"vertical bob must not exceed DRIFT_BOB_AMP"
	)


func test_xz_orbit_radius_stays_constant() -> void:
	var cam: Camera3D = _make_cam("Cam")
	var ctrl: BuildModeCamera = _make_ctrl()
	var pivot := Vector3(0.0, 1.2, 0.0)
	ctrl.start_idle_drift(pivot, cam, &"test")
	for _i: int in range(50):
		ctrl._process(0.4)
		var dist_xz: float = Vector2(
			cam.global_position.x - pivot.x,
			cam.global_position.z - pivot.z
		).length()
		assert_almost_eq(
			dist_xz, BuildModeCamera.DRIFT_RADIUS, 0.001,
			"XZ orbit radius must remain constant during drift"
		)


func test_camera_looks_at_pivot_during_drift() -> void:
	var cam: Camera3D = _make_cam("Cam")
	var ctrl: BuildModeCamera = _make_ctrl()
	var pivot := Vector3(0.0, 1.2, 0.0)
	ctrl.start_idle_drift(pivot, cam, &"test")
	ctrl._process(3.7)
	# Camera -Z (forward) should point roughly toward pivot.
	var to_pivot: Vector3 = (pivot - cam.global_position).normalized()
	var forward: Vector3 = -cam.global_transform.basis.z
	var dot: float = forward.dot(to_pivot)
	assert_gt(dot, 0.99, "camera forward must point at pivot during drift")


func test_invalid_camera_is_silently_ignored() -> void:
	var ctrl: BuildModeCamera = _make_ctrl()
	# Passing null must not crash
	ctrl.start_idle_drift(Vector3.ZERO, null, &"test")
	assert_false(ctrl._is_drifting, "drift must not start with null camera")


func test_drift_does_not_respond_to_unhandled_input() -> void:
	# Verifies there is no _unhandled_input override — drift is pure ambient.
	var ctrl: BuildModeCamera = _make_ctrl()
	assert_false(
		ctrl.get_script().has_method("_unhandled_input"),
		"BuildModeCamera must not have _unhandled_input (drift is input-free)"
	)
