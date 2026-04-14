## GUT unit tests for MilestoneSystem — counter accumulation, threshold
## evaluation, reward emission, and no re-emission on load.
extends GutTest


var _ms: MilestoneSystem


func before_each() -> void:
	_ms = MilestoneSystem.new()
	add_child_autofree(_ms)
	_ms._init_counters()
	_ms._milestones = _build_test_milestones()


func _make_milestone(
	id: String, stat_key: String, threshold: float,
	reward_type: String = "cash", reward_value: float = 10.0,
	visible: bool = true, unlock_id: String = ""
) -> MilestoneDefinition:
	var m := MilestoneDefinition.new()
	m.id = id
	m.display_name = id.capitalize()
	m.trigger_stat_key = stat_key
	m.trigger_threshold = threshold
	m.reward_type = reward_type
	m.reward_value = reward_value
	m.is_visible = visible
	m.unlock_id = unlock_id
	return m


func _build_test_milestones() -> Array[MilestoneDefinition]:
	var r: Array[MilestoneDefinition] = []
	r.append(_make_milestone(
		"first_sale", "customer_purchased_count", 1
	))
	r.append(_make_milestone(
		"big_earner", "cumulative_revenue", 200.0, "cash", 50.0
	))
	r.append(_make_milestone(
		"master_haggler", "haggle_max_price_ratio", 1.5, "cash", 25.0
	))
	r.append(_make_milestone(
		"pricing_pro", "pricing_streak_in_range", 3, "cash", 15.0
	))
	r.append(_make_milestone(
		"week_one_survivor", "current_day", 7, "unlock", 0.0,
		true, "order_catalog_expansion_1"
	))
	r.append(_make_milestone(
		"hidden_crash", "market_crash_survived", 1, "cash", 100.0,
		false
	))
	r.append(_make_milestone(
		"rare_collector", "rare_items_sold", 3, "cash", 30.0
	))
	r.append(_make_milestone(
		"daily_record", "single_day_revenue", 500.0, "cash", 20.0
	))
	r.append(_make_milestone(
		"crowd_pleaser", "satisfied_customer_count", 5, "cash", 20.0
	))
	return r


# ── 1. Counter initialization ──


func test_all_counters_initialize_to_zero() -> void:
	assert_almost_eq(
		float(_ms._counters["cumulative_revenue"]), 0.0, 0.01
	)
	assert_almost_eq(
		float(_ms._counters["single_day_revenue"]), 0.0, 0.01
	)
	assert_eq(int(_ms._counters["customer_purchased_count"]), 0)
	assert_eq(int(_ms._counters["satisfied_customer_count"]), 0)
	assert_eq(int(_ms._counters["owned_store_count"]), 0)
	assert_eq(int(_ms._counters["unique_store_types_entered"]), 0)
	assert_eq(int(_ms._counters["max_reputation_tier_seen"]), 0)
	assert_almost_eq(
		float(_ms._counters["haggle_max_price_ratio"]), 0.0, 0.01
	)
	assert_eq(int(_ms._counters["rare_items_sold"]), 0)
	assert_eq(int(_ms._counters["pricing_streak_in_range"]), 0)
	assert_eq(int(_ms._counters["market_crash_survived"]), 0)


# ── 2. Counter accumulation per signal ──


func test_successful_transaction_increments_both_revenues() -> void:
	_ms._on_transaction_completed(100.0, true, "sale")
	assert_almost_eq(
		float(_ms._counters["cumulative_revenue"]), 100.0, 0.01
	)
	assert_almost_eq(
		float(_ms._counters["single_day_revenue"]), 100.0, 0.01
	)


func test_failed_transaction_does_not_increment_revenue() -> void:
	_ms._on_transaction_completed(50.0, false, "declined")
	assert_almost_eq(
		float(_ms._counters["cumulative_revenue"]), 0.0, 0.01
	)
	assert_almost_eq(
		float(_ms._counters["single_day_revenue"]), 0.0, 0.01
	)


func test_day_started_resets_single_day_revenue() -> void:
	_ms._on_transaction_completed(300.0, true, "sale")
	_ms._on_day_started(2)
	assert_almost_eq(
		float(_ms._counters["single_day_revenue"]), 0.0, 0.01,
		"single_day_revenue must reset on day_started"
	)


func test_day_started_preserves_cumulative_revenue() -> void:
	_ms._on_transaction_completed(200.0, true, "sale")
	_ms._on_day_started(2)
	assert_almost_eq(
		float(_ms._counters["cumulative_revenue"]), 200.0, 0.01,
		"cumulative_revenue must persist across days"
	)


func test_customer_left_satisfied_increments() -> void:
	_ms._on_customer_left({"satisfied": true})
	assert_eq(int(_ms._counters["satisfied_customer_count"]), 1)


func test_customer_left_unsatisfied_no_increment() -> void:
	_ms._on_customer_left({"satisfied": false})
	assert_eq(int(_ms._counters["satisfied_customer_count"]), 0)


func test_customer_purchased_increments_count() -> void:
	_ms._on_customer_purchased(
		&"store", &"item_1", 25.0, &"cust_1"
	)
	assert_eq(int(_ms._counters["customer_purchased_count"]), 1)


func test_store_entered_two_unique() -> void:
	_ms._on_store_entered(&"sports_cards")
	_ms._on_store_entered(&"retro_games")
	assert_eq(int(_ms._counters["unique_store_types_entered"]), 2)


func test_store_entered_deduplicates() -> void:
	_ms._on_store_entered(&"sports_cards")
	_ms._on_store_entered(&"sports_cards")
	assert_eq(
		int(_ms._counters["unique_store_types_entered"]), 1,
		"Repeated store_entered must not double-count"
	)


func test_haggle_completed_updates_ratio() -> void:
	_ms._on_haggle_completed(
		&"store", &"item", 180.0, 100.0, true, 3
	)
	assert_almost_eq(
		float(_ms._counters["haggle_max_price_ratio"]), 1.8, 0.01
	)


func test_haggle_rejected_no_ratio_update() -> void:
	_ms._on_haggle_completed(
		&"store", &"item", 180.0, 100.0, false, 3
	)
	assert_almost_eq(
		float(_ms._counters["haggle_max_price_ratio"]), 0.0, 0.01
	)


func test_haggle_keeps_max_ratio() -> void:
	_ms._on_haggle_completed(
		&"store", &"a", 180.0, 100.0, true, 2
	)
	_ms._on_haggle_completed(
		&"store", &"b", 120.0, 100.0, true, 1
	)
	assert_almost_eq(
		float(_ms._counters["haggle_max_price_ratio"]), 1.8, 0.01,
		"Max ratio must not be overwritten by lower value"
	)


func test_pricing_streak_increments_in_range() -> void:
	_ms._on_item_price_set(&"s", &"a", 12.0, 1.3)
	_ms._on_item_price_set(&"s", &"b", 14.0, 1.4)
	_ms._on_item_price_set(&"s", &"c", 15.0, 1.5)
	assert_eq(int(_ms._counters["pricing_streak_in_range"]), 3)


func test_pricing_streak_resets_above_range() -> void:
	_ms._on_item_price_set(&"s", &"a", 12.0, 1.3)
	_ms._on_item_price_set(&"s", &"b", 14.0, 1.4)
	_ms._on_item_price_set(&"s", &"c", 20.0, 2.0)
	assert_eq(
		int(_ms._counters["pricing_streak_in_range"]), 0,
		"Streak must reset when ratio exceeds 1.5"
	)


func test_pricing_streak_resets_below_range() -> void:
	_ms._on_item_price_set(&"s", &"a", 12.0, 1.3)
	_ms._on_item_price_set(&"s", &"b", 10.0, 1.0)
	assert_eq(
		int(_ms._counters["pricing_streak_in_range"]), 0,
		"Streak must reset when ratio is below 1.2"
	)


func test_random_event_market_crash_survived() -> void:
	_ms._on_random_event_resolved(&"market_crash", &"survived")
	assert_eq(int(_ms._counters["market_crash_survived"]), 1)


func test_random_event_non_crash_ignored() -> void:
	_ms._on_random_event_resolved(&"power_outage", &"survived")
	assert_eq(int(_ms._counters["market_crash_survived"]), 0)


# ── 3. Milestone threshold evaluation ──


func test_first_sale_fires_after_first_purchase() -> void:
	var fired_id: Array = [&""]
	var cb: Callable = func(
		id: StringName, _r: Dictionary
	) -> void:
		fired_id[0] = id
	EventBus.milestone_unlocked.connect(cb)
	_ms._on_customer_purchased(&"s", &"i", 10.0, &"c")
	assert_eq(fired_id[0], &"first_sale")
	EventBus.milestone_unlocked.disconnect(cb)


func test_milestone_unlocked_fires_exactly_once() -> void:
	var count: Array = [0]
	var cb: Callable = func(
		_id: StringName, _r: Dictionary
	) -> void:
		count[0] += 1
	EventBus.milestone_unlocked.connect(cb)
	_ms._on_customer_purchased(&"s", &"i1", 10.0, &"c")
	_ms._on_customer_purchased(&"s", &"i2", 10.0, &"c")
	assert_eq(count[0], 1, "Must fire exactly once per milestone")
	EventBus.milestone_unlocked.disconnect(cb)


func test_milestone_not_refired_on_second_threshold_cross() -> void:
	var ids: Array[StringName] = []
	var cb: Callable = func(
		id: StringName, _r: Dictionary
	) -> void:
		ids.append(id)
	EventBus.milestone_unlocked.connect(cb)
	_ms._on_transaction_completed(200.0, true, "s1")
	_ms._on_transaction_completed(200.0, true, "s2")
	var big_count: Array = [0]
	for fid: StringName in ids:
		if fid == &"big_earner":
			big_count[0] += 1
	assert_eq(big_count[0], 1, "Must not re-fire after completion")
	EventBus.milestone_unlocked.disconnect(cb)


func test_week_one_survivor_emits_unlock_granted() -> void:
	var granted_id: Array = [&""]
	var cb: Callable = func(uid: StringName) -> void:
		granted_id[0] = uid
	EventBus.milestone_unlock_granted.connect(cb)
	_ms._on_day_ended(7)
	assert_eq(granted_id[0], &"order_catalog_expansion_1")
	EventBus.milestone_unlock_granted.disconnect(cb)


func test_cash_reward_emits_transaction_completed() -> void:
	var reward_amount: Array = [0.0]
	var reward_msg: Array = [""]
	var cb: Callable = func(
		amount: float, success: bool, message: String
	) -> void:
		if "Milestone" in message:
			reward_amount[0] = amount
			reward_msg[0] = message
	EventBus.transaction_completed.connect(cb)
	_ms._on_customer_purchased(&"s", &"i", 10.0, &"c")
	assert_almost_eq(reward_amount[0], 10.0, 0.01)
	assert_string_contains(reward_msg, "first_sale")
	EventBus.transaction_completed.disconnect(cb)


func test_hidden_milestone_fires_when_met() -> void:
	var fired: Array = [false]
	var cb: Callable = func(
		id: StringName, _r: Dictionary
	) -> void:
		if id == &"hidden_crash":
			fired[0] = true
	EventBus.milestone_unlocked.connect(cb)
	_ms._on_random_event_resolved(&"market_crash", &"survived")
	assert_true(fired[0])
	EventBus.milestone_unlocked.disconnect(cb)


# ── 4. Load symmetry and no re-emission ──


func test_save_data_contains_required_keys() -> void:
	_ms._on_transaction_completed(200.0, true, "sale")
	var data: Dictionary = _ms.get_save_data()
	assert_true(data.has("completed"))
	assert_true(data.has("counters"))
	assert_true(data.has("unique_stores_seen"))


func test_load_state_restores_completed() -> void:
	_ms._on_customer_purchased(&"s", &"i", 10.0, &"c")
	var save_data: Dictionary = _ms.get_save_data()

	var ms2 := MilestoneSystem.new()
	add_child_autofree(ms2)
	ms2._milestones = _build_test_milestones()
	ms2.load_state(save_data)
	assert_true(ms2.is_complete(&"first_sale"))


func test_load_state_restores_counters() -> void:
	_ms._on_transaction_completed(150.0, true, "sale")
	_ms._on_customer_purchased(&"s", &"i", 10.0, &"c")
	var save_data: Dictionary = _ms.get_save_data()

	var ms2 := MilestoneSystem.new()
	add_child_autofree(ms2)
	ms2._milestones = _build_test_milestones()
	ms2.load_state(save_data)
	assert_almost_eq(
		float(ms2._counters["cumulative_revenue"]), 150.0, 0.01
	)
	assert_eq(int(ms2._counters["customer_purchased_count"]), 1)


func test_load_state_does_not_refire_milestone_unlocked() -> void:
	_ms._on_customer_purchased(&"s", &"i", 10.0, &"c")
	var save_data: Dictionary = _ms.get_save_data()

	var ms2 := MilestoneSystem.new()
	add_child_autofree(ms2)
	ms2._milestones = _build_test_milestones()

	var count: Array = [0]
	var cb: Callable = func(
		_id: StringName, _r: Dictionary
	) -> void:
		count[0] += 1
	EventBus.milestone_unlocked.connect(cb)
	ms2.load_state(save_data)
	assert_eq(count[0], 0, "load_state must not re-fire signals")
	EventBus.milestone_unlocked.disconnect(cb)


func test_load_state_preserves_unique_stores() -> void:
	_ms._on_store_entered(&"retro_games")
	_ms._on_store_entered(&"video_rental")
	var save_data: Dictionary = _ms.get_save_data()

	var ms2 := MilestoneSystem.new()
	add_child_autofree(ms2)
	ms2.load_state(save_data)
	assert_eq(
		int(ms2._counters["unique_store_types_entered"]), 2
	)


# ── 5. Public API ──


func test_get_completion_percent_zero_initially() -> void:
	assert_almost_eq(_ms.get_completion_percent(), 0.0, 0.01)


func test_get_completion_percent_after_one_visible() -> void:
	_ms._on_customer_purchased(&"s", &"i", 10.0, &"c")
	var visible_total: Array = [0]
	for m: MilestoneDefinition in _ms._milestones:
		if m.is_visible:
			visible_total[0] += 1
	var expected: float = 1.0 / float(visible_total)
	assert_almost_eq(_ms.get_completion_percent(), expected, 0.01)


func test_get_completion_percent_excludes_hidden() -> void:
	_ms._on_random_event_resolved(&"market_crash", &"survived")
	assert_true(_ms.is_complete(&"hidden_crash"))
	assert_almost_eq(
		_ms.get_completion_percent(), 0.0, 0.01,
		"Hidden milestone must not affect completion percent"
	)


func test_is_complete_false_before_threshold() -> void:
	assert_false(_ms.is_complete(&"big_earner"))


func test_is_complete_true_after_threshold() -> void:
	_ms._on_transaction_completed(200.0, true, "sale")
	assert_true(_ms.is_complete(&"big_earner"))


func test_is_complete_unknown_id_returns_false() -> void:
	assert_false(_ms.is_complete(&"nonexistent"))


func test_get_completed_ids_empty_initially() -> void:
	assert_eq(_ms.get_completed_ids().size(), 0)


func test_get_completed_ids_contains_completed() -> void:
	_ms._on_customer_purchased(&"s", &"i", 10.0, &"c")
	assert_has(_ms.get_completed_ids(), &"first_sale")
