## Unit tests for CameraAuthority autoload (ISSUE-010).
## Verifies request_current activates one camera and clears others, current()
## returns the active camera, and assert_single_active distinguishes 0/1/N.
extends GutTest

const CameraAuthorityScript: GDScript = preload("res://game/autoload/camera_authority.gd")

var _authority: Node


func before_each() -> void:
	_authority = CameraAuthorityScript.new()
	add_child_autofree(_authority)
	_authority._reset_for_tests()


func _make_cam_3d(name_str: String) -> Camera3D:
	var cam: Camera3D = Camera3D.new()
	cam.name = name_str
	add_child_autofree(cam)
	return cam


func test_request_current_makes_camera_current() -> void:
	var cam: Camera3D = _make_cam_3d("CamA")
	var ok: bool = _authority.request_current(cam, &"test_source")
	assert_true(ok, "request_current should succeed for valid Camera3D")
	assert_true(cam.current, "requested camera should be current")
	assert_eq(_authority.current(), cam)
	assert_eq(_authority.current_source(), &"test_source")


func test_request_current_clears_previous() -> void:
	var cam_a: Camera3D = _make_cam_3d("CamA")
	var cam_b: Camera3D = _make_cam_3d("CamB")
	_authority.request_current(cam_a, &"source_a")
	assert_true(cam_a.current)
	_authority.request_current(cam_b, &"source_b")
	assert_false(cam_a.current, "previous camera should be cleared")
	assert_true(cam_b.current, "new camera should be current")
	assert_eq(_authority.current(), cam_b)


func test_request_current_rejects_null() -> void:
	var ok: bool = _authority.request_current(null, &"source")
	assert_false(ok)
	assert_null(_authority.current())


func test_request_current_rejects_non_camera() -> void:
	var node: Node = Node.new()
	add_child_autofree(node)
	var ok: bool = _authority.request_current(node, &"source")
	assert_false(ok)


func test_request_current_emits_signal() -> void:
	watch_signals(_authority)
	var cam: Camera3D = _make_cam_3d("CamA")
	_authority.request_current(cam, &"source_x")
	assert_signal_emitted_with_parameters(_authority, "camera_changed", [cam, &"source_x"])


func test_assert_single_active_passes_with_one_current() -> void:
	var cam: Camera3D = _make_cam_3d("CamA")
	_authority.request_current(cam, &"source")
	assert_true(_authority.assert_single_active())


func test_assert_single_active_fails_with_zero() -> void:
	# No cameras registered/current at all.
	assert_false(_authority.assert_single_active())


func test_assert_single_active_fails_with_multiple() -> void:
	var cam_a: Camera3D = _make_cam_3d("CamA")
	var cam_b: Camera3D = _make_cam_3d("CamB")
	# Route both through the authority so they're in the cameras group, then
	# force the second one current via the engine API to simulate a violator.
	_authority.request_current(cam_a, &"source_a")
	cam_a.add_to_group(_authority.CAMERAS_GROUP)
	cam_b.add_to_group(_authority.CAMERAS_GROUP)
	cam_b.make_current()
	# Both report current=true now (cam_a was not cleared by the bypass).
	assert_true(cam_a.current)
	assert_true(cam_b.current)
	assert_false(_authority.assert_single_active(),
		"should fail when more than one camera in 'cameras' group is current")


func test_two_activations_through_authority_leave_exactly_one_current() -> void:
	# Acceptance criterion: activating two cameras via the authority leaves
	# exactly one current.
	var cam_a: Camera3D = _make_cam_3d("CamA")
	var cam_b: Camera3D = _make_cam_3d("CamB")
	_authority.request_current(cam_a, &"a")
	_authority.request_current(cam_b, &"b")
	assert_true(_authority.assert_single_active(),
		"after two requests through the authority, exactly one camera is current")
	assert_eq(_authority.current(), cam_b)
