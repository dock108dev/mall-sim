## Tests ShopperAI FSM states, needs model, personality, and utility scoring.
extends GutTest


class AlwaysBuyShopper:
	extends ShopperAI

	func _should_buy_item() -> bool:
		return true


class NeverBuyShopper:
	extends ShopperAI

	func _should_buy_item() -> bool:
		return false


class RecordingShopperNavigation:
	extends ShopperNavigation

	var separation_calls: int = 0

	func apply_separation(_delta: float) -> void:
		separation_calls += 1


var _shopper: ShopperAI


func before_each() -> void:
	_shopper = ShopperAI.new()
	var agent := MallWaypointAgent.new()
	agent.name = "MallWaypointAgent"
	_shopper.add_child(agent)
	add_child_autofree(_shopper)


func _make_waypoint(
	wp_name: String,
	pos: Vector3 = Vector3.ZERO,
	type: MallWaypoint.WaypointType = MallWaypoint.WaypointType.HALLWAY,
	store_id: StringName = &""
) -> MallWaypoint:
	var wp := MallWaypoint.new()
	wp.name = wp_name
	wp.position = pos
	wp.waypoint_type = type
	wp.associated_store_id = store_id
	add_child_autofree(wp)
	return wp


func _connect_bi(a: MallWaypoint, b: MallWaypoint) -> void:
	a.connected_waypoints.append(b)
	b.connected_waypoints.append(a)


func _make_personality(
	p_type: PersonalityData.PersonalityType = PersonalityData.PersonalityType.WINDOW_BROWSER
) -> PersonalityData:
	var pd := PersonalityData.new()
	pd.personality_type = p_type
	pd.shop_weight = 1.0
	pd.impulse_factor = 0.3
	pd.hunger_rate_mult = 1.0
	pd.energy_drain_mult = 1.0
	pd.social_need_baseline = 0.5
	pd.browse_duration_mult = 1.0
	pd.min_budget = 20.0
	pd.max_budget = 100.0
	pd.avg_visit_minutes_min = 30.0
	pd.avg_visit_minutes_max = 60.0
	return pd


func test_shopper_state_enum_has_required_states() -> void:
	assert_eq(ShopperAI.ShopperState.ENTERING, 0)
	assert_eq(ShopperAI.ShopperState.WALKING, 1)
	assert_eq(ShopperAI.ShopperState.BROWSING, 2)
	assert_eq(ShopperAI.ShopperState.WINDOW_SHOPPING, 3)
	assert_eq(ShopperAI.ShopperState.BUYING, 4)
	assert_eq(ShopperAI.ShopperState.EATING, 5)
	assert_eq(ShopperAI.ShopperState.SITTING, 6)
	assert_eq(ShopperAI.ShopperState.SOCIALIZING, 7)
	assert_eq(ShopperAI.ShopperState.LEAVING, 8)


func test_initial_state_is_entering() -> void:
	assert_eq(_shopper.current_state, ShopperAI.ShopperState.ENTERING)


func test_initialize_sets_entering_state() -> void:
	var _hw: MallWaypoint = _make_waypoint(
		"H1", Vector3(5, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_shopper.initialize(Vector3.ZERO)
	assert_eq(_shopper.current_state, ShopperAI.ShopperState.ENTERING)
	assert_not_null(_shopper.target_waypoint)


func test_initialize_without_hallway_transitions_to_leaving() -> void:
	_shopper.initialize(Vector3.ZERO)
	assert_eq(_shopper.current_state, ShopperAI.ShopperState.LEAVING)


func test_entering_transitions_to_walking_on_arrival() -> void:
	var _hw: MallWaypoint = _make_waypoint(
		"H1", Vector3(0.1, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_shopper.initialize(Vector3.ZERO)
	_shopper._physics_process(0.1)
	assert_eq(
		_shopper.current_state, ShopperAI.ShopperState.WALKING,
		"Should transition to WALKING after reaching first waypoint"
	)


func test_browsing_state_has_timer() -> void:
	_shopper._transition_to(ShopperAI.ShopperState.BROWSING)
	assert_eq(_shopper.current_state, ShopperAI.ShopperState.BROWSING)
	assert_true(
		_shopper._state_timer >= ShopperAI.BROWSE_TIME_MIN,
		"Browse timer should be at least minimum"
	)
	assert_true(
		_shopper._state_timer <= ShopperAI.BROWSE_TIME_MAX,
		"Browse timer should be at most maximum"
	)


func test_window_shopping_state_has_timer() -> void:
	_shopper._transition_to(ShopperAI.ShopperState.WINDOW_SHOPPING)
	assert_eq(
		_shopper.current_state,
		ShopperAI.ShopperState.WINDOW_SHOPPING
	)
	assert_true(
		_shopper._state_timer >= ShopperAI.WINDOW_SHOP_TIME_MIN
	)
	assert_true(
		_shopper._state_timer <= ShopperAI.WINDOW_SHOP_TIME_MAX
	)


func test_buying_state_has_timer() -> void:
	_shopper._transition_to(ShopperAI.ShopperState.BUYING)
	assert_eq(_shopper.current_state, ShopperAI.ShopperState.BUYING)
	assert_true(_shopper._state_timer >= ShopperAI.BUY_TIME_MIN)
	assert_true(_shopper._state_timer <= ShopperAI.BUY_TIME_MAX)


func test_eating_state_has_timer() -> void:
	_shopper._transition_to(ShopperAI.ShopperState.EATING)
	assert_eq(_shopper.current_state, ShopperAI.ShopperState.EATING)
	assert_true(_shopper._state_timer >= ShopperAI.EAT_TIME_MIN)
	assert_true(_shopper._state_timer <= ShopperAI.EAT_TIME_MAX)


func test_sitting_state_has_timer() -> void:
	_shopper._transition_to(ShopperAI.ShopperState.SITTING)
	assert_eq(_shopper.current_state, ShopperAI.ShopperState.SITTING)
	assert_true(_shopper._state_timer >= ShopperAI.SIT_TIME_MIN)
	assert_true(_shopper._state_timer <= ShopperAI.SIT_TIME_MAX)


func test_socializing_state_has_timer() -> void:
	_shopper._transition_to(ShopperAI.ShopperState.SOCIALIZING)
	assert_eq(
		_shopper.current_state, ShopperAI.ShopperState.SOCIALIZING
	)
	assert_true(
		_shopper._state_timer >= ShopperAI.SOCIALIZE_TIME_MIN
	)
	assert_true(
		_shopper._state_timer <= ShopperAI.SOCIALIZE_TIME_MAX
	)


func test_get_state_returns_current() -> void:
	_shopper._transition_to(ShopperAI.ShopperState.WALKING)
	assert_eq(
		_shopper.get_state(), ShopperAI.ShopperState.WALKING
	)


func test_lane_offset_is_valid() -> void:
	var _hw: MallWaypoint = _make_waypoint(
		"H1", Vector3(5, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_shopper.initialize(Vector3.ZERO)
	assert_true(
		absf(_shopper._lane_side) == ShopperAI.LANE_OFFSET,
		"Lane side should be +/- LANE_OFFSET"
	)


func test_shopper_is_in_shoppers_group() -> void:
	assert_true(_shopper.is_in_group("shoppers"))


func test_is_moving_state_returns_correct() -> void:
	_shopper._transition_to(ShopperAI.ShopperState.ENTERING)
	assert_true(_shopper._is_moving_state())
	_shopper._transition_to(ShopperAI.ShopperState.WALKING)
	assert_true(_shopper._is_moving_state())
	_shopper._transition_to(ShopperAI.ShopperState.LEAVING)
	assert_true(_shopper._is_moving_state())
	_shopper._transition_to(ShopperAI.ShopperState.BROWSING)
	assert_false(_shopper._is_moving_state())
	_shopper._transition_to(ShopperAI.ShopperState.BUYING)
	assert_false(_shopper._is_moving_state())
	_shopper._transition_to(ShopperAI.ShopperState.EATING)
	assert_false(_shopper._is_moving_state())
	_shopper._transition_to(ShopperAI.ShopperState.SITTING)
	assert_false(_shopper._is_moving_state())
	_shopper._transition_to(ShopperAI.ShopperState.SOCIALIZING)
	assert_false(_shopper._is_moving_state())


func test_speed_changed_pauses_shopper() -> void:
	var _hw: MallWaypoint = _make_waypoint(
		"H1", Vector3(5, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_shopper.initialize(Vector3.ZERO)
	EventBus.speed_changed.emit(0.0)
	assert_true(_shopper._time_paused)
	EventBus.speed_changed.emit(1.0)
	assert_false(_shopper._time_paused)


func test_needs_initialized_with_defaults() -> void:
	assert_eq(_shopper.needs.shopping, 1.0)
	assert_eq(_shopper.needs.hunger, 0.0)
	assert_eq(_shopper.needs.energy, 1.0)
	assert_eq(_shopper.needs.social, 0.5)


func test_ready_initializes_needs_from_personality() -> void:
	var shopper := ShopperAI.new()
	var agent := MallWaypointAgent.new()
	agent.name = "MallWaypointAgent"
	shopper.add_child(agent)
	var pd: PersonalityData = _make_personality()
	pd.social_need_baseline = 0.85
	shopper.personality = pd
	add_child_autofree(shopper)
	assert_eq(
		shopper.needs.social, 0.85,
		"_ready should seed needs from the assigned personality"
	)


func test_needs_initialized_from_personality() -> void:
	var pd: PersonalityData = _make_personality()
	pd.social_need_baseline = 0.9
	_shopper.personality = pd
	var _hw: MallWaypoint = _make_waypoint(
		"H1", Vector3(5, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_shopper.initialize(Vector3.ZERO)
	assert_eq(
		_shopper.needs.social, 0.9,
		"Social need should initialize to personality baseline"
	)


func test_shopping_need_drains_while_browsing() -> void:
	var before: float = _shopper.needs.shopping
	_shopper.needs.update(1.0, false, "BROWSING", null)
	assert_lt(
		_shopper.needs.shopping, before,
		"Shopping need should decrease while browsing"
	)


func test_hunger_grows_passively() -> void:
	var before: float = _shopper.needs.hunger
	_shopper.needs.update(1.0, false, "BROWSING", null)
	assert_gt(
		_shopper.needs.hunger, before,
		"Hunger should increase passively"
	)


func test_hunger_grows_faster_while_walking() -> void:
	_shopper.needs.update(1.0, true, "OTHER", null)
	var walking_hunger: float = _shopper.needs.hunger

	_shopper.needs.hunger = 0.0
	_shopper.needs.update(1.0, false, "BROWSING", null)
	var idle_hunger: float = _shopper.needs.hunger

	assert_gt(
		walking_hunger, idle_hunger,
		"Hunger should grow faster while walking"
	)


func test_energy_drains_while_walking() -> void:
	var before: float = _shopper.needs.energy
	_shopper.needs.update(1.0, true, "OTHER", null)
	assert_lt(
		_shopper.needs.energy, before,
		"Energy should decrease while walking"
	)


func test_energy_restores_while_sitting() -> void:
	_shopper.needs.energy = 0.3
	var before: float = _shopper.needs.energy
	_shopper.needs.update(1.0, false, "SITTING", null)
	assert_gt(
		_shopper.needs.energy, before,
		"Energy should increase while sitting"
	)


func test_hunger_restores_while_eating() -> void:
	_shopper.needs.hunger = 0.8
	var before: float = _shopper.needs.hunger
	_shopper.needs.update(1.0, false, "EATING", null)
	assert_lt(
		_shopper.needs.hunger, before,
		"Hunger should decrease while eating"
	)


func test_needs_clamped_between_zero_and_one() -> void:
	_shopper.needs.shopping = -0.5
	_shopper.needs.hunger = 1.5
	_shopper.needs.energy = -0.1
	_shopper.needs.social = 2.0
	_shopper.needs.update(0.0, false, "OTHER", null)
	assert_eq(_shopper.needs.shopping, 0.0)
	assert_eq(_shopper.needs.hunger, 1.0)
	assert_eq(_shopper.needs.energy, 0.0)
	assert_eq(_shopper.needs.social, 1.0)


func test_score_action_returns_float() -> void:
	var score: float = _shopper._score_action("visit_store")
	assert_typeof(score, TYPE_FLOAT)


func test_score_action_all_six_actions_valid() -> void:
	var actions: PackedStringArray = [
		"visit_store", "eat", "sit",
		"window_shop", "socialize", "leave"
	]
	for action: String in actions:
		var score: float = _shopper._score_action(action)
		assert_true(
			is_finite(score),
			"Score for '%s' should be finite" % action
		)


func test_score_action_visit_store_uses_shop_weight() -> void:
	var pd: PersonalityData = _make_personality()
	pd.shop_weight = 2.0
	_shopper.personality = pd
	_shopper.needs.shopping = 1.0
	var scores: Array[float] = []
	for i: int in range(20):
		scores.append(_shopper._score_action("visit_store"))
	var avg: Array = [0.0]
	for s: float in scores:
		avg[0] += s
	avg[0] /= scores.size()
	assert_gt(avg[0], 1.5, "High shop_weight should produce high scores")


func test_score_action_leave_high_when_shopping_depleted() -> void:
	_shopper.needs.shopping = 0.0
	var scores: Array[float] = []
	for i: int in range(20):
		scores.append(_shopper._score_action("leave"))
	var avg: Array = [0.0]
	for s: float in scores:
		avg[0] += s
	avg[0] /= scores.size()
	assert_gt(
		avg[0], 0.5,
		"Leave score should be high when shopping need is depleted"
	)


func test_execute_window_shop_transitions_to_window_shopping() -> void:
	_shopper._transition_to(ShopperAI.ShopperState.WALKING)
	_shopper._execute_action("window_shop")
	assert_eq(
		_shopper.current_state,
		ShopperAI.ShopperState.WINDOW_SHOPPING
	)
	assert_null(_shopper.target_waypoint)
	assert_null(_shopper._nav.target_waypoint)


func test_budget_assigned_from_personality_on_initialize() -> void:
	var pd: PersonalityData = _make_personality()
	pd.min_budget = 50.0
	pd.max_budget = 150.0
	_shopper.personality = pd
	var _hw: MallWaypoint = _make_waypoint(
		"H1", Vector3(5, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_shopper.initialize(Vector3.ZERO)
	assert_gte(
		_shopper.shopper_budget, 50.0,
		"Budget should be >= min_budget"
	)
	assert_lte(
		_shopper.shopper_budget, 150.0,
		"Budget should be <= max_budget"
	)


func test_personality_hunger_rate_mult_affects_hunger() -> void:
	var pd_fast: PersonalityData = _make_personality()
	pd_fast.hunger_rate_mult = 2.0
	_shopper.needs.update(1.0, false, "OTHER", pd_fast)
	var fast_hunger: float = _shopper.needs.hunger

	_shopper.needs.hunger = 0.0
	var pd_slow: PersonalityData = _make_personality()
	pd_slow.hunger_rate_mult = 0.5
	_shopper.needs.update(1.0, false, "OTHER", pd_slow)
	var slow_hunger: float = _shopper.needs.hunger

	assert_gt(
		fast_hunger, slow_hunger,
		"Higher hunger_rate_mult should produce faster hunger growth"
	)


func test_evaluate_skips_during_entering_and_leaving() -> void:
	_shopper._transition_to(ShopperAI.ShopperState.ENTERING)
	var state_before: ShopperAI.ShopperState = _shopper.current_state
	_shopper._evaluate_next_action()
	assert_eq(
		_shopper.current_state, state_before,
		"Should not change state during ENTERING"
	)

	_shopper._transition_to(ShopperAI.ShopperState.LEAVING)
	state_before = _shopper.current_state
	_shopper._evaluate_next_action()
	assert_eq(
		_shopper.current_state, state_before,
		"Should not change state during LEAVING"
	)


func test_evaluate_skips_while_timer_active() -> void:
	_shopper._transition_to(ShopperAI.ShopperState.BROWSING)
	assert_gt(_shopper._state_timer, 0.0)
	var state_before: ShopperAI.ShopperState = _shopper.current_state
	_shopper._evaluate_next_action()
	assert_eq(
		_shopper.current_state, state_before,
		"Should not re-evaluate while timer is running"
	)


func test_browse_duration_mult_affects_timer() -> void:
	var pd: PersonalityData = _make_personality()
	pd.browse_duration_mult = 2.0
	_shopper.personality = pd
	_shopper._transition_to(ShopperAI.ShopperState.BROWSING)
	assert_gte(
		_shopper._state_timer,
		ShopperAI.BROWSE_TIME_MIN * 2.0,
		"Browse timer should be scaled by browse_duration_mult"
	)


func test_ai_detail_enum_has_three_values() -> void:
	assert_eq(ShopperAI.AIDetail.FULL, 0)
	assert_eq(ShopperAI.AIDetail.SIMPLE, 1)
	assert_eq(ShopperAI.AIDetail.MINIMAL, 2)


func test_ai_detail_defaults_to_full() -> void:
	assert_eq(_shopper.ai_detail, ShopperAI.AIDetail.FULL)


func test_lod_radius_constants_defined() -> void:
	assert_eq(ShopperAI.FULL_AI_RADIUS, 30.0)
	assert_eq(ShopperAI.SIMPLE_AI_RADIUS, 60.0)


func test_minimal_detail_only_updates_needs() -> void:
	var _hw: MallWaypoint = _make_waypoint(
		"H1", Vector3(50, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_shopper.initialize(Vector3.ZERO)
	_shopper.ai_detail = ShopperAI.AIDetail.MINIMAL
	_shopper._transition_to(ShopperAI.ShopperState.WALKING)
	var pos_before: Vector3 = _shopper.global_position
	var state_before: ShopperAI.ShopperState = _shopper.current_state
	_shopper._physics_process(1.0)
	assert_eq(
		_shopper.current_state, state_before,
		"MINIMAL should not change state"
	)
	assert_eq(
		_shopper.global_position, pos_before,
		"MINIMAL should not move"
	)


func test_simple_detail_uses_longer_utility_interval() -> void:
	var _hw: MallWaypoint = _make_waypoint(
		"H1", Vector3(50, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_shopper.initialize(Vector3.ZERO)
	_shopper.ai_detail = ShopperAI.AIDetail.SIMPLE
	_shopper._utility_timer = 0.0
	_shopper._transition_to(ShopperAI.ShopperState.WALKING)
	_shopper._physics_process(0.016)
	assert_almost_eq(
		_shopper._utility_timer,
		ShopperAI.SIMPLE_UTILITY_INTERVAL,
		0.1,
		"SIMPLE should reset utility timer to 5s interval"
	)


func test_simple_detail_skips_browsing_and_heads_to_register() -> void:
	var hallway: MallWaypoint = _make_waypoint(
		"Hallway", Vector3(0, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	var store: MallWaypoint = _make_waypoint(
		"Store", Vector3(4, 0, 0),
		MallWaypoint.WaypointType.STORE_ENTRANCE, &"retro_games"
	)
	var register: MallWaypoint = _make_waypoint(
		"Register", Vector3(8, 0, 0),
		MallWaypoint.WaypointType.REGISTER, &"retro_games"
	)
	_connect_bi(hallway, store)
	_connect_bi(store, register)

	var shopper := AlwaysBuyShopper.new()
	var agent := MallWaypointAgent.new()
	agent.name = "MallWaypointAgent"
	shopper.add_child(agent)
	add_child_autofree(shopper)

	shopper.initialize(store.global_position)
	shopper.global_position = store.global_position
	shopper.ai_detail = ShopperAI.AIDetail.SIMPLE
	shopper._transition_to(ShopperAI.ShopperState.BROWSING)
	shopper._physics_process(0.016)

	assert_eq(shopper.current_state, ShopperAI.ShopperState.WALKING)
	for _i: int in range(120):
		shopper._physics_process(0.1)
		if shopper.current_state == ShopperAI.ShopperState.BUYING:
			break
	assert_eq(shopper.current_state, ShopperAI.ShopperState.BUYING)


func test_simple_detail_skips_browsing_and_requests_leave() -> void:
	var exit_wp: MallWaypoint = _make_waypoint(
		"Exit", Vector3(-4, 0, 0),
		MallWaypoint.WaypointType.EXIT
	)
	var hallway: MallWaypoint = _make_waypoint(
		"Hallway", Vector3(0, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	var store: MallWaypoint = _make_waypoint(
		"Store", Vector3(4, 0, 0),
		MallWaypoint.WaypointType.STORE_ENTRANCE, &"retro_games"
	)
	_connect_bi(exit_wp, hallway)
	_connect_bi(hallway, store)

	var shopper := NeverBuyShopper.new()
	var agent := MallWaypointAgent.new()
	agent.name = "MallWaypointAgent"
	shopper.add_child(agent)
	add_child_autofree(shopper)

	shopper.initialize(store.global_position)
	shopper.global_position = store.global_position
	shopper.ai_detail = ShopperAI.AIDetail.SIMPLE
	shopper._transition_to(ShopperAI.ShopperState.BROWSING)
	shopper._physics_process(0.016)

	assert_eq(shopper.current_state, ShopperAI.ShopperState.LEAVING)


func test_simple_detail_skips_separation_steering() -> void:
	var recording_nav := RecordingShopperNavigation.new()
	_shopper._nav = recording_nav
	var _hw: MallWaypoint = _make_waypoint(
		"H1", Vector3(50, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_shopper.initialize(Vector3.ZERO)
	_shopper.ai_detail = ShopperAI.AIDetail.SIMPLE
	_shopper._utility_timer = 99.0
	_shopper._transition_to(ShopperAI.ShopperState.WALKING)

	_shopper._physics_process(0.016)

	assert_eq(recording_nav.separation_calls, 0)


func test_full_detail_uses_standard_utility_interval() -> void:
	var _hw: MallWaypoint = _make_waypoint(
		"H1", Vector3(50, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_shopper.initialize(Vector3.ZERO)
	_shopper.ai_detail = ShopperAI.AIDetail.FULL
	_shopper._utility_timer = 0.0
	_shopper._transition_to(ShopperAI.ShopperState.WALKING)
	_shopper._physics_process(0.016)
	assert_almost_eq(
		_shopper._utility_timer,
		ShopperAI.UTILITY_EVAL_INTERVAL,
		0.1,
		"FULL should reset utility timer to 1s interval"
	)


func test_full_detail_evaluates_to_leave_after_one_second() -> void:
	var exit_wp: MallWaypoint = _make_waypoint(
		"Exit", Vector3(-5, 0, 0),
		MallWaypoint.WaypointType.EXIT
	)
	var hallway: MallWaypoint = _make_waypoint(
		"Hallway", Vector3(5, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_connect_bi(exit_wp, hallway)
	_shopper.initialize(Vector3.ZERO)
	_shopper._transition_to(ShopperAI.ShopperState.WALKING)
	_shopper.target_waypoint = null
	_shopper._nav.target_waypoint = null
	_shopper.needs.shopping = 0.0
	_shopper.needs.hunger = 0.0
	_shopper.needs.energy = 1.0
	_shopper.needs.social = 0.0
	_shopper._utility_timer = 0.0
	_shopper._state_timer = 0.0

	_shopper._physics_process(1.0)

	assert_eq(
		_shopper.current_state,
		ShopperAI.ShopperState.LEAVING,
		"A zero shopping need should drive the leave action on the 1s utility tick"
	)
	assert_almost_eq(
		_shopper._utility_timer,
		ShopperAI.UTILITY_EVAL_INTERVAL,
		0.001,
		"FULL detail should reset the utility timer to 1 second after evaluation"
	)


func test_ai_detail_can_change_without_teleport() -> void:
	var _hw: MallWaypoint = _make_waypoint(
		"H1", Vector3(50, 0, 0),
		MallWaypoint.WaypointType.HALLWAY
	)
	_shopper.initialize(Vector3.ZERO)
	_shopper.ai_detail = ShopperAI.AIDetail.MINIMAL
	_shopper._transition_to(ShopperAI.ShopperState.WALKING)
	var pos_before: Vector3 = _shopper.global_position
	_shopper._physics_process(1.0)
	_shopper.ai_detail = ShopperAI.AIDetail.FULL
	assert_eq(
		_shopper.global_position, pos_before,
		"Returning from MINIMAL should not teleport"
	)
	assert_eq(
		_shopper.current_state, ShopperAI.ShopperState.WALKING,
		"State should be preserved when returning from MINIMAL"
	)
