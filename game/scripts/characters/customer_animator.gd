## Manages procedural animations for the customer placeholder model.
class_name CustomerAnimator
extends Node

const CROSSFADE_DURATION: float = 0.3
const WALK_BOB_HEIGHT: float = 0.05
const WALK_BOB_SPEED: float = 0.4
const IDLE_SWAY_ANGLE: float = 3.0
const IDLE_SWAY_SPEED: float = 1.2
const BROWSE_HEAD_TURN: float = 20.0
const BROWSE_HEAD_SPEED: float = 1.0
const BROWSE_LEAN_ANGLE: float = 5.0
const LEAVE_BOB_HEIGHT: float = 0.07
const LEAVE_BOB_SPEED: float = 0.35

var _animation_player: AnimationPlayer = null
var _current_animation: String = ""


func initialize(animation_player: AnimationPlayer) -> void:
	_animation_player = animation_player
	_create_animations()
	_animation_player.active = true


## Plays the animation matching the given customer state.
func play_for_state(state: Customer.State) -> void:
	if not _animation_player:
		return
	var anim_name: String = _get_animation_for_state(state)
	if anim_name == _current_animation:
		return
	_current_animation = anim_name
	if _animation_player.current_animation != "":
		_animation_player.play(
			anim_name, CROSSFADE_DURATION
		)
	else:
		_animation_player.play(anim_name)


func _get_animation_for_state(state: Customer.State) -> String:
	match state:
		Customer.State.ENTERING:
			return "walk"
		Customer.State.BROWSING:
			return "browse"
		Customer.State.DECIDING:
			return "idle"
		Customer.State.PURCHASING:
			return "walk"
		Customer.State.WAITING_IN_QUEUE:
			return "idle"
		Customer.State.LEAVING:
			return "leave"
	return "idle"


func _create_animations() -> void:
	_create_walk_animation()
	_create_browse_animation()
	_create_idle_animation()
	_create_leave_animation()


func _create_walk_animation() -> void:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = WALK_BOB_SPEED

	# Body vertical bob
	var body_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(body_track, "BodyMesh")
	anim.track_insert_key(
		body_track, 0.0, Vector3(0.0, 0.7, 0.0)
	)
	anim.track_insert_key(
		body_track, WALK_BOB_SPEED * 0.5,
		Vector3(0.0, 0.7 + WALK_BOB_HEIGHT, 0.0)
	)
	anim.track_insert_key(
		body_track, WALK_BOB_SPEED, Vector3(0.0, 0.7, 0.0)
	)

	# Head follows body bob
	var head_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(head_track, "HeadMesh")
	anim.track_insert_key(
		head_track, 0.0, Vector3(0.0, 1.6, 0.0)
	)
	anim.track_insert_key(
		head_track, WALK_BOB_SPEED * 0.5,
		Vector3(0.0, 1.6 + WALK_BOB_HEIGHT, 0.0)
	)
	anim.track_insert_key(
		head_track, WALK_BOB_SPEED, Vector3(0.0, 1.6, 0.0)
	)

	# Collision shape follows body bob
	var col_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(col_track, "CollisionShape3D")
	anim.track_insert_key(
		col_track, 0.0, Vector3(0.0, 0.7, 0.0)
	)
	anim.track_insert_key(
		col_track, WALK_BOB_SPEED * 0.5,
		Vector3(0.0, 0.7 + WALK_BOB_HEIGHT, 0.0)
	)
	anim.track_insert_key(
		col_track, WALK_BOB_SPEED, Vector3(0.0, 0.7, 0.0)
	)

	var lib: AnimationLibrary = _get_or_create_library()
	lib.add_animation("walk", anim)


func _create_browse_animation() -> void:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = BROWSE_HEAD_SPEED

	# Head turns left and right as if scanning shelf
	var head_rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(head_rot_track, "HeadMesh")
	var left_quat := Quaternion.from_euler(
		Vector3(0.0, deg_to_rad(BROWSE_HEAD_TURN), 0.0)
	)
	var center_quat := Quaternion.IDENTITY
	var right_quat := Quaternion.from_euler(
		Vector3(0.0, deg_to_rad(-BROWSE_HEAD_TURN), 0.0)
	)
	anim.track_insert_key(head_rot_track, 0.0, center_quat)
	anim.track_insert_key(
		head_rot_track, BROWSE_HEAD_SPEED * 0.25, left_quat
	)
	anim.track_insert_key(
		head_rot_track, BROWSE_HEAD_SPEED * 0.5, center_quat
	)
	anim.track_insert_key(
		head_rot_track, BROWSE_HEAD_SPEED * 0.75, right_quat
	)
	anim.track_insert_key(
		head_rot_track, BROWSE_HEAD_SPEED, center_quat
	)

	# Body leans forward slightly while browsing
	var body_rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(body_rot_track, "BodyMesh")
	var lean_quat := Quaternion.from_euler(
		Vector3(deg_to_rad(BROWSE_LEAN_ANGLE), 0.0, 0.0)
	)
	anim.track_insert_key(body_rot_track, 0.0, lean_quat)
	anim.track_insert_key(
		body_rot_track, BROWSE_HEAD_SPEED, lean_quat
	)

	var lib: AnimationLibrary = _get_or_create_library()
	lib.add_animation("browse", anim)


func _create_idle_animation() -> void:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = IDLE_SWAY_SPEED

	# Body sways side to side
	var body_rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(body_rot_track, "BodyMesh")
	var sway_left := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(IDLE_SWAY_ANGLE))
	)
	var sway_right := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(-IDLE_SWAY_ANGLE))
	)
	var neutral := Quaternion.IDENTITY
	anim.track_insert_key(body_rot_track, 0.0, neutral)
	anim.track_insert_key(
		body_rot_track, IDLE_SWAY_SPEED * 0.25, sway_left
	)
	anim.track_insert_key(
		body_rot_track, IDLE_SWAY_SPEED * 0.5, neutral
	)
	anim.track_insert_key(
		body_rot_track, IDLE_SWAY_SPEED * 0.75, sway_right
	)
	anim.track_insert_key(
		body_rot_track, IDLE_SWAY_SPEED, neutral
	)

	# Head follows sway slightly
	var head_rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(head_rot_track, "HeadMesh")
	var head_sway_left := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(IDLE_SWAY_ANGLE * 0.5))
	)
	var head_sway_right := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(-IDLE_SWAY_ANGLE * 0.5))
	)
	anim.track_insert_key(head_rot_track, 0.0, neutral)
	anim.track_insert_key(
		head_rot_track, IDLE_SWAY_SPEED * 0.25, head_sway_left
	)
	anim.track_insert_key(
		head_rot_track, IDLE_SWAY_SPEED * 0.5, neutral
	)
	anim.track_insert_key(
		head_rot_track, IDLE_SWAY_SPEED * 0.75, head_sway_right
	)
	anim.track_insert_key(
		head_rot_track, IDLE_SWAY_SPEED, neutral
	)

	var lib: AnimationLibrary = _get_or_create_library()
	lib.add_animation("idle", anim)


func _create_leave_animation() -> void:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = LEAVE_BOB_SPEED

	# Faster, slightly larger bob than walk — hurrying to exit
	var body_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(body_track, "BodyMesh")
	anim.track_insert_key(
		body_track, 0.0, Vector3(0.0, 0.7, 0.0)
	)
	anim.track_insert_key(
		body_track, LEAVE_BOB_SPEED * 0.5,
		Vector3(0.0, 0.7 + LEAVE_BOB_HEIGHT, 0.0)
	)
	anim.track_insert_key(
		body_track, LEAVE_BOB_SPEED, Vector3(0.0, 0.7, 0.0)
	)

	var head_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(head_track, "HeadMesh")
	anim.track_insert_key(
		head_track, 0.0, Vector3(0.0, 1.6, 0.0)
	)
	anim.track_insert_key(
		head_track, LEAVE_BOB_SPEED * 0.5,
		Vector3(0.0, 1.6 + LEAVE_BOB_HEIGHT, 0.0)
	)
	anim.track_insert_key(
		head_track, LEAVE_BOB_SPEED, Vector3(0.0, 1.6, 0.0)
	)

	var col_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(col_track, "CollisionShape3D")
	anim.track_insert_key(
		col_track, 0.0, Vector3(0.0, 0.7, 0.0)
	)
	anim.track_insert_key(
		col_track, LEAVE_BOB_SPEED * 0.5,
		Vector3(0.0, 0.7 + LEAVE_BOB_HEIGHT, 0.0)
	)
	anim.track_insert_key(
		col_track, LEAVE_BOB_SPEED, Vector3(0.0, 0.7, 0.0)
	)

	var lib: AnimationLibrary = _get_or_create_library()
	lib.add_animation("leave", anim)


func _get_or_create_library() -> AnimationLibrary:
	if _animation_player.has_animation_library(""):
		return _animation_player.get_animation_library("")
	var lib := AnimationLibrary.new()
	_animation_player.add_animation_library("", lib)
	return lib
