## GUT tests: new-release price decay timeline and late-fee waive/collect branching.
extends GutTest


var _controller: VideoRentalStoreController


func before_each() -> void:
	_controller = VideoRentalStoreController.new()
	add_child_autofree(_controller)
	_controller._new_release_window_days = 7
	_controller._base_late_fee = 1.0
	_controller._per_day_rate = 0.5
	_controller._max_late_fee = 15.0
	_controller._grace_period_days = 0


# ── Price decay ───────────────────────────────────────────────────────────────

func test_new_release_price_within_window() -> void:
	var item: ItemInstance = _make_new_release_item("nr_a", 3.5, 2.0, 1)
	var price: float = _controller.get_effective_rental_price(item, 5)
	assert_almost_eq(price, 3.5, 0.001,
		"Before window expires rental_fee should apply")


func test_new_release_price_at_window_boundary() -> void:
	var item: ItemInstance = _make_new_release_item("nr_b", 3.5, 2.0, 1)
	# release_day=1, window=7 → decays on day 8
	var price: float = _controller.get_effective_rental_price(item, 8)
	assert_almost_eq(price, 2.0, 0.001,
		"At or after window expiry catalog_price should apply")


func test_new_release_price_after_window() -> void:
	var item: ItemInstance = _make_new_release_item("nr_c", 3.5, 2.0, 1)
	var price: float = _controller.get_effective_rental_price(item, 20)
	assert_almost_eq(price, 2.0, 0.001,
		"Well past window catalog_price should apply")


func test_catalog_item_price_unchanged() -> void:
	var item: ItemInstance = _make_catalog_item("cat_a", 2.0)
	var price: float = _controller.get_effective_rental_price(item, 20)
	assert_almost_eq(price, 2.0, 0.001,
		"Classic/catalog items should always use rental_fee")


func test_new_release_no_catalog_price_uses_rental_fee() -> void:
	# catalog_price == 0 means decay is not configured
	var item: ItemInstance = _make_new_release_item("nr_d", 3.5, 0.0, 1)
	var price: float = _controller.get_effective_rental_price(item, 20)
	assert_almost_eq(price, 3.5, 0.001,
		"When catalog_price is 0 rental_fee should always be returned")


func test_new_release_no_release_day_uses_rental_fee() -> void:
	# release_day == 0 means decay is not configured
	var item: ItemInstance = _make_new_release_item("nr_e", 3.5, 2.0, 0)
	var price: float = _controller.get_effective_rental_price(item, 20)
	assert_almost_eq(price, 3.5, 0.001,
		"When release_day is 0 rental_fee should always be returned")


func test_price_configurable_window() -> void:
	_controller._new_release_window_days = 3
	var item: ItemInstance = _make_new_release_item("nr_f", 3.5, 2.0, 1)
	assert_almost_eq(
		_controller.get_effective_rental_price(item, 3), 3.5, 0.001,
		"Day 3 still within 3-day window"
	)
	assert_almost_eq(
		_controller.get_effective_rental_price(item, 4), 2.0, 0.001,
		"Day 4 is at/past the 3-day window"
	)


# ── Waive / collect signal branching ─────────────────────────────────────────

func test_collect_late_fee_emits_late_fee_collected() -> void:
	var collected: Array[Dictionary] = []
	var on_collected: Callable = func(
		item_id: String, amount: float, days: int
	) -> void:
		collected.append({"item_id": item_id, "amount": amount, "days": days})
	EventBus.late_fee_collected.connect(on_collected)

	_controller._pending_late_fees["item_x"] = {"amount": 2.5, "days_late": 2}
	_controller.collect_late_fee("item_x")

	EventBus.late_fee_collected.disconnect(on_collected)
	assert_eq(collected.size(), 1, "collect_late_fee should emit late_fee_collected")
	assert_almost_eq(
		float(collected[0]["amount"]), 2.5, 0.001, "collected amount should match"
	)


func test_waive_late_fee_emits_late_fee_waived() -> void:
	var waived: Array[Dictionary] = []
	var on_waived: Callable = func(
		item_id: String, amount: float, rep_delta: float
	) -> void:
		waived.append({"item_id": item_id, "amount": amount, "rep": rep_delta})
	EventBus.late_fee_waived.connect(on_waived)

	_controller._pending_late_fees["item_y"] = {"amount": 3.0, "days_late": 3}
	_controller.waive_late_fee("item_y")

	EventBus.late_fee_waived.disconnect(on_waived)
	assert_eq(waived.size(), 1, "waive_late_fee should emit late_fee_waived")
	assert_almost_eq(
		float(waived[0]["amount"]), 3.0, 0.001, "waived amount should match"
	)
	assert_true(
		float(waived[0]["rep"]) > 0.0, "waive should award positive reputation delta"
	)


func test_waive_removes_pending_fee() -> void:
	_controller._pending_late_fees["item_z"] = {"amount": 1.5, "days_late": 1}
	_controller.waive_late_fee("item_z")
	assert_false(
		_controller._pending_late_fees.has("item_z"),
		"Waived fee should be removed from pending"
	)


func test_collect_removes_pending_fee() -> void:
	_controller._pending_late_fees["item_w"] = {"amount": 1.5, "days_late": 1}
	_controller.collect_late_fee("item_w")
	assert_false(
		_controller._pending_late_fees.has("item_w"),
		"Collected fee should be removed from pending"
	)


func test_waive_unknown_item_returns_false() -> void:
	var result: bool = _controller.waive_late_fee("no_such_item")
	assert_false(result, "waive_late_fee on unknown item_id should return false")


func test_collect_unknown_item_returns_false() -> void:
	var result: bool = _controller.collect_late_fee("no_such_item")
	assert_false(result, "collect_late_fee on unknown item_id should return false")


func test_collect_accumulates_daily_total() -> void:
	_controller._daily_late_fee_total = 0.0
	_controller._pending_late_fees["item_1"] = {"amount": 2.5, "days_late": 2}
	_controller._pending_late_fees["item_2"] = {"amount": 1.5, "days_late": 1}
	_controller.collect_late_fee("item_1")
	_controller.collect_late_fee("item_2")
	assert_almost_eq(
		_controller._daily_late_fee_total, 4.0, 0.001,
		"Daily total should accumulate across collected fees"
	)


func test_title_rented_signal_emitted() -> void:
	var rented: Array[Dictionary] = []
	var on_rented: Callable = func(
		item_id: String, fee: float, tier: String
	) -> void:
		rented.append({"item_id": item_id, "fee": fee, "tier": tier})
	EventBus.title_rented.connect(on_rented)

	_controller.process_rental("inst_123", "vhs_new_release", "overnight", 3.5, 1)

	EventBus.title_rented.disconnect(on_rented)
	assert_eq(rented.size(), 1, "process_rental should emit title_rented")
	assert_eq(rented[0]["item_id"], "inst_123")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_new_release_item(
	item_id: String,
	rental_fee: float,
	catalog_price_val: float,
	release_day_val: int,
) -> ItemInstance:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = item_id
	def.item_name = item_id
	def.base_price = 14.0
	def.category = &"vhs_new_release"
	def.store_type = &"rentals"
	def.rental_fee = rental_fee
	def.catalog_price = catalog_price_val
	def.release_day = release_day_val
	def.rental_period_days = 1
	return ItemInstance.create_from_definition(def)


func _make_catalog_item(item_id: String, rental_fee: float) -> ItemInstance:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = item_id
	def.item_name = item_id
	def.base_price = 8.0
	def.category = &"vhs_classic"
	def.store_type = &"rentals"
	def.rental_fee = rental_fee
	def.rental_period_days = 3
	return ItemInstance.create_from_definition(def)
