## Tests ShopperGroup leader/follower model, formation, scoring, and reluctant override.
extends GutTest


var _group: ShopperGroup


func before_each() -> void:
	_group = ShopperGroup.new()


func _make_shopper(
	p_type: PersonalityData.PersonalityType = PersonalityData.PersonalityType.SOCIAL_BUTTERFLY,
	social_baseline: float = 0.5,
) -> ShopperAI:
	var shopper := ShopperAI.new()
	var agent := MallWaypointAgent.new()
	agent.name = "MallWaypointAgent"
	shopper.add_child(agent)
	var pd := PersonalityData.new()
	pd.personality_type = p_type
	pd.shop_weight = 1.0
	pd.impulse_factor = 0.3
	pd.hunger_rate_mult = 1.0
	pd.energy_drain_mult = 1.0
	pd.social_need_baseline = social_baseline
	pd.browse_duration_mult = 1.0
	pd.min_budget = 20.0
	pd.max_budget = 100.0
	shopper.personality = pd
	shopper.needs.initialize_from_personality(pd)
	add_child_autofree(shopper)
	return shopper


func test_add_member_sets_first_as_leader() -> void:
	var s1 := _make_shopper()
	_group.add_member(s1)
	assert_eq(_group.leader, s1)
	assert_eq(_group.followers.size(), 0)


func test_add_member_sets_subsequent_as_followers() -> void:
	var s1 := _make_shopper()
	var s2 := _make_shopper()
	var s3 := _make_shopper()
	_group.add_member(s1)
	_group.add_member(s2)
	_group.add_member(s3)
	assert_eq(_group.leader, s1)
	assert_eq(_group.followers.size(), 2)
	assert_true(_group.followers.has(s2))
	assert_true(_group.followers.has(s3))


func test_add_member_rejects_duplicates() -> void:
	var s1 := _make_shopper()
	_group.add_member(s1)
	_group.add_member(s1)
	assert_eq(_group.get_member_count(), 1)


func test_assign_leader_picks_highest_social_need() -> void:
	var s1 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.3
	)
	var s2 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.9
	)
	var s3 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.6
	)
	_group.add_member(s1)
	_group.add_member(s2)
	_group.add_member(s3)
	_group.assign_leader()
	assert_eq(
		_group.leader, s2,
		"Leader should be the member with highest social_need_baseline"
	)
	assert_eq(_group.followers.size(), 2)
	assert_false(_group.followers.has(s2))


func test_get_all_members_includes_leader_and_followers() -> void:
	var s1 := _make_shopper()
	var s2 := _make_shopper()
	_group.add_member(s1)
	_group.add_member(s2)
	var all: Array[ShopperAI] = _group.get_all_members()
	assert_eq(all.size(), 2)
	assert_true(all.has(s1))
	assert_true(all.has(s2))


func test_get_member_count() -> void:
	assert_eq(_group.get_member_count(), 0)
	var s1 := _make_shopper()
	_group.add_member(s1)
	assert_eq(_group.get_member_count(), 1)
	var s2 := _make_shopper()
	_group.add_member(s2)
	assert_eq(_group.get_member_count(), 2)


func test_formation_offsets_are_unique() -> void:
	var s1 := _make_shopper()
	var s2 := _make_shopper()
	var s3 := _make_shopper()
	_group.add_member(s1)
	_group.add_member(s2)
	_group.add_member(s3)
	var o0: Vector3 = _group.get_formation_offset(0)
	var o1: Vector3 = _group.get_formation_offset(1)
	assert_true(
		o0.distance_to(o1) > 0.1,
		"Formation offsets should be unique per follower"
	)


func test_formation_offset_behind_leader() -> void:
	var s1 := _make_shopper()
	var s2 := _make_shopper()
	_group.add_member(s1)
	_group.add_member(s2)
	var offset: Vector3 = _group.get_formation_offset(0)
	assert_true(
		offset.length() >= ShopperGroup.FORMATION_BASE_RADIUS - 0.01,
		"Offset should be at least base radius from leader"
	)


func test_formation_radius_increases_with_index() -> void:
	var shoppers: Array[ShopperAI] = []
	for i: int in range(5):
		var s := _make_shopper()
		shoppers.append(s)
		_group.add_member(s)
	var r0: float = _group.get_formation_offset(0).length()
	var r3: float = _group.get_formation_offset(3).length()
	assert_gt(
		r3, r0,
		"Later followers should be farther from leader"
	)


func test_should_follower_catch_up_when_far() -> void:
	var s1 := _make_shopper()
	var s2 := _make_shopper()
	_group.add_member(s1)
	_group.add_member(s2)
	s1.global_position = Vector3.ZERO
	s2.global_position = Vector3(20.0, 0.0, 20.0)
	assert_true(
		_group.should_follower_catch_up(0),
		"Follower far from slot should need to catch up"
	)


func test_should_not_catch_up_when_close() -> void:
	var s1 := _make_shopper()
	var s2 := _make_shopper()
	_group.add_member(s1)
	_group.add_member(s2)
	s1.global_position = Vector3.ZERO
	var slot: Vector3 = _group.get_formation_world_position(0)
	s2.global_position = slot
	assert_false(
		_group.should_follower_catch_up(0),
		"Follower at slot should not need to catch up"
	)


func test_score_group_action_leader_weighted() -> void:
	var s1 := _make_shopper()
	var s2 := _make_shopper()
	_group.add_member(s1)
	_group.add_member(s2)
	_group.assign_leader()
	var score: float = _group.score_group_action("visit_store")
	assert_typeof(score, TYPE_FLOAT)
	assert_true(is_finite(score), "Group score should be finite")


func test_reluctant_companion_override_triggers() -> void:
	var s1 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.9
	)
	var s2 := _make_shopper(
		PersonalityData.PersonalityType.RELUCTANT_COMPANION, 0.2
	)
	_group.add_member(s1)
	_group.add_member(s2)
	_group.assign_leader()
	s2.needs.energy = 0.2
	assert_true(
		_group.has_reluctant_companion_override(),
		"Should trigger when RELUCTANT_COMPANION energy < 0.3"
	)


func test_reluctant_companion_override_does_not_trigger_high_energy() -> void:
	var s1 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.9
	)
	var s2 := _make_shopper(
		PersonalityData.PersonalityType.RELUCTANT_COMPANION, 0.2
	)
	_group.add_member(s1)
	_group.add_member(s2)
	_group.assign_leader()
	s2.needs.energy = 0.8
	assert_false(
		_group.has_reluctant_companion_override(),
		"Should not trigger when RELUCTANT_COMPANION energy >= 0.3"
	)


func test_reluctant_override_ignores_non_reluctant() -> void:
	var s1 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.9
	)
	var s2 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.8
	)
	_group.add_member(s1)
	_group.add_member(s2)
	_group.assign_leader()
	s2.needs.energy = 0.1
	assert_false(
		_group.has_reluctant_companion_override(),
		"Non-RELUCTANT low energy should not trigger override"
	)


func test_remove_leader_promotes_next() -> void:
	var s1 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.9
	)
	var s2 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.7
	)
	var s3 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.8
	)
	_group.add_member(s1)
	_group.add_member(s2)
	_group.add_member(s3)
	_group.assign_leader()
	assert_eq(_group.leader, s1)
	_group.remove_member(s1)
	assert_eq(
		_group.leader, s3,
		"Next highest social should become leader"
	)
	assert_eq(_group.followers.size(), 1)
	assert_true(_group.followers.has(s2))


func test_queue_free_leader_promotes_next() -> void:
	var s1 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.9
	)
	var s2 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.7
	)
	var s3 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.8
	)
	_group.add_member(s1)
	_group.add_member(s2)
	_group.add_member(s3)
	_group.assign_leader()
	assert_eq(_group.leader, s1)

	s1.queue_free()
	await get_tree().process_frame

	assert_eq(
		_group.leader, s3,
		"queue_free should promote the remaining highest-social follower"
	)
	assert_eq(_group.followers.size(), 1)
	assert_true(_group.followers.has(s2))


func test_remove_follower_keeps_leader() -> void:
	var s1 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.9
	)
	var s2 := _make_shopper(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY, 0.5
	)
	_group.add_member(s1)
	_group.add_member(s2)
	_group.assign_leader()
	_group.remove_member(s2)
	assert_eq(_group.leader, s1)
	assert_eq(_group.followers.size(), 0)


func test_remove_last_member_clears_group() -> void:
	var s1 := _make_shopper()
	_group.add_member(s1)
	_group.remove_member(s1)
	assert_null(_group.leader)
	assert_eq(_group.followers.size(), 0)


func test_is_group_archetype_config() -> void:
	assert_true(ShopperArchetypeConfig.is_group_archetype(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY
	))
	assert_true(ShopperArchetypeConfig.is_group_archetype(
		PersonalityData.PersonalityType.TEEN_PACK_MEMBER
	))
	assert_true(ShopperArchetypeConfig.is_group_archetype(
		PersonalityData.PersonalityType.FOOD_COURT_CAMPER
	))
	assert_false(ShopperArchetypeConfig.is_group_archetype(
		PersonalityData.PersonalityType.POWER_SHOPPER
	))
	assert_false(ShopperArchetypeConfig.is_group_archetype(
		PersonalityData.PersonalityType.SPEED_RUNNER
	))


func test_group_size_ranges() -> void:
	var sb: Vector2i = ShopperArchetypeConfig.get_group_size_range(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY
	)
	assert_eq(sb.x, 2)
	assert_eq(sb.y, 4)

	var tp: Vector2i = ShopperArchetypeConfig.get_group_size_range(
		PersonalityData.PersonalityType.TEEN_PACK_MEMBER
	)
	assert_eq(tp.x, 3)
	assert_eq(tp.y, 8)

	var fc: Vector2i = ShopperArchetypeConfig.get_group_size_range(
		PersonalityData.PersonalityType.FOOD_COURT_CAMPER
	)
	assert_eq(fc.x, 2)
	assert_eq(fc.y, 4)


func test_non_group_archetype_returns_one_one() -> void:
	var ps: Vector2i = ShopperArchetypeConfig.get_group_size_range(
		PersonalityData.PersonalityType.POWER_SHOPPER
	)
	assert_eq(ps, Vector2i(1, 1))


func test_shopper_ai_is_group_follower() -> void:
	var s1 := _make_shopper()
	var s2 := _make_shopper()
	_group.add_member(s1)
	_group.add_member(s2)
	_group.assign_leader()
	s1.shopper_group = _group
	s2.shopper_group = _group
	assert_false(
		s1._is_group_follower(),
		"Leader should not be follower"
	)
	assert_true(
		s2._is_group_follower(),
		"Non-leader member should be follower"
	)


func test_shopper_ai_is_group_leader() -> void:
	var s1 := _make_shopper()
	var s2 := _make_shopper()
	_group.add_member(s1)
	_group.add_member(s2)
	_group.assign_leader()
	s1.shopper_group = _group
	s2.shopper_group = _group
	assert_true(s1._is_group_leader())
	assert_false(s2._is_group_leader())


func test_solo_shopper_not_follower_or_leader() -> void:
	var s1 := _make_shopper()
	assert_false(s1._is_group_follower())
	assert_false(s1._is_group_leader())


func test_group_mood_defaults() -> void:
	assert_eq(_group.group_mood, 0.5)


func test_formation_world_position_relative_to_leader() -> void:
	var s1 := _make_shopper()
	var s2 := _make_shopper()
	_group.add_member(s1)
	_group.add_member(s2)
	_group.assign_leader()
	s1.global_position = Vector3(10.0, 0.0, 5.0)
	var world_pos: Vector3 = _group.get_formation_world_position(0)
	var offset: Vector3 = _group.get_formation_offset(0)
	var expected: Vector3 = s1.global_position + offset
	assert_almost_eq(world_pos.x, expected.x, 0.01)
	assert_almost_eq(world_pos.z, expected.z, 0.01)


func test_catchup_speed_multiplier_constant() -> void:
	assert_eq(ShopperGroup.CATCHUP_SPEED_MULT, 1.3)


func test_regroup_distance_constant() -> void:
	assert_eq(ShopperGroup.REGROUP_DISTANCE, 2.5)
