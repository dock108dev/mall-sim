## Integration test: SaveManager save/load round-trip preserves EconomySystem cash,
## InventorySystem stock, StaffSystem roster, ReputationSystem scores, TimeSystem day,
## StoreStateManager owned_slots, MilestoneSystem completed list, and emits no unexpected signals.
extends GutTest

const STORE_ID: StringName = &"store_01"
const ITEM_DEF_ID: String = "item_boots"
const STAFF_DEF_ID: String = "staff_alice"
const SAVE_SLOT: int = 1

const PRE_SAVE_CASH: float = 1234.56
const STOCK_COUNT: int = 7
const PRE_SAVE_REPUTATION: float = 72.5
const PRE_SAVE_DAY: int = 5
const FLOAT_EPSILON: float = 0.001
const MILESTONE_ID: StringName = &"first_sale"

var _economy: EconomySystem
var _inventory: InventorySystem
var _time: TimeSystem
var _reputation: ReputationSystem
var _staff: StaffSystem
var _store_state_manager: StoreStateManager
var _milestone_system: MilestoneSystem
var _data_loader: DataLoader
var _save_manager: SaveManager
var _item_def: ItemDefinition
var _staff_def: StaffDefinition

var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]
var _saved_day: int


func before_each() -> void:
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_day = GameManager.current_day

	GameManager.current_store_id = STORE_ID
	GameManager.owned_stores = [STORE_ID]
	GameManager.current_day = PRE_SAVE_DAY

	_register_store_in_content_registry()

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_test_data()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(0.0)
	_economy._current_cash = PRE_SAVE_CASH

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)
	_seed_inventory()

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.initialize()
	_time.current_day = PRE_SAVE_DAY

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store(String(STORE_ID))
	_reputation._scores[String(STORE_ID)] = PRE_SAVE_REPUTATION

	_staff = StaffSystem.new()
	add_child_autofree(_staff)
	_staff.initialize(_economy, _reputation, _inventory, _data_loader)
	_staff.hire_staff(STAFF_DEF_ID, String(STORE_ID))

	_store_state_manager = StoreStateManager.new()
	add_child_autofree(_store_state_manager)
	_store_state_manager.initialize(_inventory, _economy)
	_store_state_manager.register_slot_ownership(0, STORE_ID)

	_milestone_system = MilestoneSystem.new()
	add_child_autofree(_milestone_system)
	_milestone_system._completed[MILESTONE_ID] = true

	_save_manager = SaveManager.new()
	add_child_autofree(_save_manager)
	_save_manager.initialize(_economy, _inventory, _time)
	_save_manager.set_reputation_system(_reputation)
	_save_manager.set_staff_system(_staff)
	_save_manager.set_store_state_manager(_store_state_manager)
	_save_manager.set_milestone_system(_milestone_system)

	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)


func after_each() -> void:
	_save_manager.delete_save(SAVE_SLOT)
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	GameManager.current_day = _saved_day
	_unregister_store_from_content_registry()


## save_game returns true for an initialized save manager on a valid slot.
func test_save_game_returns_true() -> void:
	var saved: bool = _save_manager.save_game(SAVE_SLOT)
	assert_true(saved, "save_game must return true with initialized systems and a valid slot")


## load_game returns true when a valid save file exists for the requested slot.
func test_load_game_returns_true() -> void:
	assert_true(_save_manager.save_game(SAVE_SLOT), "Precondition: save must succeed")
	var fresh: Dictionary = _create_fresh_systems()
	var loaded: bool = (fresh["save_manager"] as SaveManager).load_game(SAVE_SLOT)
	assert_true(loaded, "load_game must return true when the save file exists")


## EconomySystem cash is preserved exactly (within epsilon) after a round-trip.
func test_cash_preserved_after_round_trip() -> void:
	assert_true(_save_manager.save_game(SAVE_SLOT), "Precondition: save must succeed")
	var fresh: Dictionary = _create_fresh_systems()
	assert_true(
		(fresh["save_manager"] as SaveManager).load_game(SAVE_SLOT),
		"Precondition: load must succeed"
	)
	assert_almost_eq(
		(fresh["economy"] as EconomySystem).get_cash(),
		PRE_SAVE_CASH,
		FLOAT_EPSILON,
		"EconomySystem.get_cash() must equal %.2f after load" % PRE_SAVE_CASH
	)


## InventorySystem stock count for the test item is preserved after a round-trip.
func test_inventory_stock_preserved_after_round_trip() -> void:
	assert_true(_save_manager.save_game(SAVE_SLOT), "Precondition: save must succeed")
	var fresh: Dictionary = _create_fresh_systems()
	assert_true(
		(fresh["save_manager"] as SaveManager).load_game(SAVE_SLOT),
		"Precondition: load must succeed"
	)
	var stock: Array[ItemInstance] = (fresh["inventory"] as InventorySystem).get_stock(STORE_ID)
	assert_eq(
		_count_items_by_def(stock, ITEM_DEF_ID),
		STOCK_COUNT,
		"Stock count for '%s' must be %d after load" % [ITEM_DEF_ID, STOCK_COUNT]
	)


## StaffSystem roster is preserved and staff role is correct after a round-trip.
func test_staff_roster_preserved_after_round_trip() -> void:
	assert_true(_save_manager.save_game(SAVE_SLOT), "Precondition: save must succeed")
	var fresh: Dictionary = _create_fresh_systems()
	assert_true(
		(fresh["save_manager"] as SaveManager).load_game(SAVE_SLOT),
		"Precondition: load must succeed"
	)
	var fresh_staff: StaffSystem = fresh["staff"] as StaffSystem
	var alice: StaffDefinition = fresh_staff.get_staff(StringName(STAFF_DEF_ID))
	assert_not_null(
		alice,
		"StaffSystem.get_staff('%s') must return a definition after load" % STAFF_DEF_ID
	)
	if not alice:
		return
	assert_eq(
		alice.role,
		StaffDefinition.StaffRole.CASHIER,
		"Staff '%s' must have role CASHIER after load" % STAFF_DEF_ID
	)


## ReputationSystem score is preserved within epsilon after a round-trip.
func test_reputation_preserved_after_round_trip() -> void:
	assert_true(_save_manager.save_game(SAVE_SLOT), "Precondition: save must succeed")
	var fresh: Dictionary = _create_fresh_systems()
	assert_true(
		(fresh["save_manager"] as SaveManager).load_game(SAVE_SLOT),
		"Precondition: load must succeed"
	)
	var score: float = (fresh["reputation"] as ReputationSystem).get_reputation(String(STORE_ID))
	assert_almost_eq(
		score,
		PRE_SAVE_REPUTATION,
		FLOAT_EPSILON,
		"ReputationSystem score for '%s' must be %.1f after load" % [STORE_ID, PRE_SAVE_REPUTATION]
	)


## TimeSystem current day is preserved exactly after a round-trip.
func test_day_number_preserved_after_round_trip() -> void:
	assert_true(_save_manager.save_game(SAVE_SLOT), "Precondition: save must succeed")
	var fresh: Dictionary = _create_fresh_systems()
	assert_true(
		(fresh["save_manager"] as SaveManager).load_game(SAVE_SLOT),
		"Precondition: load must succeed"
	)
	assert_eq(
		(fresh["time"] as TimeSystem).current_day,
		PRE_SAVE_DAY,
		"TimeSystem.current_day must be %d after load" % PRE_SAVE_DAY
	)


## StoreStateManager owned_slots contains the pre-save leased store after a round-trip.
func test_owned_slots_preserved_after_round_trip() -> void:
	assert_true(_save_manager.save_game(SAVE_SLOT), "Precondition: save must succeed")
	var fresh: Dictionary = _create_fresh_systems()
	assert_true(
		(fresh["save_manager"] as SaveManager).load_game(SAVE_SLOT),
		"Precondition: load must succeed"
	)
	var fresh_store: StoreStateManager = fresh["store_state"] as StoreStateManager
	assert_true(
		fresh_store.owned_slots.values().has(STORE_ID),
		"owned_slots must contain STORE_ID '%s' after load" % STORE_ID
	)


## MilestoneSystem completed list is preserved exactly after a round-trip.
func test_milestone_list_preserved_after_round_trip() -> void:
	assert_true(_save_manager.save_game(SAVE_SLOT), "Precondition: save must succeed")
	var fresh: Dictionary = _create_fresh_systems()
	assert_true(
		(fresh["save_manager"] as SaveManager).load_game(SAVE_SLOT),
		"Precondition: load must succeed"
	)
	var fresh_ms: MilestoneSystem = fresh["milestone"] as MilestoneSystem
	assert_true(
		fresh_ms.is_complete(MILESTONE_ID),
		"Milestone '%s' must be complete after load" % MILESTONE_ID
	)


## day_ended and transaction_completed must not fire during load_game.
func test_no_unexpected_signals_during_load() -> void:
	assert_true(_save_manager.save_game(SAVE_SLOT), "Precondition: save must succeed")
	var fresh: Dictionary = _create_fresh_systems()
	watch_signals(EventBus)
	(fresh["save_manager"] as SaveManager).load_game(SAVE_SLOT)
	assert_signal_not_emitted(
		EventBus, "day_ended",
		"day_ended must not fire during load_game"
	)
	assert_signal_not_emitted(
		EventBus, "transaction_completed",
		"transaction_completed must not fire during load_game"
	)


# ── Helpers ────────────────────────────────────────────────────────────────────


func _create_fresh_systems() -> Dictionary:
	var fresh_economy := EconomySystem.new()
	add_child_autofree(fresh_economy)
	fresh_economy.initialize(0.0)

	var fresh_inventory := InventorySystem.new()
	add_child_autofree(fresh_inventory)
	fresh_inventory.initialize(_data_loader)

	var fresh_time := TimeSystem.new()
	add_child_autofree(fresh_time)
	fresh_time.initialize()

	var fresh_reputation := ReputationSystem.new()
	add_child_autofree(fresh_reputation)

	var fresh_staff := StaffSystem.new()
	add_child_autofree(fresh_staff)
	fresh_staff.initialize(
		fresh_economy, fresh_reputation, fresh_inventory, _data_loader
	)

	var fresh_store_state := StoreStateManager.new()
	add_child_autofree(fresh_store_state)
	fresh_store_state.initialize(fresh_inventory, fresh_economy)

	var fresh_milestone := MilestoneSystem.new()
	add_child_autofree(fresh_milestone)

	var fresh_mgr := SaveManager.new()
	add_child_autofree(fresh_mgr)
	fresh_mgr.initialize(fresh_economy, fresh_inventory, fresh_time)
	fresh_mgr.set_reputation_system(fresh_reputation)
	fresh_mgr.set_staff_system(fresh_staff)
	fresh_mgr.set_store_state_manager(fresh_store_state)
	fresh_mgr.set_milestone_system(fresh_milestone)

	return {
		"economy": fresh_economy,
		"inventory": fresh_inventory,
		"time": fresh_time,
		"reputation": fresh_reputation,
		"staff": fresh_staff,
		"store_state": fresh_store_state,
		"milestone": fresh_milestone,
		"save_manager": fresh_mgr,
	}


func _seed_inventory() -> void:
	for _i: int in range(STOCK_COUNT):
		var item: ItemInstance = ItemInstance.create(_item_def, "good", 0, 5.0)
		item.current_location = "backroom"
		_inventory.register_item(item)


func _count_items_by_def(
	items: Array[ItemInstance], def_id: String
) -> int:
	var count: Array = [0]
	for item: ItemInstance in items:
		if item.definition and item.definition.id == def_id:
			count[0] += 1
	return count[0]


func _register_test_data() -> void:
	_item_def = ItemDefinition.new()
	_item_def.id = ITEM_DEF_ID
	_item_def.item_name = "Test Boots"
	_item_def.store_type = String(STORE_ID)
	_item_def.base_price = 10.0
	_item_def.rarity = "common"
	_item_def.condition_range = PackedStringArray(["good"])
	_data_loader._items[ITEM_DEF_ID] = _item_def

	_staff_def = StaffDefinition.new()
	_staff_def.staff_id = STAFF_DEF_ID
	_staff_def.display_name = "Alice"
	_staff_def.role = StaffDefinition.StaffRole.CASHIER
	_staff_def.skill_level = 1
	_staff_def.daily_wage = 20.0
	_data_loader._staff_definitions[STAFF_DEF_ID] = _staff_def

	var store_def := StoreDefinition.new()
	store_def.id = String(STORE_ID)
	store_def.store_name = "Test Store 01"
	store_def.store_type = String(STORE_ID)
	store_def.shelf_capacity = 20
	store_def.backroom_capacity = 30
	_data_loader._stores[String(STORE_ID)] = store_def


func _register_store_in_content_registry() -> void:
	if ContentRegistry.exists(String(STORE_ID)):
		return
	ContentRegistry.register_entry(
		{
			"id": String(STORE_ID),
			"name": "Test Store 01",
			"scene_path": "",
			"backroom_capacity": 30,
		},
		"store"
	)


func _unregister_store_from_content_registry() -> void:
	if not ContentRegistry.exists(String(STORE_ID)):
		return
	var entries: Dictionary = ContentRegistry._entries
	var aliases: Dictionary = ContentRegistry._aliases
	var types: Dictionary = ContentRegistry._types
	var display_names: Dictionary = ContentRegistry._display_names
	var scene_map: Dictionary = ContentRegistry._scene_map
	entries.erase(StringName(STORE_ID))
	types.erase(StringName(STORE_ID))
	display_names.erase(StringName(STORE_ID))
	scene_map.erase(StringName(STORE_ID))
	var canonical_key: StringName = StringName(STORE_ID)
	for key: StringName in aliases.keys():
		if aliases[key] == canonical_key:
			aliases.erase(key)
