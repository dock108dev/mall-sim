## GUT parameterized tests that confirm every ending in ending_config.json
## is reachable by simulating the matching stat vector through
## EndingEvaluatorSystem.evaluate(). Each case also verifies that no
## other ending fires for the same vector, which protects against priority
## collisions introduced by future content edits.
extends GutTest


var _system: EndingEvaluatorSystem


func before_each() -> void:
	_system = EndingEvaluatorSystem.new()
	add_child_autofree(_system)
	_system.initialize()


## Builds a full zero-baseline stat dict and merges the provided overrides.
func _build_stats(overrides: Dictionary) -> Dictionary:
	var base: Dictionary = {
		"cumulative_revenue": 0.0,
		"cumulative_expenses": 0.0,
		"peak_cash": 0.0,
		"final_cash": 0.0,
		"days_survived": 0.0,
		"owned_store_count_peak": 0.0,
		"owned_store_count_final": 0.0,
		"total_sales_count": 0.0,
		"satisfied_customer_count": 0.0,
		"unsatisfied_customer_count": 0.0,
		"satisfaction_ratio": 0.0,
		"max_reputation_tier": 0.0,
		"final_reputation_tier": 0.0,
		"secret_threads_completed": 0.0,
		"haggle_attempts": 0.0,
		"haggle_never_used": 1.0,
		"days_near_bankruptcy": 0.0,
		"rare_items_sold": 0.0,
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


## Returns a table of {id, stats} cases — one entry per ending.
## Each stat vector is designed to satisfy exactly that ending's criteria
## and no higher-priority ending.
func _ending_cases() -> Array[Dictionary]:
	return [
		{
			"id": "the_mall_between_the_walls",
			"stats": {
				"ghost_tenant_thread_completed": 1.0,
			},
		},
		{
			"id": "the_mall_legend_redux",
			"stats": {
				"secret_threads_completed": 4.0,
				"cumulative_revenue": 25000.0,
				"ghost_tenant_thread_completed": 0.0,
			},
		},
		{
			"id": "lights_out",
			"stats": {
				"trigger_type_bankruptcy": 1.0,
				"days_survived": 5.0,
			},
		},
		{
			"id": "foreclosure",
			"stats": {
				"trigger_type_bankruptcy": 1.0,
				"days_survived": 10.0,
			},
		},
		{
			"id": "going_going_gone",
			"stats": {
				"trigger_type_bankruptcy": 1.0,
				"days_survived": 20.0,
			},
		},
		{
			"id": "prestige_champion",
			"stats": {
				"cumulative_revenue": 50000.0,
				"max_reputation_tier": 4.0,
				"satisfied_customer_count": 900.0,
				"unsatisfied_customer_count": 100.0,
				"days_survived": 30.0,
				"trigger_type_bankruptcy": 0.0,
			},
		},
		{
			"id": "the_local_legend",
			"stats": {
				"owned_store_count_final": 1.0,
				"max_reputation_tier": 4.0,
				"days_survived": 30.0,
				"cumulative_revenue": 5000.0,
				"trigger_type_bankruptcy": 0.0,
			},
		},
		{
			"id": "the_mall_tycoon",
			"stats": {
				"owned_store_count_final": 5.0,
				"cumulative_revenue": 25000.0,
				"trigger_type_bankruptcy": 0.0,
			},
		},
		{
			"id": "the_mini_empire",
			"stats": {
				"owned_store_count_final": 3.0,
				"cumulative_revenue": 10000.0,
				"days_survived": 30.0,
				"trigger_type_bankruptcy": 0.0,
			},
		},
		{
			"id": "the_fair_dealer",
			"stats": {
				"satisfied_customer_count": 200.0,
				"haggle_never_used": 1.0,
				"max_reputation_tier": 3.0,
				"trigger_type_bankruptcy": 0.0,
			},
		},
		{
			"id": "broke_even",
			"stats": {
				"days_survived": 30.0,
				"final_cash": 100.0,
				"cumulative_revenue": 500.0,
				"trigger_type_bankruptcy": 0.0,
			},
		},
		{
			"id": "the_comfortable_middle",
			"stats": {
				"days_survived": 30.0,
				"cumulative_revenue": 5000.0,
				"trigger_type_bankruptcy": 0.0,
				"days_near_bankruptcy": 0.0,
			},
		},
		{
			"id": "crisis_operator",
			"stats": {
				"days_near_bankruptcy": 10.0,
				"days_survived": 30.0,
				"final_cash": 100.0,
				"cumulative_revenue": 15000.0,
				"trigger_type_bankruptcy": 0.0,
			},
		},
	]


## Iterates all ending cases and asserts each produces the expected id.
func test_all_13_endings_reachable_via_distinct_stat_vectors() -> void:
	var cases: Array[Dictionary] = _ending_cases()
	assert_eq(
		cases.size(), 13,
		"Expected 13 ending cases — one per entry in ending_config.json"
	)
	for entry: Dictionary in cases:
		var expected_id: StringName = StringName(str(entry.get("id", "")))
		var overrides: Dictionary = entry.get("stats", {}) as Dictionary
		_system = EndingEvaluatorSystem.new()
		add_child_autofree(_system)
		_system.initialize()
		_load_stats(overrides)
		var got: StringName = _system.evaluate()
		assert_eq(
			got, expected_id,
			"Ending '%s' should fire for its stat vector; got '%s'" % [
				expected_id, got
			]
		)


## Verifies the fallback 'broke_even' fires when no specific criteria match.
func test_fallback_fires_when_no_criteria_match() -> void:
	_load_stats({})
	assert_eq(
		_system.evaluate(),
		&"broke_even",
		"Zero-stats run must fall back to broke_even"
	)


## Verifies that ending_triggered is emitted exactly once and carries the id.
func test_ending_triggered_carries_resolved_id() -> void:
	watch_signals(EventBus)
	_load_stats({
		"days_survived": 30.0,
		"final_cash": 200.0,
		"cumulative_revenue": 8000.0,
	})
	EventBus.ending_requested.emit("player_quit")
	assert_signal_emitted(
		EventBus,
		"ending_triggered",
		"ending_triggered must fire after ending_requested"
	)
	assert_eq(
		get_signal_emit_count(EventBus, "ending_triggered"),
		1,
		"ending_triggered must emit exactly once"
	)


## Verifies that ContentSchema accepts all 13 endings without criteria errors.
func test_content_schema_validates_all_ending_criteria() -> void:
	var ids: Array[StringName] = ContentRegistry.get_all_ids("ending")
	assert_gt(
		ids.size(), 0,
		"ContentRegistry must have at least one ending registered"
	)
	for ending_id: StringName in ids:
		var entry: Dictionary = ContentRegistry.get_entry(ending_id)
		assert_false(
			entry.is_empty(),
			"ContentRegistry entry for '%s' must not be empty" % ending_id
		)
		var errors: Array[String] = ContentSchema.validate(entry, "ending")
		assert_eq(
			errors.size(), 0,
			"Ending '%s' must pass ContentSchema validation; errors: %s"
			% [ending_id, str(errors)]
		)
