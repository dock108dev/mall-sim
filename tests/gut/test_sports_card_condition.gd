## Integration test: full signal chain from condition selection to completed sale.
## Covers: card_condition_selected → PriceResolver → price_set → sale.
extends GutTest


const STORE_ID: StringName = &"sports"
const ITEM_DEF_ID: StringName = &"sports_signed_baseball_sledge"
const BASE_PRICE: float = 95.0
const FLOAT_TOLERANCE: float = 0.001

var _saved_data_loader: DataLoader
var _data_loader: DataLoader
var _inventory: InventorySystem
var _economy: EconomySystem
var _controller: SportsMemorabiliaController


func before_each() -> void:
	_saved_data_loader = GameManager.data_loader
	ContentRegistry.clear_for_testing()

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all_content()
	GameManager.data_loader = _data_loader

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(200.0)

	_controller = SportsMemorabiliaController.new()
	add_child_autofree(_controller)
	_controller.set_inventory_system(_inventory)
	_controller.initialize(1)


func after_each() -> void:
	GameManager.data_loader = _saved_data_loader
	ContentRegistry.clear_for_testing()


func _make_item(condition: String = "good") -> ItemInstance:
	var def: ItemDefinition = ContentRegistry.get_item_definition(ITEM_DEF_ID)
	assert_not_null(def, "Item definition should load from ContentRegistry")
	var item: ItemInstance = ItemInstance.create_from_definition(def, condition)
	_inventory.add_item(STORE_ID, item)
	return item


## Condition scale has exactly 5 levels with distinct multipliers.
func test_five_condition_levels_exist() -> void:
	var expected: Array[String] = ["mint", "near_mint", "good", "fair", "poor"]
	for cond: String in expected:
		assert_true(
			ItemInstance.CONDITION_MULTIPLIERS.has(cond),
			"CONDITION_MULTIPLIERS must include '%s'" % cond
		)
	assert_eq(
		ItemInstance.CONDITION_MULTIPLIERS.size(), 5,
		"CONDITION_MULTIPLIERS must have exactly 5 entries"
	)


func test_condition_multipliers_are_ordered() -> void:
	var mint: float = ItemInstance.CONDITION_MULTIPLIERS["mint"]
	var near_mint: float = ItemInstance.CONDITION_MULTIPLIERS["near_mint"]
	var good: float = ItemInstance.CONDITION_MULTIPLIERS["good"]
	var fair: float = ItemInstance.CONDITION_MULTIPLIERS["fair"]
	var poor: float = ItemInstance.CONDITION_MULTIPLIERS["poor"]
	assert_gt(mint, near_mint, "mint must be worth more than near_mint")
	assert_gt(near_mint, good, "near_mint must be worth more than good")
	assert_gt(good, fair, "good must be worth more than fair")
	assert_gt(fair, poor, "fair must be worth more than poor")


func test_price_resolver_applies_condition_multiplier() -> void:
	var item: ItemInstance = _make_item("good")
	var price: float = _controller.get_item_price(StringName(item.instance_id))
	assert_almost_eq(
		price,
		BASE_PRICE * 1.0,
		FLOAT_TOLERANCE,
		"Good condition should yield base_price × 1.0"
	)


func test_condition_selection_updates_item_and_price() -> void:
	var item: ItemInstance = _make_item("good")
	var price_set_values: Array[float] = []
	var capture: Callable = func(iid: String, p: float) -> void:
		if iid == String(item.instance_id):
			price_set_values.append(p)
	EventBus.price_set.connect(capture)

	EventBus.card_condition_selected.emit(
		StringName(item.instance_id), "mint"
	)

	EventBus.price_set.disconnect(capture)
	assert_eq(item.condition, "mint", "item.condition should be updated to mint")
	assert_eq(
		price_set_values.size(), 1,
		"price_set should fire once after condition selection"
	)
	assert_almost_eq(
		price_set_values[0],
		BASE_PRICE * 2.0,
		FLOAT_TOLERANCE,
		"Mint price should be base_price × 2.0"
	)


func test_condition_selection_emits_price_resolved_with_audit() -> void:
	var item: ItemInstance = _make_item("fair")
	var audit_captures: Array = []
	var capture: Callable = func(
		iid: StringName, _final: float, steps: Array
	) -> void:
		if iid == StringName(item.instance_id):
			audit_captures.append(steps)
	EventBus.price_resolved.connect(capture)

	EventBus.card_condition_selected.emit(
		StringName(item.instance_id), "near_mint"
	)

	EventBus.price_resolved.disconnect(capture)
	assert_eq(
		audit_captures.size(), 1,
		"price_resolved should fire once"
	)
	var steps: Array = audit_captures[0]
	assert_true(steps.size() >= 2, "Audit must have base + condition steps")
	var base_step: PriceResolver.AuditStep = steps[0]
	assert_eq(
		base_step.label, "Base",
		"First audit step must be the canonical 'Base' entry"
	)
	var condition_step: PriceResolver.AuditStep = steps[1]
	assert_eq(
		condition_step.label, "Condition",
		"Condition audit step must follow the base entry"
	)
	assert_almost_eq(
		condition_step.factor,
		ItemInstance.CONDITION_MULTIPLIERS["near_mint"],
		FLOAT_TOLERANCE,
		"Condition audit step factor should match near_mint multiplier"
	)


func test_full_condition_to_sale_signal_chain() -> void:
	var item: ItemInstance = _make_item("poor")
	var sale_signals: Array[Dictionary] = []
	var on_sold: Callable = func(
		iid: String, price: float, _cat: String
	) -> void:
		if iid == String(item.instance_id):
			sale_signals.append({"price": price})
	EventBus.item_sold.connect(on_sold)

	# Select mint condition
	EventBus.card_condition_selected.emit(
		StringName(item.instance_id), "mint"
	)
	var mint_price: float = _controller.get_item_price(
		StringName(item.instance_id)
	)

	# Complete the sale
	EventBus.item_sold.emit(
		String(item.instance_id),
		mint_price,
		String(item.definition.category)
	)

	EventBus.item_sold.disconnect(on_sold)
	assert_eq(item.condition, "mint", "Condition should be mint after selection")
	assert_almost_eq(
		mint_price,
		BASE_PRICE * 2.0,
		FLOAT_TOLERANCE,
		"Sale price should reflect mint condition multiplier"
	)
	assert_eq(sale_signals.size(), 1, "item_sold should fire once")
	assert_almost_eq(
		float(sale_signals[0]["price"]),
		BASE_PRICE * 2.0,
		FLOAT_TOLERANCE,
		"Emitted sale price should match condition-resolved price"
	)


func test_poor_condition_reduces_price_below_base() -> void:
	var item: ItemInstance = _make_item("poor")
	var price: float = _controller.get_item_price(StringName(item.instance_id))
	assert_lt(
		price, BASE_PRICE,
		"Poor condition price should be below base_price"
	)
	assert_almost_eq(
		price,
		BASE_PRICE * 0.25,
		FLOAT_TOLERANCE,
		"Poor condition price should be base_price × 0.25"
	)


func test_unknown_condition_ignored_with_warning() -> void:
	var item: ItemInstance = _make_item("good")
	var original_condition: String = item.condition
	EventBus.card_condition_selected.emit(
		StringName(item.instance_id), "invalid_grade"
	)
	assert_eq(
		item.condition, original_condition,
		"Unknown condition should not change item.condition"
	)


func test_save_data_has_no_authentication_key() -> void:
	var data: Dictionary = _controller.get_save_data()
	assert_false(
		data.has("authentication"),
		"Save data must not contain binary authentication key"
	)
	assert_true(
		data.has("season_cycle"),
		"Save data must contain season_cycle"
	)


func test_price_resolver_audit_format() -> void:
	var multipliers: Array = [
		{"label": "Condition", "factor": 2.0, "detail": "Mint"},
		{"label": "Season Demand", "factor": 1.5, "detail": "Active season boost"},
	]
	var result: PriceResolver.Result = PriceResolver.resolve(10.0, multipliers)
	assert_almost_eq(result.final_price, 30.0, FLOAT_TOLERANCE,
		"10.0 × 2.0 × 1.5 should equal 30.0")
	assert_eq(result.steps.size(), 2, "Audit must have 2 steps")
	var audit_text: String = result.format_audit()
	assert_true(
		audit_text.contains("Condition"),
		"Audit text must include 'Condition' label"
	)
	assert_true(
		audit_text.contains("FINAL"),
		"Audit text must include FINAL price"
	)
