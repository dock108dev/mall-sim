## Integration tests for the StorePlayerBody spawn flow contract.
##
## Verifies the body camera structure (cameras group, InteractionRay child)
## and the CameraAuthority handoff against a MockStoreRoot fixture. Stores
## that opt into the orbit-camera flow embed their PlayerController directly
## and bypass this spawn path; the contract here applies only to walking-body
## stores that author a `PlayerEntrySpawn` marker.
extends GutTest

const STORE_PLAYER_SCENE: PackedScene = preload(
	"res://game/scenes/player/store_player_body.tscn"
)


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


func test_player_camera_is_in_cameras_group() -> void:
	# The body's _ready asserts a store-root ancestor (parent chain has
	# get_store_id). Wrap in MockStoreRoot so the spawn contract passes; the
	# .tscn structure (group + Camera3D child) is what we actually verify.
	var root := MockStoreRoot.new()
	add_child_autofree(root)
	var player: StorePlayerBody = (
		STORE_PLAYER_SCENE.instantiate() as StorePlayerBody
	)
	root.add_child(player)  # add_child runs _ready; we do not assert focus here
	var cam: Camera3D = player.find_child("Camera3D", false, false) as Camera3D
	assert_not_null(cam, "store_player_body.tscn must include a Camera3D child")
	assert_true(
		cam.is_in_group(&"cameras"),
		"Body Camera3D must declare groups=[\"cameras\"] for assert_single_active"
	)


func test_player_camera_has_interaction_ray_child() -> void:
	# ISSUE-002: body camera owns the InteractionRay so the press-E loop
	# follows the player's view direction.
	var root := MockStoreRoot.new()
	add_child_autofree(root)
	var player: StorePlayerBody = (
		STORE_PLAYER_SCENE.instantiate() as StorePlayerBody
	)
	root.add_child(player)
	var cam: Camera3D = player.find_child("Camera3D", false, false) as Camera3D
	assert_not_null(cam, "body must have a Camera3D")
	if cam == null:
		return
	var ray: Node = cam.get_node_or_null("InteractionRay")
	assert_not_null(
		ray, "Camera3D must have an InteractionRay child for press-E routing"
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


func test_camera_authority_marks_body_camera_current() -> void:
	_store_root = _instantiate_mock_store()
	_player = _spawn_player_in(_store_root)
	var cam: Camera3D = (
		_player.find_child("Camera3D", false, false) as Camera3D
	)
	assert_not_null(cam, "spawned player must have a Camera3D child")
	var ok: bool = CameraAuthority.request_current(cam, &"mock_store")
	assert_true(ok, "CameraAuthority.request_current should accept the body cam")
	assert_eq(
		CameraAuthority.current(), cam,
		"body camera should be the active camera after request_current"
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


func test_camera_authority_self_heals_after_player_freed() -> void:
	_store_root = _instantiate_mock_store()
	_player = _spawn_player_in(_store_root)
	var cam: Camera3D = (
		_player.find_child("Camera3D", false, false) as Camera3D
	)
	CameraAuthority.request_current(cam, &"mock_store")
	_store_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# After the store (and its child player+camera) is freed, current() must
	# self-heal to null rather than handing back a freed reference.
	assert_null(
		CameraAuthority.current(),
		"CameraAuthority should drop a freed camera on next current() call"
	)
