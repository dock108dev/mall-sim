## Tests CustomerSystem spawn scheduling: density curve, day-of-week, archetypes.
extends GutTest


var _system: CustomerSystem
var _mall_root: Node3D
var _spawned_shoppers: Array[Node] = []
var _original_tier: StringName


func before_all() -> void:
	DifficultySystemSingleton._load_config()


func before_each() -> void:
	_original_tier = DifficultySystemSingleton.get_current_tier_id()
	_system = CustomerSystem.new()
	add_child_autofree(_system)
	_system.max_customers_in_mall = 30
	_spawned_shoppers = []
	_mall_root = null
	_safe_disconnect(EventBus.customer_spawned, _on_customer_spawned)
	EventBus.customer_spawned.connect(_on_customer_spawned)
	DifficultySystemSingleton.set_tier(&"normal")


func after_each() -> void:
	_safe_disconnect(EventBus.customer_spawned, _on_customer_spawned)
	DifficultySystemSingleton.set_tier(_original_tier)


# --- HOUR_DENSITY table completeness ---


func test_hour_density_covers_all_operating_hours() -> void:
	for hour: int in range(9, 22):
		assert_true(
			CustomerSystem.HOUR_DENSITY.has(hour),
			"HOUR_DENSITY missing hour %d" % hour
		)


func test_hour_density_matches_research_curve() -> void:
	var expected: Dictionary = {
		9: 0.1,
		10: 0.25,
		11: 0.55,
		12: 0.85,
		13: 0.75,
		14: 0.4,
		15: 0.35,
		16: 0.5,
		17: 0.8,
		18: 0.7,
		19: 0.45,
		20: 0.2,
		21: 0.0,
	}
	assert_eq(
		CustomerSystem.HOUR_DENSITY,
		expected,
		"HOUR_DENSITY should match the research two-peak curve exactly"
	)


func test_hour_density_values_in_range() -> void:
	for hour: int in CustomerSystem.HOUR_DENSITY:
		var density: float = CustomerSystem.HOUR_DENSITY[hour]
		assert_true(
			density >= 0.0 and density <= 1.0,
			"Density at hour %d out of [0,1]: %.2f" % [hour, density]
		)


func test_hour_density_peak_at_lunch() -> void:
	assert_eq(
		CustomerSystem.HOUR_DENSITY[12], 0.85,
		"Lunch peak should be 0.85"
	)


func test_hour_density_closed_at_21() -> void:
	assert_eq(
		CustomerSystem.HOUR_DENSITY[21], 0.0,
		"Density at closing should be 0.0"
	)


# --- Density interpolation ---


func test_interpolate_at_exact_hour() -> void:
	var target: int = _target_for_hour(12, 0)
	var expected: int = roundi(0.85 * 30.0 * 0.7)
	assert_eq(target, expected, "Exact hour 12 should use 0.85")


func test_interpolate_between_hours() -> void:
	_system._current_hour = 12
	var seconds_per_hour: float = (
		Constants.SECONDS_PER_GAME_MINUTE * Constants.MINUTES_PER_HOUR
	)
	_system._hour_elapsed = seconds_per_hour * 0.5
	_system._current_day_of_week = 0
	var target: int = _system.get_spawn_target()
	var expected_density: float = lerpf(0.85, 0.75, 0.5)
	var expected: int = mini(
		roundi(expected_density * 30.0 * 0.7), 30
	)
	assert_eq(
		target, expected,
		"Halfway between 12 and 13 should lerp density"
	)


# --- Day-of-week modifiers ---


func test_day_of_week_modifier_count() -> void:
	assert_eq(
		CustomerSystem.DAY_OF_WEEK_MODIFIERS.size(), 7,
		"Should have 7 day-of-week modifiers"
	)


func test_monday_modifier() -> void:
	assert_eq(
		CustomerSystem.DAY_OF_WEEK_MODIFIERS[0], 0.7,
		"Monday modifier should be 0.7"
	)


func test_saturday_modifier() -> void:
	assert_eq(
		CustomerSystem.DAY_OF_WEEK_MODIFIERS[5], 1.3,
		"Saturday modifier should be 1.3"
	)


func test_day_of_week_affects_target() -> void:
	var monday_target: int = _target_for_day(0, 12)
	var saturday_target: int = _target_for_day(5, 12)
	assert_true(
		saturday_target > monday_target,
		"Saturday target (%d) should exceed Monday (%d)"
		% [saturday_target, monday_target]
	)


# --- MAX_CUSTOMERS_IN_MALL cap ---


func test_target_never_exceeds_max() -> void:
	_system.max_customers_in_mall = 10
	_system._current_hour = 12
	_system._hour_elapsed = 0.0
	_system._current_day_of_week = 5
	var target: int = _system.get_spawn_target()
	assert_true(
		target <= 10,
		"Target %d should not exceed max 10" % target
	)


# --- Archetype weight tables ---


func test_morning_weights_sum_to_100() -> void:
	var total: int = _sum_weights(
		ShopperArchetypeConfig.WEIGHTS_MORNING
	)
	assert_eq(total, 100, "Morning weights should sum to 100")


func test_afternoon_weights_sum_to_100() -> void:
	var total: int = _sum_weights(
		ShopperArchetypeConfig.WEIGHTS_AFTERNOON
	)
	assert_eq(total, 100, "Afternoon weights should sum to 100")


func test_evening_weights_sum_to_100() -> void:
	var total: int = _sum_weights(
		ShopperArchetypeConfig.WEIGHTS_EVENING
	)
	assert_eq(total, 100, "Evening weights should sum to 100")


func test_morning_bucket_before_noon() -> void:
	var weights: Dictionary = (
		ShopperArchetypeConfig.get_weights_for_hour(10)
	)
	assert_eq(
		weights, ShopperArchetypeConfig.WEIGHTS_MORNING,
		"Hour 10 should use morning weights"
	)


func test_afternoon_bucket_at_noon() -> void:
	var weights: Dictionary = (
		ShopperArchetypeConfig.get_weights_for_hour(12)
	)
	assert_eq(
		weights, ShopperArchetypeConfig.WEIGHTS_AFTERNOON,
		"Hour 12 should use afternoon weights"
	)


func test_evening_bucket_at_18() -> void:
	var weights: Dictionary = (
		ShopperArchetypeConfig.get_weights_for_hour(18)
	)
	assert_eq(
		weights, ShopperArchetypeConfig.WEIGHTS_EVENING,
		"Hour 18 should use evening weights"
	)


func test_afternoon_bucket_at_17() -> void:
	var weights: Dictionary = (
		ShopperArchetypeConfig.get_weights_for_hour(17)
	)
	assert_eq(
		weights, ShopperArchetypeConfig.WEIGHTS_AFTERNOON,
		"Hour 17 should use afternoon weights (boundary at 18)"
	)


func test_all_archetypes_have_defaults() -> void:
	for archetype_val: int in PersonalityData.PersonalityType.values():
		var archetype: PersonalityData.PersonalityType = (
			archetype_val as PersonalityData.PersonalityType
		)
		assert_true(
			ShopperArchetypeConfig.ARCHETYPE_DEFAULTS.has(archetype),
			"Missing defaults for archetype %d" % archetype_val
		)


# --- Mall hallway gating ---


func test_in_mall_hallway_default_true() -> void:
	assert_true(
		_system._in_mall_hallway,
		"Should default to being in mall hallway"
	)


func test_store_entered_disables_hallway() -> void:
	_system._on_store_entered(&"sports")
	assert_false(
		_system._in_mall_hallway,
		"Should be false after store_entered"
	)


func test_active_store_changed_empty_enables_hallway() -> void:
	_system._on_store_entered(&"sports")
	_system._on_active_store_changed(&"")
	assert_true(
		_system._in_mall_hallway,
		"Should be true after returning to the hallway"
	)


# --- Day reset ---


func test_day_started_resets_count() -> void:
	_system._active_mall_shopper_count = 10
	_system._on_day_started(2)
	assert_eq(
		_system._active_mall_shopper_count, 0,
		"Shopper count should reset on day start"
	)


func test_day_started_sets_day_of_week() -> void:
	_system._on_day_started(8)
	assert_eq(
		_system._current_day_of_week, 0,
		"Day 8 should be day-of-week 0 (Monday)"
	)


func test_day_started_wraps_week() -> void:
	_system._on_day_started(15)
	assert_eq(
		_system._current_day_of_week, 0,
		"Day 15 should wrap to day-of-week 0"
	)


# --- customer_left decrements ---


func test_customer_left_decrements_count_for_shopper_ai() -> void:
	_system._active_mall_shopper_count = 5
	var shopper: Node = Node.new()
	add_child_autofree(shopper)
	shopper.add_to_group("shoppers")
	_system._on_customer_left({"customer": shopper, "satisfied": true})
	assert_eq(
		_system._active_mall_shopper_count, 4,
		"Should decrement by 1"
	)


func test_customer_left_ignores_non_shopper_payloads() -> void:
	_system._active_mall_shopper_count = 5
	_system._on_customer_left({"satisfied": false})
	assert_eq(
		_system._active_mall_shopper_count, 5,
		"Payloads without a ShopperAI should not change the mall count"
	)


func test_customer_left_floors_at_zero() -> void:
	_system._active_mall_shopper_count = 0
	var shopper: Node = Node.new()
	add_child_autofree(shopper)
	shopper.add_to_group("shoppers")
	_system._on_customer_left({"customer": shopper, "satisfied": false})
	assert_eq(
		_system._active_mall_shopper_count, 0,
		"Should not go below 0"
	)


# --- Weighted random selection ---


func test_weighted_select_returns_valid_type() -> void:
	var weights: Dictionary = ShopperArchetypeConfig.WEIGHTS_MORNING
	for i: int in range(20):
		var result: PersonalityData.PersonalityType = (
			ShopperArchetypeConfig.weighted_random_select(weights)
		)
		assert_true(
			weights.has(result),
			"Selected archetype %d not in weights (iter %d)"
			% [result, i]
		)


# --- Phase-based archetype weights ---


func test_phase_morning_ramp_uses_morning_weights() -> void:
	var weights: Dictionary = (
		ShopperArchetypeConfig.get_weights_for_phase(
			TimeSystem.DayPhase.MORNING_RAMP
		)
	)
	assert_eq(
		weights, ShopperArchetypeConfig.WEIGHTS_MORNING,
		"MORNING_RAMP phase should use morning weights"
	)


func test_phase_midday_rush_uses_afternoon_weights() -> void:
	var weights: Dictionary = (
		ShopperArchetypeConfig.get_weights_for_phase(
			TimeSystem.DayPhase.MIDDAY_RUSH
		)
	)
	assert_eq(
		weights, ShopperArchetypeConfig.WEIGHTS_AFTERNOON,
		"MIDDAY_RUSH phase should use afternoon weights"
	)


func test_phase_afternoon_uses_afternoon_weights() -> void:
	var weights: Dictionary = (
		ShopperArchetypeConfig.get_weights_for_phase(
			TimeSystem.DayPhase.AFTERNOON
		)
	)
	assert_eq(
		weights, ShopperArchetypeConfig.WEIGHTS_AFTERNOON,
		"AFTERNOON phase should use afternoon weights"
	)


func test_phase_evening_uses_evening_weights() -> void:
	var weights: Dictionary = (
		ShopperArchetypeConfig.get_weights_for_phase(
			TimeSystem.DayPhase.EVENING
		)
	)
	assert_eq(
		weights, ShopperArchetypeConfig.WEIGHTS_EVENING,
		"EVENING phase should use evening weights"
	)


func test_day_phase_changed_updates_archetype_weights() -> void:
	_system._on_day_phase_changed(TimeSystem.DayPhase.EVENING)
	assert_eq(
		_system._current_archetype_weights,
		ShopperArchetypeConfig.WEIGHTS_EVENING,
		"day_phase_changed should switch the active archetype weights immediately"
	)


func test_day_phase_changed_midday_rush_uses_afternoon_weights() -> void:
	_system._on_day_phase_changed(TimeSystem.DayPhase.MIDDAY_RUSH)
	assert_eq(
		_system._current_archetype_weights,
		ShopperArchetypeConfig.WEIGHTS_AFTERNOON,
		"MIDDAY_RUSH starts the 11:30 afternoon bucket"
	)


func test_day_started_resets_archetype_weights() -> void:
	_system._current_archetype_weights = (
		ShopperArchetypeConfig.WEIGHTS_EVENING
	)
	_system._on_day_started(1)
	assert_eq(
		_system._current_archetype_weights,
		ShopperArchetypeConfig.WEIGHTS_MORNING,
		"Day start should reset to morning weights"
	)


# --- Mall close behavior ---


func test_spawn_target_zero_at_close_hour() -> void:
	_system._current_hour = TimeSystem.MALL_CLOSE_HOUR
	_system._hour_elapsed = 0.0
	_system._current_day_of_week = 5
	var target: int = _system.get_spawn_target()
	assert_eq(target, 0, "Target should be 0 at closing hour")


func test_second_peak_at_17() -> void:
	var target: int = _target_for_hour(17, 0)
	var expected: int = roundi(0.8 * 30.0 * 0.7)
	assert_eq(
		target, expected,
		"Hour 17 target should reflect 0.80 density"
	)


func test_lull_at_15() -> void:
	var target: int = _target_for_hour(15, 0)
	var expected: int = roundi(0.35 * 30.0 * 0.7)
	assert_eq(
		target, expected,
		"Hour 15 target should reflect 0.35 density (lull)"
	)


# --- Minute cadence and spawn events ---


func test_process_updates_toward_target_once_per_game_minute() -> void:
	_system._in_mall_hallway = false
	_system._spawn_check_timer = 0.0

	_system._process(Constants.SECONDS_PER_GAME_MINUTE * 0.5)
	assert_almost_eq(
		_system._spawn_check_timer,
		Constants.SECONDS_PER_GAME_MINUTE * 0.5,
		0.001,
		"Half a game-minute should not trigger a mall spawn update"
	)

	_system._process(Constants.SECONDS_PER_GAME_MINUTE * 0.5)
	assert_almost_eq(
		_system._spawn_check_timer,
		0.0,
		0.001,
		"A full game-minute should consume the mall spawn update interval"
	)


func test_try_spawn_mall_shopper_emits_customer_spawned() -> void:
	_setup_spawnable_mall_waypoints()
	_system._shopper_scene = preload(
		"res://game/scenes/characters/shopper_ai.tscn"
	)
	_system.max_customers_in_mall = 1
	_system._active_mall_shopper_count = 0
	_system._current_hour = 12
	_system._current_archetype_weights = {
		PersonalityData.PersonalityType.POWER_SHOPPER: 100,
	}

	_system._try_spawn_mall_shopper()

	assert_eq(
		_spawned_shoppers.size(),
		1,
		"Spawning a mall shopper should emit EventBus.customer_spawned once"
	)
	assert_eq(
		_system._active_mall_shopper_count,
		1,
		"Active mall shopper count should increment after a successful spawn"
	)


func test_spawn_target_cap_prevents_extra_shoppers() -> void:
	_setup_spawnable_mall_waypoints()
	_system._shopper_scene = preload(
		"res://game/scenes/characters/shopper_ai.tscn"
	)
	_system.max_customers_in_mall = 1
	_system._active_mall_shopper_count = 1

	_system._try_spawn_mall_shopper()

	assert_eq(
		_spawned_shoppers.size(),
		0,
		"MAX_CUSTOMERS_IN_MALL should act as a hard cap for active ShopperAI nodes"
	)


func test_live_shopper_nodes_enforce_hard_cap_when_count_stale() -> void:
	_setup_spawnable_mall_waypoints()
	_system._shopper_scene = preload(
		"res://game/scenes/characters/shopper_ai.tscn"
	)
	_system.max_customers_in_mall = 1
	_system._active_mall_shopper_count = 0
	var existing_shopper: Node3D = Node3D.new()
	add_child_autofree(existing_shopper)
	existing_shopper.add_to_group("shoppers")

	_system._try_spawn_mall_shopper()

	assert_eq(
		_spawned_shoppers.size(),
		0,
		"Live ShopperAI nodes should enforce the hard cap even if tracking drifts"
	)


func test_over_target_removes_one_leaving_shopper() -> void:
	_system.max_customers_in_mall = 30
	_system._active_mall_shopper_count = 1
	_system._current_hour = TimeSystem.MALL_CLOSE_HOUR
	_system._current_day_of_week = 0
	var shopper: ShopperAI = preload(
		"res://game/scenes/characters/shopper_ai.tscn"
	).instantiate() as ShopperAI
	add_child_autofree(shopper)
	shopper.current_state = ShopperAI.ShopperState.LEAVING

	_system._update_mall_shoppers()

	assert_eq(
		_system._active_mall_shopper_count,
		0,
		"Over-target updates should despawn one shopper already in LEAVING"
	)
	assert_true(shopper.is_queued_for_deletion())


func test_close_hour_requests_all_shoppers_leave() -> void:
	_setup_spawnable_mall_waypoints()
	_system._shopper_scene = preload(
		"res://game/scenes/characters/shopper_ai.tscn"
	)
	_system.max_customers_in_mall = 1
	_system._current_archetype_weights = {
		PersonalityData.PersonalityType.POWER_SHOPPER: 100,
	}
	_system._try_spawn_mall_shopper()
	assert_eq(_spawned_shoppers.size(), 1)
	var shopper: ShopperAI = _spawned_shoppers[0] as ShopperAI
	assert_not_null(shopper)

	_system._on_hour_changed(TimeSystem.MALL_CLOSE_HOUR)

	assert_eq(
		shopper.current_state,
		ShopperAI.ShopperState.LEAVING,
		"At MALL_CLOSE_HOUR existing shoppers should transition to LEAVING"
	)


func test_group_spawn_skips_when_capacity_below_minimum_group_size() -> void:
	_setup_spawnable_mall_waypoints()
	_system._shopper_scene = preload(
		"res://game/scenes/characters/shopper_ai.tscn"
	)
	_system.max_customers_in_mall = 30
	_system._active_mall_shopper_count = 0

	_system._spawn_shopper_group(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY,
		Vector3.ZERO,
		1
	)

	assert_eq(
		_system._active_mall_shopper_count,
		0,
		"Group archetypes should not degrade into solo spawns when only one slot remains"
	)
	assert_eq(
		_spawned_shoppers.size(),
		0,
		"Group archetypes should skip spawning when there is not enough capacity for a group"
	)


func test_group_spawn_members_share_one_shopper_group() -> void:
	_setup_spawnable_mall_waypoints()
	_system._shopper_scene = preload(
		"res://game/scenes/characters/shopper_ai.tscn"
	)
	_system.max_customers_in_mall = 30
	_system._active_mall_shopper_count = 0

	var archetype: PersonalityData.PersonalityType = (
		PersonalityData.PersonalityType.TEEN_PACK_MEMBER
	)
	_system._spawn_shopper_group(archetype, Vector3.ZERO, 8)

	var size_range: Vector2i = ShopperArchetypeConfig.get_group_size_range(
		archetype
	)
	assert_true(
		_spawned_shoppers.size() >= size_range.x
		and _spawned_shoppers.size() <= size_range.y,
		"Spawned group size should stay within the configured range"
	)
	var first_shopper: ShopperAI = _spawned_shoppers[0] as ShopperAI
	assert_not_null(first_shopper)
	assert_not_null(first_shopper.shopper_group)
	var group: ShopperGroup = first_shopper.shopper_group
	assert_eq(group.get_member_count(), _spawned_shoppers.size())
	for node: Node in _spawned_shoppers:
		var shopper: ShopperAI = node as ShopperAI
		assert_eq(
			shopper.shopper_group,
			group,
			"All spawned members should share the same ShopperGroup instance"
		)


# --- Helpers ---


func _target_for_hour(hour: int, dow: int) -> int:
	_system._current_hour = hour
	_system._hour_elapsed = 0.0
	_system._current_day_of_week = dow
	return _system.get_spawn_target()


func _target_for_day(dow: int, hour: int) -> int:
	return _target_for_hour(hour, dow)


func _sum_weights(weights: Dictionary) -> int:
	var total: int = 0
	for w: int in weights.values():
		total += w
	return total


func _setup_spawnable_mall_waypoints() -> void:
	_mall_root = Node3D.new()
	_mall_root.name = "MallWaypointRoot"
	add_child_autofree(_mall_root)

	var hallway: MallWaypoint = MallWaypoint.new()
	hallway.name = "Hallway"
	hallway.position = Vector3.ZERO
	hallway.waypoint_type = MallWaypoint.WaypointType.HALLWAY
	_mall_root.add_child(hallway)

	var exit: MallWaypoint = MallWaypoint.new()
	exit.name = "Exit"
	exit.position = Vector3(2.0, 0.0, 0.0)
	exit.waypoint_type = MallWaypoint.WaypointType.EXIT
	_mall_root.add_child(exit)

	hallway.connected_waypoints = [exit]
	exit.connected_waypoints = [hallway]


func _on_customer_spawned(customer: Node) -> void:
	_spawned_shoppers.append(customer)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)
