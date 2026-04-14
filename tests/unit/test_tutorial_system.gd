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
		TutorialSystem.TutorialStep.WALK_TO_STORE,
		"Step should advance from WELCOME to WALK_TO_STORE"
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

	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)
	_tutorial._movement_accumulated = TutorialSystem.MOVEMENT_THRESHOLD
	_tutorial._track_movement(0.01)
	EventBus.store_entered.emit(&"test_store")
	EventBus.panel_opened.emit("inventory")
	EventBus.item_stocked.emit("item_1", "shelf_1")
	EventBus.panel_opened.emit("pricing")
	EventBus.price_set.emit("item_1", 9.99)
	var mock_customer := Node.new()
	EventBus.customer_spawned.emit(mock_customer)
	mock_customer.queue_free()
	EventBus.customer_purchased.emit(&"", &"item_1", 9.99, &"")
	EventBus.day_ended.emit(1)

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

	EventBus.store_entered.emit(&"test_store")
	EventBus.panel_opened.emit("inventory")
	EventBus.item_stocked.emit("item_1", "shelf_1")
	EventBus.day_ended.emit(1)

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
		TutorialSystem.TutorialStep.WALK_TO_STORE,
		"Serialized step should be WALK_TO_STORE"
	)
	assert_false(
		data["tutorial_completed"] as bool,
		"tutorial_completed should be false mid-tutorial"
	)


func test_load_state_restores_step_and_completion() -> void:
	var save_data: Dictionary = {
		"tutorial_completed": true,
		"tutorial_active": false,
		"current_step": TutorialSystem.TutorialStep.FINISHED,
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


func test_load_state_restores_mid_tutorial() -> void:
	var save_data: Dictionary = {
		"tutorial_completed": false,
		"tutorial_active": true,
		"current_step": TutorialSystem.TutorialStep.OPEN_INVENTORY,
		"tips_shown": {},
	}

	_tutorial.load_save_data(save_data)

	assert_false(
		_tutorial.tutorial_completed,
		"tutorial_completed should be false"
	)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.OPEN_INVENTORY,
		"current_step should restore to OPEN_INVENTORY"
	)
	assert_true(
		_tutorial.tutorial_active,
		"Tutorial should be active for mid-tutorial state"
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

	_tutorial._movement_accumulated = TutorialSystem.MOVEMENT_THRESHOLD
	_tutorial._track_movement(0.01)

	EventBus.store_entered.emit(&"test_store")

	assert_eq(emitted_ids.size(), 3, "Three steps should have completed")
	assert_eq(emitted_ids[0], "welcome", "First: welcome")
	assert_eq(emitted_ids[1], "walk_to_store", "Second: walk_to_store")
	assert_eq(emitted_ids[2], "enter_store", "Third: enter_store")

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
		changed_ids.has("walk_to_store"),
		"tutorial_step_changed should emit walk_to_store after advancing"
	)

	EventBus.tutorial_step_changed.disconnect(on_changed)
