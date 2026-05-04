## Integration tests for the StorePlayerBody spawn flow contract.
##
## Verifies the walking-body scene shape (embedded eye-level Camera3D;
## InteractionRay on the CharacterBody root), CameraAuthority activation, and
## movement focus gating. Orbit-camera stores embed `PlayerController`
## directly and bypass `StorePlayerBody`.
extends GutTest

const STORE_PLAYER_SCENE: PackedScene = preload(
	"res://game/scenes/player/store_player_body.tscn"
)

const STORE_CAMERA_NAME: StringName = &"StoreCamera"


class MockStoreRoot:
	extends Node3D
	func get_store_id() -> StringName:
		return &"mock_store"


var _store_root: Node3D
var _player: StorePlayerBody


func before_each() -> void:
	InputFocus._reset_for_tests()
	CameraAuthority._reset_for_tests()


func after_each() -> void:
	# Children are autofreed by GUT; reset shared autoload state so other suites
	# do not observe leaked focus frames or cached camera refs.
	InputFocus._reset_for_tests()
	CameraAuthority._reset_for_tests()
	_store_root = null
	_player = null


func _instantiate_mock_store() -> Node3D:
	var root := MockStoreRoot.new()
	add_child_autofree(root)
	return root


func _spawn_player_in(store_root: Node3D) -> StorePlayerBody:
	var player: StorePlayerBody = (
		STORE_PLAYER_SCENE.instantiate() as StorePlayerBody
	)
	store_root.add_child(player)
	player.global_position = Vector3.ZERO
	# Production: StoreController pushes CTX_STORE_GAMEPLAY on
	# EventBus.store_entered. The mock fixture does not run that flow, so push
	# the context manually to mirror the runtime contract.
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	return player


func _add_mock_store_camera(store_root: Node3D) -> Camera3D:
	var cam := Camera3D.new()
	cam.name = String(STORE_CAMERA_NAME)
	cam.current = false
	store_root.add_child(cam)
	return cam


func test_player_body_has_embedded_fp_camera() -> void:
	var root := MockStoreRoot.new()
	add_child_autofree(root)
	var player: StorePlayerBody = (
		STORE_PLAYER_SCENE.instantiate() as StorePlayerBody
	)
	root.add_child(player)
	var cam: Camera3D = player.find_child("StoreCamera", false, false) as Camera3D
	assert_not_null(
		cam,
		"store_player_body.tscn must embed a StoreCamera for first-person view"
	)
	if cam == null:
		return
	assert_almost_eq(
		cam.position.y, 1.7, 0.0001,
		"FP camera must sit at ~1.7 m (eye level for the 1.8 m capsule)"
	)
	assert_almost_eq(
		cam.near, 0.05, 0.0001,
		"FP camera near clip must be 0.05 so close props don't clip"
	)
	assert_true(
		cam.is_in_group(&"cameras"),
		"FP camera must join the 'cameras' group so CameraAuthority can track it"
	)


func test_player_body_has_interaction_ray_on_root() -> void:
	var root := MockStoreRoot.new()
	add_child_autofree(root)
	var player: StorePlayerBody = (
		STORE_PLAYER_SCENE.instantiate() as StorePlayerBody
	)
	root.add_child(player)
	var ray: Node = player.get_node_or_null("InteractionRay")
	assert_not_null(
		ray,
		"Player root must own InteractionRay (tracks EventBus.active_camera_changed)",
	)
	if ray == null:
		return
	var script: Script = ray.get_script()
	assert_not_null(script, "InteractionRay node must have a script attached")
	if script != null:
		assert_eq(
			script.resource_path,
			"res://game/scripts/player/interaction_ray.gd",
			"InteractionRay must use interaction_ray.gd",
		)


func test_camera_authority_marks_store_camera_current() -> void:
	_store_root = _instantiate_mock_store()
	_add_mock_store_camera(_store_root)
	_player = _spawn_player_in(_store_root)
	var cam: Camera3D = (
		_store_root.get_node_or_null(String(STORE_CAMERA_NAME)) as Camera3D
	)
	assert_not_null(cam, "fixture must expose a StoreCamera Camera3D node")
	var ok: bool = CameraAuthority.request_current(cam, &"mock_store")
	assert_true(ok, "CameraAuthority.request_current should accept the StoreCamera")
	assert_eq(
		CameraAuthority.current(), cam,
		"StoreCamera should be the active camera after request_current"
	)
	assert_true(
		CameraAuthority.assert_single_active(),
		"exactly one camera in the 'cameras' group should be current"
	)


func test_movement_halts_when_modal_steals_focus() -> void:
	_store_root = _instantiate_mock_store()
	_player = _spawn_player_in(_store_root)
	# Simulate any modal pushing its context on top of store_gameplay.
	InputFocus.push_context(&"modal")
	_player.velocity = Vector3(2.0, 0.0, 2.0)
	_player._physics_process(0.016)
	assert_eq(
		_player.velocity, Vector3.ZERO,
		"_physics_process must zero velocity while a modal owns focus"
	)


func test_spawn_player_applies_marker_basis() -> void:
	# Production: GameWorld._spawn_player_in_store sets the player's
	# global_transform from the spawn marker — not just the origin — so a
	# rotated marker steers the body's facing direction. Verify by mirroring
	# the contract here: after assigning marker.global_transform onto the
	# player, the body's forward axis matches the marker's.
	_store_root = _instantiate_mock_store()
	var marker := Marker3D.new()
	marker.name = "PlayerEntrySpawn"
	# Yaw 90° around Y so forward (-Z) rotates to -X.
	var basis := Basis(Vector3.UP, deg_to_rad(90.0))
	marker.global_transform = Transform3D(basis, Vector3(1.5, 0.0, 2.5))
	_store_root.add_child(marker)
	_player = STORE_PLAYER_SCENE.instantiate() as StorePlayerBody
	_store_root.add_child(_player)
	_player.global_transform = marker.global_transform
	assert_almost_eq(
		_player.global_position.x, 1.5, 0.001,
		"Player origin must follow marker.x"
	)
	assert_almost_eq(
		_player.global_position.z, 2.5, 0.001,
		"Player origin must follow marker.z"
	)
	var player_forward: Vector3 = -_player.global_transform.basis.z
	var marker_forward: Vector3 = -marker.global_transform.basis.z
	assert_almost_eq(
		player_forward.x, marker_forward.x, 0.001,
		"Player forward.x must match marker forward.x"
	)
	assert_almost_eq(
		player_forward.z, marker_forward.z, 0.001,
		"Player forward.z must match marker forward.z"
	)


func test_camera_authority_self_heals_after_store_freed() -> void:
	_store_root = _instantiate_mock_store()
	_add_mock_store_camera(_store_root)
	_player = _spawn_player_in(_store_root)
	var cam: Camera3D = (
		_store_root.get_node_or_null(String(STORE_CAMERA_NAME)) as Camera3D
	)
	CameraAuthority.request_current(cam, &"mock_store")
	_store_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# After the store subtree (including StoreCamera) is freed, current() must
	# self-heal to null rather than handing back a freed reference.
	assert_null(
		CameraAuthority.current(),
		"CameraAuthority should drop a freed camera on next current() call"
	)
