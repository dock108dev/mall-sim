## Integration test: PocketCreatures store flow — pack opening, card
## inventory, and tournament eligibility.
extends GutTest

var _inventory: InventorySystem
var _economy: EconomySystem
var _data_loader: DataLoader
var _controller: PocketCreaturesStoreController
var _tournament: TournamentSystem
var _reputation: ReputationSystem
var _customer: CustomerSystem
var _fixture_placement: FixturePlacementSystem

const STORE_ID: StringName = &"pocket_creatures"
const PACK_ID: String = "pc_booster_base_set"
const PACK_BASE_PRICE: float = 3.99
const STARTING_CASH: float = 5000.0
const BACKROOM_CAPACITY: int = 500


func before_each() -> void:
	_register_store_in_content_registry()

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
	add_child_autofree(_reputation)

	_customer = CustomerSystem.new()
	add_child_autofree(_customer)

	_fixture_placement = FixturePlacementSystem.new()
	add_child_autofree(_fixture_placement)

	_controller = PocketCreaturesStoreController.new()
	add_child_autofree(_controller)
	_controller.set_economy_system(_economy)
	_controller.initialize()
	_controller.initialize_pack_system(_data_loader, _inventory)

	_tournament = TournamentSystem.new()
	add_child_autofree(_tournament)
	_tournament.initialize(
		_economy, _reputation, _customer,
		_fixture_placement, _data_loader
	)
	_controller.set_tournament_system(_tournament)


func after_each() -> void:
	_unregister_store_from_content_registry()


func test_open_pack_returns_non_empty_array() -> void:
	var pack: ItemInstance = _create_and_stock_pack()
	var cards: Array[ItemInstance] = (
		_controller.pack_opening_system.open_pack(pack.instance_id)
	)
	assert_gt(
		cards.size(), 0,
		"open_pack returns non-empty Array for booster pack"
	)


func test_opened_cards_present_in_inventory() -> void:
	var pack: ItemInstance = _create_and_stock_pack()
	var cards: Array[ItemInstance] = (
		_controller.pack_opening_system.open_pack(pack.instance_id)
	)
	assert_gt(cards.size(), 0, "Cards were generated")

	for card: ItemInstance in cards:
		var found: ItemInstance = _inventory.get_item(card.instance_id)
		assert_not_null(
			found,
			"Card '%s' present in InventorySystem" % card.instance_id
		)


func test_rare_card_appears_across_100_opens() -> void:
	var rare_found: bool = false
	var rare_subcategories: Array[String] = [
		"rare", "rare_holo", "secret_rare",
	]

	for i: int in range(100):
		var pack: ItemInstance = _create_and_stock_pack()
		var cards: Array[ItemInstance] = (
			_controller.pack_opening_system.open_pack(pack.instance_id)
		)
		for card: ItemInstance in cards:
			if not card.definition:
				continue
			if card.definition.subcategory in rare_subcategories:
				rare_found = true
				break
		if rare_found:
			break

	assert_true(
		rare_found,
		"At least 1 rare+ card appears across 100 pack opens"
	)


func test_tournament_scheduling_and_activation() -> void:
	_place_tournament_table()
	GameManager.current_store_id = STORE_TYPE_STR

	assert_true(
		_tournament.can_host_tournament(),
		"Can host tournament with table placed"
	)

	var started: bool = _tournament.start_tournament(
		TournamentSystem.TournamentSize.SMALL
	)
	assert_true(started, "Tournament started successfully")
	assert_true(
		_tournament.is_active(),
		"Tournament is ACTIVE after starting"
	)


func test_tournament_completes_and_awards_prize() -> void:
	_place_tournament_table()
	GameManager.current_store_id = STORE_TYPE_STR

	_tournament.start_tournament(
		TournamentSystem.TournamentSize.SMALL
	)
	assert_true(_tournament.is_active(), "Tournament is active")

	var completed_fired: bool = false
	var completed_participants: int = 0
	var completed_revenue: float = 0.0

	var on_completed := func(
		participants: int, revenue: float
	) -> void:
		completed_fired = true
		completed_participants = participants
		completed_revenue = revenue

	EventBus.tournament_completed.connect(on_completed)

	var cash_before: float = _economy.get_cash()

	EventBus.item_sold.emit("test_card_001", 15.0, "singles")
	EventBus.item_sold.emit("test_card_002", 10.0, "singles")

	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.EVENING)

	assert_true(completed_fired, "tournament_completed signal fires")
	assert_false(
		_tournament.is_active(),
		"Tournament is no longer active after completion"
	)
	assert_gt(
		completed_participants, 0,
		"Participant count is positive"
	)

	EventBus.tournament_completed.disconnect(on_completed)


func test_tournament_cooldown_after_completion() -> void:
	_place_tournament_table()
	GameManager.current_store_id = STORE_TYPE_STR

	_tournament.start_tournament(
		TournamentSystem.TournamentSize.SMALL
	)
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.EVENING)

	assert_eq(
		_tournament.get_cooldown_remaining(),
		TournamentSystem.COOLDOWN_DAYS,
		"Cooldown set after tournament completion"
	)

	for i: int in range(TournamentSystem.COOLDOWN_DAYS):
		EventBus.day_started.emit(i + 2)

	assert_eq(
		_tournament.get_cooldown_remaining(), 0,
		"Cooldown reaches 0 after enough days pass"
	)


func test_full_flow_pack_to_tournament() -> void:
	var pack: ItemInstance = _create_and_stock_pack()
	var cards: Array[ItemInstance] = (
		_controller.pack_opening_system.open_pack(pack.instance_id)
	)
	assert_gt(cards.size(), 0, "Pack opened with cards")

	for card: ItemInstance in cards:
		var found: ItemInstance = _inventory.get_item(card.instance_id)
		assert_not_null(found, "Card in inventory")

	_place_tournament_table()
	GameManager.current_store_id = STORE_TYPE_STR

	var cash_before_tournament: float = _economy.get_cash()
	var started: bool = _tournament.start_tournament(
		TournamentSystem.TournamentSize.SMALL
	)
	assert_true(started, "Tournament started")
	assert_almost_eq(
		_economy.get_cash(),
		cash_before_tournament - TournamentSystem.SMALL_COST,
		0.01,
		"Tournament cost deducted"
	)

	EventBus.item_sold.emit("sale_during_tourney", 20.0, "singles")
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.EVENING)

	assert_false(
		_tournament.is_active(),
		"Tournament completed after EVENING phase"
	)


# -- Helpers ----------------------------------------------------------

const STORE_TYPE_STR: String = "pocket_creatures"


func _create_pack_definition() -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = PACK_ID
	def.item_name = "Base Set Booster"
	def.category = "booster_packs"
	def.subcategory = "sealed"
	def.store_type = "pocket_creatures"
	def.base_price = PACK_BASE_PRICE
	def.rarity = "common"
	def.condition_range = PackedStringArray(
		["good", "near_mint", "mint"]
	)
	def.tags = PackedStringArray(
		["base_set", "sealed", "booster", "pack"]
	)
	return def


func _create_and_stock_pack() -> ItemInstance:
	var def: ItemDefinition = _create_pack_definition()
	var pack: ItemInstance = ItemInstance.create(
		def, "mint", 0, PACK_BASE_PRICE
	)
	_inventory.add_item(STORE_ID, pack)
	return pack


func _place_tournament_table() -> void:
	_fixture_placement.register_existing_fixture(
		"tournament_table_001",
		"tournament_table",
		Vector2i(0, 0),
		0,
		false,
		0.0,
	)


func _register_store_in_content_registry() -> void:
	if ContentRegistry.exists("pocket_creatures"):
		return
	ContentRegistry.register_entry(
		{
			"id": "pocket_creatures",
			"name": "PocketCreatures Cards",
			"scene_path": "",
			"backroom_capacity": BACKROOM_CAPACITY,
		},
		"store"
	)


func _unregister_store_from_content_registry() -> void:
	if not ContentRegistry.exists("pocket_creatures"):
		return
	var entries: Dictionary = ContentRegistry._entries
	var aliases: Dictionary = ContentRegistry._aliases
	var types: Dictionary = ContentRegistry._types
	var display_names: Dictionary = ContentRegistry._display_names
	var scene_map: Dictionary = ContentRegistry._scene_map
	entries.erase(&"pocket_creatures")
	types.erase(&"pocket_creatures")
	display_names.erase(&"pocket_creatures")
	scene_map.erase(&"pocket_creatures")
	var alias_key: StringName = StringName("pocket_creatures")
	for key: StringName in aliases.keys():
		if aliases[key] == alias_key:
			aliases.erase(key)
