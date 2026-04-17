## Tests VideoRentalStoreController return handling, tape degradation, and save/load.
extends GutTest


var _controller: VideoRentalStoreController
var _inventory: InventorySystem
var _economy: EconomySystem
var _data_loader: DataLoader
var _previous_data_loader: DataLoader
var _returned_signals: Array[Dictionary] = []
var _notifications: Array[String] = []


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_previous_data_loader = GameManager.data_loader
	GameManager.data_loader = _data_loader

	_controller = VideoRentalStoreController.new()
	_inventory = InventorySystem.new()
	_economy = EconomySystem.new()
	add_child_autofree(_controller)
	add_child_autofree(_inventory)
	add_child_autofree(_economy)
	_inventory.initialize(_data_loader)
	_economy.initialize(0.0)
	_controller.set_inventory_system(_inventory)
	_controller.set_economy_system(_economy)

	_returned_signals = []
	_notifications = []
	EventBus.rental_returned.connect(_on_rental_returned)
	EventBus.notification_requested.connect(_on_notification_requested)


func after_each() -> void:
	GameManager.data_loader = _previous_data_loader
	_disconnect_if_needed(EventBus.rental_returned, _on_rental_returned)
	_disconnect_if_needed(
		EventBus.notification_requested,
		_on_notification_requested
	)


func test_process_rental_moves_item_to_rented_and_tracks_record() -> void:
	var item: ItemInstance = _register_item("tape_a", "good")

	var record: Dictionary = _controller.process_rental(
		item.instance_id,
		"vhs_tapes",
		"three_day",
		2.0,
		5,
		"cust_1"
	)

	assert_true(
		_controller.rental_records.has(item.instance_id),
		"Rental records should include the rented tape"
	)
	assert_eq(
		item.current_location,
		VideoRentalStoreController.RENTED_LOCATION,
		"Rental checkout should move the tape to the rented location"
	)
	assert_eq(
		int(record.get("return_day", -1)),
		8,
		"Return day should be checkout day plus rental duration"
	)


func test_due_return_moves_rentable_tape_to_returns_bin() -> void:
	var item: ItemInstance = _register_item("tape_b", "good")
	_controller.process_rental(
		item.instance_id,
		"vhs_tapes",
		"overnight",
		2.0,
		1
	)

	_controller._on_day_started(2)

	assert_eq(
		item.current_location,
		VideoRentalStoreController.RETURNS_BIN_LOCATION,
		"Returned rentable tapes should go to the returns bin"
	)
	assert_eq(
		item.rental_due_day,
		-1,
		"Returned tapes should clear their due date"
	)


func test_return_threshold_updates_inventory_condition() -> void:
	var item: ItemInstance = _register_item("tape_c", "good")
	_controller._wear_tracker.initialize_item(item.instance_id, item.condition)
	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1):
		_controller._wear_tracker.record_return(item.instance_id)
	var rental: Dictionary = _make_rental_dict(item.instance_id, 1, 4)

	var result: Dictionary = _controller._apply_degradation(rental)

	assert_true(
		bool(result.get("condition_changed", false)),
		"Crossing the threshold should report a condition change"
	)
	assert_eq(
		item.condition,
		"fair",
		"InventorySystem should persist the degraded condition"
	)
	assert_eq(
		_controller.get_tape_wear(item.instance_id),
		0,
		"Play count should reset after dropping a condition tier"
	)


func test_written_off_return_moves_tape_to_backroom_and_notifies_player() -> void:
	var item: ItemInstance = _register_item("tape_d", "poor")
	_controller._wear_tracker.initialize_item(item.instance_id, item.condition)
	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1):
		_controller._wear_tracker.record_return(item.instance_id)
	_controller.process_rental(
		item.instance_id,
		"vhs_tapes",
		"overnight",
		2.0,
		1
	)

	_controller._on_day_started(2)

	assert_eq(
		item.current_location,
		VideoRentalStoreController.BACKROOM_LOCATION,
		"Written-off returns should be moved to the backroom automatically"
	)
	assert_false(
		_controller.is_rentable(item),
		"Written-off returns should be ineligible for rental"
	)
	assert_eq(
		_returned_signals.size(),
		1,
		"rental_returned should fire for the completed return"
	)
	assert_true(
		bool(_returned_signals[0].get("worn_out", false)),
		"rental_returned should flag written-off tapes as worn out"
	)
	assert_true(
		_notifications_contain("worn out"),
		"Written-off returns should notify the player about retirement"
	)


func test_save_load_preserves_partial_tape_progress() -> void:
	var item: ItemInstance = _register_item("tape_e", "poor")
	_controller._wear_tracker.initialize_item(item.instance_id, item.condition)
	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1):
		_controller._wear_tracker.record_return(item.instance_id)
	_controller.process_rental(
		item.instance_id,
		"vhs_tapes",
		"three_day",
		2.0,
		5,
		"cust_99"
	)
	var save_data: Dictionary = _controller.get_save_data()

	_controller.rental_records.clear()
	_controller._wear_tracker.load_save_data({})
	_controller.load_save_data(save_data)

	assert_true(
		_controller.rental_records.has(item.instance_id),
		"Rental records should survive save/load"
	)
	assert_eq(
		_controller.get_tape_wear(item.instance_id),
		TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1,
		"Tape wear progress should restore exactly from save data"
	)


func _register_item(instance_id: String, condition: String) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "%s_def" % instance_id
	def.item_name = "Test Tape"
	def.category = "vhs_tapes"
	def.store_type = "rentals"
	def.base_price = 10.0
	def.rental_fee = 2.0
	def.rental_period_days = 3
	def.rental_tier = "three_day"

	var item := ItemInstance.new()
	item.definition = def
	item.instance_id = instance_id
	item.condition = condition
	item.current_location = "shelf:slot_1"
	_inventory.register_item(item)
	return item


func _make_rental_dict(
	instance_id: String,
	checkout_day: int,
	return_day: int
) -> Dictionary:
	return {
		"instance_id": instance_id,
		"customer_id": "cust_test",
		"category": "vhs_tapes",
		"rental_fee": 2.0,
		"rental_tier": "three_day",
		"checkout_day": checkout_day,
		"return_day": return_day,
	}


func _on_rental_returned(instance_id: String, worn_out: bool) -> void:
	_returned_signals.append({
		"instance_id": instance_id,
		"worn_out": worn_out,
	})


func _on_notification_requested(message: String) -> void:
	_notifications.append(message)


func _disconnect_if_needed(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _notifications_contain(fragment: String) -> bool:
	for message: String in _notifications:
		if message.find(fragment) != -1:
			return true
	return false
