## Integration test: PocketCreatures store flow covering pack opening rarity
## distribution and tournament-driven demand spikes.
extends GutTest

const STORE_ID: StringName = &"pocket_creatures"
const TEST_SET_TAG: String = "base_set"
const FLOAT_DELTA: float = 0.001
const CARDS_PER_PACK: int = 11
const FIFTY_PACK_COUNT: int = 50

var _inventory: InventorySystem
var _economy: EconomySystem
var _pack_system: PackOpeningSystem
var _seasonal: SeasonalEventSystem
var _market: MarketValueSystem
var _saved_data_loader: DataLoader
var _test_data_loader: DataLoader
var _pack_def: ItemDefinition
var _registered_store: bool = false
var _registered_item_ids: Array[String] = []


func before_each() -> void:
	_saved_data_loader = GameManager.data_loader
	_ensure_store_registry_entry()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(9999.0)

	_test_data_loader = DataLoader.new()
	add_child_autofree(_test_data_loader)
	_populate_test_data_loader()
	GameManager.data_loader = _test_data_loader

	_pack_system = PackOpeningSystem.new()
	_pack_system.initialize(_test_data_loader, _inventory, _economy)

	_seasonal = SeasonalEventSystem.new()
	add_child_autofree(_seasonal)
	_seasonal.initialize(null)

	_market = MarketValueSystem.new()
	add_child_autofree(_market)
	_market.initialize(_inventory, null, _seasonal)


func after_each() -> void:
	GameManager.data_loader = _saved_data_loader
	_cleanup_registry()


# ── Scenario A: Card pack rarity distribution ─────────────────────────────────


func test_pack_removed_from_inventory_after_opening() -> void:
	var pack: ItemInstance = _make_pack_instance()
	_inventory.register_item(pack)
	assert_not_null(
		_inventory.get_item(pack.instance_id),
		"Pack should exist in inventory before opening"
	)
	_pack_system.open_pack(pack.instance_id)
	assert_null(
		_inventory.get_item(pack.instance_id),
		"Pack should be removed from inventory after opening"
	)


func test_card_count_matches_cards_per_pack() -> void:
	var pack: ItemInstance = _make_pack_instance()
	_inventory.register_item(pack)
	var cards: Array[ItemInstance] = _pack_system.open_pack(
		pack.instance_id
	)
	assert_eq(
		cards.size(), CARDS_PER_PACK,
		"Card count should match cards_per_pack from content config"
	)


func test_all_drawn_card_ids_resolve_in_content_registry() -> void:
	var pack: ItemInstance = _make_pack_instance()
	_inventory.register_item(pack)
	var cards: Array[ItemInstance] = _pack_system.open_pack(
		pack.instance_id
	)
	for card: ItemInstance in cards:
		assert_true(
			ContentRegistry.exists(card.definition.id),
			"Card id '%s' should resolve in ContentRegistry" % card.definition.id
		)


func test_double_open_returns_empty() -> void:
	var pack: ItemInstance = _make_pack_instance()
	_inventory.register_item(pack)
	var first: Array[ItemInstance] = _pack_system.open_pack(
		pack.instance_id
	)
	assert_false(
		first.is_empty(),
		"First open should produce cards"
	)
	var second: Array[ItemInstance] = _pack_system.open_pack(
		pack.instance_id
	)
	assert_true(
		second.is_empty(),
		"Second open on the same pack id should return empty (double-open guard)"
	)


func test_50_packs_yield_at_least_one_ultra_rare() -> void:
	var holo_or_better_found: bool = false
	for _i: int in range(FIFTY_PACK_COUNT):
		var pack: ItemInstance = _make_pack_instance()
		_inventory.register_item(pack)
		var cards: Array[ItemInstance] = _pack_system.open_pack(
			pack.instance_id
		)
		for card: ItemInstance in cards:
			var sub: String = card.definition.subcategory
			if sub == "rare_holo" or sub == "secret_rare":
				holo_or_better_found = true
				break
		if holo_or_better_found:
			break
	assert_true(
		holo_or_better_found,
		"50 pack openings should yield at least one holo rare or better"
	)


# ── Scenario B: Tournament demand spike ───────────────────────────────────────


func test_tournament_announced_one_day_before_start() -> void:
	var def: TournamentEventDefinition = _make_tournament_def(
		"test_tournament_a", "singles", 10, 3, 1.5
	)
	_seasonal._tournament_definitions = [def]
	var announced_id: String = ""
	var cb: Callable = func(event_id: String) -> void:
		announced_id = event_id
	EventBus.tournament_event_announced.connect(cb)
	EventBus.day_started.emit(9)
	EventBus.tournament_event_announced.disconnect(cb)
	assert_eq(
		announced_id, "test_tournament_a",
		"tournament_event_announced should fire with the event id on start_day - 1"
	)


func test_demand_multiplier_applied_to_singles_during_tournament() -> void:
	var def: TournamentEventDefinition = _make_tournament_def(
		"test_tournament_b", "singles", 10, 3, 1.5
	)
	_seasonal._tournament_definitions = [def]
	EventBus.day_started.emit(9)
	EventBus.day_started.emit(10)
	var singles_item: ItemInstance = _make_singles_item_instance()
	assert_almost_eq(
		_seasonal.get_tournament_demand_multiplier(singles_item),
		1.5,
		FLOAT_DELTA,
		"Tournament multiplier should be 1.5 for singles during active tournament"
	)


func test_unrelated_category_not_affected_during_tournament() -> void:
	var def: TournamentEventDefinition = _make_tournament_def(
		"test_tournament_c", "singles", 10, 3, 1.5
	)
	_seasonal._tournament_definitions = [def]
	EventBus.day_started.emit(9)
	EventBus.day_started.emit(10)
	var pack_item: ItemInstance = _make_booster_item_instance()
	assert_almost_eq(
		_seasonal.get_tournament_demand_multiplier(pack_item),
		1.0,
		FLOAT_DELTA,
		"Booster pack category should not be affected by a singles tournament"
	)


func test_multiplier_removed_after_tournament_end() -> void:
	var def: TournamentEventDefinition = _make_tournament_def(
		"test_tournament_d", "singles", 10, 3, 1.5
	)
	_seasonal._tournament_definitions = [def]
	EventBus.day_started.emit(9)
	EventBus.day_started.emit(10)
	EventBus.day_started.emit(13)
	var singles_item: ItemInstance = _make_singles_item_instance()
	assert_almost_eq(
		_seasonal.get_tournament_demand_multiplier(singles_item),
		1.0,
		FLOAT_DELTA,
		"Tournament multiplier should return to 1.0 after tournament end day"
	)


func test_market_value_higher_during_tournament_for_matching_category() -> void:
	var def: TournamentEventDefinition = _make_tournament_def(
		"test_tournament_e", "singles", 10, 3, 1.5
	)
	_seasonal._tournament_definitions = [def]
	var singles_item: ItemInstance = _make_singles_item_instance()
	var value_before: float = _market.calculate_item_value(singles_item)
	EventBus.day_started.emit(9)
	EventBus.day_started.emit(10)
	var value_during: float = _market.calculate_item_value(singles_item)
	assert_gt(
		value_during,
		value_before,
		"Market value should increase during tournament for the matching category"
	)
	EventBus.day_started.emit(13)
	var value_after: float = _market.calculate_item_value(singles_item)
	assert_almost_eq(
		value_after,
		value_before,
		FLOAT_DELTA,
		"Market value should return to pre-tournament baseline after tournament ends"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _make_pack_instance() -> ItemInstance:
	return ItemInstance.create(
		_pack_def, "near_mint", 0, _pack_def.base_price
	)


func _make_singles_item_instance() -> ItemInstance:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "test_singles_card"
	def.item_name = "Test Singles Card"
	def.category = "singles"
	def.subcategory = "common"
	def.store_type = "pocket_creatures"
	def.base_price = 100.0
	def.rarity = "common"
	def.condition_range = PackedStringArray(["good", "near_mint", "mint"])
	return ItemInstance.create(def, "good", 0, def.base_price)


func _make_booster_item_instance() -> ItemInstance:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = "test_booster_pack"
	def.item_name = "Test Booster Pack"
	def.category = "booster_packs"
	def.subcategory = "sealed"
	def.store_type = "pocket_creatures"
	def.base_price = 4.0
	def.rarity = "common"
	def.condition_range = PackedStringArray(["good", "near_mint", "mint"])
	return ItemInstance.create(def, "good", 0, def.base_price)


func _make_card_def(
	id: String, subcategory: String, tags: Array[String]
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = id
	def.item_name = id.replace("_", " ").capitalize()
	def.category = "singles"
	def.subcategory = subcategory
	def.store_type = "pocket_creatures"
	def.base_price = 1.0
	def.rarity = "common"
	def.condition_range = PackedStringArray(["good", "near_mint", "mint"])
	def.tags = PackedStringArray(tags)
	return def


func _make_tournament_def(
	id: String,
	card_category: String,
	start_day: int,
	duration_days: int,
	demand_multiplier: float,
) -> TournamentEventDefinition:
	var def := TournamentEventDefinition.new()
	def.id = id
	def.name = id
	def.card_category = card_category
	def.start_day = start_day
	def.duration_days = duration_days
	def.demand_multiplier = demand_multiplier
	def.announcement_text = ""
	def.active_text = ""
	return def


func _populate_test_data_loader() -> void:
	var card_defs: Array[ItemDefinition] = [
		_make_card_def("tc_common_1", "common", [TEST_SET_TAG, "fire"]),
		_make_card_def("tc_common_2", "common", [TEST_SET_TAG, "water"]),
		_make_card_def("tc_common_3", "common", [TEST_SET_TAG, "grass"]),
		_make_card_def("tc_uncommon_1", "uncommon", [TEST_SET_TAG]),
		_make_card_def("tc_uncommon_2", "uncommon", [TEST_SET_TAG]),
		_make_card_def("tc_rare_1", "rare", [TEST_SET_TAG]),
		_make_card_def("tc_holo_1", "rare_holo", [TEST_SET_TAG]),
		_make_card_def("tc_energy_1", "energy", []),
	]

	_pack_def = ItemDefinition.new()
	_pack_def.id = "tc_booster_base_set"
	_pack_def.item_name = "Test Booster Base Set"
	_pack_def.category = "booster_packs"
	_pack_def.subcategory = "sealed"
	_pack_def.store_type = "pocket_creatures"
	_pack_def.base_price = 3.99
	_pack_def.rarity = "common"
	_pack_def.condition_range = PackedStringArray(["good", "near_mint", "mint"])
	_pack_def.tags = PackedStringArray(
		["pack", "booster", "sealed", TEST_SET_TAG]
	)

	for def: ItemDefinition in card_defs:
		_register_test_item(def)
	_register_test_item(_pack_def)


func _register_test_item(def: ItemDefinition) -> void:
	_test_data_loader._items[def.id] = def
	if not ContentRegistry.exists(def.id):
		ContentRegistry.register_entry(
			{"id": def.id, "name": def.item_name}, "item"
		)
		_registered_item_ids.append(def.id)


func _ensure_store_registry_entry() -> void:
	if ContentRegistry.exists("pocket_creatures"):
		_registered_store = false
		return
	ContentRegistry.register_entry(
		{
			"id": "pocket_creatures",
			"name": "PocketCreatures Cards",
			"scene_path": "",
			"backroom_capacity": 2000,
		},
		"store"
	)
	_registered_store = true


func _cleanup_registry() -> void:
	for id: String in _registered_item_ids:
		var sid: StringName = StringName(id)
		ContentRegistry._entries.erase(sid)
		ContentRegistry._types.erase(sid)
		ContentRegistry._display_names.erase(sid)
		for key: StringName in ContentRegistry._aliases.keys():
			if ContentRegistry._aliases[key] == sid:
				ContentRegistry._aliases.erase(key)
	_registered_item_ids.clear()

	if not _registered_store:
		return
	if not ContentRegistry.exists("pocket_creatures"):
		return
	ContentRegistry._entries.erase(&"pocket_creatures")
	ContentRegistry._types.erase(&"pocket_creatures")
	ContentRegistry._display_names.erase(&"pocket_creatures")
	ContentRegistry._scene_map.erase(&"pocket_creatures")
	for key: StringName in ContentRegistry._aliases.keys():
		if ContentRegistry._aliases[key] == &"pocket_creatures":
			ContentRegistry._aliases.erase(key)
