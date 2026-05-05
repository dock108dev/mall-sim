## Integration test: TutorialSystem first-play flow — new_game through tutorial_completed.
extends GutTest

var _tutorial: TutorialSystem
var _saved_tutorial_active: bool


func before_each() -> void:
	_saved_tutorial_active = GameManager.is_tutorial_active
	_tutorial = TutorialSystem.new()
	add_child_autofree(_tutorial)


func after_each() -> void:
	GameManager.is_tutorial_active = _saved_tutorial_active


# --- New game start ---


func test_new_game_start_activates_tutorial_at_welcome() -> void:
	_tutorial.initialize(true)
	assert_true(
		_tutorial.tutorial_active,
		"Tutorial should be active after new game"
	)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WELCOME,
		"First step should be WELCOME"
	)
	assert_false(
		_tutorial.tutorial_completed,
		"Tutorial should not be marked completed at start"
	)


func test_after_welcome_step_platform_match_is_active() -> void:
	_tutorial.initialize(true)

	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.PLATFORM_MATCH,
		"After WELCOME expires, current step should be PLATFORM_MATCH"
	)
	var step_id: String = TutorialSystem.STEP_IDS[_tutorial.current_step]
	assert_eq(
		step_id, "platform_match",
		"Step ID for the platform-match milestone should be platform_match"
	)


# --- Step-by-step index advancement ---


func test_each_trigger_advances_step_index_by_one() -> void:
	_tutorial.initialize(true)

	var step: int = int(_tutorial.current_step)

	# WELCOME → PLATFORM_MATCH (welcome timer expires)
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after WELCOME timer expires"
	)

	# PLATFORM_MATCH → STOCK_SHELF
	EventBus.customer_platform_identified.emit(&"c1", &"ignite_go", true)
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after customer_platform_identified"
	)

	# STOCK_SHELF → CONDITION_RISK
	EventBus.item_stocked.emit("test_item", "shelf_1")
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after item_stocked"
	)

	# CONDITION_RISK → SPORTS_DEPRECIATION
	EventBus.trade_in_condition_graded.emit(&"used_cart_a", "good")
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after trade_in_condition_graded"
	)

	# SPORTS_DEPRECIATION → HOLD_PRESSURE
	EventBus.trade_in_price_confirmed.emit(&"field_blitz_07", 4.50)
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after trade_in_price_confirmed"
	)

	# HOLD_PRESSURE → HIDDEN_THREAD
	EventBus.hold_decision_made.emit(&"dungeon_frenzy_2", true)
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after hold_decision_made"
	)

	# HIDDEN_THREAD → CLOSE_DAY
	EventBus.hidden_clue_acknowledged.emit(&"void_protocols_red_label")
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after hidden_clue_acknowledged"
	)

	# CLOSE_DAY → DAY_SUMMARY (day_close_requested)
	EventBus.day_close_requested.emit()
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after day_close_requested"
	)

	# DAY_SUMMARY → FINISHED (day_acknowledged)
	EventBus.day_acknowledged.emit()
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.FINISHED,
		"Final trigger should land on FINISHED"
	)


# --- Completion state ---


func test_tutorial_completed_true_after_full_sequence() -> void:
	_drive_to_completion()
	assert_true(
		_tutorial.tutorial_completed,
		"tutorial_completed should be true after all steps complete"
	)


func test_tutorial_active_false_after_full_sequence() -> void:
	_drive_to_completion()
	assert_false(
		_tutorial.tutorial_active,
		"tutorial_active should be false after tutorial completes"
	)


func test_game_manager_flag_cleared_after_completion() -> void:
	_drive_to_completion()
	assert_false(
		GameManager.is_tutorial_active,
		"GameManager.is_tutorial_active should be false after tutorial completes"
	)


# --- Signal emission ---


func test_tutorial_completed_signal_emitted_exactly_once() -> void:
	_tutorial.initialize(true)

	var completed_count: Array = [0]
	var on_complete: Callable = func() -> void:
		completed_count[0] += 1
	EventBus.tutorial_completed.connect(on_complete)

	_drive_full_sequence()

	# Emit triggers again — must not fire tutorial_completed a second time.
	EventBus.customer_platform_identified.emit(&"c1", &"ignite_go", true)
	EventBus.item_stocked.emit("test_item", "shelf_1")
	EventBus.day_acknowledged.emit()

	assert_eq(
		completed_count[0], 1,
		"tutorial_completed signal should fire exactly once"
	)

	EventBus.tutorial_completed.disconnect(on_complete)


func test_no_tutorial_signals_after_completion() -> void:
	_drive_to_completion()

	var signals_fired: Array = [0]
	var on_step_changed: Callable = func(_id: String) -> void:
		signals_fired[0] += 1
	var on_step_completed: Callable = func(_id: String) -> void:
		signals_fired[0] += 1
	var on_completed: Callable = func() -> void:
		signals_fired[0] += 1

	EventBus.tutorial_step_changed.connect(on_step_changed)
	EventBus.tutorial_step_completed.connect(on_step_completed)
	EventBus.tutorial_completed.connect(on_completed)

	EventBus.customer_platform_identified.emit(&"c1", &"ignite_go", true)
	EventBus.item_stocked.emit("test_item", "shelf_1")
	EventBus.day_acknowledged.emit()

	assert_eq(
		signals_fired[0], 0,
		"No tutorial signals should fire after tutorial_completed is true"
	)

	EventBus.tutorial_step_changed.disconnect(on_step_changed)
	EventBus.tutorial_step_completed.disconnect(on_step_completed)
	EventBus.tutorial_completed.disconnect(on_completed)


func test_step_completed_signal_fires_for_each_step() -> void:
	_tutorial.initialize(true)

	var completed_ids: Array[String] = []
	var on_step_completed: Callable = func(id: String) -> void:
		completed_ids.append(id)
	EventBus.tutorial_step_completed.connect(on_step_completed)

	_drive_full_sequence()

	assert_eq(
		completed_ids.size(),
		TutorialSystem.TutorialStep.FINISHED,
		"tutorial_step_completed should fire once per non-FINISHED step"
	)
	assert_eq(completed_ids[0], "welcome", "Step 0 completed: welcome")
	assert_eq(
		completed_ids[1], "platform_match",
		"Step 1 completed: platform_match"
	)
	assert_eq(
		completed_ids[2], "stock_shelf",
		"Step 2 completed: stock_shelf"
	)
	assert_eq(
		completed_ids[3], "condition_risk",
		"Step 3 completed: condition_risk"
	)
	assert_eq(
		completed_ids[4], "sports_depreciation",
		"Step 4 completed: sports_depreciation"
	)
	assert_eq(
		completed_ids[5], "hold_pressure",
		"Step 5 completed: hold_pressure"
	)
	assert_eq(
		completed_ids[6], "hidden_thread",
		"Step 6 completed: hidden_thread"
	)
	assert_eq(
		completed_ids[7], "close_day",
		"Step 7 completed: close_day"
	)
	assert_eq(
		completed_ids[8], "day_summary",
		"Step 8 completed: day_summary"
	)

	EventBus.tutorial_step_completed.disconnect(on_step_completed)


# --- Helpers ---


func _drive_full_sequence() -> void:
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)
	EventBus.customer_platform_identified.emit(&"c1", &"ignite_go", true)
	EventBus.item_stocked.emit("test_item", "shelf_1")
	EventBus.trade_in_condition_graded.emit(&"used_cart_a", "good")
	EventBus.trade_in_price_confirmed.emit(&"field_blitz_07", 4.50)
	EventBus.hold_decision_made.emit(&"dungeon_frenzy_2", true)
	EventBus.hidden_clue_acknowledged.emit(&"void_protocols_red_label")
	EventBus.day_close_requested.emit()
	EventBus.day_acknowledged.emit()


func _drive_to_completion() -> void:
	_tutorial.initialize(true)
	_drive_full_sequence()
