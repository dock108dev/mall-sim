## Integration tests for ISSUE-001 — hub-mode StorePlayerBody spawn flow.
##
## Verifies the spawn helper in game_world.gd against a real retro_games.tscn
## instance plus the body camera registering through CameraAuthority. Covers
## acceptance criteria 1-5 except the visual on-screen movement check.
extends GutTest

const RETRO_GAMES_SCENE: PackedScene = preload(
	"res://game/scenes/stores/retro_games.tscn"
)
const STORE_PLAYER_SCENE: PackedScene = preload(
	"res://game/scenes/player/store_player_body.tscn"
)

const PLAYER_ENTRY_SPAWN_NAME: StringName = &"PlayerEntrySpawn"

var _store_root: Node3D
var _player: StorePlayerBody
var _baseline_focus_depth: int


func before_each() -> void:
	InputFocus._reset_for_tests()
	CameraAuthority._reset_for_tests()
	_baseline_focus_depth = InputFocus.depth()


func after_each() -> void:
	# Children are autofreed by GUT; reset shared autoload state so other suites
	# do not observe leaked focus frames or cached camera refs.
	InputFocus._reset_for_tests()
	CameraAuthority._reset_for_tests()
	_store_root = null
	_player = null


func _instantiate_store() -> Node3D:
	var root: Node3D = RETRO_GAMES_SCENE.instantiate() as Node3D
	add_child_autofree(root)
	return root


func _spawn_player_at_marker(store_root: Node3D) -> StorePlayerBody:
	var marker: Marker3D = (
		store_root.get_node_or_null(String(PLAYER_ENTRY_SPAWN_NAME))
		as Marker3D
	)
	assert_not_null(
		marker,
		"retro_games.tscn must define a PlayerEntrySpawn Marker3D"
	)
	var player: StorePlayerBody = (
		STORE_PLAYER_SCENE.instantiate() as StorePlayerBody
	)
	store_root.add_child(player)
	player.global_position = marker.global_position
	return player


func test_retro_games_scene_has_player_entry_spawn_marker() -> void:
	_store_root = _instantiate_store()
	var marker: Marker3D = (
		_store_root.get_node_or_null(String(PLAYER_ENTRY_SPAWN_NAME))
		as Marker3D
	)
	assert_not_null(marker, "PlayerEntrySpawn must exist in retro_games.tscn")
	# Marker should sit inside the store, not outside the front wall (z=2.55).
	assert_lt(
		marker.global_position.z, 2.55,
		"PlayerEntrySpawn should be inside the store, not behind the door"
	)


func test_store_controller_exposes_get_store_id() -> void:
	_store_root = _instantiate_store()
	assert_true(
		_store_root.has_method("get_store_id"),
		"StoreController must expose get_store_id() for spawn assertion"
	)
	# RetroGames sets store_type = STORE_ID = "retro_games" in initialize().
	assert_eq(
		_store_root.call("get_store_id"), &"retro_games",
		"get_store_id() should return the canonical store id"
	)


func test_player_camera_is_in_cameras_group() -> void:
	# Loading a fresh body (without parent) is enough — the .tscn declares
	# group membership at author time.
	var player: StorePlayerBody = (
		STORE_PLAYER_SCENE.instantiate() as StorePlayerBody
	)
	add_child_autofree(player)  # add_child runs _ready; we do not assert focus here
	var cam: Camera3D = player.find_child("Camera3D", false, false) as Camera3D
	assert_not_null(cam, "store_player_body.tscn must include a Camera3D child")
	assert_true(
		cam.is_in_group(&"cameras"),
		"Body Camera3D must declare groups=[\"cameras\"] for assert_single_active"
	)


func test_player_camera_has_interaction_ray_child() -> void:
	# ISSUE-002: body camera owns the InteractionRay so the press-E loop
	# follows the player's view direction.
	var player: StorePlayerBody = (
		STORE_PLAYER_SCENE.instantiate() as StorePlayerBody
	)
	add_child_autofree(player)
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


func test_spawn_pushes_store_gameplay_context() -> void:
	_store_root = _instantiate_store()
	_player = _spawn_player_at_marker(_store_root)
	assert_eq(
		InputFocus.current(), &"store_gameplay",
		"Player._ready must push store_gameplay onto InputFocus"
	)


func test_camera_authority_marks_body_camera_current() -> void:
	_store_root = _instantiate_store()
	_player = _spawn_player_at_marker(_store_root)
	var cam: Camera3D = (
		_player.find_child("Camera3D", false, false) as Camera3D
	)
	assert_not_null(cam, "spawned player must have a Camera3D child")
	var ok: bool = CameraAuthority.request_current(cam, &"retro_games")
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
	_store_root = _instantiate_store()
	_player = _spawn_player_at_marker(_store_root)
	# Simulate any modal pushing its context on top of store_gameplay.
	InputFocus.push_context(&"modal")
	_player.velocity = Vector3(2.0, 0.0, 2.0)
	_player._physics_process(0.016)
	assert_eq(
		_player.velocity, Vector3.ZERO,
		"_physics_process must zero velocity while a modal owns focus"
	)


func test_enter_exit_enter_does_not_leak_input_focus_frames() -> void:
	# Cycle 1
	_store_root = _instantiate_store()
	_player = _spawn_player_at_marker(_store_root)
	assert_eq(InputFocus.current(), &"store_gameplay")
	_store_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(
		InputFocus.depth(), _baseline_focus_depth,
		"InputFocus depth should return to baseline after the store is freed"
	)

	# Cycle 2 — re-enter and confirm push happens cleanly.
	_store_root = _instantiate_store()
	_player = _spawn_player_at_marker(_store_root)
	assert_eq(
		InputFocus.current(), &"store_gameplay",
		"Re-entering the store must push store_gameplay again"
	)
	assert_eq(
		InputFocus.depth(), _baseline_focus_depth + 1,
		"Re-entry should add exactly one frame, not stack residue"
	)


func test_camera_authority_self_heals_after_player_freed() -> void:
	_store_root = _instantiate_store()
	_player = _spawn_player_at_marker(_store_root)
	var cam: Camera3D = (
		_player.find_child("Camera3D", false, false) as Camera3D
	)
	CameraAuthority.request_current(cam, &"retro_games")
	_store_root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# After the store (and its child player+camera) is freed, current() must
	# self-heal to null rather than handing back a freed reference.
	assert_null(
		CameraAuthority.current(),
		"CameraAuthority should drop a freed camera on next current() call"
	)
