## Manages procedural animations for the customer placeholder model.
class_name CustomerAnimator
extends Node

const CROSSFADE_DURATION: float = 0.3
const WALK_BOB_HEIGHT: float = 0.06
const WALK_BOB_SPEED: float = 0.4
const WALK_LEAN_ANGLE: float = 5.0
const ARM_SWING_ANGLE: float = 15.0
const IDLE_SWAY_ANGLE: float = 3.0
const IDLE_SWAY_SPEED: float = 1.2
const IDLE_LOOK_ANGLE: float = 25.0
const BROWSE_HEAD_TURN: float = 20.0
const BROWSE_HEAD_SPEED: float = 1.0
const BROWSE_LEAN_ANGLE: float = 5.0
const BROWSE_SHIFT_ANGLE: float = 3.0
const PURCHASE_NOD_ANGLE: float = 15.0
const PURCHASE_ANIM_SPEED: float = 0.8
const PURCHASE_RAISE_ANGLE: float = 45.0
const LEAVE_HAPPY_BOB: float = 0.08
const LEAVE_HAPPY_SPEED: float = 0.35
const LEAVE_UPSET_SPEED: float = 0.25
const LEAVE_UPSET_LEAN: float = 8.0
const MOVE_THRESHOLD: float = 0.1

var _animation_player: AnimationPlayer = null
var _current_animation: String = ""
var _current_state: Customer.State = Customer.State.ENTERING
var _is_moving: bool = false
var _is_satisfied: bool = false


func initialize(animation_player: AnimationPlayer) -> void:
	_animation_player = animation_player
	_is_satisfied = false
	_create_animations()
	_animation_player.active = true


## Sets whether the customer is satisfied (affects leaving animation).
func set_satisfied(satisfied: bool) -> void:
	_is_satisfied = satisfied


## Plays the animation matching the given customer state.
func play_for_state(state: Customer.State) -> void:
	if not _animation_player:
		return
	_current_state = state
	var anim_name: String = _get_animation_for_state(state)
	_play_animation(anim_name)


## Updates animation based on movement velocity each frame.
func update_movement(velocity: Vector3) -> void:
	var moving: bool = velocity.length() > MOVE_THRESHOLD
	if moving == _is_moving:
		return
	_is_moving = moving
	if moving:
		_play_animation(_get_walk_animation())
	else:
		_play_animation(_get_stationary_animation(_current_state))


func _play_animation(anim_name: String) -> void:
	if not _animation_player:
		return
	if anim_name == _current_animation:
		return
	_current_animation = anim_name
	if _animation_player.current_animation != "":
		_animation_player.play(anim_name, CROSSFADE_DURATION)
	else:
		_animation_player.play(anim_name)


func _get_walk_animation() -> String:
	if _current_state == Customer.State.LEAVING:
		return "leave_happy" if _is_satisfied else "leave_upset"
	return "walk"


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
			return "leave_happy" if _is_satisfied else "leave_upset"
	return "idle"


## Returns the animation to play when the customer is stationary.
func _get_stationary_animation(state: Customer.State) -> String:
	match state:
		Customer.State.BROWSING:
			return "browse"
		Customer.State.DECIDING:
			return "idle"
		Customer.State.PURCHASING:
			return "purchase"
		Customer.State.WAITING_IN_QUEUE:
			return "idle"
	return "idle"


func _create_animations() -> void:
	_create_walk_animation()
	_create_browse_animation()
	_create_idle_animation()
	_create_purchase_animation()
	_create_leave_happy_animation()
	_create_leave_upset_animation()


func _create_walk_animation() -> void:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = WALK_BOB_SPEED
	var body_y: float = 0.7
	var head_y: float = 1.6

	var body_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(body_track, "BodyMesh")
	anim.track_insert_key(body_track, 0.0, Vector3(0.0, body_y, 0.0))
	anim.track_insert_key(
		body_track, WALK_BOB_SPEED * 0.5,
		Vector3(0.0, body_y + WALK_BOB_HEIGHT, 0.0)
	)
	anim.track_insert_key(
		body_track, WALK_BOB_SPEED, Vector3(0.0, body_y, 0.0)
	)

	var head_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(head_track, "HeadMesh")
	anim.track_insert_key(head_track, 0.0, Vector3(0.0, head_y, 0.0))
	anim.track_insert_key(
		head_track, WALK_BOB_SPEED * 0.5,
		Vector3(0.0, head_y + WALK_BOB_HEIGHT, 0.0)
	)
	anim.track_insert_key(
		head_track, WALK_BOB_SPEED, Vector3(0.0, head_y, 0.0)
	)

	var col_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(col_track, "CollisionShape3D")
	anim.track_insert_key(col_track, 0.0, Vector3(0.0, body_y, 0.0))
	anim.track_insert_key(
		col_track, WALK_BOB_SPEED * 0.5,
		Vector3(0.0, body_y + WALK_BOB_HEIGHT, 0.0)
	)
	anim.track_insert_key(
		col_track, WALK_BOB_SPEED, Vector3(0.0, body_y, 0.0)
	)

	var body_rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(body_rot_track, "BodyMesh")
	var walk_lean := Quaternion.from_euler(
		Vector3(deg_to_rad(WALK_LEAN_ANGLE), 0.0, 0.0)
	)
	anim.track_insert_key(body_rot_track, 0.0, walk_lean)
	anim.track_insert_key(body_rot_track, WALK_BOB_SPEED, walk_lean)

	_add_arm_swing(anim, "BodyMesh/LeftArm", ARM_SWING_ANGLE, true)
	_add_arm_swing(anim, "BodyMesh/RightArm", ARM_SWING_ANGLE, false)

	var lib: AnimationLibrary = _get_or_create_library()
	lib.add_animation("walk", anim)


func _create_browse_animation() -> void:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	var cycle: float = BROWSE_HEAD_SPEED
	anim.length = cycle * 2.0

	var head_rot: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(head_rot, "HeadMesh")
	var left := Quaternion.from_euler(
		Vector3(0.0, deg_to_rad(BROWSE_HEAD_TURN), 0.0)
	)
	var center := Quaternion.IDENTITY
	var right := Quaternion.from_euler(
		Vector3(0.0, deg_to_rad(-BROWSE_HEAD_TURN), 0.0)
	)
	anim.track_insert_key(head_rot, 0.0, center)
	anim.track_insert_key(head_rot, cycle * 0.25, left)
	anim.track_insert_key(head_rot, cycle * 0.5, center)
	anim.track_insert_key(head_rot, cycle * 0.75, right)
	anim.track_insert_key(head_rot, cycle, center)
	anim.track_insert_key(head_rot, cycle * 1.25, left)
	anim.track_insert_key(head_rot, cycle * 1.5, center)
	anim.track_insert_key(head_rot, cycle * 1.75, right)
	anim.track_insert_key(head_rot, cycle * 2.0, center)

	var body_rot: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(body_rot, "BodyMesh")
	var lean := Quaternion.from_euler(
		Vector3(deg_to_rad(BROWSE_LEAN_ANGLE), 0.0, 0.0)
	)
	var lean_left := Quaternion.from_euler(
		Vector3(
			deg_to_rad(BROWSE_LEAN_ANGLE), 0.0,
			deg_to_rad(BROWSE_SHIFT_ANGLE)
		)
	)
	var lean_right := Quaternion.from_euler(
		Vector3(
			deg_to_rad(BROWSE_LEAN_ANGLE), 0.0,
			deg_to_rad(-BROWSE_SHIFT_ANGLE)
		)
	)
	anim.track_insert_key(body_rot, 0.0, lean)
	anim.track_insert_key(body_rot, cycle, lean)
	anim.track_insert_key(body_rot, cycle * 1.25, lean_left)
	anim.track_insert_key(body_rot, cycle * 1.5, lean)
	anim.track_insert_key(body_rot, cycle * 1.75, lean_right)
	anim.track_insert_key(body_rot, cycle * 2.0, lean)

	var lib: AnimationLibrary = _get_or_create_library()
	lib.add_animation("browse", anim)


func _create_idle_animation() -> void:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	var cycle: float = IDLE_SWAY_SPEED
	anim.length = cycle * 2.0
	var neutral := Quaternion.IDENTITY

	var body_rot: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(body_rot, "BodyMesh")
	var sway_l := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(IDLE_SWAY_ANGLE))
	)
	var sway_r := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(-IDLE_SWAY_ANGLE))
	)
	anim.track_insert_key(body_rot, 0.0, neutral)
	anim.track_insert_key(body_rot, cycle * 0.25, sway_l)
	anim.track_insert_key(body_rot, cycle * 0.5, neutral)
	anim.track_insert_key(body_rot, cycle * 0.75, sway_r)
	anim.track_insert_key(body_rot, cycle, neutral)
	anim.track_insert_key(body_rot, cycle * 1.25, sway_l)
	anim.track_insert_key(body_rot, cycle * 1.5, neutral)
	anim.track_insert_key(body_rot, cycle * 1.75, sway_r)
	anim.track_insert_key(body_rot, cycle * 2.0, neutral)

	var head_rot: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(head_rot, "HeadMesh")
	var head_sway_l := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(IDLE_SWAY_ANGLE * 0.5))
	)
	var head_sway_r := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(-IDLE_SWAY_ANGLE * 0.5))
	)
	var look_left := Quaternion.from_euler(
		Vector3(0.0, deg_to_rad(IDLE_LOOK_ANGLE), 0.0)
	)
	var look_right := Quaternion.from_euler(
		Vector3(0.0, deg_to_rad(-IDLE_LOOK_ANGLE), 0.0)
	)
	anim.track_insert_key(head_rot, 0.0, neutral)
	anim.track_insert_key(head_rot, cycle * 0.25, head_sway_l)
	anim.track_insert_key(head_rot, cycle * 0.5, neutral)
	anim.track_insert_key(head_rot, cycle * 0.75, head_sway_r)
	anim.track_insert_key(head_rot, cycle, neutral)
	anim.track_insert_key(head_rot, cycle * 1.25, look_left)
	anim.track_insert_key(head_rot, cycle * 1.5, neutral)
	anim.track_insert_key(head_rot, cycle * 1.75, look_right)
	anim.track_insert_key(head_rot, cycle * 2.0, neutral)

	var lib: AnimationLibrary = _get_or_create_library()
	lib.add_animation("idle", anim)


func _create_purchase_animation() -> void:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = PURCHASE_ANIM_SPEED
	var neutral := Quaternion.IDENTITY
	var l: float = PURCHASE_ANIM_SPEED

	var arm_rot: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(arm_rot, "BodyMesh/RightArm")
	var raised := Quaternion.from_euler(
		Vector3(deg_to_rad(-PURCHASE_RAISE_ANGLE), 0.0, 0.0)
	)
	anim.track_insert_key(arm_rot, 0.0, neutral)
	anim.track_insert_key(arm_rot, l * 0.1, raised)
	anim.track_insert_key(arm_rot, l * 0.3, raised)
	anim.track_insert_key(arm_rot, l * 0.5, neutral)
	anim.track_insert_key(arm_rot, l, neutral)

	var head_rot: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(head_rot, "HeadMesh")
	var nod_down := Quaternion.from_euler(
		Vector3(deg_to_rad(PURCHASE_NOD_ANGLE), 0.0, 0.0)
	)
	anim.track_insert_key(head_rot, 0.0, neutral)
	anim.track_insert_key(head_rot, l * 0.2, neutral)
	anim.track_insert_key(head_rot, l * 0.35, nod_down)
	anim.track_insert_key(head_rot, l * 0.55, neutral)
	anim.track_insert_key(head_rot, l, neutral)

	var body_scale: int = anim.add_track(Animation.TYPE_SCALE_3D)
	anim.track_set_path(body_scale, "BodyMesh")
	var normal_s := Vector3(1.0, 1.0, 1.0)
	var pulse_s := Vector3(1.05, 1.02, 1.05)
	anim.track_insert_key(body_scale, 0.0, normal_s)
	anim.track_insert_key(body_scale, l * 0.3, pulse_s)
	anim.track_insert_key(body_scale, l * 0.6, normal_s)
	anim.track_insert_key(body_scale, l, normal_s)

	var lib: AnimationLibrary = _get_or_create_library()
	lib.add_animation("purchase", anim)


func _create_leave_happy_animation() -> void:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = LEAVE_HAPPY_SPEED
	var body_y: float = 0.7
	var head_y: float = 1.6

	var body_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(body_track, "BodyMesh")
	anim.track_insert_key(body_track, 0.0, Vector3(0.0, body_y, 0.0))
	anim.track_insert_key(
		body_track, LEAVE_HAPPY_SPEED * 0.5,
		Vector3(0.0, body_y + LEAVE_HAPPY_BOB, 0.0)
	)
	anim.track_insert_key(
		body_track, LEAVE_HAPPY_SPEED, Vector3(0.0, body_y, 0.0)
	)

	var head_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(head_track, "HeadMesh")
	anim.track_insert_key(head_track, 0.0, Vector3(0.0, head_y, 0.0))
	anim.track_insert_key(
		head_track, LEAVE_HAPPY_SPEED * 0.5,
		Vector3(0.0, head_y + LEAVE_HAPPY_BOB, 0.0)
	)
	anim.track_insert_key(
		head_track, LEAVE_HAPPY_SPEED, Vector3(0.0, head_y, 0.0)
	)

	var col_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(col_track, "CollisionShape3D")
	anim.track_insert_key(col_track, 0.0, Vector3(0.0, body_y, 0.0))
	anim.track_insert_key(
		col_track, LEAVE_HAPPY_SPEED * 0.5,
		Vector3(0.0, body_y + LEAVE_HAPPY_BOB, 0.0)
	)
	anim.track_insert_key(
		col_track, LEAVE_HAPPY_SPEED, Vector3(0.0, body_y, 0.0)
	)

	var body_rot: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(body_rot, "BodyMesh")
	var lean := Quaternion.from_euler(
		Vector3(deg_to_rad(WALK_LEAN_ANGLE), 0.0, 0.0)
	)
	anim.track_insert_key(body_rot, 0.0, lean)
	anim.track_insert_key(body_rot, LEAVE_HAPPY_SPEED, lean)

	_add_arm_swing(anim, "BodyMesh/LeftArm", ARM_SWING_ANGLE, true)
	_add_arm_swing(anim, "BodyMesh/RightArm", ARM_SWING_ANGLE, false)

	var lib: AnimationLibrary = _get_or_create_library()
	lib.add_animation("leave_happy", anim)


func _create_leave_upset_animation() -> void:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = LEAVE_UPSET_SPEED
	var body_y: float = 0.7
	var head_y: float = 1.6

	var body_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(body_track, "BodyMesh")
	anim.track_insert_key(body_track, 0.0, Vector3(0.0, body_y, 0.0))
	anim.track_insert_key(
		body_track, LEAVE_UPSET_SPEED, Vector3(0.0, body_y, 0.0)
	)

	var head_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(head_track, "HeadMesh")
	anim.track_insert_key(head_track, 0.0, Vector3(0.0, head_y, 0.0))
	anim.track_insert_key(
		head_track, LEAVE_UPSET_SPEED, Vector3(0.0, head_y, 0.0)
	)

	var body_rot: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(body_rot, "BodyMesh")
	var lean := Quaternion.from_euler(
		Vector3(deg_to_rad(LEAVE_UPSET_LEAN), 0.0, 0.0)
	)
	anim.track_insert_key(body_rot, 0.0, lean)
	anim.track_insert_key(body_rot, LEAVE_UPSET_SPEED, lean)

	var half_swing: float = ARM_SWING_ANGLE * 0.5
	_add_arm_swing(anim, "BodyMesh/LeftArm", half_swing, true)
	_add_arm_swing(anim, "BodyMesh/RightArm", half_swing, false)

	var lib: AnimationLibrary = _get_or_create_library()
	lib.add_animation("leave_upset", anim)


## Adds alternating arm rotation keyframes to an animation track.
func _add_arm_swing(
	anim: Animation, path: String, angle: float, start_forward: bool
) -> void:
	var track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, path)
	var forward := Quaternion.from_euler(
		Vector3(deg_to_rad(angle), 0.0, 0.0)
	)
	var backward := Quaternion.from_euler(
		Vector3(deg_to_rad(-angle), 0.0, 0.0)
	)
	var neutral := Quaternion.IDENTITY
	var first: Quaternion = forward if start_forward else backward
	var second: Quaternion = backward if start_forward else forward
	var l: float = anim.length
	anim.track_insert_key(track, 0.0, first)
	anim.track_insert_key(track, l * 0.25, neutral)
	anim.track_insert_key(track, l * 0.5, second)
	anim.track_insert_key(track, l * 0.75, neutral)


func _get_or_create_library() -> AnimationLibrary:
	if _animation_player.has_animation_library(""):
		return _animation_player.get_animation_library("")
	var lib := AnimationLibrary.new()
	_animation_player.add_animation_library("", lib)
	return lib
