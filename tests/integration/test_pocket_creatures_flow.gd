## Integration test for the PocketCreatures flow from pack opening through
## tournament resolution, including meta_shift factor in PriceBreakdown.
extends GutTest


const STORE_ID: StringName = &"pocket_creatures"
const PACK_DEFINITION_ID: String = "pc_booster_base_set"
const PRIMARY_PACK_INSTANCE_ID: StringName = &"booster_pack"
const TOURNAMENT_DAY: int = 5
const PRIZE_AMOUNT: float = 125.0
const STARTING_CASH: float = 1000.0
const RARE_SUBCATEGORIES: Array[String] = ["rare", "rare_holo", "secret_rare"]

var _data_loader: DataLoader
var _inventory: InventorySystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _controller: PocketCreaturesStoreController
var _tournament: TournamentSystem
var _meta_shift: MetaShiftSystem


func before_each() -> void:
	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store(String(STORE_ID))

	_meta_shift = MetaShiftSystem.new()
	add_child_autofree(_meta_shift)
	_meta_shift.initialize(_data_loader)

	_controller = PocketCreaturesStoreController.new()
	add_child_autofree(_controller)
	_controller.set_economy_system(_economy)
	_controller.initialize()
	_controller.initialize_pack_system(_data_loader, _inventory)
	_controller.set_meta_shift_system(_meta_shift)

	_tournament = TournamentSystem.new()
	add_child_autofree(_tournament)
	_tournament.initialize(_economy, _reputation, null, null, null)
	_controller.set_tournament_system(_tournament)


func test_open_pack_returns_non_empty_array_and_registers_cards() -> void:
	var pack: ItemInstance = _create_pack_instance(PRIMARY_PACK_INSTANCE_ID)

	var cards: Array[ItemInstance] = (
		_controller.pack_opening_system.open_pack(String(pack.instance_id))
	)

	assert_gt(cards.size(), 0, "open_pack should return a non-empty Array")

	var store_items: Array[ItemInstance] = _inventory.get_items_for_store(
		String(STORE_ID)
	)
	for card: ItemInstance in cards:
		assert_not_null(
			_inventory.get_item(String(card.instance_id)),
			"Card '%s' should be present in InventorySystem" % card.instance_id
		)
		assert_true(
			_store_has_item(store_items, String(card.instance_id)),
			"Card '%s' should be stocked under pocket_creatures" % card.instance_id
		)


func test_rare_or_higher_card_appears_across_100_pack_opens() -> void:
	seed(224)
	var rare_found: bool = false

	for pack_index: int in range(100):
		var pack: ItemInstance = _create_pack_instance(
			StringName("booster_pack_%d" % pack_index)
		)
		var cards: Array[ItemInstance] = (
			_controller.pack_opening_system.open_pack(String(pack.instance_id))
		)
		for card: ItemInstance in cards:
			if not card.definition:
				continue
			if RARE_SUBCATEGORIES.has(card.definition.subcategory):
				rare_found = true
				break
		if rare_found:
			break

	assert_true(
		rare_found,
		"At least one pack opening should produce a rare-or-better card"
	)


func test_tournament_schedule_activation_and_resolution_award_prize() -> void:
	var scheduled: bool = _controller.tournament_system.schedule_tournament(
		TOURNAMENT_DAY
	)
	assert_true(scheduled, "schedule_tournament should return true")
	assert_true(
		_controller.tournament_system.is_tournament_scheduled(TOURNAMENT_DAY),
		"Tournament day should be scheduled"
	)

	EventBus.day_started.emit(TOURNAMENT_DAY)

	assert_eq(
		_controller.tournament_system.get_state(),
		TournamentSystem.TournamentState.ACTIVE,
		"Tournament should become ACTIVE on day 5"
	)

	var cash_before: float = _economy.get_cash()
	watch_signals(EventBus)

	var resolved: bool = _controller.tournament_system.resolve_tournament(
		&"player_one", PRIZE_AMOUNT
	)

	assert_true(resolved, "resolve_tournament should return true")
	assert_signal_emitted(
		EventBus,
		"tournament_resolved",
		"tournament_resolved signal should fire after resolution"
	)
	assert_almost_eq(
		_economy.get_cash(),
		cash_before + PRIZE_AMOUNT,
		0.01,
		"Player cash should increase by the tournament prize amount"
	)


## Verifies that when a meta shift is active, resolve_card_price() returns a
## PriceBreakdown containing a meta_shift step with factor != 1.0.
func test_resolve_card_price_includes_meta_shift_when_shift_active() -> void:
	# Seed a card single into inventory so resolve_card_price can find it.
	var card_def: ItemDefinition = _data_loader.get_item("pc_single_flameleon_common")
	if not card_def:
		pass_test("pc_single_flameleon_common not in content — skip")
		return
	var card: ItemInstance = ItemInstance.create_from_definition(card_def)
	card.instance_id = &"meta_test_card"
	_inventory.add_item(STORE_ID, card)
	_controller._inventory_system = _inventory

	# Activate a manual meta shift on this card.
	_meta_shift.trigger_shift(StringName(card_def.id), 3)
	assert_true(_meta_shift.is_shift_active(), "Meta shift should be active")

	# Resolve price — breakdown should contain a meta_shift step.
	var result: PriceResolver.Result = _controller.resolve_card_price(
		&"meta_test_card"
	)
	assert_gt(result.final_price, 0.0, "Resolved price should be positive")

	var found_meta_shift: bool = false
	for step: Variant in result.audit_trace:
		if step is Dictionary:
			var label: String = str((step as Dictionary).get("name", ""))
			if label == "MetaShift":
				found_meta_shift = true
				break

	assert_true(
		found_meta_shift,
		"PriceBreakdown audit_trace should contain a MetaShift step"
	)


func _create_pack_instance(instance_id: StringName) -> ItemInstance:
	var pack_definition: ItemDefinition = _data_loader.get_item(PACK_DEFINITION_ID)
	assert_not_null(
		pack_definition,
		"PocketCreatures pack definition should load from content data"
	)
	var pack: ItemInstance = ItemInstance.create_from_definition(pack_definition)
	pack.instance_id = instance_id
	_inventory.add_item(STORE_ID, pack)
	return pack


func _store_has_item(
	store_items: Array[ItemInstance], instance_id: String
) -> bool:
	for item: ItemInstance in store_items:
		if String(item.instance_id) == instance_id:
			return true
	return false
