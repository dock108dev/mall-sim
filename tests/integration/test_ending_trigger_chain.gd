## Integration test: ending_triggered → GameManager game_over transition → correct ending_id.
extends GutTest


var _time: TimeSystem
var _ending_evaluator: EndingEvaluatorSystem
var _save_manager: SaveManager

var _saved_state: GameManager.State
var _saved_ending_id: StringName


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_ending_id = GameManager.get_ending_id()

	GameManager.current_state = GameManager.State.GAMEPLAY
	GameManager._ending_id = &""

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.initialize()

	_ending_evaluator = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_evaluator)
	_ending_evaluator.initialize()

	_save_manager = SaveManager.new()
	add_child_autofree(_save_manager)
	_save_manager.set_store_state_manager(null)


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager._ending_id = _saved_ending_id


## Scenario 1: Normal ending chain — ending_triggered transitions GameManager to GAME_OVER,
## records the ending_id, pauses TimeSystem, and calls SaveManager.mark_run_complete.
func test_normal_ending_chain() -> void:
	# Advance pending day so mark_run_complete's reset to -1 is detectable.
	EventBus.day_ended.emit(5)
	assert_eq(
		_save_manager._pending_auto_save_day, 5,
		"Pending save day should be 5 before ending fires"
	)

	EventBus.ending_triggered.emit(&"successful_exit", {})

	assert_eq(
		GameManager.current_state,
		GameManager.State.GAME_OVER,
		"GameManager should transition to GAME_OVER after ending_triggered"
	)
	assert_eq(
		GameManager.get_ending_id(),
		&"successful_exit",
		"GameManager should record the triggered ending_id"
	)
	assert_true(
		_time.is_paused(),
		"TimeSystem should be paused after ending_triggered fires"
	)
	assert_eq(
		_save_manager._pending_auto_save_day, -1,
		"SaveManager.mark_run_complete should reset pending save day to -1"
	)


## Scenario 2: Bankruptcy special case — bankruptcy_declared causes EndingEvaluatorSystem
## to process the ending and drive GameManager to GAME_OVER.
func test_bankruptcy_chain_reaches_game_over() -> void:
	EventBus.bankruptcy_declared.emit()

	assert_true(
		_ending_evaluator.has_ending_been_shown(),
		"EndingEvaluatorSystem should have processed the bankruptcy ending"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.State.GAME_OVER,
		"GameManager should be GAME_OVER after bankruptcy_declared chain completes"
	)
	assert_true(
		not GameManager.get_ending_id().is_empty(),
		"GameManager should have a non-empty ending_id after bankruptcy"
	)


## Scenario 3: A second ending_triggered emission is ignored once GAME_OVER is reached.
func test_duplicate_ending_ignored() -> void:
	EventBus.ending_triggered.emit(&"successful_exit", {})

	assert_eq(
		GameManager.current_state,
		GameManager.State.GAME_OVER,
		"GameManager should be GAME_OVER after first ending_triggered"
	)
	assert_eq(
		GameManager.get_ending_id(),
		&"successful_exit",
		"First ending_id should be recorded"
	)

	EventBus.ending_triggered.emit(&"second_ending", {})

	assert_eq(
		GameManager.get_ending_id(),
		&"successful_exit",
		"ending_id must not be overwritten by second emission when already GAME_OVER"
	)
	assert_eq(
		GameManager.current_state,
		GameManager.State.GAME_OVER,
		"State must remain GAME_OVER after duplicate emission"
	)


## Scenario 4: ending_triggered while in MAIN_MENU is silently ignored.
func test_ending_from_main_menu_ignored() -> void:
	GameManager.current_state = GameManager.State.MAIN_MENU

	EventBus.ending_triggered.emit(&"successful_exit", {})

	assert_eq(
		GameManager.current_state,
		GameManager.State.MAIN_MENU,
		"GameManager must remain in MAIN_MENU when ending_triggered fires from that state"
	)
	assert_eq(
		GameManager.get_ending_id(),
		&"",
		"ending_id must remain empty when ending_triggered is ignored in MAIN_MENU"
	)
