## 3D in-store staff NPC with role-based state machine and navigation.
class_name StaffNPC
extends CharacterBody3D

enum State {
	SHIFT_START,
	WALKING,
	IDLE_AT_REGISTER,
	PROCESSING_CUSTOMER,
	IDLE_IN_BACKROOM,
	WALK_TO_SHELF,
	STOCK_SHELF,
	IDLE_AT_ENTRANCE,
	GREET_CUSTOMER,
	SHIFT_END,
}

const MOVE_SPEED: float = 2.5
const NAV_RECALC_INTERVAL: float = 0.2
const GREET_RADIUS: float = 3.5
const GREET_DURATION: float = 2.0
const STOCK_DURATION: float = 1.5
const RESTOCK_INTERVAL_MIN: float = 8.0
const RESTOCK_INTERVAL_MAX: float = 15.0
const MICRO_BEHAVIOR_DURATION: float = 1.5

const CASHIER_CHECK_REGISTER_MIN: float = 15.0
const CASHIER_CHECK_REGISTER_MAX: float = 25.0
const CASHIER_WIPE_COUNTER_MIN: float = 30.0
const CASHIER_WIPE_COUNTER_MAX: float = 45.0

const STOCKER_STRETCH_MIN: float = 60.0
const STOCKER_STRETCH_MAX: float = 90.0
const STOCKER_CLIPBOARD_MIN: float = 20.0
const STOCKER_CLIPBOARD_MAX: float = 35.0

const GREETER_WAVE_MIN: float = 8.0
const GREETER_WAVE_MAX: float = 15.0
const GREETER_BADGE_MIN: float = 45.0
const GREETER_BADGE_MAX: float = 60.0

var current_state: State = State.SHIFT_START
var _staff_def: StaffDefinition = null
var _role: StaffDefinition.StaffRole = StaffDefinition.StaffRole.CASHIER
var _morale: float = StaffDefinition.DEFAULT_MORALE
var _role_marker: Marker3D = null
var _backroom_marker: Marker3D = null
var _shelf_markers: Array[Marker3D] = []
var _initialized: bool = false
var _time_paused: bool = false
var _nav_recalc_timer: float = 0.0
var _state_timer: float = 0.0
var _restock_timer: float = 0.0
var _micro_timer_a: float = 0.0
var _micro_timer_b: float = 0.0
var _playing_micro: bool = false
var _micro_anim_timer: float = 0.0
var _target_shelf_index: int = -1

@onready var _navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _staff_animator: StaffAnimator = $StaffAnimator


func _ready() -> void:
	_navigation_agent.velocity_computed.connect(_on_velocity_computed)


func initialize(
	staff_def: StaffDefinition, role_config: StoreStaffConfig
) -> void:
	_staff_def = staff_def
	_role = staff_def.role
	_morale = staff_def.morale

	_role_marker = role_config.get_marker_for_role(_role)
	if _role == StaffDefinition.StaffRole.STOCKER:
		_backroom_marker = role_config.backroom_point

	_staff_animator.initialize(_animation_player)
	_apply_role_color()
	_reset_micro_timers()
	_restock_timer = randf_range(RESTOCK_INTERVAL_MIN, RESTOCK_INTERVAL_MAX)
	_initialized = true


func begin_shift() -> void:
	if not _initialized:
		push_warning("StaffNPC: begin_shift called before initialize")
		return
	_transition_to(State.WALKING)
	_navigate_to_marker(_role_marker)


func end_shift() -> void:
	_play_animation("idle_stand")
	_transition_to(State.SHIFT_END)
	var tween: Tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(queue_free)


func play_role_idle() -> void:
	match _role:
		StaffDefinition.StaffRole.CASHIER:
			_transition_to(State.IDLE_AT_REGISTER)
			_play_animation("cashier_idle")
		StaffDefinition.StaffRole.STOCKER:
			_transition_to(State.IDLE_IN_BACKROOM)
			_play_animation("idle_stand")
		StaffDefinition.StaffRole.GREETER:
			_transition_to(State.IDLE_AT_ENTRANCE)
			_play_animation("idle_stand")


func notify_customer_at_register() -> void:
	if _role != StaffDefinition.StaffRole.CASHIER:
		return
	if current_state == State.IDLE_AT_REGISTER:
		_transition_to(State.PROCESSING_CUSTOMER)
		_play_animation("cashier_scan")


func notify_customer_checkout_done() -> void:
	if _role != StaffDefinition.StaffRole.CASHIER:
		return
	if current_state == State.PROCESSING_CUSTOMER:
		_transition_to(State.IDLE_AT_REGISTER)
		_play_animation("cashier_idle")


func set_shelf_markers(markers: Array[Marker3D]) -> void:
	_shelf_markers = markers


func _physics_process(delta: float) -> void:
	if not _initialized or _time_paused:
		return
	match current_state:
		State.WALKING:
			_process_walking(delta)
		State.IDLE_AT_REGISTER:
			_process_idle_at_register(delta)
		State.PROCESSING_CUSTOMER:
			_process_processing_customer(delta)
		State.IDLE_IN_BACKROOM:
			_process_idle_in_backroom(delta)
		State.WALK_TO_SHELF:
			_process_walk_to_shelf(delta)
		State.STOCK_SHELF:
			_process_stock_shelf(delta)
		State.IDLE_AT_ENTRANCE:
			_process_idle_at_entrance(delta)
		State.GREET_CUSTOMER:
			_process_greet_customer(delta)
	_move_along_path(delta)
	_process_micro_behaviors(delta)


func _process_walking(_delta: float) -> void:
	if _navigation_agent.is_navigation_finished():
		_on_arrival_at_role_marker()


func _on_arrival_at_role_marker() -> void:
	match _role:
		StaffDefinition.StaffRole.CASHIER:
			_transition_to(State.IDLE_AT_REGISTER)
			_play_animation("cashier_idle")
		StaffDefinition.StaffRole.STOCKER:
			_transition_to(State.IDLE_IN_BACKROOM)
			_play_animation("idle_stand")
		StaffDefinition.StaffRole.GREETER:
			_transition_to(State.IDLE_AT_ENTRANCE)
			_play_animation("idle_stand")


func _process_idle_at_register(_delta: float) -> void:
	pass


func _process_processing_customer(_delta: float) -> void:
	pass


func _process_idle_in_backroom(delta: float) -> void:
	_restock_timer -= delta
	if _restock_timer <= 0.0:
		_restock_timer = randf_range(
			RESTOCK_INTERVAL_MIN, RESTOCK_INTERVAL_MAX
		)
		if not _shelf_markers.is_empty():
			_target_shelf_index = randi() % _shelf_markers.size()
			_transition_to(State.WALK_TO_SHELF)
			_navigate_to_marker(_shelf_markers[_target_shelf_index])
			_play_animation("idle_stand")


func _process_walk_to_shelf(_delta: float) -> void:
	if _navigation_agent.is_navigation_finished():
		_transition_to(State.STOCK_SHELF)
		_state_timer = STOCK_DURATION
		_play_animation("place_item")


func _process_stock_shelf(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_transition_to(State.WALKING)
		_navigate_to_marker(_backroom_marker)
		_play_animation("idle_stand")


func _process_idle_at_entrance(_delta: float) -> void:
	var customers: Array[Node] = get_tree().get_nodes_in_group("customers")
	for node: Node in customers:
		var body: Node3D = node as Node3D
		if not body:
			continue
		var dist: float = global_position.distance_to(body.global_position)
		if dist <= GREET_RADIUS:
			_transition_to(State.GREET_CUSTOMER)
			_state_timer = GREET_DURATION
			_play_animation("wave")
			return


func _process_greet_customer(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_transition_to(State.IDLE_AT_ENTRANCE)
		_play_animation("idle_stand")


func _process_micro_behaviors(delta: float) -> void:
	if _playing_micro:
		_micro_anim_timer -= delta
		if _micro_anim_timer <= 0.0:
			_playing_micro = false
			_restore_role_animation()
		return

	_micro_timer_a -= delta
	_micro_timer_b -= delta

	if _micro_timer_a <= 0.0:
		_trigger_micro_a()
	if _micro_timer_b <= 0.0:
		_trigger_micro_b()


func _trigger_micro_a() -> void:
	match _role:
		StaffDefinition.StaffRole.CASHIER:
			if current_state == State.IDLE_AT_REGISTER:
				_play_micro("idle_look_around")
			_micro_timer_a = randf_range(
				CASHIER_CHECK_REGISTER_MIN, CASHIER_CHECK_REGISTER_MAX
			)
		StaffDefinition.StaffRole.STOCKER:
			if current_state == State.IDLE_IN_BACKROOM:
				_play_micro("idle_look_around")
			_micro_timer_a = randf_range(
				STOCKER_STRETCH_MIN, STOCKER_STRETCH_MAX
			)
		StaffDefinition.StaffRole.GREETER:
			if current_state == State.IDLE_AT_ENTRANCE:
				_play_micro("wave")
			_micro_timer_a = randf_range(
				GREETER_WAVE_MIN, GREETER_WAVE_MAX
			)


func _trigger_micro_b() -> void:
	match _role:
		StaffDefinition.StaffRole.CASHIER:
			if current_state == State.IDLE_AT_REGISTER:
				_play_micro("idle_look_around")
			_micro_timer_b = randf_range(
				CASHIER_WIPE_COUNTER_MIN, CASHIER_WIPE_COUNTER_MAX
			)
		StaffDefinition.StaffRole.STOCKER:
			if current_state == State.IDLE_IN_BACKROOM:
				_play_micro("idle_look_around")
			_micro_timer_b = randf_range(
				STOCKER_CLIPBOARD_MIN, STOCKER_CLIPBOARD_MAX
			)
		StaffDefinition.StaffRole.GREETER:
			if current_state == State.IDLE_AT_ENTRANCE:
				_play_micro("idle_look_around")
			_micro_timer_b = randf_range(
				GREETER_BADGE_MIN, GREETER_BADGE_MAX
			)


func _play_micro(anim_name: String) -> void:
	_playing_micro = true
	_micro_anim_timer = MICRO_BEHAVIOR_DURATION
	_play_animation(anim_name)


func _restore_role_animation() -> void:
	match current_state:
		State.IDLE_AT_REGISTER:
			_play_animation("cashier_idle")
		State.IDLE_IN_BACKROOM, State.IDLE_AT_ENTRANCE:
			_play_animation("idle_stand")


func _reset_micro_timers() -> void:
	match _role:
		StaffDefinition.StaffRole.CASHIER:
			_micro_timer_a = randf_range(
				CASHIER_CHECK_REGISTER_MIN, CASHIER_CHECK_REGISTER_MAX
			)
			_micro_timer_b = randf_range(
				CASHIER_WIPE_COUNTER_MIN, CASHIER_WIPE_COUNTER_MAX
			)
		StaffDefinition.StaffRole.STOCKER:
			_micro_timer_a = randf_range(
				STOCKER_STRETCH_MIN, STOCKER_STRETCH_MAX
			)
			_micro_timer_b = randf_range(
				STOCKER_CLIPBOARD_MIN, STOCKER_CLIPBOARD_MAX
			)
		StaffDefinition.StaffRole.GREETER:
			_micro_timer_a = randf_range(
				GREETER_WAVE_MIN, GREETER_WAVE_MAX
			)
			_micro_timer_b = randf_range(
				GREETER_BADGE_MIN, GREETER_BADGE_MAX
			)


func _transition_to(new_state: State) -> void:
	current_state = new_state


func _navigate_to_marker(marker: Marker3D) -> void:
	if not marker:
		push_warning("StaffNPC: Attempted to navigate to null marker")
		return
	_navigation_agent.target_position = marker.global_position


func _move_along_path(delta: float) -> void:
	if _navigation_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		return
	_nav_recalc_timer -= delta
	var next_pos: Vector3
	if _nav_recalc_timer <= 0.0:
		_nav_recalc_timer = NAV_RECALC_INTERVAL
		next_pos = _navigation_agent.get_next_path_position()
	else:
		next_pos = _navigation_agent.target_position
	var direction: Vector3 = next_pos - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		velocity = Vector3.ZERO
		return
	direction = direction.normalized()
	var desired: Vector3 = direction * MOVE_SPEED
	if _navigation_agent.avoidance_enabled:
		_navigation_agent.set_velocity(desired)
	else:
		velocity = desired
		move_and_slide()


func _play_animation(anim_name: String) -> void:
	_staff_animator.play_animation(anim_name)


func _apply_role_color() -> void:
	if not _mesh:
		return
	var color: Color
	match _role:
		StaffDefinition.StaffRole.CASHIER:
			color = Color(0.2, 0.4, 0.8)
		StaffDefinition.StaffRole.STOCKER:
			color = Color(0.8, 0.5, 0.2)
		StaffDefinition.StaffRole.GREETER:
			color = Color(0.2, 0.7, 0.3)
		_:
			color = Color(0.6, 0.6, 0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	_mesh.material_override = mat


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	move_and_slide()
