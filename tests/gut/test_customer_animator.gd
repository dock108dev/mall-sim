## Tests CustomerAnimator procedural animation creation, state mapping,
## arm swing tracks, and leaving animation variant selection.
extends GutTest


var _animator: CustomerAnimator
var _anim_player: AnimationPlayer
var _root: Node3D


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)

	var body := MeshInstance3D.new()
	body.name = "BodyMesh"
	_root.add_child(body)

	var left_arm := MeshInstance3D.new()
	left_arm.name = "LeftArm"
	body.add_child(left_arm)

	var left_hand := MeshInstance3D.new()
	left_hand.name = "LeftHand"
	left_arm.add_child(left_hand)

	var right_arm := MeshInstance3D.new()
	right_arm.name = "RightArm"
	body.add_child(right_arm)

	var right_hand := MeshInstance3D.new()
	right_hand.name = "RightHand"
	right_arm.add_child(right_hand)

	var head := MeshInstance3D.new()
	head.name = "HeadMesh"
	_root.add_child(head)

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	_root.add_child(col)

	_anim_player = AnimationPlayer.new()
	_anim_player.name = "AnimationPlayer"
	_root.add_child(_anim_player)

	_animator = CustomerAnimator.new()
	_animator.name = "CustomerAnimator"
	_root.add_child(_animator)
	_animator.initialize(_anim_player)


# --- Animation existence ---


func test_all_six_animations_created() -> void:
	var lib: AnimationLibrary = _anim_player.get_animation_library("")
	assert_true(lib.has_animation("walk"), "walk animation exists")
	assert_true(lib.has_animation("browse"), "browse animation exists")
	assert_true(lib.has_animation("idle"), "idle animation exists")
	assert_true(lib.has_animation("purchase"), "purchase animation exists")
	assert_true(
		lib.has_animation("leaving_happy"), "leaving_happy animation exists"
	)
	assert_true(
		lib.has_animation("leaving_upset"), "leaving_upset animation exists"
	)


# --- Walk animation arm swing ---


func test_walk_has_arm_swing_tracks() -> void:
	var lib: AnimationLibrary = _anim_player.get_animation_library("")
	var walk: Animation = lib.get_animation("walk")
	var left_found: Array = [false]
	var right_found: Array = [false]
	var left_hand_found: Array = [false]
	var right_hand_found: Array = [false]
	for i: int in range(walk.get_track_count()):
		var path: String = str(walk.track_get_path(i))
		if path == "BodyMesh/LeftArm":
			left_found[0] = true
			assert_eq(
				walk.track_get_type(i),
				Animation.TYPE_ROTATION_3D,
				"LeftArm track is rotation"
			)
		elif path == "BodyMesh/RightArm":
			right_found[0] = true
			assert_eq(
				walk.track_get_type(i),
				Animation.TYPE_ROTATION_3D,
				"RightArm track is rotation"
			)
		elif path == "BodyMesh/LeftArm/LeftHand":
			left_hand_found[0] = true
		elif path == "BodyMesh/RightArm/RightHand":
			right_hand_found[0] = true
	assert_true(left_found[0], "Walk has LeftArm rotation track")
	assert_true(right_found[0], "Walk has RightArm rotation track")
	assert_true(left_hand_found[0], "Walk has LeftHand rotation track")
	assert_true(right_hand_found[0], "Walk has RightHand rotation track")


# --- Browse body shift ---


func test_browse_animation_is_double_cycle() -> void:
	var lib: AnimationLibrary = _anim_player.get_animation_library("")
	var browse: Animation = lib.get_animation("browse")
	assert_almost_eq(
		browse.length,
		CustomerAnimator.BROWSE_HEAD_SPEED * 2.0,
		0.001,
		"Browse animation is 2x head speed cycle"
	)


func test_browse_body_has_shift_keys() -> void:
	var lib: AnimationLibrary = _anim_player.get_animation_library("")
	var browse: Animation = lib.get_animation("browse")
	var cycle: float = CustomerAnimator.BROWSE_HEAD_SPEED
	for i: int in range(browse.get_track_count()):
		var path: String = str(browse.track_get_path(i))
		if path != "BodyMesh":
			continue
		if browse.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var key_count: int = browse.track_get_key_count(i)
		assert_gt(
			key_count, 2,
			"Body rotation track has shift keys beyond static lean"
		)
		var has_second_half_key: bool = false
		for k: int in range(key_count):
			if browse.track_get_key_time(i, k) > cycle:
				has_second_half_key = true
				break
		assert_true(
			has_second_half_key,
			"Body rotation has keys in second cycle (shift variation)"
		)
		return
	fail_test("Browse has no BodyMesh rotation track")


# --- Idle head look-around ---


func test_idle_animation_is_double_cycle() -> void:
	var lib: AnimationLibrary = _anim_player.get_animation_library("")
	var idle: Animation = lib.get_animation("idle")
	assert_almost_eq(
		idle.length,
		CustomerAnimator.IDLE_SWAY_SPEED * 2.0,
		0.001,
		"Idle animation is 2x sway speed cycle"
	)


func test_idle_head_has_look_around_keys() -> void:
	var lib: AnimationLibrary = _anim_player.get_animation_library("")
	var idle: Animation = lib.get_animation("idle")
	var cycle: float = CustomerAnimator.IDLE_SWAY_SPEED
	for i: int in range(idle.get_track_count()):
		var path: String = str(idle.track_get_path(i))
		if path != "HeadMesh":
			continue
		if idle.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var key_count: int = idle.track_get_key_count(i)
		assert_gt(
			key_count, 4,
			"Head has keys spanning both cycles"
		)
		return
	fail_test("Idle has no HeadMesh rotation track")


# --- Purchase hand raise ---


func test_purchase_has_right_arm_track() -> void:
	var lib: AnimationLibrary = _anim_player.get_animation_library("")
	var purchase: Animation = lib.get_animation("purchase")
	for i: int in range(purchase.get_track_count()):
		var path: String = str(purchase.track_get_path(i))
		if path == "BodyMesh/RightArm":
			assert_eq(
				purchase.track_get_type(i),
				Animation.TYPE_ROTATION_3D,
				"RightArm track is rotation"
			)
			assert_gt(
				purchase.track_get_key_count(i), 2,
				"RightArm has multiple raise/lower keys"
			)
			return
	fail_test("Purchase has no RightArm rotation track")


# --- Leaving animation variant selection ---


func test_leaving_unsatisfied_plays_upset() -> void:
	_animator.set_satisfied(false)
	_animator.play_for_state(Customer.State.LEAVING)
	assert_eq(
		_anim_player.current_animation, "leaving_upset",
		"Unsatisfied customer plays leaving_upset"
	)


func test_leaving_satisfied_plays_happy() -> void:
	_animator.set_satisfied(true)
	_animator.play_for_state(Customer.State.LEAVING)
	assert_eq(
		_anim_player.current_animation, "leaving_happy",
		"Satisfied customer plays leaving_happy"
	)


func test_default_satisfaction_is_false() -> void:
	_animator.play_for_state(Customer.State.LEAVING)
	assert_eq(
		_anim_player.current_animation, "leaving_upset",
		"Default leaving animation is leaving_upset (not satisfied)"
	)


# --- Leave happy has bounce, leave upset has no bob ---


func test_leave_happy_has_vertical_bob() -> void:
	var lib: AnimationLibrary = _anim_player.get_animation_library("")
	var happy: Animation = lib.get_animation("leaving_happy")
	for i: int in range(happy.get_track_count()):
		var path: String = str(happy.track_get_path(i))
		if path != "BodyMesh":
			continue
		if happy.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var has_bob: bool = false
		for k: int in range(happy.track_get_key_count(i)):
			var pos: Vector3 = happy.track_get_key_value(i, k)
			if pos.y > 0.7:
				has_bob = true
				break
		assert_true(has_bob, "Leave happy has vertical bob above rest y=0.7")
		return
	fail_test("Leave happy has no BodyMesh position track")


func test_leave_upset_has_no_bob() -> void:
	var lib: AnimationLibrary = _anim_player.get_animation_library("")
	var upset: Animation = lib.get_animation("leaving_upset")
	for i: int in range(upset.get_track_count()):
		var path: String = str(upset.track_get_path(i))
		if path != "BodyMesh":
			continue
		if upset.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		for k: int in range(upset.track_get_key_count(i)):
			var pos: Vector3 = upset.track_get_key_value(i, k)
			assert_almost_eq(
				pos.y, 0.7, 0.001,
				"Leave upset body stays at rest height (no bob)"
			)
		return
	fail_test("Leave upset has no BodyMesh position track")


# --- Crossfade duration preserved ---


func test_crossfade_duration_unchanged() -> void:
	assert_almost_eq(
		CustomerAnimator.CROSSFADE_DURATION, 0.3, 0.001,
		"CROSSFADE_DURATION remains 0.3s"
	)


# --- State mapping coverage ---


func test_entering_state_plays_walk() -> void:
	_animator.play_for_state(Customer.State.ENTERING)
	assert_eq(_anim_player.current_animation, "walk")


func test_browsing_state_plays_browse() -> void:
	_animator.play_for_state(Customer.State.BROWSING)
	assert_eq(_anim_player.current_animation, "browse")


func test_deciding_state_plays_idle() -> void:
	_animator.play_for_state(Customer.State.DECIDING)
	assert_eq(_anim_player.current_animation, "idle")


func test_waiting_in_queue_plays_idle() -> void:
	_animator.play_for_state(Customer.State.WAITING_IN_QUEUE)
	assert_eq(_anim_player.current_animation, "idle")
