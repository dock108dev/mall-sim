## Tests for TutorialSystem step progression, skip, persistence, and tips.
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


func test_initialize_new_game_activates_tutorial() -> void:
	_tutorial.initialize(true)
	assert_true(
		_tutorial.tutorial_active,
		"Tutorial should be active after initialize with new game"
	)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WELCOME,
		"Initial step should be WELCOME"
	)


func test_step_progression_welcome_to_walk() -> void:
	_tutorial.initialize(true)
	var step_changed_id: String = ""
	var on_step: Callable = func(id: String) -> void:
		step_changed_id = id
	EventBus.tutorial_step_changed.connect(on_step)

	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WALK_TO_STORE,
		"Step should advance to WALK_TO_STORE after welcome timer"
	)
	assert_eq(
		step_changed_id, "walk_to_store",
		"tutorial_step_changed should emit with walk_to_store"
	)
	EventBus.tutorial_step_changed.disconnect(on_step)


func test_step_progression_through_three_steps() -> void:
	_tutorial.initialize(true)
	var completed_steps: Array[String] = []
	var on_completed: Callable = func(id: String) -> void:
		completed_steps.append(id)
	EventBus.tutorial_step_completed.connect(on_completed)

	# WELCOME -> WALK_TO_STORE (timer expires)
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WALK_TO_STORE,
		"Should be on WALK_TO_STORE"
	)

	# WALK_TO_STORE -> ENTER_STORE (simulate movement threshold)
	_tutorial._movement_accumulated = TutorialSystem.MOVEMENT_THRESHOLD
	_tutorial._track_movement(0.01)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.ENTER_STORE,
		"Should be on ENTER_STORE"
	)

	# ENTER_STORE -> OPEN_INVENTORY (store entered signal)
	EventBus.store_entered.emit(&"test_store")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.OPEN_INVENTORY,
		"Should be on OPEN_INVENTORY"
	)

	assert_eq(
		completed_steps.size(), 3,
		"Three steps should have been completed"
	)
	assert_eq(completed_steps[0], "welcome", "First completed: welcome")
	assert_eq(
		completed_steps[1], "walk_to_store",
		"Second completed: walk_to_store"
	)
	assert_eq(
		completed_steps[2], "enter_store",
		"Third completed: enter_store"
	)

	EventBus.tutorial_step_completed.disconnect(on_completed)


func test_full_step_progression_to_completion() -> void:
	_tutorial.initialize(true)
	var tutorial_completed_fired: bool = false
	var on_complete: Callable = func() -> void:
		tutorial_completed_fired = true
	EventBus.tutorial_completed.connect(on_complete)

	# WELCOME -> WALK_TO_STORE
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)

	# WALK_TO_STORE -> ENTER_STORE
	_tutorial._movement_accumulated = TutorialSystem.MOVEMENT_THRESHOLD
	_tutorial._track_movement(0.01)

	# ENTER_STORE -> OPEN_INVENTORY
	EventBus.store_entered.emit(&"test_store")

	# OPEN_INVENTORY -> PLACE_ITEM
	EventBus.panel_opened.emit("inventory")

	# PLACE_ITEM -> OPEN_PRICING
	EventBus.item_stocked.emit("item_1", "shelf_1")

	# OPEN_PRICING -> SET_PRICE
	EventBus.panel_opened.emit("pricing")

	# SET_PRICE -> WAIT_FOR_CUSTOMER
	EventBus.price_set.emit("item_1", 9.99)

	# WAIT_FOR_CUSTOMER -> SALE_COMPLETED
	var mock_customer := Node.new()
	EventBus.customer_spawned.emit(mock_customer)
	mock_customer.queue_free()

	# SALE_COMPLETED -> END_OF_DAY
	EventBus.customer_purchased.emit(&"", &"item_1", 9.99, &"")

	# END_OF_DAY -> FINISHED
	EventBus.day_ended.emit(1)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.FINISHED,
		"Should reach FINISHED step"
	)
	assert_false(
		_tutorial.tutorial_active,
		"Tutorial should no longer be active"
	)
	assert_true(
		_tutorial.tutorial_completed,
		"Tutorial should be marked completed"
	)
	assert_true(
		tutorial_completed_fired,
		"tutorial_completed signal should have fired"
	)

	EventBus.tutorial_completed.disconnect(on_complete)


func test_wrong_signal_does_not_advance_step() -> void:
	_tutorial.initialize(true)
	# Advance past WELCOME
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)

	# Advance past WALK_TO_STORE
	_tutorial._movement_accumulated = TutorialSystem.MOVEMENT_THRESHOLD
	_tutorial._track_movement(0.01)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.ENTER_STORE,
		"Should be on ENTER_STORE"
	)

	# Emit item_stocked while on ENTER_STORE — should not advance
	EventBus.item_stocked.emit("item_1", "shelf_1")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.ENTER_STORE,
		"Should still be on ENTER_STORE after wrong signal"
	)


func test_ten_steps_defined() -> void:
	var step_count: int = TutorialSystem.TutorialStep.FINISHED
	assert_eq(
		step_count, 10,
		"There should be exactly 10 tutorial steps (FINISHED = 10)"
	)


# --- Skip tutorial ---


func test_skip_tutorial_prevents_further_progression() -> void:
	_tutorial.initialize(true)
	assert_true(_tutorial.tutorial_active, "Tutorial should be active before skip")

	var skipped_fired: bool = false
	var on_skip: Callable = func() -> void:
		skipped_fired = true
	EventBus.tutorial_skipped.connect(on_skip)

	_tutorial.skip_tutorial()

	assert_false(
		_tutorial.tutorial_active,
		"Tutorial should not be active after skip"
	)
	assert_true(
		_tutorial.tutorial_completed,
		"Tutorial should be marked completed after skip"
	)
	assert_true(
		skipped_fired,
		"tutorial_skipped signal should have fired"
	)
	assert_false(
		GameManager.is_tutorial_active,
		"GameManager.is_tutorial_active should be false after skip"
	)

	EventBus.tutorial_skipped.disconnect(on_skip)


func test_skip_flag_prevents_tutorial_from_starting() -> void:
	_tutorial.tutorial_completed = true
	var started_fired: bool = false
	var on_step: Callable = func(_id: String) -> void:
		started_fired = true
	EventBus.tutorial_step_changed.connect(on_step)

	_tutorial.initialize(true)

	assert_true(
		_tutorial.tutorial_active,
		"New game should always start tutorial even if previously completed"
	)

	EventBus.tutorial_step_changed.disconnect(on_step)


func test_initialize_not_new_game_no_cfg_does_not_start() -> void:
	var started_fired: bool = false
	var on_step: Callable = func(_id: String) -> void:
		started_fired = true
	EventBus.tutorial_step_changed.connect(on_step)

	_tutorial.initialize(false)

	assert_false(
		_tutorial.tutorial_active,
		"Tutorial should not activate for non-new game without cfg"
	)
	assert_false(
		started_fired,
		"tutorial_step_changed should not fire for non-new game without cfg"
	)

	EventBus.tutorial_step_changed.disconnect(on_step)


func test_system_silent_after_completion() -> void:
	_tutorial.tutorial_completed = true
	_tutorial.tutorial_active = false
	_tutorial.current_step = TutorialSystem.TutorialStep.FINISHED

	var signals_fired: int = 0
	var on_step: Callable = func(_id: String) -> void:
		signals_fired += 1
	var on_completed: Callable = func() -> void:
		signals_fired += 1
	EventBus.tutorial_step_changed.connect(on_step)
	EventBus.tutorial_completed.connect(on_completed)

	EventBus.store_entered.emit(&"test_store")
	EventBus.panel_opened.emit("inventory")
	EventBus.item_stocked.emit("item_1", "shelf_1")

	assert_eq(
		signals_fired, 0,
		"No tutorial signals should fire after completion"
	)

	EventBus.tutorial_step_changed.disconnect(on_step)
	EventBus.tutorial_completed.disconnect(on_completed)


# --- Contextual tips ---


func test_contextual_tip_fires_once_per_trigger() -> void:
	_tutorial.tutorial_completed = true
	_tutorial._ensure_day_started_connected()

	var tip_texts: Array[String] = []
	var on_tip: Callable = func(text: String) -> void:
		tip_texts.append(text)
	EventBus.contextual_tip_requested.connect(on_tip)

	EventBus.day_started.emit(2)
	var first_count: int = tip_texts.size()
	assert_true(
		first_count >= 1,
		"At least one tip should fire on day 2"
	)

	EventBus.day_started.emit(2)
	assert_eq(
		tip_texts.size(), first_count,
		"Tip count should not increase on second day 2 emission"
	)

	EventBus.contextual_tip_requested.disconnect(on_tip)


func test_contextual_tip_day_3_fires_reputation_tip() -> void:
	_tutorial.tutorial_completed = true
	_tutorial._ensure_day_started_connected()

	var tip_texts: Array[String] = []
	var on_tip: Callable = func(text: String) -> void:
		tip_texts.append(text)
	EventBus.contextual_tip_requested.connect(on_tip)

	EventBus.day_started.emit(3)
	assert_eq(
		tip_texts.size(), 1,
		"Day 3 should fire exactly one immediate tip (reputation)"
	)

	EventBus.contextual_tip_requested.disconnect(on_tip)


func test_contextual_tip_does_not_fire_when_tutorial_incomplete() -> void:
	_tutorial.tutorial_completed = false
	_tutorial._ensure_day_started_connected()

	var tip_texts: Array[String] = []
	var on_tip: Callable = func(text: String) -> void:
		tip_texts.append(text)
	EventBus.contextual_tip_requested.connect(on_tip)

	EventBus.day_started.emit(2)
	assert_eq(
		tip_texts.size(), 0,
		"No tips should fire when tutorial is not completed"
	)

	EventBus.contextual_tip_requested.disconnect(on_tip)


func test_contextual_tip_does_not_fire_after_day_3() -> void:
	_tutorial.tutorial_completed = true
	_tutorial._ensure_day_started_connected()

	var tip_texts: Array[String] = []
	var on_tip: Callable = func(text: String) -> void:
		tip_texts.append(text)
	EventBus.contextual_tip_requested.connect(on_tip)

	EventBus.day_started.emit(4)
	assert_eq(
		tip_texts.size(), 0,
		"No tips should fire after CONTEXTUAL_TIP_DAYS"
	)

	EventBus.contextual_tip_requested.disconnect(on_tip)


# --- Save/load round-trip ---


func test_save_and_load_preserves_state() -> void:
	_tutorial.tutorial_completed = true
	_tutorial.current_step = TutorialSystem.TutorialStep.FINISHED
	_tutorial._tips_shown = {"ordering": true, "build_mode": true}

	var save_data: Dictionary = _tutorial.get_save_data()
	assert_true(
		save_data["tutorial_completed"] as bool,
		"Save data should show tutorial_completed"
	)

	var new_tutorial: TutorialSystem = TutorialSystem.new()
	add_child_autofree(new_tutorial)
	new_tutorial.load_save_data(save_data)

	assert_true(
		new_tutorial.tutorial_completed,
		"tutorial_completed should be restored"
	)
	assert_eq(
		new_tutorial.current_step,
		TutorialSystem.TutorialStep.FINISHED,
		"current_step should be FINISHED after load"
	)
	assert_true(
		new_tutorial._tips_shown.get("ordering", false) as bool,
		"ordering tip should be marked shown after load"
	)
	assert_true(
		new_tutorial._tips_shown.get("build_mode", false) as bool,
		"build_mode tip should be marked shown after load"
	)


func test_new_game_always_starts_at_step_zero() -> void:
	_tutorial.tutorial_completed = true
	_tutorial.current_step = TutorialSystem.TutorialStep.FINISHED

	_tutorial.initialize(true)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WELCOME,
		"New game should always start at WELCOME regardless of prior state"
	)
	assert_true(
		_tutorial.tutorial_active,
		"Tutorial should be active on new game"
	)
	assert_false(
		_tutorial.tutorial_completed,
		"tutorial_completed should be false on new game"
	)
