## Unit tests for RetroGamesController — condition grade pricing,
## refurbishment eligibility gate, and console type trend routing.
extends GutTest


var _refurb: RefurbishmentSystem
var _inventory: InventorySystem
var _economy: EconomySystem
var _trend: TrendSystem


func _make_retro_def(
	id: String,
	base_price: float,
	category: String = "cartridge",
	tags: PackedStringArray = PackedStringArray(),
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = "Test %s" % id
	def.store_type = "retro_games"
	def.base_price = base_price
	def.rarity = "common"
	def.category = category
	def.tags = tags
	return def


func _make_item(
	def: ItemDefinition,
	cond: String = "good",
	location: String = "backroom",
) -> ItemInstance:
	var item: ItemInstance = ItemInstance.create_from_definition(def, cond)
	item.current_location = location
	return item


func _register_item(item: ItemInstance) -> void:
	_inventory._items[item.instance_id] = item


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)
	_refurb = RefurbishmentSystem.new()
	add_child_autofree(_refurb)
	_refurb.initialize(_inventory, _economy)
	_trend = TrendSystem.new()
	add_child_autofree(_trend)
	_trend.initialize()


func after_each() -> void:
	if EventBus.day_started.is_connected(_refurb._on_day_started):
		EventBus.day_started.disconnect(_refurb._on_day_started)
	if EventBus.day_started.is_connected(_trend._on_day_started):
		EventBus.day_started.disconnect(_trend._on_day_started)
	if EventBus.item_sold.is_connected(_trend._on_item_sold):
		EventBus.item_sold.disconnect(_trend._on_item_sold)


func test_condition_grade_affects_price() -> void:
	var def: ItemDefinition = _make_retro_def("grade_test", 40.0)
	var item_mint: ItemInstance = _make_item(def, "mint")
	var item_poor: ItemInstance = _make_item(def, "poor")

	var price_mint: float = item_mint.get_current_value()
	var price_poor: float = item_poor.get_current_value()

	assert_gt(
		price_mint, price_poor,
		"MINT condition price must exceed POOR condition price"
	)
	var mint_mult: float = ItemInstance.CONDITION_MULTIPLIERS["mint"]
	var poor_mult: float = ItemInstance.CONDITION_MULTIPLIERS["poor"]
	var expected_diff: float = def.base_price * (mint_mult - poor_mult)
	assert_almost_eq(
		price_mint - price_poor, expected_diff, 0.01,
		"Price differential must match the condition multiplier gap"
	)


func test_refurbishment_eligible_item_can_be_queued() -> void:
	var def: ItemDefinition = _make_retro_def("refurb_eligible", 20.0)
	var item: ItemInstance = _make_item(def, "poor")
	_register_item(item)

	var started_ids: Array[String] = []
	var capture: Callable = func(
		id: String, _cost: float, _duration: int
	) -> void:
		started_ids.append(id)
	EventBus.refurbishment_started.connect(capture)

	var result: bool = _refurb.start_refurbishment(item.instance_id)

	EventBus.refurbishment_started.disconnect(capture)

	assert_true(result, "start_refurbishment should succeed for a poor-condition item")
	assert_eq(
		_refurb.get_active_count(), 1,
		"RefurbishmentSystem queue should contain the item after queuing"
	)
	var queue: Array[Dictionary] = _refurb.get_queue()
	assert_eq(
		queue[0]["instance_id"], item.instance_id,
		"Queue entry must reference the correct instance_id"
	)
	assert_eq(
		started_ids.size(), 1,
		"refurbishment_started signal should fire exactly once"
	)
	assert_eq(
		started_ids[0], item.instance_id,
		"refurbishment_started should carry the queued item's instance_id"
	)


func test_refurbishment_ineligible_item_rejected() -> void:
	var def: ItemDefinition = _make_retro_def("refurb_ineligible", 20.0)
	var item: ItemInstance = _make_item(def, "good")
	_register_item(item)

	var result: bool = _refurb.start_refurbishment(item.instance_id)

	assert_false(
		result,
		"start_refurbishment must return false for a good-condition item"
	)
	assert_eq(
		_refurb.get_active_count(), 0,
		"Queue must remain empty after rejecting an ineligible item"
	)
	var queue: Array[Dictionary] = _refurb.get_queue()
	var found: Array = [false]
	for entry: Dictionary in queue:
		if entry.get("instance_id", "") == item.instance_id:
			found[0] = true
			break
	assert_false(found[0], "Rejected item must not appear in the refurbishment queue")


func test_console_type_demand_routes_correctly() -> void:
	var super_def: ItemDefinition = _make_retro_def(
		"super_cart", 30.0, "cartridge", PackedStringArray(["SuperStation"])
	)
	var mega_def: ItemDefinition = _make_retro_def(
		"mega_cart", 30.0, "cartridge", PackedStringArray(["MegaDrive16"])
	)
	var item_super: ItemInstance = _make_item(super_def, "good")
	var item_mega: ItemInstance = _make_item(mega_def, "good")

	# Inject a HOT trend active on day 0 targeting only the SuperStation tag.
	# active_day=0 ensures the trend is in effect for any GameManager.current_day >= 0.
	_trend._active_trends.append({
		"target_type": "tag",
		"target": "SuperStation",
		"trend_type": TrendSystem.TrendType.HOT,
		"multiplier": 2.0,
		"announced_day": 0,
		"active_day": 0,
		"end_day": 999,
		"fade_end_day": 1001,
	})

	var mult_super: float = _trend.get_trend_multiplier(item_super)
	var mult_mega: float = _trend.get_trend_multiplier(item_mega)

	assert_almost_eq(
		mult_super, 2.0, 0.01,
		"SuperStation item should receive the full trend multiplier"
	)
	assert_almost_eq(
		mult_mega, 1.0, 0.01,
		"MegaDrive16 item must not receive the SuperStation trend multiplier"
	)


func test_mint_condition_item_commands_premium() -> void:
	var def: ItemDefinition = _make_retro_def("mint_item", 50.0)
	var item: ItemInstance = _make_item(def, "mint")

	var price: float = item.get_current_value()
	var mint_multiplier: float = ItemInstance.CONDITION_MULTIPLIERS["mint"]
	var expected: float = def.base_price * mint_multiplier

	assert_almost_eq(
		price, expected, 0.01,
		"MINT price must equal base_price * mint_multiplier"
	)
	assert_gt(
		price, def.base_price,
		"MINT condition price must exceed the item's base price"
	)
