## Integration test verifying the EndingEvaluatorSystem evaluation pipeline
## for bankruptcy, full-success, and partial-completion ending paths.
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


func _on_ending_triggered(ending_id: StringName, _final_stats: Dictionary) -> void:
	_triggered_endings.append({"id": ending_id})


# ── Scenario A — Bankruptcy after minimum day threshold ───────────────────────


func test_bankruptcy_after_fifteen_days_selects_going_going_gone() -> void:
	_evaluator._stats["days_survived"] = 15.0

	EventBus.bankruptcy_declared.emit()

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")
	assert_eq(
		_triggered_endings[0]["id"],
		&"going_going_gone",
		"Bankruptcy with 15+ days must select going_going_gone"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.State.GAME_OVER,
		"GameManager must transition to GAME_OVER after ending fires"
	)


func test_bankruptcy_ending_fires_only_once_on_repeated_emissions() -> void:
	_evaluator._stats["days_survived"] = 15.0

	EventBus.bankruptcy_declared.emit()
	EventBus.bankruptcy_declared.emit()

	assert_eq(
		_triggered_endings.size(),
		1,
		"First-trigger-wins: second bankruptcy emission must not fire a second ending"
	)


# ── Scenario B — Full success: all stores owned with max reputation ───────────


func test_all_stores_with_max_rep_over_30_days_selects_local_legend() -> void:
	_evaluator._stats["owned_store_count_final"] = 5.0
	_evaluator._stats["max_reputation_tier"] = 4.0
	_evaluator._stats["days_survived"] = 30.0

	EventBus.ending_requested.emit("time_limit")

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")
	assert_eq(
		_triggered_endings[0]["id"],
		&"the_local_legend",
		"Five stores owned with max reputation over 30+ days must select the_local_legend"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.State.GAME_OVER,
		"GameManager must transition to GAME_OVER"
	)


# ── Scenario C — Partial completion: 3 stores, moderate revenue ───────────────


func test_partial_stores_moderate_revenue_selects_comfortable_middle() -> void:
	_evaluator._stats["owned_store_count_final"] = 3.0
	_evaluator._stats["max_reputation_tier"] = 2.0
	_evaluator._stats["days_survived"] = 30.0
	_evaluator._stats["cumulative_revenue"] = 5000.0
	_evaluator._stats["final_cash"] = 100.0
	_evaluator._stats["hidden_thread_interactions"] = 1.0

	EventBus.ending_requested.emit("time_limit")

	assert_eq(_triggered_endings.size(), 1, "Exactly one ending must fire")
	var triggered_id: StringName = _triggered_endings[0]["id"]
	assert_eq(
		triggered_id,
		&"the_comfortable_middle",
		"Three stores, rep tier 2, revenue 5000, 30 days must select the_comfortable_middle"
	)
	assert_ne(
		triggered_id, &"going_going_gone",
		"Non-bankruptcy path must not select a bankruptcy ending"
	)
	assert_ne(
		triggered_id, &"the_local_legend",
		"Partial completion must not select the full-success ending"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.State.GAME_OVER,
		"GameManager must transition to GAME_OVER"
	)
