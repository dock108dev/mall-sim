## Unit tests for ReturnsBin return eligibility, late fee computation, and condition degradation.
extends GutTest

const TEST_SIGNAL_UTILS: GDScript = preload("res://game/tests/signal_utils.gd")

var _controller: VideoRentalStoreController
var _inventory: InventorySystem
var _economy: EconomySystem
var _data_loader: DataLoader
var _previous_data_loader: DataLoader

# Use base_late_fee=0.0 so fee equals exactly per_day_rate × overdue_days,
# making assertions straightforward without an additive base term.
var _base_late_fee: float = 0.0
var _per_day_rate: float = 1.0
var _max_late_fee: float = 30.0
var _grace_period_days: int = 0

var _late_fee_signals: Array[Dictionary] = []


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_previous_data_loader = GameManager.data_loader
	GameManager.data_loader = _data_loader
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

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

	_late_fee_signals = []
	EventBus.rental_late_fee.connect(_on_rental_late_fee)


func after_each() -> void:
	GameManager.data_loader = _previous_data_loader
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.rental_late_fee, _on_rental_late_fee)


func _on_rental_late_fee(item_id: String, late_fee: float, days_late: int) -> void:
	_late_fee_signals.append({
		"item_id": item_id,
		"late_fee": late_fee,
		"days_late": days_late,
	})


func _make_item(instance_id: String, condition: String = "good") -> ItemInstance:
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
	inst.condition = condition
	inst.current_location = "shelf:slot_0"
	_inventory.register_item(inst)
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


# ── Return eligibility ─────────────────────────────────────────────────────────


func test_return_rejected_before_rental_period_expires() -> void:
	var item: ItemInstance = _make_item("tape_101")
	var checkout_day: int = 1
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", 2.99, checkout_day
	)
	var return_day: int = checkout_day + 3
	_controller._on_day_started(return_day - 1)
	assert_true(
		_controller.rental_records.has(item.instance_id),
		"Rental record must remain active when current_day < return_day"
	)
	assert_eq(
		_late_fee_signals.size(),
		0,
		"rental_late_fee must not fire before rental period expires"
	)


func test_return_accepted_on_due_date() -> void:
	var item: ItemInstance = _make_item("tape_102")
	var checkout_day: int = 1
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", 2.99, checkout_day
	)
	var return_day: int = checkout_day + 3
	_controller._on_day_started(return_day)
	assert_false(
		_controller.rental_records.has(item.instance_id),
		"Rental record must be cleared when item returned on due date"
	)
	# remove_item sets location to "sold"; move_item sets it to returns_bin or backroom.
	# Either way the item must no longer be in the rented location.
	assert_ne(
		item.current_location,
		VideoRentalStoreController.RENTED_LOCATION,
		"Item must leave rented status when returned on due date"
	)


# ── Late fee computation ────────────────────────────────────────────────────────


func test_late_fee_computed_per_overdue_day() -> void:
	var rental: Dictionary = _make_rental_dict("tape_103", 1, 4)
	_controller._daily_late_fee_total = 0.0
	var overdue_days: int = 3
	_controller._collect_late_fee(rental, overdue_days)
	# With base_late_fee=0.0 and per_day_rate=1.0: fee = 0.0 + (3 × 1.0) = 3.0
	var expected_fee: float = _base_late_fee + float(overdue_days) * _per_day_rate
	assert_almost_eq(
		_controller._daily_late_fee_total,
		expected_fee,
		0.001,
		"Late fee must equal base_late_fee + (overdue_days × per_day_rate)"
	)


func test_late_fee_signal_emitted_with_correct_amount() -> void:
	var rental: Dictionary = _make_rental_dict("tape_104", 1, 4)
	var overdue_days: int = 3
	var expected_fee: float = minf(
		_base_late_fee + float(overdue_days) * _per_day_rate,
		_max_late_fee
	)
	_controller._collect_late_fee(rental, overdue_days)
	assert_eq(
		_late_fee_signals.size(),
		1,
		"rental_late_fee signal must fire exactly once per late return processed"
	)
	assert_eq(
		_late_fee_signals[0]["item_id"],
		"tape_104",
		"Signal must carry the correct rental instance_id"
	)
	assert_almost_eq(
		float(_late_fee_signals[0]["late_fee"]),
		expected_fee,
		0.001,
		"Signal must carry the exact computed late fee amount"
	)


# ── Condition degradation ──────────────────────────────────────────────────────


func test_condition_degrades_after_return() -> void:
	var item: ItemInstance = _make_item("tape_105", "good")
	_controller._wear_tracker.initialize_item(item.instance_id, item.condition)
	for _i: int in range(TapeWearTracker.RENTALS_PER_CONDITION_DROP - 1):
		_controller._wear_tracker.record_return(item.instance_id)
	var rental: Dictionary = _make_rental_dict("tape_105", 1, 4)
	_controller._apply_degradation(rental)
	assert_eq(
		item.condition,
		"fair",
		"Item condition must degrade after enough returns are recorded"
	)
