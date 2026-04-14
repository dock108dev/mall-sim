## Unit tests for VideoRentalController: rental creation, late fee calculation, and return processing.
extends GutTest

var _controller: VideoRentalStoreController
var _inventory: InventorySystem
var _economy: EconomySystem

var _base_late_fee: float = 1.0
var _per_day_rate: float = 0.5
var _max_late_fee: float = 20.0
var _grace_period_days: int = 1

var _returned_signals: Array[Dictionary] = []
var _late_fee_signals: Array[Dictionary] = []


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(500.0)

	_controller = VideoRentalStoreController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)
	_controller.set_economy_system(_economy)
	_controller._base_late_fee = _base_late_fee
	_controller._per_day_rate = _per_day_rate
	_controller._max_late_fee = _max_late_fee
	_controller._grace_period_days = _grace_period_days

	_returned_signals = []
	_late_fee_signals = []
	EventBus.rental_returned.connect(_on_rental_returned)
	EventBus.rental_late_fee.connect(_on_rental_late_fee)


func after_each() -> void:
	_safe_disconnect(EventBus.rental_returned, _on_rental_returned)
	_safe_disconnect(EventBus.rental_late_fee, _on_rental_late_fee)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_rental_returned(instance_id: String, worn_out: bool) -> void:
	_returned_signals.append({"instance_id": instance_id, "worn_out": worn_out})


func _on_rental_late_fee(instance_id: String, late_fee: float, days_late: int) -> void:
	_late_fee_signals.append({
		"instance_id": instance_id,
		"late_fee": late_fee,
		"days_late": days_late,
	})


func _make_item(instance_id: String) -> ItemInstance:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "vhs_test_tape"
	def.item_name = "Test VHS Tape"
	def.category = "vhs_tapes"
	def.store_type = "rentals"
	def.base_price = 8.0
	def.rental_fee = 2.99
	def.rental_period_days = 3
	def.rental_tier = "three_day"
	var inst: ItemInstance = ItemInstance.new()
	inst.definition = def
	inst.instance_id = instance_id
	inst.condition = "good"
	inst.current_location = "shelf:slot_0"
	_inventory._items[instance_id] = inst
	return inst


func _make_rental_dict(
	instance_id: String,
	checkout_day: int,
	return_day: int,
) -> Dictionary:
	return {
		"instance_id": instance_id,
		"customer_id": "cust_test",
		"category": "vhs_tapes",
		"rental_fee": 2.99,
		"rental_tier": "three_day",
		"checkout_day": checkout_day,
		"return_day": return_day,
	}


# ── Rental record creation ─────────────────────────────────────────────────────


func test_rental_creates_active_record() -> void:
	var item: ItemInstance = _make_item("tape_r01")
	var checkout_day: int = 5
	var customer_id: String = "cust_alpha"

	_controller.process_rental(
		item.instance_id,
		"vhs_tapes",
		"three_day",
		2.99,
		checkout_day,
		customer_id,
	)

	var active: Array[Dictionary] = _controller.get_active_rentals()
	assert_eq(active.size(), 1, "get_active_rentals should contain exactly one record")

	var record: Dictionary = active[0]
	assert_eq(
		record["instance_id"],
		item.instance_id,
		"Active rental should store the correct instance_id"
	)
	assert_eq(
		record["customer_id"],
		customer_id,
		"Active rental should store the correct customer_id"
	)
	var expected_due_day: int = (
		checkout_day + VideoRentalStoreController.RENTAL_DURATIONS["three_day"]
	)
	assert_eq(
		record["return_day"],
		expected_due_day,
		"Active rental return_day should equal checkout_day + rental duration"
	)
	assert_eq(
		item.current_location,
		VideoRentalStoreController.RENTED_LOCATION,
		"Item should be moved to rented location after checkout"
	)


# ── On-time return ─────────────────────────────────────────────────────────────


func test_on_time_return_no_late_fee() -> void:
	var item: ItemInstance = _make_item("tape_r02")
	var checkout_day: int = 1
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", 2.99, checkout_day
	)
	var due_day: int = checkout_day + VideoRentalStoreController.RENTAL_DURATIONS["three_day"]

	_controller._daily_late_fee_total = 0.0
	_controller._on_day_started(due_day)

	assert_almost_eq(
		_controller._daily_late_fee_total,
		0.0,
		0.001,
		"No late fee should accrue when item is returned on the due day"
	)
	assert_false(
		_controller.rental_records.has(item.instance_id),
		"Rental record should be removed after return"
	)
	assert_ne(
		item.current_location,
		VideoRentalStoreController.RENTED_LOCATION,
		"Item should no longer be at rented location after return"
	)


# ── Overdue return with late fee ───────────────────────────────────────────────


func test_overdue_return_accrues_late_fee() -> void:
	var rental: Dictionary = _make_rental_dict("tape_r03", 1, 4)
	var days_overdue: int = 3
	var expected_fee: float = _base_late_fee + (float(days_overdue) * _per_day_rate)

	_controller._daily_late_fee_total = 0.0
	_controller._collect_late_fee(rental, days_overdue)

	assert_almost_eq(
		_controller._daily_late_fee_total,
		expected_fee,
		0.001,
		"Late fee should equal base_late_fee + (days_overdue * per_day_rate)"
	)
	assert_eq(
		_late_fee_signals.size(),
		1,
		"rental_late_fee signal should fire once for the overdue return"
	)
	assert_almost_eq(
		_late_fee_signals[0]["late_fee"] as float,
		expected_fee,
		0.001,
		"rental_late_fee signal should carry the correct fee amount"
	)


# ── Unknown rental ID ──────────────────────────────────────────────────────────


func test_process_return_unknown_rental_id() -> void:
	watch_signals(EventBus)

	var result: bool = _controller.retire_tape("nonexistent_id", false)

	assert_false(result, "retire_tape with an unknown id should return false")
	assert_signal_not_emitted(
		EventBus,
		"rental_returned",
		"rental_returned should not fire when the item does not exist"
	)


# ── Overdue rentals list accuracy ──────────────────────────────────────────────


func test_overdue_rentals_list_accuracy() -> void:
	# deadline = return_day + grace_period (1). Overdue if current_day > deadline.
	_controller.rental_records["tape_r04"] = _make_rental_dict("tape_r04", 1, 3)
	_controller.rental_records["tape_r05"] = _make_rental_dict("tape_r05", 2, 5)
	_controller.rental_records["tape_r06"] = _make_rental_dict("tape_r06", 3, 10)

	# tape_r04: deadline=4 → overdue at 9
	# tape_r05: deadline=6 → overdue at 9
	# tape_r06: deadline=11 → not overdue at 9
	var current_day: int = 9
	var overdue: Array[Dictionary] = _controller.get_overdue_rentals(current_day)

	assert_eq(
		overdue.size(),
		2,
		"get_overdue_rentals should return exactly the 2 overdue rentals"
	)

	var overdue_ids: Array[String] = []
	for rec: Dictionary in overdue:
		overdue_ids.append(rec["instance_id"] as String)

	assert_true(
		overdue_ids.has("tape_r04"),
		"tape_r04 (past grace period) should appear in overdue list"
	)
	assert_true(
		overdue_ids.has("tape_r05"),
		"tape_r05 (past grace period) should appear in overdue list"
	)
	assert_false(
		overdue_ids.has("tape_r06"),
		"tape_r06 (not yet due) should not appear in overdue list"
	)
