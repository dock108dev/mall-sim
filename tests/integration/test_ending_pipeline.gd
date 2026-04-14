## Integration test: full ending pipeline — day 30 → evaluate → ending_triggered.
extends GutTest


const BANKRUPTCY_ENDINGS: Array[StringName] = [
	&"lights_out", &"foreclosure", &"going_going_gone",
]

var _ending_evaluator: EndingEvaluatorSystem

var _saved_state: GameManager.GameState
var _saved_ending_id: StringName


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_ending_id = GameManager.get_ending_id()

	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager._ending_id = &""

	_ending_evaluator = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_evaluator)
	_ending_evaluator.initialize()


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager._ending_id = _saved_ending_id


func _seed_stats(overrides: Dictionary) -> void:
	var save_data: Dictionary = _ending_evaluator.get_save_data()
	var stats: Dictionary = save_data.get("stats", {}).duplicate()
	for key: String in overrides:
		stats[key] = overrides[key]
	save_data["stats"] = stats
	_ending_evaluator.load_state(save_data)


func _build_session_stats(
	day: int, balance: float, reputation_score: float,
	stores_owned: int
) -> Dictionary:
	return {
		"day": day,
		"balance": balance,
		"reputation_score": reputation_score,
		"stores_owned": stores_owned,
	}


func _validate_session_stats_shape(stats: Dictionary) -> bool:
	var required_keys: Array[String] = [
		"day", "balance", "reputation_score", "stores_owned",
	]
	for key: String in required_keys:
		if not stats.has(key):
			push_error(
				"Session stats missing required key: %s" % key
			)
			return false
	if not (stats["day"] is int or stats["day"] is float):
		push_error("Session stats 'day' must be numeric")
		return false
	if not (stats["balance"] is float or stats["balance"] is int):
		push_error("Session stats 'balance' must be numeric")
		return false
	if not (
		stats["reputation_score"] is float
		or stats["reputation_score"] is int
	):
		push_error("Session stats 'reputation_score' must be numeric")
		return false
	if not (
		stats["stores_owned"] is int
		or stats["stores_owned"] is float
	):
		push_error("Session stats 'stores_owned' must be numeric")
		return false
	return true


## Bankruptcy ending: balance=-1 on day 30 triggers a bankruptcy-category ending.
func test_bankruptcy_ending() -> void:
	_seed_stats({
		"days_survived": 30.0,
		"final_cash": -1.0,
	})

	var triggered_id: StringName = &""
	var triggered_stats: Dictionary = {}
	var on_ending: Callable = func(
		id: StringName, stats: Dictionary
	) -> void:
		triggered_id = id
		triggered_stats = stats
	EventBus.ending_triggered.connect(on_ending)

	EventBus.bankruptcy_declared.emit()

	assert_true(
		triggered_id in BANKRUPTCY_ENDINGS,
		"Day 30 bankruptcy should trigger a bankruptcy ending; got: %s"
		% triggered_id
	)
	assert_eq(
		triggered_id,
		&"going_going_gone",
		"days_survived=30 bankruptcy should select going_going_gone"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"GameManager must transition to GAME_OVER"
	)
	assert_true(
		_ending_evaluator.has_ending_been_shown(),
		"EndingEvaluatorSystem must mark ending as shown"
	)
	assert_true(
		triggered_stats.has("trigger_type_bankruptcy"),
		"final_stats must include trigger_type_bankruptcy"
	)
	assert_eq(
		triggered_stats.get("trigger_type_bankruptcy", 0.0),
		1.0,
		"trigger_type_bankruptcy must be 1.0"
	)

	EventBus.ending_triggered.disconnect(on_ending)


## Survival ending: balance=500, reputation_score=40 on day 30 triggers a survival ending.
func test_survival_ending() -> void:
	_seed_stats({
		"days_survived": 30.0,
		"final_cash": 500.0,
		"cumulative_revenue": 500.0,
		"max_reputation_tier": 2.0,
		"final_reputation_tier": 2.0,
		"trigger_type_bankruptcy": 0.0,
	})

	var triggered_id: StringName = &""
	var triggered_stats: Dictionary = {}
	var on_ending: Callable = func(
		id: StringName, stats: Dictionary
	) -> void:
		triggered_id = id
		triggered_stats = stats
	EventBus.ending_triggered.connect(on_ending)

	EventBus.ending_requested.emit("completion")

	assert_eq(
		triggered_id,
		&"broke_even",
		"balance=500, rep=40, day 30 should trigger broke_even survival ending"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"GameManager must transition to GAME_OVER"
	)
	assert_true(
		_ending_evaluator.has_ending_been_shown(),
		"EndingEvaluatorSystem must mark ending as shown"
	)
	assert_eq(
		triggered_stats.get("trigger_type_bankruptcy", -1.0),
		0.0,
		"trigger_type_bankruptcy must be 0.0 for survival endings"
	)

	EventBus.ending_triggered.disconnect(on_ending)


## Prestige ending: balance=1000, reputation_score=80 on day 30 triggers a success ending.
func test_prestige_ending() -> void:
	_seed_stats({
		"days_survived": 30.0,
		"final_cash": 1000.0,
		"cumulative_revenue": 1000.0,
		"max_reputation_tier": 4.0,
		"final_reputation_tier": 4.0,
		"owned_store_count_final": 1.0,
		"trigger_type_bankruptcy": 0.0,
	})

	var triggered_id: StringName = &""
	var triggered_stats: Dictionary = {}
	var on_ending: Callable = func(
		id: StringName, stats: Dictionary
	) -> void:
		triggered_id = id
		triggered_stats = stats
	EventBus.ending_triggered.connect(on_ending)

	EventBus.ending_requested.emit("completion")

	assert_eq(
		triggered_id,
		&"the_local_legend",
		"balance=1000, rep=80 (tier 4), day 30 should trigger the_local_legend"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAME_OVER,
		"GameManager must transition to GAME_OVER"
	)
	assert_true(
		_ending_evaluator.has_ending_been_shown(),
		"EndingEvaluatorSystem must mark ending as shown"
	)
	assert_eq(
		triggered_stats.get("max_reputation_tier", 0.0),
		4.0,
		"final_stats must reflect max_reputation_tier = 4.0"
	)

	EventBus.ending_triggered.disconnect(on_ending)


## day_ended on day 15 must NOT trigger ending evaluation.
func test_no_premature_trigger() -> void:
	_seed_stats({
		"days_survived": 15.0,
		"final_cash": 5000.0,
		"cumulative_revenue": 50000.0,
		"max_reputation_tier": 4.0,
		"owned_store_count_final": 5.0,
		"satisfaction_ratio": 0.95,
	})

	var fire_count: int = 0
	var on_ending: Callable = func(
		_id: StringName, _stats: Dictionary
	) -> void:
		fire_count += 1
	EventBus.ending_triggered.connect(on_ending)

	EventBus.day_ended.emit(15)

	assert_eq(
		fire_count, 0,
		"ending_triggered must NOT fire on day_ended alone"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAMEPLAY,
		"GameManager must remain in GAMEPLAY after day_ended on day 15"
	)
	assert_false(
		_ending_evaluator.has_ending_been_shown(),
		"Ending must not be shown after day_ended without ending_requested"
	)

	EventBus.ending_triggered.disconnect(on_ending)


## After ending_triggered, ending data from the catalog contains flavor_text and title.
func test_catalog_validation() -> void:
	_seed_stats({
		"days_survived": 30.0,
		"final_cash": -1.0,
	})

	var triggered_id: StringName = &""
	var on_ending: Callable = func(
		id: StringName, _stats: Dictionary
	) -> void:
		triggered_id = id
	EventBus.ending_triggered.connect(on_ending)

	EventBus.bankruptcy_declared.emit()

	assert_false(
		triggered_id.is_empty(),
		"An ending must have been triggered"
	)

	var ending_data: Dictionary = (
		_ending_evaluator.get_ending_data(triggered_id)
	)
	assert_false(
		ending_data.is_empty(),
		"Ending data must exist in catalog for %s" % triggered_id
	)
	assert_true(
		ending_data.has("title"),
		"Ending catalog entry must contain 'title'"
	)
	assert_true(
		ending_data.has("text"),
		"Ending catalog entry must contain 'text' (flavor text)"
	)

	var title: String = str(ending_data.get("title", ""))
	var text: String = str(ending_data.get("text", ""))
	assert_false(
		title.is_empty(),
		"Ending title must not be empty for %s" % triggered_id
	)
	assert_false(
		text.is_empty(),
		"Ending flavor text must not be empty for %s" % triggered_id
	)

	assert_eq(
		ending_data.get("id", ""),
		String(triggered_id),
		"Catalog entry id must match triggered ending_id"
	)

	EventBus.ending_triggered.disconnect(on_ending)


## Session stats shape { day, balance, reputation_score, stores_owned } validates correctly.
func test_session_stats_shape_valid() -> void:
	var valid_stats: Dictionary = _build_session_stats(
		30, 500.0, 40.0, 1
	)
	assert_true(
		_validate_session_stats_shape(valid_stats),
		"Valid session stats must pass shape validation"
	)
	assert_true(
		valid_stats.has("day"),
		"Session stats must contain 'day'"
	)
	assert_true(
		valid_stats.has("balance"),
		"Session stats must contain 'balance'"
	)
	assert_true(
		valid_stats.has("reputation_score"),
		"Session stats must contain 'reputation_score'"
	)
	assert_true(
		valid_stats.has("stores_owned"),
		"Session stats must contain 'stores_owned'"
	)


## Session stats with missing keys must trigger push_error, not crash.
func test_session_stats_shape_missing_keys() -> void:
	var incomplete: Dictionary = {"day": 30, "balance": 500.0}
	assert_false(
		_validate_session_stats_shape(incomplete),
		"Incomplete session stats must fail shape validation"
	)

	var empty_stats: Dictionary = {}
	assert_false(
		_validate_session_stats_shape(empty_stats),
		"Empty session stats must fail shape validation"
	)
