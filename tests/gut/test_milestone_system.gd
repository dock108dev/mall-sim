## GUT tests for MilestoneSystem — counters, signals, save/load, rewards.
extends GutTest


var _ms: MilestoneSystem


func before_each() -> void:
	_ms = MilestoneSystem.new()
	add_child_autofree(_ms)
	_ms._init_counters()
	_ms._milestones = _build_test_milestones()


func _build_test_milestones() -> Array[MilestoneDefinition]:
	var result: Array[MilestoneDefinition] = []

	var m1 := MilestoneDefinition.new()
	m1.id = "test_revenue"
	m1.display_name = "Revenue Test"
	m1.trigger_stat_key = "cumulative_revenue"
	m1.trigger_threshold = 100.0
	m1.reward_type = "cash"
	m1.reward_value = 25.0
	result.append(m1)

	var m2 := MilestoneDefinition.new()
	m2.id = "test_sales"
	m2.display_name = "Sales Test"
	m2.trigger_stat_key = "customer_purchased_count"
	m2.trigger_threshold = 5
	m2.reward_type = "cash"
	m2.reward_value = 10.0
	result.append(m2)

	var m3 := MilestoneDefinition.new()
	m3.id = "test_haggle"
	m3.display_name = "Haggle Test"
	m3.trigger_stat_key = "haggle_max_price_ratio"
	m3.trigger_threshold = 1.5
	m3.reward_type = "cash"
	m3.reward_value = 50.0
	result.append(m3)

	var m4 := MilestoneDefinition.new()
	m4.id = "test_streak"
	m4.display_name = "Streak Test"
	m4.trigger_stat_key = "pricing_streak_in_range"
	m4.trigger_threshold = 3
	m4.reward_type = "cash"
	m4.reward_value = 15.0
	result.append(m4)

	return result


func test_counters_initialized_to_zero() -> void:
	assert_almost_eq(
		float(_ms._counters["cumulative_revenue"]), 0.0, 0.01
	)
	assert_eq(int(_ms._counters["customer_purchased_count"]), 0)
	assert_eq(int(_ms._counters["satisfied_customer_count"]), 0)
	assert_eq(int(_ms._counters["owned_store_count"]), 0)
	assert_eq(int(_ms._counters["unique_store_types_entered"]), 0)
	assert_eq(int(_ms._counters["max_reputation_tier_seen"]), 0)
	assert_almost_eq(
		float(_ms._counters["single_day_revenue"]), 0.0, 0.01
	)
	assert_almost_eq(
		float(_ms._counters["haggle_max_price_ratio"]), 0.0, 0.01
	)
	assert_eq(int(_ms._counters["rare_items_sold"]), 0)
	assert_eq(int(_ms._counters["pricing_streak_in_range"]), 0)
	assert_eq(int(_ms._counters["market_crash_survived"]), 0)


func test_single_day_revenue_resets_on_day_started() -> void:
	_ms._counters["single_day_revenue"] = 500.0
	_ms._on_day_started(2)
	assert_almost_eq(
		float(_ms._counters["single_day_revenue"]), 0.0, 0.01,
		"single_day_revenue should reset on day_started"
	)


func test_transaction_increments_revenue() -> void:
	_ms._on_transaction_completed(50.0, true, "sale")
	assert_almost_eq(
		float(_ms._counters["cumulative_revenue"]), 50.0, 0.01
	)
	assert_almost_eq(
		float(_ms._counters["single_day_revenue"]), 50.0, 0.01
	)


func test_transaction_ignores_failures() -> void:
	_ms._on_transaction_completed(50.0, false, "failed")
	assert_almost_eq(
		float(_ms._counters["cumulative_revenue"]), 0.0, 0.01
	)


func test_customer_purchased_increments_count() -> void:
	_ms._on_customer_purchased(
		&"test_store", &"item_1", 25.0, &"cust_1"
	)
	assert_eq(int(_ms._counters["customer_purchased_count"]), 1)


func test_customer_left_satisfied_increments() -> void:
	_ms._on_customer_left({"satisfied": true})
	assert_eq(int(_ms._counters["satisfied_customer_count"]), 1)


func test_customer_left_unsatisfied_no_change() -> void:
	_ms._on_customer_left({"satisfied": false})
	assert_eq(int(_ms._counters["satisfied_customer_count"]), 0)


func test_store_leased_increments_count() -> void:
	_ms._on_store_leased(0, "retro_games")
	assert_eq(int(_ms._counters["owned_store_count"]), 1)


func test_store_entered_tracks_unique() -> void:
	_ms._on_store_entered(&"retro_games")
	_ms._on_store_entered(&"retro_games")
	_ms._on_store_entered(&"video_rental")
	assert_eq(int(_ms._counters["unique_store_types_entered"]), 2)


func test_haggle_completed_updates_ratio() -> void:
	_ms._on_haggle_completed(
		&"store", &"item", 30.0, 20.0, true, 2
	)
	assert_almost_eq(
		float(_ms._counters["haggle_max_price_ratio"]),
		1.5, 0.01
	)


func test_haggle_rejected_no_update() -> void:
	_ms._on_haggle_completed(
		&"store", &"item", 30.0, 20.0, false, 2
	)
	assert_almost_eq(
		float(_ms._counters["haggle_max_price_ratio"]),
		0.0, 0.01
	)


func test_pricing_streak_increments_in_range() -> void:
	_ms._on_item_price_set(&"store", &"item_a", 12.0, 1.3)
	_ms._on_item_price_set(&"store", &"item_b", 14.0, 1.4)
	_ms._on_item_price_set(&"store", &"item_c", 15.0, 1.5)
	assert_eq(int(_ms._counters["pricing_streak_in_range"]), 3)


func test_pricing_streak_resets_out_of_range() -> void:
	_ms._on_item_price_set(&"store", &"item_a", 12.0, 1.3)
	_ms._on_item_price_set(&"store", &"item_b", 14.0, 1.4)
	_ms._on_item_price_set(&"store", &"item_c", 20.0, 2.0)
	assert_eq(int(_ms._counters["pricing_streak_in_range"]), 0)


func test_milestone_unlocked_fires_at_threshold() -> void:
	var fired_id: Array = [&""]
	var on_unlocked: Callable = func(
		id: StringName, _reward: Dictionary
	) -> void:
		fired_id[0] = id
	EventBus.milestone_unlocked.connect(on_unlocked)

	_ms._on_transaction_completed(100.0, true, "sale")

	assert_eq(
		fired_id[0], &"test_revenue",
		"milestone_unlocked should fire for test_revenue"
	)
	EventBus.milestone_unlocked.disconnect(on_unlocked)


func test_milestone_fires_exactly_once() -> void:
	var fire_count: Array = [0]
	var on_unlocked: Callable = func(
		_id: StringName, _reward: Dictionary
	) -> void:
		fire_count[0] += 1
	EventBus.milestone_unlocked.connect(on_unlocked)

	_ms._on_transaction_completed(100.0, true, "sale")
	_ms._on_transaction_completed(100.0, true, "sale2")

	assert_eq(
		fire_count[0], 1,
		"milestone_unlocked should fire exactly once"
	)
	EventBus.milestone_unlocked.disconnect(on_unlocked)


func test_is_complete_after_threshold() -> void:
	_ms._on_transaction_completed(100.0, true, "sale")
	assert_true(_ms.is_complete(&"test_revenue"))


func test_is_complete_before_threshold() -> void:
	assert_false(_ms.is_complete(&"test_revenue"))


func test_get_completed_ids() -> void:
	_ms._on_transaction_completed(100.0, true, "sale")
	var ids: Array[StringName] = _ms.get_completed_ids()
	assert_true(ids.has(&"test_revenue"))


func test_get_completion_percent_zero() -> void:
	assert_almost_eq(
		_ms.get_completion_percent(), 0.0, 0.01
	)


func test_save_load_preserves_completed() -> void:
	_ms._on_transaction_completed(100.0, true, "sale")
	assert_true(_ms.is_complete(&"test_revenue"))

	var save_data: Dictionary = _ms.get_save_data()

	var ms2 := MilestoneSystem.new()
	add_child_autofree(ms2)
	ms2._milestones = _build_test_milestones()
	ms2.load_state(save_data)

	assert_true(
		ms2.is_complete(&"test_revenue"),
		"Completed state should survive round-trip"
	)


func test_save_load_preserves_counters() -> void:
	_ms._on_transaction_completed(75.0, true, "sale")
	for i: int in range(3):
		_ms._on_customer_purchased(
			&"store", StringName("item_%d" % i), 10.0, &"cust"
		)

	var save_data: Dictionary = _ms.get_save_data()

	var ms2 := MilestoneSystem.new()
	add_child_autofree(ms2)
	ms2._milestones = _build_test_milestones()
	ms2.load_state(save_data)

	assert_almost_eq(
		float(ms2._counters["cumulative_revenue"]), 75.0, 0.01,
		"Revenue counter should survive round-trip"
	)
	assert_eq(
		int(ms2._counters["customer_purchased_count"]), 3,
		"Purchase counter should survive round-trip"
	)


func test_load_state_no_refire() -> void:
	_ms._on_transaction_completed(100.0, true, "sale")
	var save_data: Dictionary = _ms.get_save_data()

	var ms2 := MilestoneSystem.new()
	add_child_autofree(ms2)
	ms2._milestones = _build_test_milestones()

	var fire_count: Array = [0]
	var on_unlocked: Callable = func(
		_id: StringName, _reward: Dictionary
	) -> void:
		fire_count[0] += 1
	EventBus.milestone_unlocked.connect(on_unlocked)

	ms2.load_state(save_data)

	assert_eq(
		fire_count[0], 0,
		"load_state should not re-fire milestone_unlocked"
	)
	EventBus.milestone_unlocked.disconnect(on_unlocked)


func test_save_load_preserves_unique_stores() -> void:
	_ms._on_store_entered(&"retro_games")
	_ms._on_store_entered(&"video_rental")

	var save_data: Dictionary = _ms.get_save_data()

	var ms2 := MilestoneSystem.new()
	add_child_autofree(ms2)
	ms2.load_state(save_data)

	assert_eq(
		int(ms2._counters["unique_store_types_entered"]), 2,
		"Unique stores should survive round-trip"
	)


func test_haggle_milestone_fires() -> void:
	var fired: Array = [false]
	var on_unlocked: Callable = func(
		id: StringName, _reward: Dictionary
	) -> void:
		if id == &"test_haggle":
			fired[0] = true
	EventBus.milestone_unlocked.connect(on_unlocked)

	_ms._on_haggle_completed(
		&"store", &"item", 30.0, 20.0, true, 3
	)

	assert_true(
		fired[0],
		"test_haggle should fire when ratio >= 1.5"
	)
	EventBus.milestone_unlocked.disconnect(on_unlocked)


func test_pricing_streak_milestone_fires() -> void:
	var fired: Array = [false]
	var on_unlocked: Callable = func(
		id: StringName, _reward: Dictionary
	) -> void:
		if id == &"test_streak":
			fired[0] = true
	EventBus.milestone_unlocked.connect(on_unlocked)

	_ms._on_item_price_set(&"s", &"a", 12.0, 1.3)
	_ms._on_item_price_set(&"s", &"b", 14.0, 1.4)
	_ms._on_item_price_set(&"s", &"c", 15.0, 1.5)

	assert_true(
		fired[0],
		"test_streak should fire after 3 in-range prices"
	)
	EventBus.milestone_unlocked.disconnect(on_unlocked)


func test_milestone_emits_toast_on_unlock() -> void:
	var toast_message: Array = [""]
	var toast_duration: Array = [0.0]
	var on_toast: Callable = func(
		message: String, _category: StringName, duration: float
	) -> void:
		toast_message[0] = message
		toast_duration[0] = duration
	EventBus.toast_requested.connect(on_toast)
	_ms._connect_signals()

	_ms._on_transaction_completed(100.0, true, "sale")

	assert_string_contains(
		toast_message[0], "Milestone reached:",
		"toast should contain milestone prefix"
	)
	assert_gt(
		toast_duration[0], 0.0,
		"toast duration should be positive"
	)
	EventBus.toast_requested.disconnect(on_toast)
	EventBus.milestone_unlocked.disconnect(
		_ms._on_milestone_unlocked
	)
