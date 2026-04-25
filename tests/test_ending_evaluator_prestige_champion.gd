## Integration test verifying the EndingEvaluatorSystem prestige_champion ending:
## thresholds met → correct ending_id; below thresholds → different ending selected.
extends GutTest


var _evaluator: EndingEvaluatorSystem
var _triggered_endings: Array[Dictionary] = []
var _saved_game_state: int = 0


func before_each() -> void:
	_triggered_endings = []
	_saved_game_state = GameManager.current_state
	GameManager.current_state = GameManager.State.GAMEPLAY

	_evaluator = EndingEvaluatorSystem.new()
	add_child_autofree(_evaluator)
	_evaluator.initialize()

	EventBus.ending_triggered.connect(_on_ending_triggered)


func after_each() -> void:
	if EventBus.ending_triggered.is_connected(_on_ending_triggered):
		EventBus.ending_triggered.disconnect(_on_ending_triggered)
	GameManager.current_state = _saved_game_state
	GameManager._ending_id = &""


func _on_ending_triggered(ending_id: StringName, final_stats: Dictionary) -> void:
	_triggered_endings.append({"id": ending_id, "stats": final_stats})


# ── Helper ────────────────────────────────────────────────────────────────────


func _set_prestige_champion_stats() -> void:
	_evaluator._stats["cumulative_revenue"] = 50000.0
	_evaluator._stats["max_reputation_tier"] = 4.0
	_evaluator._stats["days_survived"] = 30.0
	_evaluator._stats["owned_store_count_final"] = 1.0
	# satisfaction_ratio is computed from counts in _update_computed_stats()
	_evaluator._stats["satisfied_customer_count"] = 90.0
	_evaluator._stats["unsatisfied_customer_count"] = 10.0


# ── Scenario A — All prestige_champion thresholds met ─────────────────────────


func test_prestige_champion_thresholds_met_triggers_correct_ending() -> void:
	_set_prestige_champion_stats()

	EventBus.completion_reached.emit("time_limit")

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")
	assert_eq(
		_triggered_endings[0]["id"],
		&"prestige_champion",
		"All prestige gates met must select prestige_champion"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.State.GAME_OVER,
		"GameManager must transition to GAME_OVER after ending fires"
	)


func test_prestige_champion_final_stats_contains_all_stat_summary_keys() -> void:
	_set_prestige_champion_stats()

	EventBus.completion_reached.emit("time_limit")

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")

	var final_stats: Dictionary = _triggered_endings[0]["stats"]
	var ending_data: Dictionary = _evaluator.get_ending_data(&"prestige_champion")
	var summary_keys: Variant = ending_data.get("stat_summary_keys", [])

	assert_true(
		summary_keys is Array and not (summary_keys as Array).is_empty(),
		"prestige_champion must define stat_summary_keys in endings_catalog"
	)

	for key: Variant in summary_keys:
		assert_true(
			final_stats.has(String(key)),
			"final_stats must contain stat_summary_key: %s" % key
		)


# ── Scenario B — Stats just below prestige_champion thresholds ────────────────


func test_revenue_just_below_threshold_selects_different_ending() -> void:
	_set_prestige_champion_stats()
	# Set revenue 1 below the prestige gate of 50000
	_evaluator._stats["cumulative_revenue"] = 49999.0

	EventBus.completion_reached.emit("time_limit")

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")
	var triggered_id: StringName = _triggered_endings[0]["id"]
	assert_ne(
		triggered_id,
		&"prestige_champion",
		"Revenue below gate must not select prestige_champion"
	)
	assert_ne(
		triggered_id,
		&"",
		"A fallback ending must still be selected"
	)


func test_satisfaction_below_threshold_selects_different_ending() -> void:
	_set_prestige_champion_stats()
	# Set ratio to ~0.84 (below 0.85 gate): 84 satisfied, 16 unsatisfied
	_evaluator._stats["satisfied_customer_count"] = 84.0
	_evaluator._stats["unsatisfied_customer_count"] = 16.0

	EventBus.completion_reached.emit("time_limit")

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")
	assert_ne(
		_triggered_endings[0]["id"],
		&"prestige_champion",
		"Satisfaction below gate must not select prestige_champion"
	)


# ── Scenario C — Single-trigger enforcement ───────────────────────────────────


func test_only_one_ending_triggered_per_completion_reached() -> void:
	_set_prestige_champion_stats()

	EventBus.completion_reached.emit("time_limit")
	EventBus.completion_reached.emit("time_limit")

	assert_eq(
		_triggered_endings.size(),
		1,
		"First-trigger-wins: second completion_reached must not fire a second ending"
	)


func test_prestige_champion_not_triggered_after_prior_ending_fired() -> void:
	# Fire a bankruptcy ending first to consume the trigger slot
	_evaluator._stats["days_survived"] = 15.0
	EventBus.bankruptcy_declared.emit()

	assert_eq(_triggered_endings.size(), 1, "Bankruptcy ending must fire first")
	var first_id: StringName = _triggered_endings[0]["id"]

	# Now supply prestige-level stats and emit completion — must be ignored
	_set_prestige_champion_stats()
	EventBus.completion_reached.emit("time_limit")

	assert_eq(
		_triggered_endings.size(),
		1,
		"Subsequent completion_reached after a prior ending must not fire again"
	)
	assert_eq(
		_triggered_endings[0]["id"],
		first_id,
		"Resolved ending must remain the first-triggered one"
	)
