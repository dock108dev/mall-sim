## GUT tests for RetroGames inspect→grade→price flow (ISSUE-012).
## Covers: PriceResolver grade-tier pricing, signal chain verification.
extends GutTest


var _controller: RetroGames
var _inventory: InventorySystem
var _economy: EconomySystem


func _make_retro_def(id: String, base_price: float) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = "Test %s" % id
	def.store_type = "retro_games"
	def.base_price = base_price
	def.rarity = "common"
	def.category = "cartridge"
	return def


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(500.0)
	_controller = RetroGames.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)


# ── PriceResolver grade-tier pricing ─────────────────────────────────────────

func test_price_resolver_mint_grade_applies_correct_multiplier() -> void:
	var base: float = 40.0
	var multipliers: Array = [{
		"label": "Grade",
		"factor": 1.4,
		"detail": "Mint",
	}]
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"test_mint", base, multipliers, false
	)
	assert_almost_eq(
		result.final_price, base * 1.4, 0.01,
		"Mint grade multiplier 1.4 must produce base × 1.4"
	)


func test_price_resolver_good_grade_is_neutral() -> void:
	var base: float = 40.0
	var multipliers: Array = [{
		"label": "Grade",
		"factor": 1.0,
		"detail": "Good",
	}]
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"test_good", base, multipliers, false
	)
	assert_almost_eq(
		result.final_price, base, 0.01,
		"Good grade multiplier 1.0 must leave price at base"
	)


func test_price_resolver_poor_grade_reduces_price() -> void:
	var base: float = 40.0
	var multipliers: Array = [{
		"label": "Grade",
		"factor": 0.5,
		"detail": "Poor",
	}]
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"test_poor", base, multipliers, false
	)
	assert_almost_eq(
		result.final_price, base * 0.5, 0.01,
		"Poor grade multiplier 0.5 must halve the base price"
	)


func test_grade_audit_trace_includes_grade_step() -> void:
	var multipliers: Array = [{
		"label": "Grade",
		"factor": 1.2,
		"detail": "Near Mint",
	}]
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"audit_item", 30.0, multipliers, false
	)
	var labels: Array[String] = []
	for step: Variant in result.steps:
		if step is PriceResolver.AuditStep:
			labels.append((step as PriceResolver.AuditStep).label)
	assert_true(
		labels.has("Grade"),
		"Audit trace must include a 'Grade' step"
	)


# ── inspect_item ──────────────────────────────────────────────────────────────

func test_inspect_item_emits_inspection_ready() -> void:
	var def: ItemDefinition = _make_retro_def("inspect_test", 25.0)
	var item: ItemInstance = ItemInstance.create_from_definition(def, "good")
	_inventory._items[item.instance_id] = item

	var received: Array[Dictionary] = []
	var capture: Callable = func(
		iid: StringName, cdata: Dictionary
	) -> void:
		received.append({"item_id": iid, "data": cdata})
	EventBus.inspection_ready.connect(capture)

	var ok: bool = _controller.inspect_item(StringName(item.instance_id))
	EventBus.inspection_ready.disconnect(capture)

	assert_true(ok, "inspect_item should return true for a valid item")
	assert_eq(received.size(), 1, "inspection_ready must fire exactly once")
	assert_eq(
		received[0]["item_id"], StringName(item.instance_id),
		"inspection_ready item_id must match the inspected item"
	)
	var cdata: Dictionary = received[0]["data"]
	assert_true(cdata.has("condition"), "condition_data must include 'condition'")
	assert_true(cdata.has("grades"), "condition_data must include 'grades'")


func test_inspect_item_returns_false_without_inventory() -> void:
	var controller: RetroGames = RetroGames.new()
	add_child_autofree(controller)
	var ok: bool = controller.inspect_item(&"nonexistent")
	assert_false(ok, "inspect_item must return false without InventorySystem")


func test_inspect_item_returns_false_for_unknown_item() -> void:
	var ok: bool = _controller.inspect_item(&"no_such_item")
	assert_false(ok, "inspect_item must return false for an unknown item_id")


# ── assign_grade ──────────────────────────────────────────────────────────────

func test_assign_grade_emits_grade_assigned() -> void:
	var def: ItemDefinition = _make_retro_def("grade_item", 50.0)
	var item: ItemInstance = ItemInstance.create_from_definition(def, "good")
	_inventory._items[item.instance_id] = item

	var grade_events: Array[Dictionary] = []
	var on_grade: Callable = func(iid: StringName, gid: String) -> void:
		grade_events.append({"item_id": iid, "grade_id": gid})
	EventBus.grade_assigned.connect(on_grade)

	var ok: bool = _controller.assign_grade(StringName(item.instance_id), "mint")
	EventBus.grade_assigned.disconnect(on_grade)

	assert_true(ok, "assign_grade should succeed for a known grade")
	assert_eq(grade_events.size(), 1, "grade_assigned must fire once")
	assert_eq(grade_events[0]["grade_id"], "mint", "grade_assigned must carry the grade_id")


func test_assign_grade_emits_item_priced() -> void:
	var def: ItemDefinition = _make_retro_def("price_item", 50.0)
	var item: ItemInstance = ItemInstance.create_from_definition(def, "good")
	_inventory._items[item.instance_id] = item

	var price_events: Array[Dictionary] = []
	var on_price: Callable = func(iid: StringName, price: float) -> void:
		price_events.append({"item_id": iid, "price": price})
	EventBus.item_priced.connect(on_price)

	_controller.assign_grade(StringName(item.instance_id), "mint")
	EventBus.item_priced.disconnect(on_price)

	assert_eq(price_events.size(), 1, "item_priced must fire once after grade_assigned")
	assert_gt(price_events[0]["price"], 0.0, "item_priced price must be positive")


func test_assign_grade_unknown_grade_returns_false() -> void:
	var def: ItemDefinition = _make_retro_def("bad_grade", 30.0)
	var item: ItemInstance = ItemInstance.create_from_definition(def, "good")
	_inventory._items[item.instance_id] = item

	var ok: bool = _controller.assign_grade(StringName(item.instance_id), "legendary")
	assert_false(ok, "assign_grade must return false for an unrecognised grade_id")


# ── Signal chain: inspection_ready → grade_assigned → item_priced ─────────────

func test_full_signal_chain_order() -> void:
	var def: ItemDefinition = _make_retro_def("chain_item", 30.0)
	var item: ItemInstance = ItemInstance.create_from_definition(def, "near_mint")
	_inventory._items[item.instance_id] = item

	var event_order: Array[String] = []

	var on_inspect: Callable = func(_iid: StringName, _cd: Dictionary) -> void:
		event_order.append("inspection_ready")
	var on_grade: Callable = func(_iid: StringName, _gid: String) -> void:
		event_order.append("grade_assigned")
	var on_price: Callable = func(_iid: StringName, _p: float) -> void:
		event_order.append("item_priced")

	EventBus.inspection_ready.connect(on_inspect)
	EventBus.grade_assigned.connect(on_grade)
	EventBus.item_priced.connect(on_price)

	_controller.inspect_item(StringName(item.instance_id))
	_controller.assign_grade(StringName(item.instance_id), "near_mint")

	EventBus.inspection_ready.disconnect(on_inspect)
	EventBus.grade_assigned.disconnect(on_grade)
	EventBus.item_priced.disconnect(on_price)

	assert_eq(event_order.size(), 3, "All three signals in the chain must fire")
	assert_eq(event_order[0], "inspection_ready", "inspection_ready must fire first")
	assert_eq(event_order[1], "grade_assigned", "grade_assigned must fire second")
	assert_eq(event_order[2], "item_priced", "item_priced must fire last")


# ── get_item_price ────────────────────────────────────────────────────────────

func test_get_item_price_uses_grade_multiplier() -> void:
	var def: ItemDefinition = _make_retro_def("priced_item", 100.0)
	var item: ItemInstance = ItemInstance.create_from_definition(def, "good")
	_inventory._items[item.instance_id] = item

	# Assign mint grade (multiplier 1.4 from grades.json)
	_controller.assign_grade(StringName(item.instance_id), "mint")
	var price: float = _controller.get_item_price(StringName(item.instance_id))

	assert_almost_eq(price, 140.0, 0.01, "Mint-graded $100 item must price at $140")


func test_get_item_price_without_grade_uses_base() -> void:
	var def: ItemDefinition = _make_retro_def("ungraded_item", 80.0)
	var item: ItemInstance = ItemInstance.create_from_definition(def, "good")
	_inventory._items[item.instance_id] = item

	var price: float = _controller.get_item_price(StringName(item.instance_id))
	assert_almost_eq(price, 80.0, 0.01, "Ungraded item must price at base")


func test_save_load_round_trip_includes_grades() -> void:
	var def: ItemDefinition = _make_retro_def("save_item", 60.0)
	var item: ItemInstance = ItemInstance.create_from_definition(def, "good")
	_inventory._items[item.instance_id] = item

	_controller.assign_grade(StringName(item.instance_id), "fair")
	var saved: Dictionary = _controller.get_save_data()

	assert_true(saved.has("item_grades"), "save_data must include item_grades")
	var grades_map: Dictionary = saved["item_grades"] as Dictionary
	assert_eq(
		grades_map.get(item.instance_id, ""),
		"fair",
		"Saved grades map must record the assigned grade"
	)

	var fresh: RetroGames = RetroGames.new()
	add_child_autofree(fresh)
	fresh.set_inventory_system(_inventory)
	fresh.load_save_data(saved)

	var restored_price: float = fresh.get_item_price(StringName(item.instance_id))
	assert_almost_eq(
		restored_price, 60.0 * 0.75, 0.01,
		"Restored fair-grade price must equal base × 0.75"
	)
