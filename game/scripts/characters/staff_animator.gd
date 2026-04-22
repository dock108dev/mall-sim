## Manages procedural animations for staff NPC placeholder models.
class_name StaffAnimator
extends Node

const CROSSFADE_DURATION: float = 0.25
const WALK_BOB_HEIGHT: float = 0.05
const WALK_BOB_SPEED: float = 0.4
const WAVE_ANGLE: float = 30.0
const WAVE_SPEED: float = 0.6
const SCAN_BOB_HEIGHT: float = 0.03
const SCAN_SPEED: float = 0.5
const IDLE_SWAY_ANGLE: float = 2.0
const IDLE_SWAY_SPEED: float = 1.5
const PLACE_ITEM_SPEED: float = 1.5
const LOOK_AROUND_SPEED: float = 2.0
const LOOK_AROUND_ANGLE: float = 20.0
const MESH_Y: float = 0.7

const KNOWN_ANIMATIONS: Array[String] = [
	"idle_stand",
	"cashier_idle",
	"cashier_scan",
	"place_item",
	"wave",
	"idle_look_around",
]

var _animation_player: AnimationPlayer = null
var _current_animation: String = ""
var _animations_created: bool = false


func initialize(animation_player: AnimationPlayer) -> void:
	_animation_player = animation_player
	if not _animations_created:
		_create_animations()
		_animations_created = true
	_animation_player.active = true


func play_animation(anim_name: String) -> void:
	if not _animation_player:
		return
	if anim_name == _current_animation:
		return
	if not _animation_player.has_animation(anim_name):
		push_warning(
			"StaffAnimator: Animation '%s' not found, falling back to "
			% anim_name + "idle_stand"
		)
		anim_name = "idle_stand"
		if not _animation_player.has_animation(anim_name):
			return
	_current_animation = anim_name
	if _animation_player.current_animation != "":
		_animation_player.play(anim_name, CROSSFADE_DURATION)
	else:
		_animation_player.play(anim_name)


func _create_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation("idle_stand", _build_idle_stand())
	lib.add_animation("cashier_idle", _build_cashier_idle())
	lib.add_animation("cashier_scan", _build_cashier_scan())
	lib.add_animation("place_item", _build_place_item())
	lib.add_animation("wave", _build_wave())
	lib.add_animation("idle_look_around", _build_idle_look_around())
	_animation_player.add_animation_library("", lib)


func _build_idle_stand() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = IDLE_SWAY_SPEED

	var rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot_track, "MeshInstance3D")
	var sway_a := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(-IDLE_SWAY_ANGLE))
	)
	var sway_b := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(IDLE_SWAY_ANGLE))
	)
	anim.track_insert_key(rot_track, 0.0, sway_a)
	anim.track_insert_key(rot_track, IDLE_SWAY_SPEED * 0.5, sway_b)
	anim.track_insert_key(rot_track, IDLE_SWAY_SPEED, sway_a)
	return anim


func _build_cashier_idle() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = IDLE_SWAY_SPEED * 1.5

	var rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot_track, "MeshInstance3D")
	var sway := Quaternion.from_euler(
		Vector3(deg_to_rad(1.0), 0.0, deg_to_rad(-1.0))
	)
	var neutral := Quaternion.IDENTITY
	anim.track_insert_key(rot_track, 0.0, neutral)
	anim.track_insert_key(rot_track, IDLE_SWAY_SPEED * 0.75, sway)
	anim.track_insert_key(rot_track, IDLE_SWAY_SPEED * 1.5, neutral)
	return anim


func _build_cashier_scan() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = SCAN_SPEED

	var pos_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos_track, "MeshInstance3D")
	anim.track_insert_key(pos_track, 0.0, Vector3(0.0, MESH_Y, 0.0))
	anim.track_insert_key(
		pos_track, SCAN_SPEED * 0.5,
		Vector3(0.0, MESH_Y + SCAN_BOB_HEIGHT, 0.0)
	)
	anim.track_insert_key(pos_track, SCAN_SPEED, Vector3(0.0, MESH_Y, 0.0))

	var rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot_track, "MeshInstance3D")
	var lean_down := Quaternion.from_euler(
		Vector3(deg_to_rad(5.0), 0.0, 0.0)
	)
	anim.track_insert_key(rot_track, 0.0, Quaternion.IDENTITY)
	anim.track_insert_key(rot_track, SCAN_SPEED * 0.3, lean_down)
	anim.track_insert_key(rot_track, SCAN_SPEED, Quaternion.IDENTITY)
	return anim


func _build_place_item() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_NONE
	anim.length = PLACE_ITEM_SPEED

	var pos_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos_track, "MeshInstance3D")
	anim.track_insert_key(pos_track, 0.0, Vector3(0.0, MESH_Y, 0.0))
	anim.track_insert_key(
		pos_track, PLACE_ITEM_SPEED * 0.4,
		Vector3(0.0, MESH_Y - 0.1, 0.15)
	)
	anim.track_insert_key(
		pos_track, PLACE_ITEM_SPEED * 0.7,
		Vector3(0.0, MESH_Y - 0.1, 0.15)
	)
	anim.track_insert_key(
		pos_track, PLACE_ITEM_SPEED, Vector3(0.0, MESH_Y, 0.0)
	)

	var rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot_track, "MeshInstance3D")
	var lean_fwd := Quaternion.from_euler(
		Vector3(deg_to_rad(15.0), 0.0, 0.0)
	)
	anim.track_insert_key(rot_track, 0.0, Quaternion.IDENTITY)
	anim.track_insert_key(rot_track, PLACE_ITEM_SPEED * 0.4, lean_fwd)
	anim.track_insert_key(rot_track, PLACE_ITEM_SPEED * 0.7, lean_fwd)
	anim.track_insert_key(rot_track, PLACE_ITEM_SPEED, Quaternion.IDENTITY)
	return anim


func _build_wave() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = WAVE_SPEED

	var rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot_track, "MeshInstance3D")
	var wave_left := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(-WAVE_ANGLE))
	)
	var wave_right := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(WAVE_ANGLE))
	)
	anim.track_insert_key(rot_track, 0.0, wave_left)
	anim.track_insert_key(rot_track, WAVE_SPEED * 0.5, wave_right)
	anim.track_insert_key(rot_track, WAVE_SPEED, wave_left)
	return anim


func _build_idle_look_around() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = LOOK_AROUND_SPEED

	var rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot_track, "MeshInstance3D")
	var look_left := Quaternion.from_euler(
		Vector3(0.0, deg_to_rad(-LOOK_AROUND_ANGLE), 0.0)
	)
	var look_right := Quaternion.from_euler(
		Vector3(0.0, deg_to_rad(LOOK_AROUND_ANGLE), 0.0)
	)
	anim.track_insert_key(rot_track, 0.0, Quaternion.IDENTITY)
	anim.track_insert_key(rot_track, LOOK_AROUND_SPEED * 0.25, look_left)
	anim.track_insert_key(rot_track, LOOK_AROUND_SPEED * 0.5, Quaternion.IDENTITY)
	anim.track_insert_key(rot_track, LOOK_AROUND_SPEED * 0.75, look_right)
	anim.track_insert_key(rot_track, LOOK_AROUND_SPEED, Quaternion.IDENTITY)
	return anim
