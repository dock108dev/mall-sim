## Covers ISSUE-015 acceptance: day-advance tags overdue rentals, late fees
## accrue as pending per overdue day, returning customer is blocked at rental
## until fees resolve, and performance report exposes overdue count.
extends GutTest

var _controller: VideoRentalStoreController
var _inventory: InventorySystem
var _economy: EconomySystem
var _data_loader: DataLoader
var _previous_data_loader: DataLoader

const CHECKOUT_DAY: int = 5


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
	_economy.initialize(500.0)
	_controller.set_inventory_system(_inventory)
	_controller.set_economy_system(_economy)
	_controller._grace_period_days = 1
	_controller._base_late_fee = 1.0
	_controller._per_day_rate = 0.5
	_controller._max_late_fee = 15.0


func after_each() -> void:
	GameManager.data_loader = _previous_data_loader


func test_day_advance_tags_overdue_rentals_in_run_state() -> void:
	var item: ItemInstance = _register_item("tape_overdue_tag")
	var rental: Dictionary = _controller.rent_item(
		item.instance_id, "overnight", CHECKOUT_DAY, "cust_A"
	)
	var due_day: int = int(rental["due_day"])
	# Advance past grace period (deadline = due_day + grace, overdue = +1).
	_controller._on_day_started(due_day + 2)

	var record: Dictionary = _controller.rental_records.get(
		item.instance_id, {}
	)
	assert_true(
		record.get("overdue", false),
		"Past-deadline rental must be tagged overdue in run state"
	)
	assert_gt(
		int(record.get("days_overdue", 0)), 0,
		"Overdue tag should include days_overdue > 0"
	)


func test_late_fee_accrues_per_day_via_single_formula() -> void:
	var item: ItemInstance = _register_item("tape_accrue")
	var rental: Dictionary = _controller.rent_item(
		item.instance_id, "overnight", CHECKOUT_DAY, "cust_B"
	)
	var due_day: int = int(rental["due_day"])

	# Day 1 past grace: 1 day overdue, fee = base(1.0) + 1*0.5 = 1.5.
	_controller._on_day_started(due_day + 2)
	var pending_day1: Dictionary = _controller.get_pending_late_fees()
	assert_true(
		pending_day1.has(item.instance_id),
		"Overdue rental should accrue a pending fee"
	)
	assert_almost_eq(
		float(pending_day1[item.instance_id]["amount"]), 1.5, 0.001,
		"Day-1 overdue fee should follow the documented formula"
	)

	# Day 3 past grace: 3 days overdue, fee = 1.0 + 3*0.5 = 2.5.
	_controller._on_day_started(due_day + 4)
	var pending_day3: Dictionary = _controller.get_pending_late_fees()
	assert_almost_eq(
		float(pending_day3[item.instance_id]["amount"]), 2.5, 0.001,
		"Per-day accrual must scale with days overdue"
	)


func test_pending_fee_is_not_auto_collected_until_resolved() -> void:
	var item: ItemInstance = _register_item("tape_not_auto")
	var rental: Dictionary = _controller.rent_item(
		item.instance_id, "overnight", CHECKOUT_DAY, "cust_C"
	)
	var cash_before: float = _economy.get_cash()

	_controller._on_day_started(int(rental["due_day"]) + 3)

	# Pending fee exists but no cash moved yet.
	assert_eq(
		_economy.get_cash(), cash_before,
		"Overdue accrual must not auto-collect cash"
	)
	assert_gt(
		_controller.get_pending_fees_for_customer("cust_C")["total"], 0.0,
		"Pending fee for customer must be outstanding until resolved"
	)


func test_returning_customer_with_overdue_is_blocked_at_new_rental() -> void:
	var first: ItemInstance = _register_item("tape_first")
	var second: ItemInstance = _register_item("tape_second")
	var rental: Dictionary = _controller.rent_item(
		first.instance_id, "overnight", CHECKOUT_DAY, "cust_D"
	)
	_controller._on_day_started(int(rental["due_day"]) + 2)

	var attempt: Dictionary = _controller.rent_item(
		second.instance_id, "overnight", CHECKOUT_DAY + 10, "cust_D"
	)

	assert_true(
		bool(attempt.get("blocked_by_late_fees", false)),
		"New rental must be blocked when customer has pending late fees"
	)
	assert_gt(
		float(attempt.get("pending_total", 0.0)), 0.0,
		"Blocked result must expose the pending total owed"
	)
	assert_false(
		_controller.rental_records.has(second.instance_id),
		"Blocked attempt must not create a new rental record"
	)


func test_refusing_to_pay_preserves_block_paying_clears_overdue() -> void:
	var first: ItemInstance = _register_item("tape_refuse")
	var second: ItemInstance = _register_item("tape_after_pay")
	var rental: Dictionary = _controller.rent_item(
		first.instance_id, "overnight", CHECKOUT_DAY, "cust_E"
	)
	_controller._on_day_started(int(rental["due_day"]) + 2)

	# Refuse: pending stays, subsequent rental still blocked.
	var refused: Dictionary = _controller.resolve_customer_late_fees(
		"cust_E", false
	)
	assert_eq(
		int(refused.get("items_resolved", 0)), 0,
		"Refusing to pay must not resolve any items"
	)
	var still_blocked: Dictionary = _controller.rent_item(
		second.instance_id, "overnight", CHECKOUT_DAY + 10, "cust_E"
	)
	assert_true(
		bool(still_blocked.get("blocked_by_late_fees", false)),
		"Rental must remain blocked until fees are paid"
	)

	# Pay: pending clears and normal rental resumes.
	var cash_before: float = _economy.get_cash()
	var paid: Dictionary = _controller.resolve_customer_late_fees(
		"cust_E", true
	)
	assert_gt(
		float(paid.get("total", 0.0)), 0.0,
		"Paying must collect the pending total"
	)
	assert_gt(
		_economy.get_cash(), cash_before,
		"Paying late fees must add cash to the economy"
	)
	assert_eq(
		_controller.get_pending_fees_for_customer("cust_E")["total"], 0.0,
		"Paid fees must clear pending state"
	)

	var ok_rental: Dictionary = _controller.rent_item(
		second.instance_id, "overnight", CHECKOUT_DAY + 10, "cust_E"
	)
	assert_false(
		bool(ok_rental.get("blocked_by_late_fees", false)),
		"After paying, normal rental flow must resume"
	)
	assert_eq(
		String(ok_rental.get("tape_id", "")), second.instance_id,
		"New rental must succeed after overdue resolved"
	)


func test_performance_report_carries_overdue_count_field() -> void:
	var report := PerformanceReport.new()
	report.overdue_items_count = 3

	var round_trip: PerformanceReport = PerformanceReport.from_dict(
		report.to_dict()
	)

	assert_eq(
		round_trip.overdue_items_count, 3,
		"PerformanceReport must round-trip overdue_items_count for day summary"
	)


func _register_item(instance_id: String) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "%s_def" % instance_id
	def.item_name = "Test Tape"
	def.category = "vhs_tapes"
	def.store_type = "rentals"
	def.base_price = 12.0
	def.rental_fee = 3.0
	def.rental_period_days = 3
	def.rental_tier = "three_day"

	var item := ItemInstance.new()
	item.definition = def
	item.instance_id = instance_id
	item.condition = "good"
	item.current_location = "shelf:slot_1"
	_inventory.register_item(item)
	return item
