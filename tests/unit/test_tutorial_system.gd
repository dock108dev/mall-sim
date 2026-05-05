## Unit tests for TutorialSystem step progression, guard conditions, persistence, and signals.
extends GutTest


var _tutorial: TutorialSystem
var _saved_tutorial_active: bool


func before_each() -> void:
	_saved_tutorial_active = GameManager.is_tutorial_active
	_tutorial = TutorialSystem.new()
	add_child_autofree(_tutorial)


func after_each() -> void:
	GameManager.is_tutorial_active = _saved_tutorial_active


# --- Step progression ---


func test_get_current_step_returns_first_step_on_fresh_init() -> void:
	_tutorial.initialize(true)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WELCOME,
		"Fresh init should start at WELCOME"
	)
	var text: String = _tutorial.get_current_step_text()
	assert_false(
		text.is_empty(),
		"Step text should be non-empty for the first step"
	)


func test_advance_step_moves_forward_and_emits_step_completed() -> void:
	_tutorial.initialize(true)
	var completed_id: Array = [""]
	var on_completed: Callable = func(id: String) -> void:
		completed_id[0] = id
	EventBus.tutorial_step_completed.connect(on_completed)

	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.PLATFORM_MATCH,
		"Step should advance from WELCOME to PLATFORM_MATCH"
	)
	assert_eq(
		completed_id[0], "welcome",
		"tutorial_step_completed should emit with welcome step_id"
	)

	EventBus.tutorial_step_completed.disconnect(on_completed)


func test_advance_on_final_step_emits_tutorial_completed() -> void:
	_tutorial.initialize(true)
	var tutorial_done: Array = [false]
	var on_done: Callable = func() -> void:
		tutorial_done[0] = true
	EventBus.tutorial_completed.connect(on_done)

	_drive_full_sequence()

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.FINISHED,
		"Should reach FINISHED step"
	)
	assert_true(
		tutorial_done[0],
		"tutorial_completed signal should fire on final step"
	)
	assert_true(
		_tutorial.tutorial_completed,
		"tutorial_completed flag should be true"
	)

	EventBus.tutorial_completed.disconnect(on_done)


# --- Guard conditions ---


func test_advance_after_completion_is_noop() -> void:
	_tutorial.tutorial_completed = true
	_tutorial.tutorial_active = false
	_tutorial.current_step = TutorialSystem.TutorialStep.FINISHED

	var signals_fired: Array = [0]
	var on_step: Callable = func(_id: String) -> void:
		signals_fired[0] += 1
	var on_completed: Callable = func(_id: String) -> void:
		signals_fired[0] += 1
	var on_done: Callable = func() -> void:
		signals_fired[0] += 1
	EventBus.tutorial_step_changed.connect(on_step)
	EventBus.tutorial_step_completed.connect(on_completed)
	EventBus.tutorial_completed.connect(on_done)

	EventBus.customer_platform_identified.emit(
		&"c1", &"ignite_go", true
	)
	EventBus.item_stocked.emit("item_1", "shelf_1")
	EventBus.day_close_requested.emit()

	assert_eq(
		signals_fired[0], 0,
		"No tutorial signals should fire after completion"
	)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.FINISHED,
		"Step index should not change after completion"
	)

	EventBus.tutorial_step_changed.disconnect(on_step)
	EventBus.tutorial_step_completed.disconnect(on_completed)
	EventBus.tutorial_completed.disconnect(on_done)


func test_get_current_step_text_returns_empty_after_completion() -> void:
	_tutorial.tutorial_completed = true
	_tutorial.tutorial_active = false
	_tutorial.current_step = TutorialSystem.TutorialStep.FINISHED

	var text: String = _tutorial.get_current_step_text()
	assert_eq(
		text, "",
		"Step text should be empty string after tutorial is complete"
	)


# --- Persistence ---


func test_save_state_serializes_step_and_completion() -> void:
	_tutorial.initialize(true)
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)

	var data: Dictionary = _tutorial.get_save_data()

	assert_true(
		data.has("current_step"),
		"Save data must contain current_step"
	)
	assert_true(
		data.has("tutorial_completed"),
		"Save data must contain tutorial_completed"
	)
	assert_eq(
		int(data["current_step"]),
		TutorialSystem.TutorialStep.PLATFORM_MATCH,
		"Serialized step should be PLATFORM_MATCH"
	)
	assert_false(
		data["tutorial_completed"] as bool,
		"tutorial_completed should be false mid-tutorial"
	)
	var completed_steps: Dictionary = data.get("completed_steps", {})
	assert_true(
		completed_steps.get("welcome", false) as bool,
		"Serialized state should include completed welcome step"
	)


func test_load_state_restores_step_and_completion() -> void:
	var save_data: Dictionary = {
		"tutorial_completed": true,
		"tutorial_active": false,
		"current_step": TutorialSystem.TutorialStep.FINISHED,
		"completed_steps": {"welcome": true},
		"tips_shown": {"ordering": true, "build_mode": true},
	}

	_tutorial.load_save_data(save_data)

	assert_true(
		_tutorial.tutorial_completed,
		"tutorial_completed should be restored to true"
	)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.FINISHED,
		"current_step should be restored to FINISHED"
	)
	assert_false(
		_tutorial.tutorial_active,
		"Tutorial should not be active after loading completed state"
	)
	assert_true(
		_tutorial._completed_steps.get("welcome", false) as bool,
		"Completed step IDs should be restored"
	)


func test_load_state_restores_mid_tutorial() -> void:
	var save_data: Dictionary = {
		"tutorial_completed": false,
		"tutorial_active": true,
		"current_step": TutorialSystem.TutorialStep.PLATFORM_MATCH,
		"completed_steps": {
			"welcome": true,
		},
		"tips_shown": {},
	}

	_tutorial.load_save_data(save_data)

	assert_false(
		_tutorial.tutorial_completed,
		"tutorial_completed should be false"
	)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.PLATFORM_MATCH,
		"current_step should restore to PLATFORM_MATCH"
	)
	assert_true(
		_tutorial.tutorial_active,
		"Tutorial should be active for mid-tutorial state"
	)
	assert_true(
		_tutorial._completed_steps.get("welcome", false) as bool,
		"Mid-tutorial completed step IDs should be restored"
	)


func test_load_state_resumes_last_incomplete_step() -> void:
	var save_data: Dictionary = {
		"tutorial_completed": false,
		"tutorial_active": true,
		"current_step": TutorialSystem.TutorialStep.WELCOME,
		"completed_steps": {
			"welcome": true,
			"platform_match": true,
		},
		"tips_shown": {},
	}

	_tutorial.load_save_data(save_data)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.STOCK_SHELF,
		"Loaded progress should resume at the first incomplete step"
	)


# --- Signal contracts ---


func test_eventbus_step_completed_has_correct_step_id() -> void:
	_tutorial.initialize(true)
	var emitted_ids: Array[String] = []
	var on_completed: Callable = func(id: String) -> void:
		emitted_ids.append(id)
	EventBus.tutorial_step_completed.connect(on_completed)

	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)

	EventBus.customer_platform_identified.emit(&"c1", &"ignite_go", true)

	assert_eq(emitted_ids.size(), 2, "Two steps should have completed")
	assert_eq(emitted_ids[0], "welcome", "First: welcome")
	assert_eq(emitted_ids[1], "platform_match", "Second: platform_match")

	EventBus.tutorial_step_completed.disconnect(on_completed)


func test_eventbus_step_changed_emits_new_step_id() -> void:
	_tutorial.initialize(true)
	var changed_ids: Array[String] = []
	var on_changed: Callable = func(id: String) -> void:
		changed_ids.append(id)
	EventBus.tutorial_step_changed.connect(on_changed)

	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)

	assert_true(
		changed_ids.has("platform_match"),
		"tutorial_step_changed should emit platform_match after advancing"
	)

	EventBus.tutorial_step_changed.disconnect(on_changed)


# --- Per-beat trigger gates ---


func test_platform_identified_advances_only_at_platform_match() -> void:
	_tutorial.initialize(true)
	# Drive past WELCOME so PLATFORM_MATCH is the active step.
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)

	# Item-stocked must not advance PLATFORM_MATCH.
	EventBus.item_stocked.emit("item_1", "shelf_1")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.PLATFORM_MATCH,
		"Non-platform signals must not advance PLATFORM_MATCH"
	)

	EventBus.customer_platform_identified.emit(&"c1", &"ignite_go", true)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.STOCK_SHELF,
		"customer_platform_identified should advance PLATFORM_MATCH → STOCK_SHELF"
	)


func test_platform_match_advances_on_wrong_choice_too() -> void:
	_drive_to_platform_match()
	# A wrong selection still advances — the beat is engagement-gated, not
	# correctness-gated; the dialogue handles the correction-then-retry UX.
	EventBus.customer_platform_identified.emit(&"c1", &"canopy_wave", false)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.STOCK_SHELF,
		"Wrong platform selection must still advance the beat"
	)


func test_item_stocked_advances_stock_shelf() -> void:
	_drive_to_stock_shelf()
	EventBus.item_stocked.emit("item_1", "shelf_1")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.CONDITION_RISK,
		"item_stocked should advance STOCK_SHELF → CONDITION_RISK"
	)


func test_condition_graded_advances_condition_risk_on_any_grade() -> void:
	_drive_to_condition_risk()
	# Any grade advances — the beat trains awareness, not accuracy.
	EventBus.trade_in_condition_graded.emit(&"item_1", "poor")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.SPORTS_DEPRECIATION,
		"trade_in_condition_graded should advance CONDITION_RISK → SPORTS_DEPRECIATION"
	)


func test_price_confirmed_advances_sports_depreciation() -> void:
	_drive_to_sports_depreciation()
	EventBus.trade_in_price_confirmed.emit(&"field_blitz_07", 4.50)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.HOLD_PRESSURE,
		"trade_in_price_confirmed should advance SPORTS_DEPRECIATION → HOLD_PRESSURE"
	)


func test_hold_decision_advances_hold_pressure_either_way() -> void:
	_drive_to_hold_pressure()
	# Honor or deny — both advance, so the beat does not block on a "right" answer.
	EventBus.hold_decision_made.emit(&"dungeon_frenzy_2", false)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.HIDDEN_THREAD,
		"hold_decision_made should advance HOLD_PRESSURE → HIDDEN_THREAD"
	)


func test_hidden_clue_acknowledged_advances_hidden_thread() -> void:
	_drive_to_hidden_thread()
	EventBus.hidden_clue_acknowledged.emit(&"void_protocols_red_label")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.CLOSE_DAY,
		"hidden_clue_acknowledged should advance HIDDEN_THREAD → CLOSE_DAY"
	)


# --- Helpers ---


func _drive_to_platform_match() -> void:
	_tutorial.initialize(true)
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)


func _drive_to_stock_shelf() -> void:
	_drive_to_platform_match()
	EventBus.customer_platform_identified.emit(&"c1", &"ignite_go", true)


func _drive_to_condition_risk() -> void:
	_drive_to_stock_shelf()
	EventBus.item_stocked.emit("item_1", "shelf_1")


func _drive_to_sports_depreciation() -> void:
	_drive_to_condition_risk()
	EventBus.trade_in_condition_graded.emit(&"item_1", "good")


func _drive_to_hold_pressure() -> void:
	_drive_to_sports_depreciation()
	EventBus.trade_in_price_confirmed.emit(&"field_blitz_07", 4.50)


func _drive_to_hidden_thread() -> void:
	_drive_to_hold_pressure()
	EventBus.hold_decision_made.emit(&"dungeon_frenzy_2", true)


func _drive_to_close_day() -> void:
	_drive_to_hidden_thread()
	EventBus.hidden_clue_acknowledged.emit(&"void_protocols_red_label")


func _drive_full_sequence() -> void:
	_drive_to_close_day()
	EventBus.day_close_requested.emit()
	EventBus.day_acknowledged.emit()
