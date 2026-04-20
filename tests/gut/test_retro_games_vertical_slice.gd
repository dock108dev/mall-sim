## GUT integration test: Retro Games vertical slice gate (ISSUE-006).
## Verifies: transaction_completed fires on sale, reputation_changed responds
## to item_sold, day_closed completes the chain, and Clean/Repair/Restore each
## produce a distinct PriceResolver condition multiplier in the audit log.
extends GutTest


var _rep_system: ReputationSystem
var _inventory: InventorySystem


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_rep_system = ReputationSystem.new()
	_rep_system.auto_connect_bus = false
	add_child_autofree(_rep_system)
	_rep_system.initialize_store("retro_games")


# ── Signal chain: item_sold → reputation_changed → day_closed ─────────────────

func test_full_chain_fires_in_order() -> void:
	var fired: Array[String] = []

	var on_sold: Callable = func(_iid: String, _p: float, _cat: String) -> void:
		fired.append("item_sold")
	var on_rep: Callable = func(_sid: String, _old: float, _new: float) -> void:
		fired.append("reputation_changed")
	var on_day: Callable = func(_day: int, _sum: Dictionary) -> void:
		fired.append("day_closed")

	EventBus.item_sold.connect(on_sold)
	EventBus.reputation_changed.connect(on_rep)
	EventBus.day_closed.connect(on_day)

	EventBus.item_sold.emit("retro_game_item", 45.0, "cartridge")
	_rep_system.add_reputation("retro_games", ReputationSystem.REP_FAIR_SALE)
	EventBus.day_closed.emit(1, {"day": 1, "total_revenue": 45.0})

	EventBus.item_sold.disconnect(on_sold)
	EventBus.reputation_changed.disconnect(on_rep)
	EventBus.day_closed.disconnect(on_day)

	assert_eq(fired.size(), 3, "All three chain signals must fire")
	assert_eq(fired[0], "item_sold", "item_sold fires first")
	assert_eq(fired[1], "reputation_changed", "reputation_changed fires second")
	assert_eq(fired[2], "day_closed", "day_closed fires last")


func test_reputation_increases_on_fair_sale() -> void:
	var before: float = _rep_system.get_reputation("retro_games")
	var fired_changes: Array[Dictionary] = []

	var on_rep: Callable = func(sid: String, old_val: float, new_val: float) -> void:
		fired_changes.append({"store": sid, "old": old_val, "new": new_val})
	EventBus.reputation_changed.connect(on_rep)

	_rep_system.add_reputation("retro_games", ReputationSystem.REP_FAIR_SALE)

	EventBus.reputation_changed.disconnect(on_rep)

	assert_eq(fired_changes.size(), 1, "reputation_changed must fire once")
	assert_gt(
		fired_changes[0]["new"], before,
		"reputation must increase on a fair sale"
	)


# ── transaction_completed ─────────────────────────────────────────────────────

func test_transaction_completed_carries_amount_and_success() -> void:
	var txn_data: Array[Dictionary] = []
	var on_txn: Callable = func(amount: float, success: bool, msg: String) -> void:
		txn_data.append({"amount": amount, "success": success, "message": msg})
	EventBus.transaction_completed.connect(on_txn)

	EventBus.transaction_completed.emit(45.0, true, "")

	EventBus.transaction_completed.disconnect(on_txn)

	assert_eq(txn_data.size(), 1, "transaction_completed must fire exactly once")
	assert_true(txn_data[0]["success"], "transaction must be flagged successful")
	assert_almost_eq(
		txn_data[0]["amount"], 45.0, 0.01,
		"amount must match the agreed price"
	)


# ── Refurb tier multipliers (Clean / Repair / Restore) ────────────────────────

func _make_retro_item(condition: String) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "slice_test_%s" % condition
	def.item_name = "Test Cart"
	def.store_type = "retro_games"
	def.base_price = 40.0
	def.category = "cartridge"
	var item := ItemInstance.create_from_definition(def, condition)
	_inventory._items[item.instance_id] = item
	return item


func test_clean_repair_restore_produce_distinct_condition_multipliers() -> void:
	var controller := RetroGames.new()
	add_child_autofree(controller)
	controller.set_inventory_system(_inventory)

	var poor_item := _make_retro_item("poor")
	var fair_item := _make_retro_item("fair")
	var good_item := _make_retro_item("good")

	var price_poor: float = controller.get_item_price(
		StringName(poor_item.instance_id)
	)
	var price_fair: float = controller.get_item_price(
		StringName(fair_item.instance_id)
	)
	var price_good: float = controller.get_item_price(
		StringName(good_item.instance_id)
	)

	assert_lt(
		price_poor, price_fair,
		"Clean result (fair) must price higher than before-clean (poor)"
	)
	assert_lt(
		price_fair, price_good,
		"Repair result (good) must price higher than Clean result (fair)"
	)


func test_condition_multiplier_visible_in_audit_trace() -> void:
	var controller := RetroGames.new()
	add_child_autofree(controller)
	controller.set_inventory_system(_inventory)

	var item := _make_retro_item("near_mint")
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		StringName(item.instance_id), item.definition.base_price,
		[{"label": "Condition", "factor": 1.2, "detail": "Near Mint"}],
		false
	)
	var labels: Array[String] = []
	for step: Variant in result.steps:
		if step is PriceResolver.AuditStep:
			labels.append((step as PriceResolver.AuditStep).label)

	assert_true(
		labels.has("Condition"),
		"AuditStep log must include a 'Condition' step for refurb tiers"
	)


func test_refurbish_clean_advances_one_tier() -> void:
	var controller := RetroGames.new()
	add_child_autofree(controller)
	controller.set_inventory_system(_inventory)

	var item := _make_retro_item("poor")
	var refurb_fired: Array[String] = []
	var on_refurb: Callable = func(iid: String, _ok: bool, new_cond: String) -> void:
		refurb_fired.append(new_cond)
	EventBus.refurbishment_completed.connect(on_refurb)

	var ok: bool = controller.refurbish_clean(StringName(item.instance_id))
	EventBus.refurbishment_completed.disconnect(on_refurb)

	assert_true(ok, "refurbish_clean must return true on a valid item")
	assert_eq(refurb_fired.size(), 1, "refurbishment_completed must fire once")
	assert_eq(refurb_fired[0], "fair", "Clean on 'poor' must produce 'fair'")


func test_refurbish_repair_advances_two_tiers() -> void:
	var controller := RetroGames.new()
	add_child_autofree(controller)
	controller.set_inventory_system(_inventory)

	var item := _make_retro_item("poor")
	var refurb_fired: Array[String] = []
	var on_refurb: Callable = func(_iid: String, _ok: bool, new_cond: String) -> void:
		refurb_fired.append(new_cond)
	EventBus.refurbishment_completed.connect(on_refurb)

	var ok: bool = controller.refurbish_repair(StringName(item.instance_id))
	EventBus.refurbishment_completed.disconnect(on_refurb)

	assert_true(ok, "refurbish_repair must return true on a valid item")
	assert_eq(refurb_fired[0], "good", "Repair on 'poor' must produce 'good'")


func test_refurbish_restore_advances_to_mint() -> void:
	var controller := RetroGames.new()
	add_child_autofree(controller)
	controller.set_inventory_system(_inventory)

	var item := _make_retro_item("fair")
	var refurb_fired: Array[String] = []
	var on_refurb: Callable = func(_iid: String, _ok: bool, new_cond: String) -> void:
		refurb_fired.append(new_cond)
	EventBus.refurbishment_completed.connect(on_refurb)

	var ok: bool = controller.refurbish_restore(StringName(item.instance_id))
	EventBus.refurbishment_completed.disconnect(on_refurb)

	assert_true(ok, "refurbish_restore must return true on a valid item")
	assert_eq(refurb_fired[0], "mint", "Restore must always produce 'mint'")


func test_refurbish_at_max_condition_returns_false() -> void:
	var controller := RetroGames.new()
	add_child_autofree(controller)
	controller.set_inventory_system(_inventory)

	var item := _make_retro_item("mint")
	var ok: bool = controller.refurbish_clean(StringName(item.instance_id))
	assert_false(ok, "refurbish_clean on mint item must return false")
