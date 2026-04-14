## Integration test — cash hits zero triggers full bankruptcy → GAME_OVER chain.
extends GutTest

const STARTING_CASH: float = 10.0
const DEDUCTION_AMOUNT: float = 15.0

## Bankruptcy-category ending IDs defined in ending_config.json.
const BANKRUPTCY_ENDINGS: Array[StringName] = [
	&"lights_out", &"foreclosure", &"going_going_gone",
]

var _economy: EconomySystem
var _ending_evaluator: EndingEvaluatorSystem
var _time: TimeSystem

var _saved_state: GameManager.GameState
var _saved_ending_id: StringName
var _saved_difficulty: StringName


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_ending_id = GameManager.get_ending_id()
	_saved_difficulty = DifficultySystemSingleton.get_current_tier_id()

	DifficultySystemSingleton.set_tier(&"normal")
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager._ending_id = &""

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.initialize()

	_ending_evaluator = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_evaluator)
	_ending_evaluator.initialize()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager._ending_id = _saved_ending_id
	DifficultySystemSingleton.set_tier(_saved_difficulty)


## Full chain: deduction past zero → bankruptcy_declared (once) → ending_triggered → GAME_OVER.
func test_deduction_below_zero_triggers_full_bankruptcy_chain() -> void:
	watch_signals(EventBus)

	_economy.force_deduct_cash(DEDUCTION_AMOUNT, "test rent")

	assert_signal_emit_count(
		EventBus, "bankruptcy_declared", 1,
		"bankruptcy_declared should fire exactly once when cash drops below zero"
	)
	assert_signal_emitted(
		EventBus, "ending_triggered",
		"ending_triggered should fire as part of the bankruptcy chain"
	)
	assert_eq(
		GameManager.current_state, GameManager.GameState.GAME_OVER,
		"GameManager should transition to GAME_OVER after bankruptcy chain"
	)
	assert_true(
		_ending_evaluator.has_ending_been_shown(),
		"EndingEvaluatorSystem should mark the ending as shown after bankruptcy"
	)


## ending_triggered must carry a bankruptcy-category ending_id and non-empty stats.
func test_ending_triggered_carries_bankruptcy_ending_id() -> void:
	watch_signals(EventBus)

	_economy.force_deduct_cash(DEDUCTION_AMOUNT, "test rent")

	assert_signal_emitted(EventBus, "ending_triggered")
	var params: Array = get_signal_parameters(EventBus, "ending_triggered", 0)
	assert_eq(
		params.size(), 2,
		"ending_triggered should have two parameters: ending_id and final_stats"
	)
	var ending_id: StringName = params[0] as StringName
	assert_true(
		ending_id in BANKRUPTCY_ENDINGS,
		"ending_triggered ending_id should be a bankruptcy-category ending, got: %s" % ending_id
	)
	var final_stats: Dictionary = params[1] as Dictionary
	assert_true(
		not final_stats.is_empty(),
		"ending_triggered final_stats should be non-empty"
	)


## TimeSystem must be paused after the GAME_OVER state is entered.
func test_time_paused_after_game_over() -> void:
	_economy.force_deduct_cash(DEDUCTION_AMOUNT, "test rent")

	assert_eq(
		GameManager.current_state, GameManager.GameState.GAME_OVER,
		"Precondition: GameManager must be GAME_OVER before checking pause"
	)
	assert_true(
		_time.is_paused(),
		"TimeSystem should be paused after GAME_OVER state entry"
	)


## Guard flag: a second deduction after bankruptcy must not re-emit bankruptcy_declared.
func test_second_deduction_does_not_re_emit_bankruptcy_declared() -> void:
	watch_signals(EventBus)

	_economy.force_deduct_cash(DEDUCTION_AMOUNT, "first deduction")
	_economy.force_deduct_cash(5.0, "second deduction")

	assert_signal_emit_count(
		EventBus, "bankruptcy_declared", 1,
		"Guard flag must prevent re-emission of bankruptcy_declared after first trigger"
	)


## cash = 10.0 and deduction = 15.0 → balance is -5.0 which is <= 0.0.
func test_economy_cash_is_negative_after_deduction() -> void:
	_economy.force_deduct_cash(DEDUCTION_AMOUNT, "test rent")

	assert_true(
		_economy.get_cash() <= 0.0,
		"Cash should be at or below zero after deduction exceeds starting balance"
	)


## Driving EconomySystem balance below zero emits EventBus.bankruptcy_declared.
func test_negative_balance_emits_bankruptcy_declared() -> void:
	watch_signals(EventBus)

	_economy.force_deduct_cash(DEDUCTION_AMOUNT, "test rent")

	assert_signal_emitted(
		EventBus, "bankruptcy_declared",
		"bankruptcy_declared must fire when cash drops below zero"
	)


## EndingEvaluatorSystem._on_bankruptcy_declared fires evaluate() exactly once,
## producing exactly one ending_triggered emission.
func test_bankruptcy_declared_calls_evaluate() -> void:
	watch_signals(EventBus)

	EventBus.bankruptcy_declared.emit()

	assert_signal_emit_count(
		EventBus, "ending_triggered", 1,
		"_on_bankruptcy_declared must trigger evaluate() exactly once"
	)


## evaluate() with bankruptcy context (trigger_type_bankruptcy=1.0) returns a
## bankruptcy-category ending ID.
func test_evaluate_selects_bankruptcy_ending() -> void:
	var save_data: Dictionary = _ending_evaluator.get_save_data()
	var stats: Dictionary = (save_data.get("stats", {}) as Dictionary).duplicate()
	stats["trigger_type_bankruptcy"] = 1.0
	stats["days_survived"] = 5.0
	save_data["stats"] = stats
	_ending_evaluator.load_state(save_data)

	var result: StringName = _ending_evaluator.evaluate()

	assert_true(
		result in BANKRUPTCY_ENDINGS,
		"evaluate() with bankruptcy context must return a bankruptcy-category ending; got: %s" % result
	)


## ending_triggered fires with a bankruptcy-category ending_id after bankruptcy_declared.
func test_ending_triggered_fires() -> void:
	watch_signals(EventBus)

	EventBus.bankruptcy_declared.emit()

	assert_signal_emitted(
		EventBus, "ending_triggered",
		"ending_triggered must fire after bankruptcy_declared"
	)
	var params: Array = get_signal_parameters(EventBus, "ending_triggered", 0)
	assert_eq(
		params.size(), 2,
		"ending_triggered must carry ending_id and final_stats"
	)
	var ending_id: StringName = params[0] as StringName
	assert_true(
		ending_id in BANKRUPTCY_ENDINGS,
		"ending_triggered ending_id must be a bankruptcy-category ending; got: %s" % ending_id
	)


## Emitting bankruptcy_declared twice does not produce a second ending_triggered emission.
func test_double_fire_guard() -> void:
	watch_signals(EventBus)

	EventBus.bankruptcy_declared.emit()
	EventBus.bankruptcy_declared.emit()

	assert_signal_emit_count(
		EventBus, "ending_triggered", 1,
		"Guard flag must prevent a second ending_triggered on repeated bankruptcy_declared"
	)


## The ending_id carried by ending_triggered exists as a defined entry in ending_config.json.
func test_bankruptcy_ending_id_matches_catalog() -> void:
	var captured_id: Array = [&""]
	var on_triggered: Callable = func(id: StringName, _stats: Dictionary) -> void:
		captured_id[0] = id
	EventBus.ending_triggered.connect(on_triggered)

	EventBus.bankruptcy_declared.emit()

	EventBus.ending_triggered.disconnect(on_triggered)

	var ending_data: Dictionary = _ending_evaluator.get_ending_data(captured_id[0])
	assert_false(
		ending_data.is_empty(),
		"Emitted ending_id '%s' must exist as a defined entry in ending_config.json" % captured_id[0]
	)
