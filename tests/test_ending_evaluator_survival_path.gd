## Integration test — EndingEvaluatorSystem SURVIVAL path: 30-day survival with
## marginal or neutral outcomes both resolve to the broke_even fallback.
extends GutTest


const SUCCESS_ENDINGS: Array[StringName] = [
	&"prestige_champion",
	&"the_local_legend",
	&"the_mini_empire",
	&"the_mall_tycoon",
	&"the_fair_dealer",
]

var _evaluator: EndingEvaluatorSystem
var _triggered_endings: Array[Dictionary] = []
var _saved_game_state: int = 0


func before_each() -> void:
	_triggered_endings = []
	_saved_game_state = GameManager.current_state
	GameManager.current_state = GameManager.GameState.GAMEPLAY

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


# ── Helpers ───────────────────────────────────────────────────────────────────


func _set_survival_marginal_stats() -> void:
	_evaluator._stats["days_survived"] = 30.0
	_evaluator._stats["final_cash"] = 500.0
	_evaluator._stats["cumulative_revenue"] = 1000.0
	_evaluator._stats["owned_store_count_final"] = 0.0
	_evaluator._stats["max_reputation_tier"] = 1.0
	_evaluator._stats["trigger_type_bankruptcy"] = 0.0


func _set_survival_neutral_stats() -> void:
	_evaluator._stats["days_survived"] = 30.0
	_evaluator._stats["final_cash"] = 0.0
	_evaluator._stats["cumulative_revenue"] = 1000.0
	_evaluator._stats["owned_store_count_final"] = 0.0
	_evaluator._stats["max_reputation_tier"] = 1.0
	_evaluator._stats["trigger_type_bankruptcy"] = 0.0


# ── Scenario A — 30-day survival with marginal profit → broke_even ─────────


func test_marginal_profit_30_days_triggers_broke_even() -> void:
	_set_survival_marginal_stats()

	EventBus.completion_reached.emit("time_limit")

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")
	assert_eq(
		_triggered_endings[0]["id"],
		&"broke_even",
		"30-day survival with marginal profit must select broke_even"
	)


func test_broke_even_not_a_success_ending() -> void:
	_set_survival_marginal_stats()

	EventBus.completion_reached.emit("time_limit")

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")
	var triggered_id: StringName = _triggered_endings[0]["id"]
	for success_id: StringName in SUCCESS_ENDINGS:
		assert_ne(
			triggered_id,
			success_id,
			"Marginal-profit survival must not select SUCCESS ending: %s" % success_id
		)


func test_broke_even_final_stats_contains_stat_summary_keys() -> void:
	_set_survival_marginal_stats()

	EventBus.completion_reached.emit("time_limit")

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")

	var final_stats: Dictionary = _triggered_endings[0]["stats"]
	var ending_data: Dictionary = _evaluator.get_ending_data(&"broke_even")
	var summary_keys: Variant = ending_data.get("stat_summary_keys", [])

	assert_true(
		summary_keys is Array,
		"stat_summary_keys from catalog must be an Array or absent"
	)

	for key: Variant in summary_keys:
		assert_true(
			final_stats.has(String(key)),
			"final_stats must contain stat_summary_key: %s" % key
		)


func test_marginal_profit_game_manager_transitions_to_game_over() -> void:
	_set_survival_marginal_stats()

	EventBus.completion_reached.emit("time_limit")

	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"GameManager must transition to GAME_OVER after ending fires"
	)


# ── Scenario B — 30-day survival with neutral profit → broke_even fallback ───


func test_neutral_profit_30_days_triggers_broke_even_fallback() -> void:
	_set_survival_neutral_stats()

	EventBus.completion_reached.emit("time_limit")

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")
	assert_eq(
		_triggered_endings[0]["id"],
		&"broke_even",
		"30-day survival with neutral profit must fall back to broke_even"
	)


func test_broke_even_fallback_not_a_success_ending() -> void:
	_set_survival_neutral_stats()

	EventBus.completion_reached.emit("time_limit")

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")
	var triggered_id: StringName = _triggered_endings[0]["id"]
	for success_id: StringName in SUCCESS_ENDINGS:
		assert_ne(
			triggered_id,
			success_id,
			"Neutral-profit fallback must not select SUCCESS ending: %s" % success_id
		)


# ── Scenario C — Priority ordering: SUCCESS > SURVIVAL ───────────────────────


func test_success_ending_wins_over_survival_when_thresholds_met() -> void:
	# Stats satisfy the_local_legend (priority 6, SUCCESS) and
	# the_comfortable_middle (priority 12, SURVIVAL) simultaneously.
	# The evaluator must select the SUCCESS ending.
	_evaluator._stats["days_survived"] = 30.0
	_evaluator._stats["cumulative_revenue"] = 3000.0
	_evaluator._stats["owned_store_count_final"] = 1.0
	_evaluator._stats["max_reputation_tier"] = 4.0
	_evaluator._stats["final_cash"] = 500.0
	_evaluator._stats["trigger_type_bankruptcy"] = 0.0

	EventBus.completion_reached.emit("time_limit")

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")
	var triggered_id: StringName = _triggered_endings[0]["id"]
	assert_eq(
		triggered_id,
		&"the_local_legend",
		"SUCCESS ending (the_local_legend) must be selected over SURVIVAL ending when both criteria are met"
	)
	assert_ne(
		triggered_id,
		&"the_comfortable_middle",
		"SURVIVAL ending must not win when a SUCCESS ending also qualifies"
	)


# ── Scenario D — Single-trigger enforcement ───────────────────────────────────


func test_only_one_ending_triggered_per_completion_reached_survival() -> void:
	_set_survival_marginal_stats()

	EventBus.completion_reached.emit("time_limit")
	EventBus.completion_reached.emit("time_limit")

	assert_eq(
		_triggered_endings.size(),
		1,
		"First-trigger-wins: second completion_reached must not fire a second ending"
	)


func test_survival_ending_not_triggered_after_prior_ending_fired() -> void:
	# Consume the trigger slot with a bankruptcy ending first.
	_evaluator._stats["days_survived"] = 5.0
	EventBus.bankruptcy_declared.emit()

	assert_eq(_triggered_endings.size(), 1, "Bankruptcy ending must fire first")
	var first_id: StringName = _triggered_endings[0]["id"]

	_set_survival_marginal_stats()
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
