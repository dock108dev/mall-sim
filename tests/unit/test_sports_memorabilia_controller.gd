## Unit tests for SportsMemorabiliaController: authentication workflow,
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
	_controller.initialize_authentication(_inventory, _economy)
	_controller.set_inventory_system(_inventory)


func _make_sports_item(auth_status: String = "none") -> ItemInstance:
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
	var item: ItemInstance = ItemInstance.create_from_definition(def, "mint")
	item.authentication_status = auth_status
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


## ---  Authentication pass ---


func test_authentication_pass_marks_item_authentic() -> void:
	var item: ItemInstance = _make_sports_item("none")
	_inventory._items[item.instance_id] = item

	watch_signals(EventBus)
	var success: bool = (
		_controller.get_authentication_system().authenticate(item.instance_id)
	)

	assert_true(success, "authenticate should return true for eligible item")
	assert_eq(
		item.authentication_status, "authenticated",
		"Item should be marked authenticated after successful auth"
	)
	assert_signal_emitted(
		EventBus, "authentication_completed",
		"authentication_completed should fire on success"
	)
	var params: Array = get_signal_parameters(
		EventBus, "authentication_completed"
	)
	assert_true(
		params[1] as bool,
		"authentication_completed should carry success=true"
	)
	assert_gt(
		_controller.get_authentication_system().get_auth_multiplier(),
		1.0,
		"Auth multiplier should be > 1.0 (authenticity premium applied)"
	)


## --- Authentication fail for suspicious item ---


func test_authentication_fail_flags_suspicious() -> void:
	var item: ItemInstance = _make_sports_item("suspicious")
	_inventory._items[item.instance_id] = item

	watch_signals(EventBus)
	var success: bool = (
		_controller.get_authentication_system().authenticate(item.instance_id)
	)

	assert_false(
		success,
		"authenticate should return false for suspicious item"
	)
	assert_eq(
		item.authentication_status, "suspicious",
		"Suspicious status should remain unchanged after failed auth"
	)
	assert_signal_emitted(
		EventBus, "authentication_completed",
		"authentication_completed should fire even on failure"
	)
	var params: Array = get_signal_parameters(
		EventBus, "authentication_completed"
	)
	assert_false(
		params[1] as bool,
		"authentication_completed should carry success=false for suspicious item"
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


## --- Bonus sale signal on authentic haggle accepted ---


func test_bonus_sale_signal_on_authentic_haggle_accepted() -> void:
	var item: ItemInstance = _make_sports_item("authenticated")
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
		"bonus_sale_completed should fire when authenticated item sells via accepted haggle"
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
		"bonus_amount should be non-zero for authenticated item sale"
	)
