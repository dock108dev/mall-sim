## Mall-wide shopper NPC with waypoint-driven movement and a lightweight FSM.
class_name ShopperAI
extends CharacterBody3D

enum ShopperState {
	ENTERING,
	WALKING,
	BROWSING,
	WINDOW_SHOPPING,
	BUYING,
	EATING,
	SITTING,
	SOCIALIZING,
	LEAVING,
}

enum AIDetail { FULL, SIMPLE, MINIMAL }

const BROWSE_TIME_MIN: float = 8.0
const BROWSE_TIME_MAX: float = 30.0
const WINDOW_SHOP_TIME_MIN: float = 4.0
const WINDOW_SHOP_TIME_MAX: float = 12.0
const BUY_TIME_MIN: float = 3.0
const BUY_TIME_MAX: float = 6.0
const EAT_TIME_MIN: float = 20.0
const EAT_TIME_MAX: float = 60.0
const SIT_TIME_MIN: float = 15.0
const SIT_TIME_MAX: float = 45.0
const SOCIALIZE_TIME_MIN: float = 10.0
const SOCIALIZE_TIME_MAX: float = 30.0
const BUY_CHANCE_BASE: float = 0.15
const LOOK_CYCLE_INTERVAL: float = 4.0
const UTILITY_EVAL_INTERVAL: float = 1.0
const SIMPLE_UTILITY_INTERVAL: float = 5.0
const ACTION_SCORE_NOISE: float = 0.1
const LANE_OFFSET: float = 0.6
const FULL_AI_RADIUS: float = 30.0
const SIMPLE_AI_RADIUS: float = 60.0

const FALLBACK_ANIMATION: StringName = &"idle"
const ANIMATION_MAP: Dictionary = {
	ShopperState.ENTERING: &"walk",
	ShopperState.WALKING: &"walk",
	ShopperState.BROWSING: &"idle_look",
	ShopperState.WINDOW_SHOPPING: &"idle_look",
	ShopperState.BUYING: &"interact",
	ShopperState.EATING: &"idle",
	ShopperState.SITTING: &"idle",
	ShopperState.SOCIALIZING: &"idle",
	ShopperState.LEAVING: &"walk",
}

@onready var _waypoint_agent: MallWaypointAgent = $MallWaypointAgent

var current_state: ShopperState = ShopperState.ENTERING
var ai_detail: AIDetail = AIDetail.FULL
var target_waypoint: MallWaypoint = null
var personality: PersonalityData = null
var shopper_budget: float = 0.0
var needs: ShopperNeeds = ShopperNeeds.new()
var shopper_group: ShopperGroup = null
var purchase_item_id: StringName = &"unknown_item"
var purchase_price: float = 0.0
var purchase_store_id: StringName = &""
var customer_id: StringName = &""

var _nav: ShopperNavigation = ShopperNavigation.new()
var _state_timer: float = 0.0
var _look_timer: float = 0.0
var _utility_timer: float = 0.0
var _made_purchase: bool = false
var _initialized: bool = false
var _time_paused: bool = false
var _lane_side: float = 0.0
var _animation_player: AnimationPlayer = null
var _is_despawning: bool = false


func _ready() -> void:
	add_to_group("shoppers")
	if not EventBus.speed_changed.is_connected(_on_speed_changed):
		EventBus.speed_changed.connect(_on_speed_changed)
	_animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _animation_player == null:
		_animation_player = AnimationPlayer.new()
		_animation_player.name = "AnimationPlayer"
		add_child(_animation_player)
	_ensure_animation_library()
	if customer_id.is_empty():
		customer_id = StringName(str(get_instance_id()))
	needs.initialize_from_personality(personality)
	EventBus.customer_spawned.emit(self)
	_play_animation_for_state(current_state)


func initialize(spawn_position: Vector3) -> void:
	global_position = spawn_position
	_nav.setup(_waypoint_agent, self)
	_lane_side = _nav.lane_side
	if personality:
		shopper_budget = randf_range(personality.min_budget, personality.max_budget)
		needs.initialize_from_personality(personality)

	var first_hallway: MallWaypoint = _nav.get_nearest_of_type(
		MallWaypoint.WaypointType.HALLWAY
	)
	if first_hallway == null:
		push_error("ShopperAI: No HALLWAY waypoint found near spawn.")
		current_state = ShopperState.LEAVING
		_initialized = true
		return

	_nav.set_target(first_hallway)
	_sync_target()
	_transition_to(ShopperState.ENTERING)
	_initialized = true


func _physics_process(delta: float) -> void:
	if not _initialized or _time_paused or _is_despawning:
		return

	match ai_detail:
		AIDetail.FULL:
			_physics_full(delta)
		AIDetail.SIMPLE:
			_physics_simple(delta)
		AIDetail.MINIMAL:
			_physics_minimal(delta)

	if ai_detail == AIDetail.FULL and _is_moving_state():
		_nav.apply_separation(delta)


func _physics_full(delta: float) -> void:
	_update_needs(delta, _is_moving_state())
	if _is_group_follower():
		_process_follower_movement(delta)
		return

	_utility_timer -= delta
	if _utility_timer <= 0.0:
		_utility_timer = UTILITY_EVAL_INTERVAL
		_evaluate_next_action()

	_process_state(delta)


func _physics_simple(delta: float) -> void:
	_update_needs(delta, _is_moving_state())
	if _is_group_follower():
		_process_follower_movement(delta)
		return

	_utility_timer -= delta
	if _utility_timer <= 0.0:
		_utility_timer = SIMPLE_UTILITY_INTERVAL
		_evaluate_next_action()

	_process_simple_state(delta)


func _physics_minimal(delta: float) -> void:
	_update_needs_only(delta)


func get_state() -> ShopperState:
	return current_state


func request_leave() -> void:
	if current_state == ShopperState.LEAVING:
		return
	if not _nav.pick_exit_path():
		_despawn()
		return
	_sync_target()
	_transition_to(ShopperState.LEAVING)


func _score_action(action: String) -> float:
	return needs.score_action(
		action,
		personality,
		_store_appeal(),
		_nav.waypoint_proximity(MallWaypoint.WaypointType.FOOD_COURT_SEAT),
		_nav.waypoint_proximity(MallWaypoint.WaypointType.BENCH),
		_nearby_shopper_count(),
		_time_spent_factor()
	)


func _evaluate_next_action() -> void:
	if current_state in [
		ShopperState.ENTERING,
		ShopperState.LEAVING,
		ShopperState.BUYING,
	]:
		return
	if _state_timer > 0.0:
		return
	if _is_group_leader() and shopper_group.has_reluctant_companion_override():
		_navigate_to_type(MallWaypoint.WaypointType.BENCH)
		return

	var actions: PackedStringArray = [
		"visit_store",
		"eat",
		"sit",
		"window_shop",
		"socialize",
		"leave",
	]
	var best_action: String = "leave"
	var best_score: float = -INF

	for action: String in actions:
		var score: float = _score_group_or_solo(action)
		score += randf_range(-ACTION_SCORE_NOISE, ACTION_SCORE_NOISE)
		if score > best_score:
			best_score = score
			best_action = action

	_execute_action(best_action)


func _execute_action(action: String) -> void:
	match action:
		"visit_store":
			_navigate_to_store()
		"eat":
			_navigate_to_type(MallWaypoint.WaypointType.FOOD_COURT_SEAT)
		"sit":
			_navigate_to_type(MallWaypoint.WaypointType.BENCH)
		"window_shop":
			target_waypoint = null
			_nav.target_waypoint = null
			_transition_to(ShopperState.WINDOW_SHOPPING)
		"socialize":
			_transition_to(ShopperState.SOCIALIZING)
		"leave":
			request_leave()


func _store_appeal() -> float:
	return 1.0


func _nearby_shopper_count() -> float:
	var count: int = 0
	var shoppers: Array[Node] = get_tree().get_nodes_in_group("shoppers")
	for node: Node in shoppers:
		if node == self:
			continue
		var other: Node3D = node as Node3D
		if other == null:
			continue
		if global_position.distance_to(other.global_position) < 10.0:
			count += 1
	return clampf(float(count) / 5.0, 0.0, 1.0)


func _time_spent_factor() -> float:
	if needs.shopping <= 0.1:
		return 1.0
	return 0.3


func _navigate_to_store() -> void:
	var waypoint: MallWaypoint = _nav.get_nearest_of_type(
		MallWaypoint.WaypointType.STORE_ENTRANCE
	)
	if waypoint == null:
		_nav.pick_next_walking_destination()
		_sync_target()
		_transition_to(ShopperState.WALKING)
		return
	_nav.navigate_to_waypoint(waypoint)
	_sync_target()
	_transition_to(ShopperState.WALKING)


func _navigate_to_type(wp_type: MallWaypoint.WaypointType) -> void:
	var waypoint: MallWaypoint = _nav.get_nearest_of_type(wp_type)
	if waypoint == null:
		_transition_to(ShopperState.WALKING)
		return
	_nav.navigate_to_waypoint(waypoint)
	_sync_target()
	_transition_to(ShopperState.WALKING)


func _process_state(delta: float) -> void:
	match current_state:
		ShopperState.ENTERING:
			_process_entering(delta)
		ShopperState.WALKING:
			_process_walking(delta)
		ShopperState.BROWSING:
			_process_browsing(delta)
		ShopperState.WINDOW_SHOPPING, ShopperState.EATING, ShopperState.SITTING, ShopperState.SOCIALIZING:
			_process_timed_state(delta)
		ShopperState.BUYING:
			_process_buying(delta)
		ShopperState.LEAVING:
			_process_leaving(delta)


func _process_simple_state(delta: float) -> void:
	match current_state:
		ShopperState.BROWSING, ShopperState.WINDOW_SHOPPING:
			_process_simple_browsing()
		_:
			_process_state(delta)


func _process_simple_browsing() -> void:
	if _should_buy_item():
		if current_state == ShopperState.WINDOW_SHOPPING:
			_navigate_to_store()
			return
		_navigate_to_register()
		return
	request_leave()


func _process_entering(delta: float) -> void:
	if target_waypoint == null:
		_transition_to(ShopperState.WALKING)
		return
	_nav.move_toward_target(delta)
	if _nav.has_arrived_at_target():
		_waypoint_agent.advance()
		target_waypoint = null
		_nav.target_waypoint = null
		_transition_to(ShopperState.WALKING)


func _process_walking(delta: float) -> void:
	if target_waypoint == null:
		_nav.pick_next_walking_destination()
		_sync_target()
		if target_waypoint == null:
			request_leave()
			return

	_nav.move_toward_target(delta)
	if not _nav.has_arrived_at_target():
		return

	var arrived_waypoint: MallWaypoint = target_waypoint
	_waypoint_agent.advance()
	_nav.advance_along_path()
	_sync_target()
	if target_waypoint != null:
		return

	match arrived_waypoint.waypoint_type:
		MallWaypoint.WaypointType.STORE_ENTRANCE:
			if purchase_store_id.is_empty():
				purchase_store_id = arrived_waypoint.associated_store_id
			_transition_to(ShopperState.BROWSING)
		MallWaypoint.WaypointType.REGISTER:
			if purchase_store_id.is_empty():
				purchase_store_id = arrived_waypoint.associated_store_id
			_transition_to(ShopperState.BUYING)
		MallWaypoint.WaypointType.FOOD_COURT_SEAT:
			_transition_to(ShopperState.EATING)
		MallWaypoint.WaypointType.BENCH:
			_transition_to(ShopperState.SITTING)
		MallWaypoint.WaypointType.EXIT:
			_despawn()


func _process_browsing(delta: float) -> void:
	_state_timer = maxf(_state_timer - delta, 0.0)
	_look_timer -= delta
	if _look_timer > 0.0:
		return

	_look_timer = LOOK_CYCLE_INTERVAL
	_play_animation(&"idle_look")
	if _should_buy_item():
		_navigate_to_register()
	elif _state_timer <= 0.0:
		_transition_to(ShopperState.WALKING)


func _navigate_to_register() -> void:
	var register: MallWaypoint = _nav.get_nearest_of_type(
		MallWaypoint.WaypointType.REGISTER
	)
	if register == null:
		request_leave()
		return
	if purchase_store_id.is_empty():
		purchase_store_id = register.associated_store_id
	_nav.navigate_to_waypoint(register)
	_sync_target()
	_transition_to(ShopperState.WALKING)


func _process_buying(delta: float) -> void:
	if target_waypoint != null:
		_nav.move_toward_target(delta)
		if not _nav.has_arrived_at_target():
			return
		_waypoint_agent.advance()
		target_waypoint = null
		_nav.target_waypoint = null

	_state_timer = maxf(_state_timer - delta, 0.0)
	if _state_timer > 0.0:
		return

	_made_purchase = true
	EventBus.customer_purchased.emit(
		purchase_store_id,
		purchase_item_id,
		purchase_price,
		customer_id
	)
	request_leave()


func _process_timed_state(delta: float) -> void:
	_state_timer = maxf(_state_timer - delta, 0.0)
	if _state_timer <= 0.0:
		_transition_to(ShopperState.WALKING)


func _process_leaving(delta: float) -> void:
	if target_waypoint == null:
		if _waypoint_agent.is_path_complete():
			_despawn()
			return
		_nav.advance_along_path()
		_sync_target()
		if target_waypoint == null:
			_despawn()
			return

	_nav.move_toward_target(delta)
	if not _nav.has_arrived_at_target():
		return

	_waypoint_agent.advance()
	if _waypoint_agent.is_path_complete():
		_despawn()
		return
	_nav.advance_along_path()
	_sync_target()


func _transition_to(new_state: ShopperState) -> void:
	current_state = new_state
	var browse_mult: float = 1.0
	if personality:
		browse_mult = personality.browse_duration_mult

	match new_state:
		ShopperState.BROWSING:
			_state_timer = randf_range(BROWSE_TIME_MIN, BROWSE_TIME_MAX) * browse_mult
			_look_timer = LOOK_CYCLE_INTERVAL
		ShopperState.WINDOW_SHOPPING:
			_state_timer = randf_range(WINDOW_SHOP_TIME_MIN, WINDOW_SHOP_TIME_MAX)
		ShopperState.BUYING:
			_state_timer = randf_range(BUY_TIME_MIN, BUY_TIME_MAX)
		ShopperState.EATING:
			_state_timer = randf_range(EAT_TIME_MIN, EAT_TIME_MAX)
		ShopperState.SITTING:
			_state_timer = randf_range(SIT_TIME_MIN, SIT_TIME_MAX)
		ShopperState.SOCIALIZING:
			_state_timer = randf_range(SOCIALIZE_TIME_MIN, SOCIALIZE_TIME_MAX)
		ShopperState.LEAVING:
			if _initialized and target_waypoint == null and _waypoint_agent.is_path_complete():
				if not _nav.pick_exit_path():
					_despawn()
					return
				_sync_target()
		_:
			_state_timer = maxf(_state_timer, 0.0)

	_play_animation_for_state(new_state)


func _sync_target() -> void:
	target_waypoint = _nav.target_waypoint


func _should_buy_item() -> bool:
	var impulse_bonus: float = 0.0
	if personality:
		impulse_bonus = personality.impulse_factor * 0.3
	var need_bonus: float = needs.shopping * 0.2
	return randf() < (BUY_CHANCE_BASE + impulse_bonus + need_bonus)


func _is_moving_state() -> bool:
	return current_state in [
		ShopperState.ENTERING,
		ShopperState.WALKING,
		ShopperState.LEAVING,
	]


func _state_name(state: ShopperState) -> String:
	match state:
		ShopperState.BROWSING:
			return "BROWSING"
		ShopperState.BUYING:
			return "BUYING"
		ShopperState.EATING:
			return "EATING"
		ShopperState.SITTING:
			return "SITTING"
		ShopperState.SOCIALIZING:
			return "SOCIALIZING"
		_:
			return "OTHER"


func _update_needs(delta: float, is_moving: bool) -> void:
	needs.update(delta, is_moving, _state_name(current_state), personality)


func _update_needs_only(delta: float) -> void:
	_update_needs(delta, false)


func _is_group_follower() -> bool:
	if shopper_group == null:
		return false
	return shopper_group.leader != self


func _is_group_leader() -> bool:
	if shopper_group == null:
		return false
	return shopper_group.leader == self


func _score_group_or_solo(action: String) -> float:
	if _is_group_leader():
		return shopper_group.score_group_action(action)
	return _score_action(action)


func _get_follower_index() -> int:
	if shopper_group == null:
		return -1
	return shopper_group.followers.find(self)


func _process_follower_movement(_delta: float) -> void:
	var follower_index: int = _get_follower_index()
	if follower_index < 0:
		return
	if shopper_group.leader == null or not is_instance_valid(shopper_group.leader):
		return

	current_state = shopper_group.leader.current_state
	var slot_position: Vector3 = shopper_group.get_formation_world_position(follower_index)
	var offset: Vector3 = slot_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		velocity = Vector3.ZERO
		return

	var move_speed: float = ShopperNavigation.BASE_WALK_SPEED
	if shopper_group.should_follower_catch_up(follower_index):
		move_speed *= ShopperGroup.CATCHUP_SPEED_MULT
	velocity = offset.normalized() * move_speed
	move_and_slide()


func _despawn() -> void:
	if _is_despawning:
		return
	_is_despawning = true
	if shopper_group:
		shopper_group.remove_member(self)
	EventBus.customer_left.emit({
		"customer": self,
		"satisfied": _made_purchase,
	})
	EventBus.customer_left_mall.emit(self, _made_purchase)
	queue_free()


func _on_speed_changed(new_speed: float) -> void:
	_time_paused = new_speed <= 0.0


func _ensure_animation_library() -> void:
	var library: AnimationLibrary = null
	if _animation_player.has_animation_library(""):
		library = _animation_player.get_animation_library("")
	if library == null:
		library = AnimationLibrary.new()
		_animation_player.add_animation_library("", library)
	_add_animation_if_missing(library, &"walk", true, 0.4)
	_add_animation_if_missing(library, &"idle_look", true, 2.0)
	_add_animation_if_missing(library, &"interact", true, 0.8)
	_add_animation_if_missing(library, &"idle", true, 1.0)


func _add_animation_if_missing(
	library: AnimationLibrary,
	animation_name: StringName,
	looping: bool,
	length: float
) -> void:
	if library.has_animation(animation_name):
		return
	var animation: Animation = Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	library.add_animation(animation_name, animation)


func _play_animation_for_state(state: ShopperState) -> void:
	_play_animation(ANIMATION_MAP.get(state, FALLBACK_ANIMATION))


func _play_animation(animation_name: StringName) -> void:
	if _animation_player == null:
		return
	if not _animation_player.has_animation(animation_name):
		animation_name = FALLBACK_ANIMATION
	if _animation_player.has_animation(animation_name):
		_animation_player.play(animation_name)
