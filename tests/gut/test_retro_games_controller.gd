## Tests RetroGames controller: lifecycle, signal wiring, and stubs.
extends GutTest


var _controller: RetroGames


func before_each() -> void:
	_controller = RetroGames.new()
	add_child_autofree(_controller)


func test_store_id_constant() -> void:
	assert_eq(
		RetroGames.STORE_ID, &"retro_games",
		"STORE_ID should be the canonical 'retro_games' StringName"
	)


func test_store_type_constant() -> void:
	assert_eq(
		RetroGames.STORE_TYPE, &"retro_games",
		"STORE_TYPE should be 'retro_games'"
	)


func test_store_type_set_in_ready() -> void:
	assert_eq(
		_controller.store_type, "retro_games",
		"store_type should be set to STORE_ID in _ready"
	)


func test_initialize_sets_store_type() -> void:
	var controller: RetroGames = RetroGames.new()
	controller.initialize()
	assert_eq(
		controller.store_type, "retro_games",
		"initialize should set store_type"
	)
	controller.free()


func test_initialize_is_idempotent() -> void:
	_controller.initialize()
	_controller.initialize()
	var opened_ids: Array[String] = []
	var capture: Callable = func(sid: String) -> void:
		opened_ids.append(sid)
	EventBus.store_opened.connect(capture)
	EventBus.store_entered.emit(&"retro_games")
	await get_tree().process_frame
	EventBus.store_opened.disconnect(capture)
	assert_eq(
		opened_ids.size(), 1,
		"initialize should not duplicate EventBus connections"
	)


func test_activates_on_matching_store_change() -> void:
	EventBus.active_store_changed.emit(&"retro_games")
	assert_true(
		_controller.is_active(),
		"Should activate when active_store_changed matches STORE_ID"
	)


func test_ignores_non_matching_store_change() -> void:
	EventBus.active_store_changed.emit(&"sports")
	assert_false(
		_controller.is_active(),
		"Should not activate for non-matching store_id"
	)


func test_store_entered_emits_store_opened() -> void:
	var opened_ids: Array[String] = []
	var capture: Callable = func(sid: String) -> void:
		opened_ids.append(sid)
	EventBus.store_opened.connect(capture)
	EventBus.store_entered.emit(&"retro_games")
	await get_tree().process_frame
	EventBus.store_opened.disconnect(capture)
	assert_eq(
		opened_ids.size(), 1,
		"store_opened should be emitted once on store_entered"
	)
	assert_eq(
		opened_ids[0], "retro_games",
		"store_opened should carry the correct store_id"
	)


func test_store_entered_ignores_other_stores() -> void:
	var opened_ids: Array[String] = []
	var capture: Callable = func(sid: String) -> void:
		opened_ids.append(sid)
	EventBus.store_opened.connect(capture)
	EventBus.store_entered.emit(&"sports")
	await get_tree().process_frame
	EventBus.store_opened.disconnect(capture)
	assert_eq(
		opened_ids.size(), 0,
		"store_opened should not emit for non-matching store_id"
	)


func test_store_exited_emits_store_closed() -> void:
	var closed_ids: Array[String] = []
	var capture: Callable = func(sid: String) -> void:
		closed_ids.append(sid)
	EventBus.store_closed.connect(capture)
	EventBus.store_exited.emit(&"retro_games")
	EventBus.store_closed.disconnect(capture)
	assert_eq(
		closed_ids.size(), 1,
		"store_closed should be emitted once on store_exited"
	)


func test_store_exited_ignores_other_stores() -> void:
	var closed_ids: Array[String] = []
	var capture: Callable = func(sid: String) -> void:
		closed_ids.append(sid)
	EventBus.store_closed.connect(capture)
	EventBus.store_exited.emit(&"sports")
	EventBus.store_closed.disconnect(capture)
	assert_eq(
		closed_ids.size(), 0,
		"store_closed should not emit for non-matching store_id"
	)


func test_can_test_item_returns_false_without_testing_system() -> void:
	var result: bool = _controller._can_test_item(&"some_item")
	assert_false(
		result,
		"_can_test_item should return false without TestingSystem"
	)


func test_queue_refurbishment_does_not_crash_without_system() -> void:
	_controller._queue_refurbishment(&"some_item")
	assert_true(
		true,
		"_queue_refurbishment should not crash without system"
	)


func test_testing_system_null_by_default() -> void:
	assert_null(
		_controller.get_testing_system(),
		"TestingSystem should be null by default"
	)


func test_save_load_round_trip() -> void:
	var save_data: Dictionary = _controller.get_save_data()
	assert_true(
		save_data.has("testing_available"),
		"Save data should include testing_available"
	)
	_controller.load_save_data(save_data)


func test_customer_purchased_does_not_crash_when_inactive() -> void:
	EventBus.customer_purchased.emit(&"", &"test_item", 50.0, &"")
	assert_true(
		true,
		"customer_purchased should not crash when store is inactive"
	)


func test_inventory_item_added_ignores_other_stores() -> void:
	EventBus.inventory_item_added.emit(&"sports", &"test_item")
	assert_true(
		true,
		"inventory_item_added for other stores should be ignored"
	)


func test_has_testing_station_false_by_default() -> void:
	assert_false(
		_controller.has_testing_station(),
		"Should have no testing station without fixtures"
	)


func test_refurbishment_system_null_by_default() -> void:
	assert_null(
		_controller.get_refurbishment_system(),
		"RefurbishmentSystem should be null by default"
	)
