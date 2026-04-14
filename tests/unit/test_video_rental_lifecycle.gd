## Unit tests for VideoRental lifecycle: record creation, state transitions, fee formula, and signal contracts.
extends GutTest


var _controller: VideoRentalStoreController
var _inventory: InventorySystem
var _economy: EconomySystem

var _standard_rental_period_days: int = 3
var _grace_period_days: int = 1
var _base_late_fee: float = 1.0
var _per_day_late_rate: float = 1.0
var _max_late_fee: float = 20.0

var _late_fee_signals: Array[Dictionary] = []
var _rented_signals: Array[Dictionary] = []


func before_all() -> void:
	var file: FileAccess = FileAccess.open(
		"res://game/content/stores/video_rental_config.json",
		FileAccess.READ
	)
	if not file:
		push_warning("test_video_rental_lifecycle: config not found, using defaults")
		return
	var text: String = file.get_as_text()
	file.close()
	var cfg: Variant = JSON.parse_string(text)
	if not cfg is Dictionary:
		push_warning("test_video_rental_lifecycle: config parse failed, using defaults")
		return
	var config: Dictionary = cfg as Dictionary
	_standard_rental_period_days = int(
		config.get("standard_rental_period_days", _standard_rental_period_days)
	)
	_grace_period_days = int(config.get("grace_period_days", _grace_period_days))
	_base_late_fee = float(config.get("base_late_fee", _base_late_fee))
	_per_day_late_rate = float(config.get("per_day_late_rate", _per_day_late_rate))
	_max_late_fee = float(config.get("max_late_fee", _max_late_fee))


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
	_controller._per_day_rate = _per_day_late_rate
	_controller._max_late_fee = _max_late_fee
	_controller._grace_period_days = _grace_period_days

	_late_fee_signals = []
	_rented_signals = []
	EventBus.rental_late_fee.connect(_on_rental_late_fee)
	EventBus.item_rented.connect(_on_item_rented)


func after_each() -> void:
	_safe_disconnect(EventBus.rental_late_fee, _on_rental_late_fee)
	_safe_disconnect(EventBus.item_rented, _on_item_rented)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_rental_late_fee(
	item_id: String, late_fee: float, days_late: int
) -> void:
	_late_fee_signals.append({
		"item_id": item_id,
		"late_fee": late_fee,
		"days_late": days_late,
	})


func _on_item_rented(
	item_id: String, rental_fee: float, rental_tier: String
) -> void:
	_rented_signals.append({
		"item_id": item_id,
		"rental_fee": rental_fee,
		"rental_tier": rental_tier,
	})


func _make_item(instance_id: String) -> ItemInstance:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "vhs_test_tape"
	def.item_name = "Test VHS Tape"
	def.category = "vhs_tapes"
	def.store_type = "rentals"
	def.base_price = 8.0
	def.rental_fee = 2.99
	def.rental_period_days = _standard_rental_period_days
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


# ── Record creation ────────────────────────────────────────────────────────────


func test_rental_record_created_on_checkout() -> void:
	var item: ItemInstance = _make_item("tape_001")
	var checkout_day: int = 5
	var record: Dictionary = _controller.process_rental(
		item.instance_id,
		"vhs_tapes",
		"three_day",
		2.99,
		checkout_day,
		"cust_42",
	)
	assert_true(
		_controller.rental_records.has(item.instance_id),
		"rental_records should contain the rented copy_id"
	)
	assert_eq(record["instance_id"], item.instance_id, "Record should store copy_id")
	assert_eq(record["customer_id"], "cust_42", "Record should store customer_id")
	assert_eq(record["checkout_day"], checkout_day, "Record should store rental_day")
	assert_eq(
		record["return_day"],
		checkout_day + _standard_rental_period_days,
		"return_day should be rental_day + standard_rental_period_days"
	)


# ── Copy state transitions ─────────────────────────────────────────────────────


func test_copy_transitions_to_rented_on_checkout() -> void:
	var item: ItemInstance = _make_item("tape_002")
	assert_ne(
		item.current_location,
		VideoRentalStoreController.RENTED_LOCATION,
		"Item should not be rented before checkout"
	)
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", 2.99, 1
	)
	assert_eq(
		item.current_location,
		VideoRentalStoreController.RENTED_LOCATION,
		"Copy status should be 'rented' after checkout"
	)


func test_copy_returns_to_available_on_return_day() -> void:
	var item: ItemInstance = _make_item("tape_003")
	var checkout_day: int = 1
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", 2.99, checkout_day
	)
	var return_day: int = checkout_day + _standard_rental_period_days
	_controller._on_day_started(return_day)
	assert_false(
		_controller.rental_records.has(item.instance_id),
		"Rental record should be removed on return_day"
	)
	assert_ne(
		item.current_location,
		VideoRentalStoreController.RENTED_LOCATION,
		"Copy should no longer be at 'rented' location on return_day"
	)


# ── Late fee: zero cases ───────────────────────────────────────────────────────


func test_late_fee_zero_on_return_day() -> void:
	var rental: Dictionary = _make_rental_dict("tape_004", 3, 6)
	_controller.rental_records["tape_004"] = rental
	_controller._daily_late_fee_total = 0.0
	_controller._on_day_started(6)
	assert_almost_eq(
		_controller._daily_late_fee_total,
		0.0,
		0.001,
		"No late fee should be collected when returned exactly on return_day"
	)


func test_late_fee_zero_within_grace_period() -> void:
	var return_day: int = 6
	var rental: Dictionary = _make_rental_dict("tape_005", 3, return_day)
	_controller.rental_records["tape_005"] = rental
	_controller._daily_late_fee_total = 0.0
	_controller._on_day_started(return_day + _grace_period_days)
	assert_almost_eq(
		_controller._daily_late_fee_total,
		0.0,
		0.001,
		"No late fee within grace_period_days of return_day"
	)


# ── Late fee: formula ─────────────────────────────────────────────────────────


func test_late_fee_formula_one_day_overdue() -> void:
	var rental: Dictionary = _make_rental_dict("tape_006", 1, 4)
	var expected_fee: float = _base_late_fee + (1.0 * _per_day_late_rate)
	_controller._daily_late_fee_total = 0.0
	_controller._collect_late_fee(rental, 1)
	assert_almost_eq(
		_controller._daily_late_fee_total,
		expected_fee,
		0.001,
		"1 day overdue: fee = base_late_fee + (1 × per_day_late_rate)"
	)


func test_late_fee_capped_at_max() -> void:
	var rental: Dictionary = _make_rental_dict("tape_007", 1, 4)
	var very_overdue_days: int = 1000
	_controller._daily_late_fee_total = 0.0
	_controller._collect_late_fee(rental, very_overdue_days)
	assert_almost_eq(
		_controller._daily_late_fee_total,
		_max_late_fee,
		0.001,
		"Late fee must not exceed max_late_fee regardless of overdue days"
	)


# ── Economy integration ────────────────────────────────────────────────────────


func test_late_fee_added_to_economy() -> void:
	var rental: Dictionary = _make_rental_dict("tape_008", 1, 4)
	var cash_before: float = _economy.get_cash()
	var expected_fee: float = minf(
		_base_late_fee + (1.0 * _per_day_late_rate),
		_max_late_fee
	)
	_controller._collect_late_fee(rental, 1)
	assert_almost_eq(
		_economy.get_cash(),
		cash_before + expected_fee,
		0.001,
		"EconomySystem should receive the exact late fee amount"
	)


# ── Signal contracts ───────────────────────────────────────────────────────────


func test_rental_income_signal_emitted() -> void:
	var item: ItemInstance = _make_item("tape_009")
	var rental_fee: float = 2.99
	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day", rental_fee, 1
	)
	assert_eq(
		_rented_signals.size(),
		1,
		"item_rented signal should fire once on checkout"
	)
	assert_eq(
		_rented_signals[0]["item_id"],
		item.instance_id,
		"item_rented should carry the correct copy_id"
	)
	assert_almost_eq(
		_rented_signals[0]["rental_fee"] as float,
		rental_fee,
		0.001,
		"item_rented should carry the correct rental fee amount"
	)
