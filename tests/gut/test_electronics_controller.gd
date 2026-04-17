## Tests the ISSUE-149 Electronics controller lifecycle wiring and stubs.
extends GutTest


var _controller: Electronics


func before_each() -> void:
	_ensure_consumer_electronics_content()
	_controller = Electronics.new()
	add_child_autofree(_controller)


func test_constants_match_consumer_electronics_store() -> void:
	assert_eq(Electronics.STORE_ID, &"consumer_electronics")
	assert_eq(Electronics.STORE_TYPE, &"consumer_electronics")


func test_initialize_sets_store_identity_and_demo_array() -> void:
	_controller.initialize()
	assert_eq(_controller.store_type, "consumer_electronics")
	assert_eq(_controller._demo_unit_ids.size(), 0)


func test_initialize_connects_issue_signals() -> void:
	assert_true(
		EventBus.active_store_changed.is_connected(
			_controller._on_active_store_changed
		)
	)
	assert_true(
		EventBus.day_started.is_connected(_controller._on_day_started)
	)
	assert_true(
		EventBus.customer_entered.is_connected(
			_controller._on_customer_entered
		)
	)


func test_designate_demo_is_stubbed_false() -> void:
	assert_false(_controller.designate_demo(&"demo_item"))
	assert_false(_controller.is_demo_unit(&"demo_item"))


func test_is_demo_unit_only_matches_tracked_ids() -> void:
	_controller._demo_unit_ids.append(&"tracked_item")
	assert_true(_controller.is_demo_unit(&"tracked_item"))
	assert_false(_controller.is_demo_unit(&"other_item"))


func test_get_demo_browse_bonus_is_stubbed_zero() -> void:
	assert_eq(_controller.get_demo_browse_bonus(), 0.0)


func test_matching_store_change_activates_controller() -> void:
	EventBus.active_store_changed.emit(&"consumer_electronics")
	assert_true(_controller.is_active())


func test_store_entered_emits_store_opened() -> void:
	var opened_ids: Array[String] = []
	var capture: Callable = func(store_id: String) -> void:
		opened_ids.append(store_id)
	EventBus.store_opened.connect(capture)
	EventBus.store_entered.emit(&"consumer_electronics")
	await get_tree().process_frame
	EventBus.store_opened.disconnect(capture)
	assert_eq(opened_ids, ["consumer_electronics"])


func test_store_entered_seeds_starter_inventory_when_empty() -> void:
	var inventory: InventorySystem = InventorySystem.new()
	add_child_autofree(inventory)
	_controller.set_inventory_system(inventory)

	_controller._on_store_entered(Electronics.STORE_ID)

	var items: Array[ItemInstance] = inventory.get_items_for_store(
		String(Electronics.STORE_ID)
	)
	assert_gt(items.size(), 0, "Starter inventory should be seeded")


func test_store_exited_emits_store_closed() -> void:
	var closed_ids: Array[String] = []
	var capture: Callable = func(store_id: String) -> void:
		closed_ids.append(store_id)
	EventBus.store_closed.connect(capture)
	_controller._on_store_exited(Electronics.STORE_ID)
	EventBus.store_closed.disconnect(capture)
	assert_eq(closed_ids, ["consumer_electronics"])


func test_day_started_and_customer_entered_hooks_are_safe() -> void:
	EventBus.day_started.emit(2)
	EventBus.customer_entered.emit({})
	assert_true(true)


func _ensure_consumer_electronics_content() -> void:
	if not ContentRegistry.exists("consumer_electronics"):
		ContentRegistry.register_entry({
			"id": "electronics",
			"aliases": ["consumer_electronics"],
			"name": "Consumer Electronics",
			"scene_path": "res://game/scenes/stores/consumer_electronics.tscn",
			"starting_inventory": ["test_elec_starter_a", "test_elec_starter_b"],
		}, "store")
	for item_id: String in ["test_elec_starter_a", "test_elec_starter_b"]:
		if ContentRegistry.exists(item_id):
			continue
		ContentRegistry.register_entry({
			"id": item_id,
			"item_name": item_id.capitalize(),
			"base_price": 25.0,
			"category": "gadgets",
			"rarity": "common",
			"store_type": "consumer_electronics",
		}, "item")
