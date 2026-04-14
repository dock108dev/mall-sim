## Visual representation of a customer NPC with animation state machine.
class_name CustomerNPC
extends CharacterBody3D

enum CustomerVisitState {
	IDLE,
	BROWSING,
	APPROACHING_CHECKOUT,
	WAITING_IN_QUEUE,
	LEAVING,
}

const MOVE_SPEED: float = 2.0
const NAV_RECALC_INTERVAL: float = 0.2
const ARRIVAL_DISTANCE_SQ: float = 0.64
const FALLBACK_ANIMATION: StringName = &"idle_stand"
const BROWSE_DURATION_MIN: float = 5.0
const BROWSE_DURATION_MAX: float = 15.0
const REPUTATION_TIER_BONUS_THRESHOLD: int = 2
const REPUTATION_PURCHASE_BONUS: float = 0.1

const ANIMATION_MAP: Dictionary = {
	CustomerVisitState.IDLE: &"idle_stand",
	CustomerVisitState.BROWSING: &"idle_browse",
	CustomerVisitState.APPROACHING_CHECKOUT: &"walk",
	CustomerVisitState.WAITING_IN_QUEUE: &"idle_wait",
	CustomerVisitState.LEAVING: &"exit_walk",
}

var _state: CustomerVisitState = CustomerVisitState.IDLE
var _nav_config: CustomerNavConfig = null
var _customer_def: Dictionary = {}
var _satisfied: bool = false
var _browse_waypoint_index: int = 0
var _nav_recalc_timer: float = 0.0
var _initialized: bool = false
var _browse_timer: float = 0.0
var _browse_timer_expired: bool = false
var _inventory_system: InventorySystem = null
var _store_id: StringName = &""

@onready var _navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_navigation_agent.velocity_computed.connect(_on_velocity_computed)
	_create_animations()


func initialize(
	customer_def: Dictionary,
	nav_config: CustomerNavConfig,
	inventory_system: InventorySystem = null,
	store_id: StringName = &""
) -> void:
	_customer_def = customer_def
	_nav_config = nav_config
	_inventory_system = inventory_system
	_store_id = store_id
	_satisfied = false
	_browse_waypoint_index = 0
	_browse_timer = randf_range(BROWSE_DURATION_MIN, BROWSE_DURATION_MAX)
	_browse_timer_expired = false
	_transition(CustomerVisitState.IDLE)
	_initialized = true


func begin_visit() -> void:
	if not _initialized:
		push_warning("CustomerNPC.begin_visit called before initialize")
		return
	_transition(CustomerVisitState.BROWSING)


func send_to_checkout() -> void:
	if not _initialized:
		push_warning("CustomerNPC.send_to_checkout called before initialize")
		return
	_transition(CustomerVisitState.APPROACHING_CHECKOUT)


func begin_leave() -> void:
	if not _initialized:
		push_warning("CustomerNPC.begin_leave called before initialize")
		return
	_satisfied = _state == CustomerVisitState.WAITING_IN_QUEUE
	_transition(CustomerVisitState.LEAVING)


func get_visit_state() -> CustomerVisitState:
	return _state


func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	match _state:
		CustomerVisitState.BROWSING:
			_process_browsing(delta)
		CustomerVisitState.APPROACHING_CHECKOUT:
			_process_approaching_checkout()
		CustomerVisitState.LEAVING:
			_process_leaving()
	_move_along_path(delta)


func _transition(new_state: CustomerVisitState) -> void:
	_state = new_state
	_play_safe(ANIMATION_MAP.get(new_state, FALLBACK_ANIMATION))
	match new_state:
		CustomerVisitState.BROWSING:
			_navigate_to_next_browse_waypoint()
		CustomerVisitState.APPROACHING_CHECKOUT:
			if _nav_config:
				_navigation_agent.target_position = (
					_nav_config.get_checkout_position()
				)
		CustomerVisitState.LEAVING:
			if _nav_config:
				_navigation_agent.target_position = (
					_nav_config.get_exit_position()
				)


func _process_browsing(delta: float) -> void:
	if not _browse_timer_expired:
		_browse_timer -= delta
		if _browse_timer <= 0.0:
			_browse_timer_expired = true
			_on_browse_timer_timeout()
			return
	if not _navigation_agent.is_navigation_finished():
		return
	_browse_waypoint_index += 1
	if not _navigate_to_next_browse_waypoint():
		_browse_waypoint_index = 0
		_navigate_to_next_browse_waypoint()


func _process_approaching_checkout() -> void:
	if _navigation_agent.is_navigation_finished():
		EventBus.customer_reached_checkout.emit(self)
		_transition(CustomerVisitState.WAITING_IN_QUEUE)


func _process_leaving() -> void:
	if _navigation_agent.is_navigation_finished():
		EventBus.customer_left_mall.emit(self, _satisfied)
		queue_free()


func _on_browse_timer_timeout() -> void:
	if _state == CustomerVisitState.APPROACHING_CHECKOUT:
		return
	var will_purchase: bool = _evaluate_purchase_intent()
	if will_purchase:
		_transition_to_checkout_approach()
	else:
		_transition_to_leave()


func _evaluate_purchase_intent() -> bool:
	var purchase_intent: float = _customer_def.get(
		"purchase_intent", 0.5
	) as float
	var interest_category: StringName = StringName(
		_customer_def.get("interest_category", "") as String
	)
	if not _has_stock_matching_category(interest_category):
		return false
	var final_chance: float = purchase_intent
	final_chance += _get_demo_browse_bonus(interest_category)
	var store_key: String = String(_store_id)
	if store_key.is_empty():
		store_key = GameManager.current_store_id
	var tier: int = ReputationSystemSingleton.get_tier(store_key) as int
	if tier > REPUTATION_TIER_BONUS_THRESHOLD:
		final_chance += REPUTATION_PURCHASE_BONUS
	return randf() < final_chance


func _has_stock_matching_category(
	interest_category: StringName,
) -> bool:
	if interest_category.is_empty():
		return true
	if not _inventory_system:
		return true
	var store_key: StringName = _store_id
	if store_key.is_empty():
		store_key = StringName(GameManager.current_store_id)
	if store_key.is_empty():
		return true
	var stock: Array[ItemInstance] = _inventory_system.get_stock(
		store_key
	)
	for item: ItemInstance in stock:
		if not item.definition:
			continue
		if StringName(item.definition.category) == interest_category:
			return true
	return false


func _get_demo_browse_bonus(
	interest_category: StringName,
) -> float:
	if not _inventory_system or interest_category.is_empty():
		return 0.0
	var store_key: StringName = _store_id
	if store_key.is_empty():
		store_key = StringName(GameManager.current_store_id)
	if store_key.is_empty():
		return 0.0
	var entry: Dictionary = ContentRegistry.get_entry(store_key)
	if entry.is_empty():
		return 0.0
	var bonus: float = float(entry.get("demo_interest_bonus", 0.0))
	if bonus <= 0.0:
		return 0.0
	var stock: Array[ItemInstance] = _inventory_system.get_stock(
		store_key
	)
	for item: ItemInstance in stock:
		if not item.is_demo or not item.definition:
			continue
		if StringName(item.definition.category) == interest_category:
			return bonus
	return 0.0


func _transition_to_checkout_approach() -> void:
	_satisfied = true
	_transition(CustomerVisitState.APPROACHING_CHECKOUT)


func _transition_to_leave() -> void:
	_satisfied = false
	_transition(CustomerVisitState.LEAVING)


func _navigate_to_next_browse_waypoint() -> bool:
	if not _nav_config:
		return false
	var positions: Array[Vector3] = _nav_config.get_browse_positions()
	if positions.is_empty():
		return false
	if _browse_waypoint_index >= positions.size():
		return false
	_navigation_agent.target_position = positions[_browse_waypoint_index]
	return true


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
	var desired: Vector3 = direction.normalized() * MOVE_SPEED
	if _navigation_agent.avoidance_enabled:
		_navigation_agent.set_velocity(desired)
	else:
		velocity = desired
		move_and_slide()


func _play_safe(anim_name: StringName) -> void:
	if not _animation_player:
		return
	if not _animation_player.has_animation(anim_name):
		push_warning(
			"CustomerNPC: missing animation '%s', falling back to '%s'"
			% [anim_name, FALLBACK_ANIMATION]
		)
		if not _animation_player.has_animation(FALLBACK_ANIMATION):
			return
		_animation_player.play(FALLBACK_ANIMATION)
		return
	_animation_player.play(anim_name)


func _create_animations() -> void:
	var lib := AnimationLibrary.new()

	lib.add_animation("idle_stand", _make_idle_stand())
	lib.add_animation("idle_browse", _make_idle_browse())
	lib.add_animation("pick_up_item", _make_pick_up_item())
	lib.add_animation("place_item", _make_place_item())
	lib.add_animation("idle_wait", _make_idle_wait())
	lib.add_animation("walk", _make_walk())
	lib.add_animation("exit_walk", _make_exit_walk())

	_animation_player.add_animation_library("", lib)


func _make_idle_stand() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = 2.0
	var track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, "MeshInstance3D")
	anim.track_insert_key(track, 0.0, Vector3(0.0, 0.7, 0.0))
	anim.track_insert_key(track, 1.0, Vector3(0.0, 0.72, 0.0))
	anim.track_insert_key(track, 2.0, Vector3(0.0, 0.7, 0.0))
	return anim


func _make_idle_browse() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = 2.0
	var track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, "MeshInstance3D")
	var left := Quaternion.from_euler(
		Vector3(0.0, deg_to_rad(15.0), 0.0)
	)
	var right := Quaternion.from_euler(
		Vector3(0.0, deg_to_rad(-15.0), 0.0)
	)
	anim.track_insert_key(track, 0.0, Quaternion.IDENTITY)
	anim.track_insert_key(track, 0.5, left)
	anim.track_insert_key(track, 1.0, Quaternion.IDENTITY)
	anim.track_insert_key(track, 1.5, right)
	anim.track_insert_key(track, 2.0, Quaternion.IDENTITY)
	return anim


func _make_pick_up_item() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_NONE
	anim.length = 0.8
	var track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, "MeshInstance3D")
	var lean := Quaternion.from_euler(
		Vector3(deg_to_rad(20.0), 0.0, 0.0)
	)
	anim.track_insert_key(track, 0.0, Quaternion.IDENTITY)
	anim.track_insert_key(track, 0.3, lean)
	anim.track_insert_key(track, 0.8, Quaternion.IDENTITY)
	return anim


func _make_place_item() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_NONE
	anim.length = 0.6
	var track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, "MeshInstance3D")
	var lean := Quaternion.from_euler(
		Vector3(deg_to_rad(10.0), 0.0, 0.0)
	)
	anim.track_insert_key(track, 0.0, Quaternion.IDENTITY)
	anim.track_insert_key(track, 0.2, lean)
	anim.track_insert_key(track, 0.6, Quaternion.IDENTITY)
	return anim


func _make_idle_wait() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = 2.4
	var track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, "MeshInstance3D")
	var sway_l := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(2.0))
	)
	var sway_r := Quaternion.from_euler(
		Vector3(0.0, 0.0, deg_to_rad(-2.0))
	)
	anim.track_insert_key(track, 0.0, Quaternion.IDENTITY)
	anim.track_insert_key(track, 0.6, sway_l)
	anim.track_insert_key(track, 1.2, Quaternion.IDENTITY)
	anim.track_insert_key(track, 1.8, sway_r)
	anim.track_insert_key(track, 2.4, Quaternion.IDENTITY)
	return anim


func _make_walk() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = 0.4
	var track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, "MeshInstance3D")
	anim.track_insert_key(track, 0.0, Vector3(0.0, 0.7, 0.0))
	anim.track_insert_key(track, 0.2, Vector3(0.0, 0.76, 0.0))
	anim.track_insert_key(track, 0.4, Vector3(0.0, 0.7, 0.0))
	var rot_track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot_track, "MeshInstance3D")
	var lean := Quaternion.from_euler(
		Vector3(deg_to_rad(5.0), 0.0, 0.0)
	)
	anim.track_insert_key(rot_track, 0.0, lean)
	anim.track_insert_key(rot_track, 0.4, lean)
	return anim


func _make_exit_walk() -> Animation:
	var anim := Animation.new()
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.length = 0.5
	var track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, "MeshInstance3D")
	anim.track_insert_key(track, 0.0, Vector3(0.0, 0.7, 0.0))
	anim.track_insert_key(track, 0.25, Vector3(0.0, 0.74, 0.0))
	anim.track_insert_key(track, 0.5, Vector3(0.0, 0.7, 0.0))
	return anim


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
	move_and_slide()
