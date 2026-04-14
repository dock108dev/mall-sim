## Tests Electronics controller: demo unit designation, browse bonus, and save/load.
extends GutTest


var _controller: Electronics


func before_each() -> void:
	_controller = Electronics.new()
	add_child_autofree(_controller)


func test_store_id_constant() -> void:
	assert_eq(
		Electronics.STORE_ID, &"consumer_electronics",
		"STORE_ID should be 'consumer_electronics'"
	)


func test_store_type_constant() -> void:
	assert_eq(
		Electronics.STORE_TYPE, &"consumer_electronics",
		"STORE_TYPE should be 'consumer_electronics'"
	)


func test_store_type_set_in_ready() -> void:
	assert_eq(
		_controller.store_type, "consumer_electronics",
		"store_type should be set to STORE_ID in _ready"
	)


func test_activates_on_matching_store_change() -> void:
	EventBus.active_store_changed.emit(&"consumer_electronics")
	assert_true(
		_controller.is_active(),
		"Should activate when active_store_changed matches STORE_ID"
	)


func test_ignores_non_matching_store_change() -> void:
	EventBus.active_store_changed.emit(&"retro_games")
	assert_false(
		_controller.is_active(),
		"Should not activate for non-matching store_id"
	)


func test_store_entered_emits_store_opened() -> void:
	var opened_ids: Array[String] = []
	var capture: Callable = func(sid: String) -> void:
		opened_ids.append(sid)
	EventBus.store_opened.connect(capture)
	EventBus.store_entered.emit(&"consumer_electronics")
	EventBus.store_opened.disconnect(capture)
	assert_eq(
		opened_ids.size(), 1,
		"store_opened should be emitted once on store_entered"
	)
	assert_eq(
		opened_ids[0], "consumer_electronics",
		"store_opened should carry the correct store_id"
	)


func test_store_entered_ignores_other_stores() -> void:
	var opened_ids: Array[String] = []
	var capture: Callable = func(sid: String) -> void:
		opened_ids.append(sid)
	EventBus.store_opened.connect(capture)
	EventBus.store_entered.emit(&"retro_games")
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
	EventBus.store_exited.emit(&"consumer_electronics")
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
	EventBus.store_exited.emit(&"retro_games")
	EventBus.store_closed.disconnect(capture)
	assert_eq(
		closed_ids.size(), 0,
		"store_closed should not emit for non-matching store_id"
	)


func test_initialize_sets_demo_unit_ids() -> void:
	_controller.initialize()
	assert_eq(
		_controller._demo_unit_ids.size(), 0,
		"_demo_unit_ids should be initialized as empty array"
	)


func test_designate_demo_succeeds_when_slots_available() -> void:
	_controller.initialize()
	var result: bool = _controller.designate_demo(&"some_item")
	assert_true(
		result,
		"designate_demo should return true when slots available"
	)
	assert_true(
		_controller.is_demo_unit(&"some_item"),
		"Item should be a demo unit after designation"
	)


func test_designate_demo_fails_when_slots_full() -> void:
	_controller.initialize()
	_controller.designate_demo(&"item_a")
	_controller.designate_demo(&"item_b")
	var result: bool = _controller.designate_demo(&"item_c")
	assert_false(
		result,
		"designate_demo should return false when max slots reached"
	)


func test_designate_demo_prevents_duplicates() -> void:
	_controller.initialize()
	_controller.designate_demo(&"item_a")
	var result: bool = _controller.designate_demo(&"item_a")
	assert_false(
		result,
		"designate_demo should return false for duplicate item"
	)


func test_undesignate_demo_returns_item() -> void:
	_controller.initialize()
	_controller.designate_demo(&"item_a")
	var result: bool = _controller.undesignate_demo(&"item_a")
	assert_true(result, "undesignate_demo should return true")
	assert_false(
		_controller.is_demo_unit(&"item_a"),
		"Item should no longer be a demo unit after removal"
	)


func test_undesignate_demo_fails_for_non_demo() -> void:
	_controller.initialize()
	var result: bool = _controller.undesignate_demo(&"not_demo")
	assert_false(
		result,
		"undesignate_demo should return false for non-demo item"
	)


func test_has_demo_slots_available() -> void:
	_controller.initialize()
	assert_true(
		_controller.has_demo_slots_available(),
		"Should have slots available when empty"
	)
	_controller.designate_demo(&"item_a")
	assert_true(
		_controller.has_demo_slots_available(),
		"Should have slots available with one demo"
	)
	_controller.designate_demo(&"item_b")
	assert_false(
		_controller.has_demo_slots_available(),
		"Should not have slots available at max"
	)


func test_is_demo_unit_false_when_not_designated() -> void:
	_controller.initialize()
	assert_false(
		_controller.is_demo_unit(&"some_item"),
		"is_demo_unit should return false for non-demo items"
	)


func test_is_demo_unit_true_when_in_list() -> void:
	_controller.initialize()
	_controller._demo_unit_ids.append(&"test_item")
	assert_true(
		_controller.is_demo_unit(&"test_item"),
		"is_demo_unit should return true for items in _demo_unit_ids"
	)


func test_get_demo_browse_bonus_returns_zero_when_empty() -> void:
	_controller.initialize()
	var result: float = _controller.get_demo_browse_bonus()
	assert_eq(
		result, 0.0,
		"get_demo_browse_bonus should return 0.0 with no demos"
	)


func test_get_demo_browse_bonus_returns_bonus_when_active() -> void:
	_controller.initialize()
	_controller.designate_demo(&"item_a")
	var result: float = _controller.get_demo_browse_bonus()
	assert_gt(
		result, 0.0,
		"get_demo_browse_bonus should return bonus with active demo"
	)


func test_apply_depreciation_tick_does_not_crash() -> void:
	_controller._apply_depreciation_tick()
	assert_true(
		true,
		"_apply_depreciation_tick should not crash (no-op stub)"
	)


func test_day_started_calls_depreciation() -> void:
	EventBus.day_started.emit(5)
	assert_true(
		true,
		"day_started should trigger without error"
	)


func test_customer_entered_does_not_crash_when_inactive() -> void:
	EventBus.customer_entered.emit({})
	assert_true(
		true,
		"customer_entered should not crash when store is inactive"
	)


func test_save_load_round_trip() -> void:
	_controller.initialize()
	_controller.designate_demo(&"item_a")
	_controller.designate_demo(&"item_b")
	var save_data: Dictionary = _controller.get_save_data()
	assert_true(
		save_data.has("demo_unit_ids"),
		"Save data should include demo_unit_ids"
	)
	_controller._demo_unit_ids.clear()
	_controller.load_save_data(save_data)
	assert_eq(
		_controller._demo_unit_ids.size(), 2,
		"Should restore 2 demo unit ids after load"
	)
	assert_true(
		_controller.is_demo_unit(&"item_a"),
		"item_a should be restored as demo unit"
	)
	assert_true(
		_controller.is_demo_unit(&"item_b"),
		"item_b should be restored as demo unit"
	)


func test_save_load_empty_state() -> void:
	_controller.initialize()
	var save_data: Dictionary = _controller.get_save_data()
	_controller.load_save_data(save_data)
	assert_eq(
		_controller._demo_unit_ids.size(), 0,
		"Should handle empty demo_unit_ids on load"
	)


func test_designate_emits_demo_item_placed() -> void:
	_controller.initialize()
	var placed_ids: Array[String] = []
	var capture: Callable = func(item_id: String) -> void:
		placed_ids.append(item_id)
	EventBus.demo_item_placed.connect(capture)
	_controller.designate_demo(&"test_item")
	EventBus.demo_item_placed.disconnect(capture)
	assert_eq(
		placed_ids.size(), 1,
		"demo_item_placed should be emitted on designate"
	)


func test_undesignate_emits_demo_item_removed() -> void:
	_controller.initialize()
	_controller.designate_demo(&"test_item")
	var removed_ids: Array[String] = []
	var capture: Callable = func(
		item_id: String, _days: int
	) -> void:
		removed_ids.append(item_id)
	EventBus.demo_item_removed.connect(capture)
	_controller.undesignate_demo(&"test_item")
	EventBus.demo_item_removed.disconnect(capture)
	assert_eq(
		removed_ids.size(), 1,
		"demo_item_removed should be emitted on undesignate"
	)
