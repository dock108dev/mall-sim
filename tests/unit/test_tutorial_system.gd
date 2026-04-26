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
		TutorialSystem.TutorialStep.CLICK_STORE,
		"Step should advance from WELCOME to CLICK_STORE"
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
	EventBus.store_entered.emit(TutorialSystem.TUTORIAL_STORE_ID)
	EventBus.panel_opened.emit("inventory")
	EventBus.item_stocked.emit("item_1", "shelf_1")
	EventBus.price_set.emit("item_1", 9.99)
	EventBus.customer_purchased.emit(&"", &"item_1", 9.99, &"")
	EventBus.day_close_requested.emit()
	EventBus.day_acknowledged.emit()

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

	EventBus.store_entered.emit(TutorialSystem.TUTORIAL_STORE_ID)
	EventBus.panel_opened.emit("inventory")
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
		TutorialSystem.TutorialStep.CLICK_STORE,
		"Serialized step should be CLICK_STORE"
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
		"current_step": TutorialSystem.TutorialStep.OPEN_INVENTORY,
		"completed_steps": {
			"welcome": true,
			"click_store": true,
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
		TutorialSystem.TutorialStep.OPEN_INVENTORY,
		"current_step should restore to OPEN_INVENTORY"
	)
	assert_true(
		_tutorial.tutorial_active,
		"Tutorial should be active for mid-tutorial state"
	)
	assert_true(
		_tutorial._completed_steps.get("click_store", false) as bool,
		"Mid-tutorial completed step IDs should be restored"
	)


func test_load_state_resumes_last_incomplete_step() -> void:
	var save_data: Dictionary = {
		"tutorial_completed": false,
		"tutorial_active": true,
		"current_step": TutorialSystem.TutorialStep.WELCOME,
		"completed_steps": {
			"welcome": true,
			"click_store": true,
		},
		"tips_shown": {},
	}

	_tutorial.load_save_data(save_data)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.OPEN_INVENTORY,
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

	EventBus.store_entered.emit(TutorialSystem.TUTORIAL_STORE_ID)

	assert_eq(emitted_ids.size(), 2, "Two steps should have completed")
	assert_eq(emitted_ids[0], "welcome", "First: welcome")
	assert_eq(emitted_ids[1], "click_store", "Second: click_store")

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
		changed_ids.has("click_store"),
		"tutorial_step_changed should emit click_store after advancing"
	)

	EventBus.tutorial_step_changed.disconnect(on_changed)


func test_click_store_ignores_non_retro_games_store() -> void:
	_tutorial.initialize(true)
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.CLICK_STORE,
		"Should be on CLICK_STORE after WELCOME"
	)

	EventBus.store_entered.emit(&"electronics")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.CLICK_STORE,
		"Non-retro_games store entry should not advance CLICK_STORE"
	)

	EventBus.store_entered.emit(TutorialSystem.TUTORIAL_STORE_ID)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.OPEN_INVENTORY,
		"retro_games entry should advance to OPEN_INVENTORY"
	)


# --- ISSUE-010: SET_PRICE grace-timer auto-advance ---


func _drive_to_place_item_step() -> void:
	_tutorial.initialize(true)
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)
	EventBus.store_entered.emit(TutorialSystem.TUTORIAL_STORE_ID)
	EventBus.panel_opened.emit("inventory")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.PLACE_ITEM,
		"Pre-condition: should be at PLACE_ITEM"
	)


func test_item_stocked_arms_set_price_grace_timer() -> void:
	_drive_to_place_item_step()
	EventBus.item_stocked.emit("item_1", "shelf_1")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.SET_PRICE,
		"item_stocked should advance PLACE_ITEM → SET_PRICE"
	)
	assert_not_null(
		_tutorial._set_price_grace_timer,
		"Grace timer should be armed at PLACE_ITEM → SET_PRICE transition"
	)


func test_set_price_grace_timeout_advances_to_wait_for_customer() -> void:
	_drive_to_place_item_step()
	EventBus.item_stocked.emit("item_1", "shelf_1")
	var armed_timer: SceneTreeTimer = _tutorial._set_price_grace_timer

	_tutorial._on_set_price_grace_timeout(armed_timer)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WAIT_FOR_CUSTOMER,
		"Grace timeout should advance SET_PRICE → WAIT_FOR_CUSTOMER"
	)
	assert_null(
		_tutorial._set_price_grace_timer,
		"Grace timer reference should clear after timeout fires"
	)


func test_price_set_fast_path_clears_grace_timer_no_double_advance() -> void:
	_drive_to_place_item_step()
	EventBus.item_stocked.emit("item_1", "shelf_1")
	var armed_timer: SceneTreeTimer = _tutorial._set_price_grace_timer
	assert_not_null(armed_timer, "Grace timer should be armed")

	EventBus.price_set.emit("item_1", 9.99)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WAIT_FOR_CUSTOMER,
		"price_set fast path should advance SET_PRICE → WAIT_FOR_CUSTOMER"
	)
	assert_null(
		_tutorial._set_price_grace_timer,
		"price_set should clear the grace timer reference"
	)

	# Late timeout from the now-stale timer must be a no-op.
	_tutorial._on_set_price_grace_timeout(armed_timer)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WAIT_FOR_CUSTOMER,
		"Stale grace timeout must not double-advance past WAIT_FOR_CUSTOMER"
	)


func test_grace_timeout_does_not_fire_after_completion() -> void:
	_drive_to_place_item_step()
	EventBus.item_stocked.emit("item_1", "shelf_1")
	var armed_timer: SceneTreeTimer = _tutorial._set_price_grace_timer

	_tutorial.skip_tutorial()
	_tutorial._on_set_price_grace_timeout(armed_timer)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.FINISHED,
		"Skipped tutorial should remain FINISHED after a stale grace timeout"
	)
