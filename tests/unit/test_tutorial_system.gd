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
		TutorialSystem.TutorialStep.OPEN_INVENTORY,
		"Step should advance from WELCOME to OPEN_INVENTORY"
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

	EventBus.panel_opened.emit("inventory")
	EventBus.placement_mode_entered.emit()
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
		TutorialSystem.TutorialStep.OPEN_INVENTORY,
		"Serialized step should be OPEN_INVENTORY"
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
			"open_inventory": true,
		},
		"tips_shown": {},
	}

	_tutorial.load_save_data(save_data)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.SELECT_ITEM,
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

	EventBus.panel_opened.emit("inventory")

	assert_eq(emitted_ids.size(), 2, "Two steps should have completed")
	assert_eq(emitted_ids[0], "welcome", "First: welcome")
	assert_eq(emitted_ids[1], "open_inventory", "Second: open_inventory")

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
		changed_ids.has("open_inventory"),
		"tutorial_step_changed should emit open_inventory after advancing"
	)

	EventBus.tutorial_step_changed.disconnect(on_changed)


# --- Per-milestone trigger gates ---


func test_panel_opened_advances_only_at_open_inventory() -> void:
	_tutorial.initialize(true)
	# Drive past WELCOME so OPEN_INVENTORY is the active step.
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)

	# A non-inventory panel must not advance.
	EventBus.panel_opened.emit("orders")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.OPEN_INVENTORY,
		"Non-inventory panel must not advance OPEN_INVENTORY"
	)

	EventBus.panel_opened.emit("inventory")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.SELECT_ITEM,
		"inventory panel should advance OPEN_INVENTORY → SELECT_ITEM"
	)


func test_placement_mode_entered_advances_select_item() -> void:
	_drive_to_select_item()
	EventBus.placement_mode_entered.emit()
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.PLACE_ITEM,
		"placement_mode_entered should advance SELECT_ITEM → PLACE_ITEM"
	)


func test_item_stocked_advances_place_item() -> void:
	_drive_to_place_item()
	EventBus.item_stocked.emit("item_1", "shelf_1")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WAIT_FOR_CUSTOMER,
		"item_stocked should advance PLACE_ITEM → WAIT_FOR_CUSTOMER"
	)


func test_customer_entered_advances_wait_for_customer() -> void:
	_drive_to_wait_for_customer()
	EventBus.customer_entered.emit({"customer_id": "c1"})
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.CUSTOMER_BROWSING,
		"customer_entered should advance WAIT_FOR_CUSTOMER → CUSTOMER_BROWSING"
	)


func test_customer_ready_to_purchase_advances_at_checkout_step() -> void:
	_drive_to_customer_at_checkout()
	EventBus.customer_ready_to_purchase.emit({"customer_id": "c1"})
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.COMPLETE_SALE,
		"customer_ready_to_purchase should advance CUSTOMER_AT_CHECKOUT → COMPLETE_SALE"
	)


func test_customer_purchased_advances_complete_sale() -> void:
	_drive_to_complete_sale()
	EventBus.customer_purchased.emit(&"store", &"item_1", 9.99, &"c1")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.CLOSE_DAY,
		"customer_purchased should advance COMPLETE_SALE → CLOSE_DAY"
	)


# --- Helpers ---


func _drive_to_open_inventory() -> void:
	_tutorial.initialize(true)
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)


func _drive_to_select_item() -> void:
	_drive_to_open_inventory()
	EventBus.panel_opened.emit("inventory")


func _drive_to_place_item() -> void:
	_drive_to_select_item()
	EventBus.placement_mode_entered.emit()


func _drive_to_wait_for_customer() -> void:
	_drive_to_place_item()
	EventBus.item_stocked.emit("item_1", "shelf_1")


func _drive_to_customer_browsing() -> void:
	_drive_to_wait_for_customer()
	EventBus.customer_entered.emit({"customer_id": "c1"})


func _drive_to_customer_at_checkout() -> void:
	_drive_to_customer_browsing()
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	var def := ItemDefinition.new()
	def.id = "item_1"
	def.item_name = "Item 1"
	def.category = "games"
	def.base_price = 9.99
	def.rarity = "common"
	def.tags = PackedStringArray([])
	def.condition_range = PackedStringArray(["good"])
	var item: ItemInstance = ItemInstance.create_from_definition(def, "good")
	EventBus.customer_item_spotted.emit(customer, item)


func _drive_to_complete_sale() -> void:
	_drive_to_customer_at_checkout()
	EventBus.customer_ready_to_purchase.emit({"customer_id": "c1"})


func _drive_full_sequence() -> void:
	_drive_to_complete_sale()
	EventBus.customer_purchased.emit(&"store", &"item_1", 9.99, &"c1")
	EventBus.day_close_requested.emit()
	EventBus.day_acknowledged.emit()
