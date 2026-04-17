## GUT tests for EndingEvaluatorSystem evaluate() logic and stat tracking.
extends GutTest


var _system: EndingEvaluatorSystem


func before_each() -> void:
	_system = EndingEvaluatorSystem.new()
	add_child_autofree(_system)
	_system.initialize()


func _build_stats(overrides: Dictionary) -> Dictionary:
	var base: Dictionary = {
		"cumulative_revenue": 0.0, "cumulative_expenses": 0.0,
		"peak_cash": 0.0, "final_cash": 0.0,
		"days_survived": 0.0, "owned_store_count_peak": 0.0,
		"owned_store_count_final": 0.0, "total_sales_count": 0.0,
		"satisfied_customer_count": 0.0,
		"unsatisfied_customer_count": 0.0,
		"satisfaction_ratio": 0.0, "max_reputation_tier": 0.0,
		"final_reputation_tier": 0.0,
		"secret_threads_completed": 0.0,
		"haggle_attempts": 0.0, "haggle_never_used": 1.0,
		"days_near_bankruptcy": 0.0, "rare_items_sold": 0.0,
		"market_events_survived": 0.0,
		"unique_store_types_owned": 0.0,
		"trigger_type_bankruptcy": 0.0,
		"ghost_tenant_thread_completed": 0.0,
	}
	for key: String in overrides:
		base[key] = overrides[key]
	return base


func _load_stats(overrides: Dictionary) -> void:
	_system.load_state({"stats": _build_stats(overrides)})


# ── Group 1: evaluate() pure function ──


func test_secret_ending_priority_over_success() -> void:
	_load_stats({
		"ghost_tenant_thread_completed": 1.0,
		"owned_store_count_final": 5.0,
		"max_reputation_tier": 4.0, "cumulative_revenue": 25000.0,
		"days_survived": 30.0,
	})
	assert_eq(
		_system.evaluate(), &"the_ghost_between_the_walls",
		"Secret ending should take priority over success endings"
	)


func test_lights_out_under_7_days() -> void:
	_load_stats({
		"trigger_type_bankruptcy": 1.0, "days_survived": 5.0,
	})
	assert_eq(
		_system.evaluate(), &"lights_out",
		"Bankruptcy under 7 days should be lights_out"
	)


func test_lights_out_boundary_7_days() -> void:
	_load_stats({
		"trigger_type_bankruptcy": 1.0, "days_survived": 7.0,
	})
	assert_eq(
		_system.evaluate(), &"lights_out",
		"Bankruptcy at 7 days should be lights_out"
	)


func test_foreclosure_at_8_days() -> void:
	_load_stats({
		"trigger_type_bankruptcy": 1.0, "days_survived": 8.0,
	})
	assert_eq(
		_system.evaluate(), &"foreclosure",
		"Bankruptcy at 8 days should be foreclosure"
	)


func test_foreclosure_at_14_days() -> void:
	_load_stats({
		"trigger_type_bankruptcy": 1.0, "days_survived": 14.0,
	})
	assert_eq(
		_system.evaluate(), &"foreclosure",
		"Bankruptcy at 14 days should be foreclosure"
	)


func test_going_going_gone_at_15_days() -> void:
	_load_stats({
		"trigger_type_bankruptcy": 1.0, "days_survived": 15.0,
	})
	assert_eq(
		_system.evaluate(), &"going_going_gone",
		"Bankruptcy at 15 days should be going_going_gone"
	)


func test_going_going_gone_at_20_days() -> void:
	_load_stats({
		"trigger_type_bankruptcy": 1.0, "days_survived": 20.0,
	})
	assert_eq(
		_system.evaluate(), &"going_going_gone",
		"Bankruptcy at 20 days should be going_going_gone"
	)


func test_the_local_legend() -> void:
	_load_stats({
		"owned_store_count_final": 1.0,
		"max_reputation_tier": 4.0, "days_survived": 30.0,
	})
	assert_eq(
		_system.evaluate(), &"the_local_legend",
		"1+ stores + rep 4 + 30 days = the_local_legend"
	)


func test_the_mini_empire() -> void:
	_load_stats({
		"owned_store_count_final": 3.0,
		"cumulative_revenue": 10000.0, "days_survived": 30.0,
	})
	assert_eq(
		_system.evaluate(), &"the_mini_empire",
		"3+ stores + 10000 revenue = the_mini_empire"
	)


func test_the_mall_tycoon() -> void:
	_load_stats({
		"owned_store_count_final": 5.0,
		"cumulative_revenue": 25000.0,
	})
	assert_eq(
		_system.evaluate(), &"the_mall_tycoon",
		"5 stores + 25000 revenue = the_mall_tycoon"
	)


func test_the_fair_dealer_no_haggle() -> void:
	_load_stats({
		"satisfied_customer_count": 200.0,
		"haggle_never_used": 1.0,
		"max_reputation_tier": 3.0, "days_survived": 30.0,
	})
	assert_eq(
		_system.evaluate(), &"the_fair_dealer",
		"200 customers + no haggle + rep 3 = the_fair_dealer"
	)


func test_the_fair_dealer_blocked_by_haggle() -> void:
	_load_stats({
		"satisfied_customer_count": 200.0,
		"haggle_never_used": 0.0,
		"max_reputation_tier": 3.0, "days_survived": 30.0,
	})
	assert_ne(
		_system.evaluate(), &"the_fair_dealer",
		"Using haggle should block the_fair_dealer"
	)


func test_the_collector() -> void:
	_load_stats({
		"rare_items_sold": 10.0,
		"cumulative_revenue": 5000.0, "days_survived": 30.0,
	})
	assert_eq(
		_system.evaluate(), &"the_collector",
		"10 rare items + 5000 revenue = the_collector"
	)


func test_broke_even_low_revenue() -> void:
	_load_stats({
		"days_survived": 30.0, "final_cash": 100.0,
		"cumulative_revenue": 1000.0,
	})
	assert_eq(
		_system.evaluate(), &"broke_even",
		"30 days + cash > 0 + revenue < 2000 = broke_even"
	)


func test_the_comfortable_middle() -> void:
	_load_stats({
		"days_survived": 30.0,
		"cumulative_revenue": 5000.0,
	})
	assert_eq(
		_system.evaluate(), &"the_comfortable_middle",
		"30 days + revenue 2000-10000 = the_comfortable_middle"
	)


func test_crisis_operator() -> void:
	_load_stats({
		"days_near_bankruptcy": 10.0,
		"days_survived": 30.0, "final_cash": 100.0,
		"cumulative_revenue": 15000.0,
	})
	assert_eq(
		_system.evaluate(), &"crisis_operator",
		"10 near-bankruptcy days + 30 survived + cash > 0 = crisis_operator"
	)


func test_forbidden_all_blocks_success_endings() -> void:
	_load_stats({
		"trigger_type_bankruptcy": 1.0,
		"owned_store_count_final": 1.0,
		"max_reputation_tier": 4.0, "days_survived": 30.0,
	})
	assert_ne(
		_system.evaluate(), &"the_local_legend",
		"Bankruptcy flag should block the_local_legend"
	)


func test_fallback_just_getting_by() -> void:
	_load_stats({
		"days_survived": 30.0,
		"cumulative_revenue": 500.0,
	})
	assert_eq(
		_system.evaluate(), &"just_getting_by",
		"Low revenue with no matching criteria = just_getting_by"
	)


func test_default_fallback_zero_stats() -> void:
	assert_eq(
		_system.evaluate(), &"just_getting_by",
		"Zero stats should return fallback just_getting_by"
	)


# ── Group 2: Stat counter tracking via signals ──


func test_revenue_accumulation() -> void:
	EventBus.customer_purchased.emit(&"s", &"a", 100.0, &"c")
	EventBus.customer_purchased.emit(&"s", &"b", 250.0, &"c")
	assert_eq(
		_system.get_tracked_stat(&"cumulative_revenue"), 350.0,
		"Revenue should sum all purchase prices"
	)


func test_haggle_never_used_starts_true() -> void:
	assert_eq(
		_system.get_tracked_stat(&"haggle_never_used"), 1.0,
		"haggle_never_used should start at 1.0"
	)


func test_haggle_sets_never_used_false() -> void:
	EventBus.haggle_completed.emit(
		&"s", &"i", 15.0, 20.0, true, 1
	)
	assert_eq(
		_system.get_tracked_stat(&"haggle_never_used"), 0.0,
		"haggle_never_used should be 0.0 after first haggle"
	)


func test_haggle_never_used_cannot_revert() -> void:
	EventBus.haggle_completed.emit(
		&"s", &"i", 15.0, 20.0, true, 1
	)
	EventBus.haggle_completed.emit(
		&"s", &"i", 10.0, 15.0, false, 2
	)
	assert_eq(
		_system.get_tracked_stat(&"haggle_never_used"), 0.0,
		"haggle_never_used must stay 0.0 after subsequent haggles"
	)


func test_secret_thread_increments_counter() -> void:
	EventBus.secret_thread_completed.emit(&"thread_a", {})
	EventBus.secret_thread_completed.emit(&"thread_b", {})
	assert_eq(
		_system.get_tracked_stat(&"secret_threads_completed"),
		2.0, "Two secret threads should yield count of 2"
	)


func test_days_near_bankruptcy_below_threshold() -> void:
	EventBus.money_changed.emit(0.0, 50.0)
	EventBus.day_ended.emit(1)
	EventBus.day_ended.emit(2)
	assert_eq(
		_system.get_tracked_stat(&"days_near_bankruptcy"), 2.0,
		"Cash < 100 on day_ended should increment counter"
	)


func test_days_near_bankruptcy_above_threshold() -> void:
	EventBus.money_changed.emit(0.0, 500.0)
	EventBus.day_ended.emit(1)
	assert_eq(
		_system.get_tracked_stat(&"days_near_bankruptcy"), 0.0,
		"Cash >= 100 should not increment near-bankruptcy counter"
	)


func test_day_started_increments_days_survived() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)
	EventBus.day_started.emit(3)
	assert_eq(
		_system.get_tracked_stat(&"days_survived"), 3.0,
		"Each day_started should increment days_survived"
	)


func test_reputation_changed_updates_max_tier() -> void:
	EventBus.reputation_changed.emit("s", 65.0)
	assert_eq(
		_system.get_tracked_stat(&"max_reputation_tier"), 3.0,
		"Reputation 65 should map to tier 3"
	)


func test_reputation_max_tier_never_decreases() -> void:
	EventBus.reputation_changed.emit("s", 85.0)
	EventBus.reputation_changed.emit("s", 30.0)
	assert_eq(
		_system.get_tracked_stat(&"max_reputation_tier"), 4.0,
		"max_reputation_tier should never decrease"
	)


func test_satisfaction_ratio_computed() -> void:
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": true})
	EventBus.customer_left.emit({"satisfied": false})
	var stats: Dictionary = _system.get_all_tracked_stats()
	assert_almost_eq(
		float(stats.get("satisfaction_ratio", 0.0)),
		0.75, 0.001, "3/4 satisfied should yield 0.75 ratio"
	)


func test_the_mall_legend_redux() -> void:
	_load_stats({
		"ghost_tenant_thread_completed": 0.0,
		"secret_threads_completed": 4.0,
		"cumulative_revenue": 25000.0,
	})
	assert_eq(
		_system.evaluate(), &"the_mall_legend_redux",
		"4+ secret threads + 25000 revenue = the_mall_legend_redux"
	)


func test_prestige_champion() -> void:
	_load_stats({
		"cumulative_revenue": 50000.0,
		"max_reputation_tier": 4.0,
		"satisfied_customer_count": 85.0,
		"unsatisfied_customer_count": 15.0,
		"days_survived": 30.0,
		"trigger_type_bankruptcy": 0.0,
	})
	assert_eq(
		_system.evaluate(), &"prestige_champion",
		"50000 revenue + rep 4 + 0.85 sat ratio + 30 days = prestige_champion"
	)
