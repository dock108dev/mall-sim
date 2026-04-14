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


func test_after_welcome_step_movement_step_is_active() -> void:
	_tutorial.initialize(true)

	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WALK_TO_STORE,
		"After WELCOME expires, current step should be WALK_TO_STORE"
	)
	var step_id: String = TutorialSystem.STEP_IDS[_tutorial.current_step]
	assert_eq(
		step_id, "walk_to_store",
		"Movement step ID should be walk_to_store"
	)


# --- Step-by-step index advancement ---


func test_each_trigger_advances_step_index_by_one() -> void:
	_tutorial.initialize(true)

	var step: int = int(_tutorial.current_step)

	# WELCOME → WALK_TO_STORE (welcome timer expires)
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after WELCOME timer expires"
	)

	# WALK_TO_STORE → ENTER_STORE (player movement threshold met)
	_tutorial._movement_accumulated = TutorialSystem.MOVEMENT_THRESHOLD
	_tutorial._track_movement(0.01)
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after movement threshold met"
	)

	# ENTER_STORE → OPEN_INVENTORY (store_entered signal)
	EventBus.store_entered.emit(&"test_store")
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after store_entered"
	)

	# OPEN_INVENTORY → PLACE_ITEM (panel_opened "inventory")
	EventBus.panel_opened.emit("inventory")
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after panel_opened inventory"
	)

	# PLACE_ITEM → OPEN_PRICING (item_stocked)
	EventBus.item_stocked.emit("test_item", "shelf_1")
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after item_stocked"
	)

	# OPEN_PRICING → SET_PRICE (panel_opened "pricing")
	EventBus.panel_opened.emit("pricing")
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after panel_opened pricing"
	)

	# SET_PRICE → WAIT_FOR_CUSTOMER (price_set)
	EventBus.price_set.emit("test_item", 9.99)
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after price_set"
	)

	# WAIT_FOR_CUSTOMER → SALE_COMPLETED (customer_spawned)
	var mock_customer := Node.new()
	EventBus.customer_spawned.emit(mock_customer)
	mock_customer.queue_free()
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after customer_spawned"
	)

	# SALE_COMPLETED → END_OF_DAY (customer_purchased)
	EventBus.customer_purchased.emit(
		&"test_store", &"test_item", 9.99, &"customer_1"
	)
	step += 1
	assert_eq(
		int(_tutorial.current_step), step,
		"Step index should advance after customer_purchased"
	)

	# END_OF_DAY → FINISHED (day_ended)
	EventBus.day_ended.emit(1)
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

	var completed_count: int = 0
	var on_complete: Callable = func() -> void:
		completed_count += 1
	EventBus.tutorial_completed.connect(on_complete)

	_drive_full_sequence()

	# Emit triggers again — must not fire tutorial_completed a second time
	EventBus.store_entered.emit(&"test_store")
	EventBus.item_stocked.emit("test_item", "shelf_1")
	EventBus.customer_purchased.emit(
		&"test_store", &"test_item", 9.99, &"customer_1"
	)
	EventBus.day_ended.emit(2)

	assert_eq(
		completed_count, 1,
		"tutorial_completed signal should fire exactly once"
	)

	EventBus.tutorial_completed.disconnect(on_complete)


func test_no_tutorial_signals_after_completion() -> void:
	_drive_to_completion()

	var signals_fired: int = 0
	var on_step_changed: Callable = func(_id: String) -> void:
		signals_fired += 1
	var on_step_completed: Callable = func(_id: String) -> void:
		signals_fired += 1
	var on_completed: Callable = func() -> void:
		signals_fired += 1

	EventBus.tutorial_step_changed.connect(on_step_changed)
	EventBus.tutorial_step_completed.connect(on_step_completed)
	EventBus.tutorial_completed.connect(on_completed)

	EventBus.store_entered.emit(&"test_store")
	EventBus.item_stocked.emit("test_item", "shelf_1")
	EventBus.customer_purchased.emit(
		&"test_store", &"test_item", 9.99, &"customer_1"
	)
	EventBus.day_ended.emit(2)

	assert_eq(
		signals_fired, 0,
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
		completed_ids[1], "walk_to_store",
		"Step 1 completed: walk_to_store"
	)
	assert_eq(
		completed_ids[2], "enter_store",
		"Step 2 completed: enter_store"
	)
	assert_eq(
		completed_ids[3], "open_inventory",
		"Step 3 completed: open_inventory"
	)
	assert_eq(
		completed_ids[4], "place_item",
		"Step 4 completed: place_item"
	)
	assert_eq(
		completed_ids[5], "open_pricing",
		"Step 5 completed: open_pricing"
	)
	assert_eq(
		completed_ids[6], "set_price",
		"Step 6 completed: set_price"
	)
	assert_eq(
		completed_ids[7], "wait_for_customer",
		"Step 7 completed: wait_for_customer"
	)
	assert_eq(
		completed_ids[8], "sale_completed",
		"Step 8 completed: sale_completed"
	)
	assert_eq(
		completed_ids[9], "end_of_day",
		"Step 9 completed: end_of_day"
	)

	EventBus.tutorial_step_completed.disconnect(on_step_completed)


# --- Helpers ---


func _drive_full_sequence() -> void:
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)
	_tutorial._movement_accumulated = TutorialSystem.MOVEMENT_THRESHOLD
	_tutorial._track_movement(0.01)
	EventBus.store_entered.emit(&"test_store")
	EventBus.panel_opened.emit("inventory")
	EventBus.item_stocked.emit("test_item", "shelf_1")
	EventBus.panel_opened.emit("pricing")
	EventBus.price_set.emit("test_item", 9.99)
	var mock_customer := Node.new()
	EventBus.customer_spawned.emit(mock_customer)
	mock_customer.queue_free()
	EventBus.customer_purchased.emit(
		&"test_store", &"test_item", 9.99, &"customer_1"
	)
	EventBus.day_ended.emit(1)


func _drive_to_completion() -> void:
	_tutorial.initialize(true)
	_drive_full_sequence()
