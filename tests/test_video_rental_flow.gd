## GUT integration test: Video Rental checkout → overdue → late fee collection.
extends GutTest


var _inventory: InventorySystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _controller: VideoRentalStoreController
var _perf_report: PerformanceReportSystem
var _item_def: ItemDefinition

var _cfg_base_late_fee: float = 1.0
var _cfg_per_day_rate: float = 1.0
var _cfg_max_late_fee: float = 20.0
var _cfg_grace_period_days: int = 1
var _cfg_standard_rental_period: int = 3

const STORE_ID: StringName = &"rentals"
const STARTING_CASH: float = 1000.0
const FLOAT_TOLERANCE: float = 0.01


func before_all() -> void:
	_load_config_from_json()


func before_each() -> void:
	_register_store_in_content_registry()
	_item_def = _create_item_definition()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation.initialize_store(String(STORE_ID))

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()

	_controller = VideoRentalStoreController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)
	_controller.set_economy_system(_economy)
	_controller.set_reputation_system(_reputation)
	_controller._base_late_fee = _cfg_base_late_fee
	_controller._per_day_rate = _cfg_per_day_rate
	_controller._max_late_fee = _cfg_max_late_fee
	_controller._grace_period_days = _cfg_grace_period_days


func after_each() -> void:
	_unregister_store_from_content_registry()


# ── Scenario A: Normal return ────────────────────────────────────────────────


func test_normal_return_rental_fee_added_not_item_price() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var rental_fee: float = _item_def.rental_fee
	var cash_before: float = _economy.get_cash()

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day",
		rental_fee, 1
	)

	assert_almost_eq(
		_economy.get_cash(),
		cash_before + rental_fee,
		FLOAT_TOLERANCE,
		"Rental fee (not base_price) added to EconomySystem on checkout"
	)
	assert_true(
		_economy.get_cash() < cash_before + _item_def.base_price,
		"Cash increase is less than base_price, confirming rental_fee was used"
	)


func test_normal_return_copy_transitions_to_available() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var checkout_day: int = 1
	var rental_fee: float = _item_def.rental_fee

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day",
		rental_fee, checkout_day
	)

	assert_eq(
		item.current_location,
		VideoRentalStoreController.RENTED_LOCATION,
		"Item location is 'rented' after checkout"
	)

	var return_day: int = checkout_day + _cfg_standard_rental_period
	_controller._on_day_started(return_day)

	assert_false(
		_controller.rental_records.has(item.instance_id),
		"Rental record removed on return_day"
	)
	assert_ne(
		item.current_location,
		VideoRentalStoreController.RENTED_LOCATION,
		"Copy no longer at 'rented' location on return_day"
	)


func test_normal_return_record_has_correct_return_day() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var checkout_day: int = 5

	var record: Dictionary = _controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day",
		_item_def.rental_fee, checkout_day
	)

	assert_eq(
		int(record["return_day"]),
		checkout_day + _cfg_standard_rental_period,
		"return_day = checkout_day + standard_rental_period_days"
	)


func test_normal_return_no_late_fee_on_return_day() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var checkout_day: int = 1

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day",
		_item_def.rental_fee, checkout_day
	)

	var late_fee_fired: Array = [false]
	var on_late_fee := func(
		_iid: String, _fee: float, _days: int
	) -> void:
		late_fee_fired[0] = true

	EventBus.rental_late_fee.connect(on_late_fee)

	var return_day: int = checkout_day + _cfg_standard_rental_period
	_controller._on_day_started(return_day)

	assert_false(late_fee_fired[0], "No late fee on exact return_day")

	EventBus.rental_late_fee.disconnect(on_late_fee)


# ── Scenario B: Overdue return with late fee ─────────────────────────────────


func test_overdue_late_fee_formula() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var checkout_day: int = 1
	var extra_days: int = 2

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day",
		_item_def.rental_fee, checkout_day
	)

	var late_fee_amount: Array = [0.0]
	var late_fee_days: Array = [0]
	var on_late_fee := func(
		_iid: String, fee: float, days: int
	) -> void:
		late_fee_amount[0] = fee
		late_fee_days[0] = days

	EventBus.rental_late_fee.connect(on_late_fee)

	var return_day: int = checkout_day + _cfg_standard_rental_period
	var trigger_day: int = return_day + _cfg_grace_period_days + extra_days
	_controller._on_day_started(trigger_day)

	var expected_fee: float = _cfg_base_late_fee + (
		float(extra_days) * _cfg_per_day_rate
	)
	assert_almost_eq(
		late_fee_amount[0], expected_fee, FLOAT_TOLERANCE,
		"Late fee = base_late_fee + (overdue_days × per_day_rate)"
	)
	assert_eq(
		late_fee_days[0], extra_days,
		"Days overdue reported correctly"
	)

	EventBus.rental_late_fee.disconnect(on_late_fee)


func test_overdue_late_fee_added_to_economy_with_late_fee_reason() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var checkout_day: int = 1
	var extra_days: int = 2

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day",
		_item_def.rental_fee, checkout_day
	)

	var cash_before: float = _economy.get_cash()
	var return_day: int = checkout_day + _cfg_standard_rental_period
	var trigger_day: int = return_day + _cfg_grace_period_days + extra_days
	_controller._on_day_started(trigger_day)

	var expected_fee: float = _cfg_base_late_fee + (
		float(extra_days) * _cfg_per_day_rate
	)
	assert_almost_eq(
		_economy.get_cash(),
		cash_before + expected_fee,
		FLOAT_TOLERANCE,
		"EconomySystem received late fee amount"
	)

	var found_late_fee_txn: Array = [false]
	for txn: Dictionary in _economy._daily_transactions:
		var reason: String = txn.get("reason", "")
		if reason.begins_with("Late fee"):
			found_late_fee_txn[0] = true
			break
	assert_true(
		found_late_fee_txn[0],
		"Transaction with 'Late fee' reason recorded in EconomySystem"
	)


func test_overdue_late_fee_in_performance_report() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var checkout_day: int = 1
	var extra_days: int = 2

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day",
		_item_def.rental_fee, checkout_day
	)

	var return_day: int = checkout_day + _cfg_standard_rental_period
	var trigger_day: int = return_day + _cfg_grace_period_days + extra_days
	_controller._on_day_started(trigger_day)

	var expected_fee: float = _cfg_base_late_fee + (
		float(extra_days) * _cfg_per_day_rate
	)
	assert_almost_eq(
		_perf_report._daily_late_fee_income,
		expected_fee,
		FLOAT_TOLERANCE,
		"PerformanceReportSystem accumulated late_fee_income"
	)


func test_overdue_max_late_fee_cap_enforced() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var checkout_day: int = 1

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day",
		_item_def.rental_fee, checkout_day
	)

	var late_fee_amount: Array = [0.0]
	var on_late_fee := func(
		_iid: String, fee: float, _days: int
	) -> void:
		late_fee_amount[0] = fee

	EventBus.rental_late_fee.connect(on_late_fee)

	var return_day: int = checkout_day + _cfg_standard_rental_period
	var trigger_day: int = return_day + _cfg_grace_period_days + 150
	_controller._on_day_started(trigger_day)

	assert_almost_eq(
		late_fee_amount[0], _cfg_max_late_fee, FLOAT_TOLERANCE,
		"Late fee capped at max_late_fee when overdue by 100+ days"
	)

	var uncapped: float = _cfg_base_late_fee + (150.0 * _cfg_per_day_rate)
	assert_true(
		uncapped > _cfg_max_late_fee,
		"Raw fee exceeds cap, confirming cap was needed"
	)

	EventBus.rental_late_fee.disconnect(on_late_fee)


func test_no_late_fee_within_grace_period() -> void:
	var item: ItemInstance = _create_and_stock_item()
	var checkout_day: int = 1

	_controller.process_rental(
		item.instance_id, "vhs_tapes", "three_day",
		_item_def.rental_fee, checkout_day
	)

	var late_fee_fired: Array = [false]
	var on_late_fee := func(
		_iid: String, _fee: float, _days: int
	) -> void:
		late_fee_fired[0] = true

	EventBus.rental_late_fee.connect(on_late_fee)

	var return_day: int = checkout_day + _cfg_standard_rental_period
	var grace_deadline: int = return_day + _cfg_grace_period_days
	_controller._on_day_started(grace_deadline)

	assert_false(
		late_fee_fired[0],
		"No late fee within grace period"
	)

	EventBus.rental_late_fee.disconnect(on_late_fee)


# ── Helpers ──────────────────────────────────────────────────────────────────


func _load_config_from_json() -> void:
	var file: FileAccess = FileAccess.open(
		"res://game/content/stores/video_rental_config.json",
		FileAccess.READ
	)
	if not file:
		push_warning("test_video_rental_flow: config not found, using defaults")
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("test_video_rental_flow: config parse failed, using defaults")
		return
	var cfg: Dictionary = parsed as Dictionary
	_cfg_base_late_fee = float(cfg.get("base_late_fee", _cfg_base_late_fee))
	_cfg_per_day_rate = float(cfg.get("per_day_late_rate", _cfg_per_day_rate))
	_cfg_max_late_fee = float(cfg.get("max_late_fee", _cfg_max_late_fee))
	_cfg_grace_period_days = int(
		cfg.get("grace_period_days", _cfg_grace_period_days)
	)
	_cfg_standard_rental_period = int(
		cfg.get("standard_rental_period_days", _cfg_standard_rental_period)
	)


func _create_and_stock_item() -> ItemInstance:
	var item: ItemInstance = ItemInstance.create(
		_item_def, "good", 0, _item_def.base_price
	)
	_inventory.add_item(STORE_ID, item)
	return item


func _create_item_definition() -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = "vhs_test_tape"
	def.item_name = "Test VHS Tape"
	def.category = "vhs_tapes"
	def.store_type = "rentals"
	def.base_price = 10.0
	def.rental_fee = 2.0
	def.rental_tier = "three_day"
	def.rental_period_days = _cfg_standard_rental_period
	def.rarity = "common"
	def.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)
	return def


func _register_store_in_content_registry() -> void:
	if ContentRegistry.exists("rentals"):
		return
	ContentRegistry.register_entry(
		{
			"id": "rentals",
			"name": "Video Rental",
			"scene_path": "",
			"backroom_capacity": 150,
		},
		"store"
	)


func _unregister_store_from_content_registry() -> void:
	if not ContentRegistry.exists("rentals"):
		return
	var entries: Dictionary = ContentRegistry._entries
	var aliases: Dictionary = ContentRegistry._aliases
	var types: Dictionary = ContentRegistry._types
	var display_names: Dictionary = ContentRegistry._display_names
	var scene_map: Dictionary = ContentRegistry._scene_map
	entries.erase(&"rentals")
	types.erase(&"rentals")
	display_names.erase(&"rentals")
	scene_map.erase(&"rentals")
	var alias_key: StringName = StringName("rentals")
	for key: StringName in aliases.keys():
		if aliases[key] == alias_key:
			aliases.erase(key)
