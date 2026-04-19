## Unit tests for SportsMemorabiliaController: condition grading,
## season multiplier logic, and bonus_sale_completed signal on haggle accept.
extends GutTest


var _controller: SportsMemorabiliaController
var _inventory: InventorySystem
var _economy: EconomySystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_controller = SportsMemorabiliaController.new()
	add_child_autofree(_controller)
	_controller.initialize(1)
	_controller.set_inventory_system(_inventory)


func _make_sports_item(condition: String = "good") -> ItemInstance:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "test_jersey"
	def.item_name = "Test Jersey"
	def.category = "memorabilia"
	def.store_type = "sports"
	def.base_price = 150.0
	def.rarity = "rare"
	def.tags = PackedStringArray(["CBF", "memorabilia"])
	def.condition_range = PackedStringArray(["good", "near_mint", "mint"])
	def.suspicious_chance = 0.0
	var item: ItemInstance = ItemInstance.create_from_definition(def, condition)
	return item


func _make_sports_item_for_season(league_tag: String) -> ItemInstance:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "test_season_item"
	def.item_name = "Season Test Item"
	def.category = "memorabilia"
	def.store_type = "sports_memorabilia"
	def.base_price = 80.0
	def.rarity = "common"
	def.tags = PackedStringArray([league_tag])
	def.condition_range = PackedStringArray(["good"])
	return ItemInstance.create_from_definition(def, "good")


## --- Condition grading ---


func test_condition_selection_updates_item_condition() -> void:
	var item: ItemInstance = _make_sports_item("good")
	_inventory._items[item.instance_id] = item

	EventBus.card_condition_selected.emit(
		StringName(item.instance_id), "mint"
	)

	assert_eq(
		item.condition, "mint",
		"card_condition_selected should update item.condition to mint"
	)


func test_condition_selection_emits_price_set() -> void:
	var item: ItemInstance = _make_sports_item("good")
	_inventory._items[item.instance_id] = item

	var prices: Array[float] = []
	var capture: Callable = func(iid: String, p: float) -> void:
		if iid == String(item.instance_id):
			prices.append(p)
	EventBus.price_set.connect(capture)

	EventBus.card_condition_selected.emit(
		StringName(item.instance_id), "mint"
	)

	EventBus.price_set.disconnect(capture)
	assert_eq(prices.size(), 1, "price_set should emit once after condition selection")
	assert_almost_eq(
		prices[0],
		150.0 * 2.0,
		0.001,
		"Mint condition price should be base_price × 2.0"
	)


## --- In-season multiplier applied ---


func test_in_season_multiplier_applied() -> void:
	var season: SeasonCycleSystem = _controller.get_season_cycle()
	# Force CBF (index 0) to HOT phase with no upcoming rotation
	season.load_save_data({
		"hot_index": 0,
		"next_rotation_day": 100,
		"announced": false,
		"current_day": 1,
	})

	var item: ItemInstance = _make_sports_item_for_season("CBF")
	var multiplier: float = season.get_season_multiplier(item)

	assert_almost_eq(
		multiplier,
		SeasonCycleSystem.PHASE_MULTIPLIERS[SeasonCycleSystem.SeasonPhase.HOT],
		0.01,
		"HOT league item should receive the HOT phase multiplier"
	)
	assert_gt(
		multiplier, 1.0,
		"In-season multiplier must be > 1.0 (base * in_season_multiplier)"
	)


## --- Out-of-season: no multiplier ---


func test_out_of_season_no_multiplier() -> void:
	var season: SeasonCycleSystem = _controller.get_season_cycle()
	# hot_index=0 → CBF=HOT, NHA=WARM, GPL=COLD (offset 2 wraps to COLD)
	season.load_save_data({
		"hot_index": 0,
		"next_rotation_day": 100,
		"announced": false,
		"current_day": 1,
	})

	var item: ItemInstance = _make_sports_item_for_season("GPL")
	var multiplier: float = season.get_season_multiplier(item)

	assert_almost_eq(
		multiplier,
		SeasonCycleSystem.PHASE_MULTIPLIERS[SeasonCycleSystem.SeasonPhase.COLD],
		0.01,
		"COLD league item should receive the COLD phase multiplier (no seasonal boost)"
	)
	assert_true(
		multiplier <= 1.0,
		"Out-of-season multiplier must be <= 1.0 (no seasonal boost applied)"
	)


## --- Bonus sale signal on mint-condition haggle accepted ---


func test_bonus_sale_signal_on_mint_haggle_accepted() -> void:
	var item: ItemInstance = _make_sports_item("mint")
	_inventory._items[item.instance_id] = item
	item.player_set_price = 200.0

	watch_signals(EventBus)
	EventBus.haggle_completed.emit(
		SportsMemorabiliaController.STORE_ID,
		StringName(item.instance_id),
		180.0,
		200.0,
		true,
		2,
	)

	assert_signal_emitted(
		EventBus, "bonus_sale_completed",
		"bonus_sale_completed should fire when mint-condition item sells via accepted haggle"
	)
	var params: Array = get_signal_parameters(EventBus, "bonus_sale_completed")
	assert_eq(
		params[0] as StringName,
		StringName(item.instance_id),
		"bonus_sale_completed should carry the correct item_id"
	)
	var bonus_amount: float = params[1] as float
	assert_gt(
		bonus_amount, 0.0,
		"bonus_amount should be non-zero for mint-condition item sale"
	)


func test_no_bonus_sale_for_good_condition_haggle() -> void:
	var item: ItemInstance = _make_sports_item("good")
	_inventory._items[item.instance_id] = item

	watch_signals(EventBus)
	EventBus.haggle_completed.emit(
		SportsMemorabiliaController.STORE_ID,
		StringName(item.instance_id),
		180.0,
		200.0,
		true,
		2,
	)

	assert_signal_not_emitted(
		EventBus, "bonus_sale_completed",
		"No bonus sale for good (×1.0) condition item"
	)
