## Integration test verifying save/load state parity across all core systems.
extends GutTest


const PRE_SAVE_CASH: float = 3500.0
const PRE_SAVE_DAY: int = 3
const ITEM_COUNT: int = 2
const SAVE_SLOT: int = 1
const SLOT_A: int = 0
const SLOT_B: int = 1
const OWNED_SLOT_INDEX: int = 0

var _save_manager: SaveManager
var _economy: EconomySystem
var _inventory: InventorySystem
var _time_system: TimeSystem
var _store_state: StoreStateManager
var _reputation: ReputationSystem
var _test_data_loader: DataLoader

var _saved_owned_stores: Array[StringName] = []
var _saved_store_id: StringName = &""
var _saved_data_loader: DataLoader


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_store_id = GameManager.current_store_id
	_saved_data_loader = GameManager.data_loader

	_test_data_loader = DataLoader.new()
	add_child_autofree(_test_data_loader)
	_test_data_loader.load_all_content()
	GameManager.data_loader = _test_data_loader

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(PRE_SAVE_CASH)

	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_test_data_loader)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)

	_store_state = StoreStateManager.new()
	add_child_autofree(_store_state)
	_store_state.initialize(_inventory, _economy)

	_save_manager = SaveManager.new()
	add_child_autofree(_save_manager)
	_save_manager.initialize(_economy, _inventory, _time_system)
	_save_manager.set_reputation_system(_reputation)
	_save_manager.set_store_state_manager(_store_state)


func after_each() -> void:
	for slot: int in range(0, 4):
		_save_manager.delete_save(slot)
	if FileAccess.file_exists(SaveManager.SLOT_INDEX_PATH):
		DirAccess.remove_absolute(SaveManager.SLOT_INDEX_PATH)
	GameManager.owned_stores = _saved_owned_stores
	GameManager.current_store_id = _saved_store_id
	GameManager.data_loader = _saved_data_loader
	ContentRegistry.clear_for_testing()


## Returns the canonical store_id for the first available item definition.
func _get_test_store_id() -> StringName:
	var items: Array[ItemDefinition] = _test_data_loader.get_all_items()
	if items.is_empty():
		return &""
	return ContentRegistry.resolve(items[0].store_type)


## Adds up to `count` items belonging to `store_id` to inventory.
## Returns the instance_ids of added items.
func _populate_inventory(
	store_id: StringName, count: int
) -> Array[String]:
	var result: Array[String] = []
	var all_defs: Array[ItemDefinition] = _test_data_loader.get_all_items()
	for def: ItemDefinition in all_defs:
		if result.size() >= count:
			break
		if ContentRegistry.resolve(def.store_type) != store_id:
			continue
		var item: ItemInstance = ItemInstance.create(
			def, "good", 0, def.base_price
		)
		item.current_location = "backroom"
		_inventory.add_item(store_id, item)
		result.append(item.instance_id)
	return result


## Configures all systems to the known pre-save state.
## Returns the instance_ids of items added to inventory.
func _apply_pre_save_state(store_id: StringName) -> Array[String]:
	_economy._current_cash = PRE_SAVE_CASH
	_time_system.current_day = PRE_SAVE_DAY
	_store_state.register_slot_ownership(OWNED_SLOT_INDEX, store_id)
	GameManager.owned_stores = [store_id]
	_store_state.set_active_store(store_id)
	return _populate_inventory(store_id, ITEM_COUNT)


## Resets all systems to a clean default state simulating a fresh boot.
func _reset_systems() -> void:
	_economy.initialize()
	_time_system.initialize()
	_inventory.initialize(_test_data_loader)
	_store_state.initialize(_inventory, _economy)
	GameManager.owned_stores = []
	GameManager.current_store_id = &""


# Scenario A — Basic state parity: set known state → save → reset → load → verify.
func test_scenario_a_state_parity_after_save_load() -> void:
	var store_id: StringName = _get_test_store_id()
	if store_id.is_empty():
		pass_test("No content loaded — skip")
		return

	var pre_item_ids: Array[String] = _apply_pre_save_state(store_id)
	if pre_item_ids.size() < ITEM_COUNT:
		pass_test(
			"Not enough items for store '%s' — skip" % store_id
		)
		return

	var saved: bool = _save_manager.save_game(SAVE_SLOT)
	assert_true(saved, "save_game should succeed")

	_reset_systems()

	var loaded: bool = _save_manager.load_game(SAVE_SLOT)
	assert_true(loaded, "load_game should succeed")

	assert_almost_eq(
		_economy._current_cash,
		PRE_SAVE_CASH,
		0.01,
		"EconomySystem cash should be restored to %.2f" % PRE_SAVE_CASH
	)
	assert_eq(
		_time_system.current_day,
		PRE_SAVE_DAY,
		"TimeSystem.current_day should be restored to %d" % PRE_SAVE_DAY
	)
	assert_true(
		_store_state.is_owned(OWNED_SLOT_INDEX),
		"Owned slot should be present after load"
	)
	assert_eq(
		_inventory.get_item_count(),
		ITEM_COUNT,
		"InventorySystem should have %d items after load" % ITEM_COUNT
	)
	for id: String in pre_item_ids:
		assert_not_null(
			_inventory.get_item(id),
			"Item '%s' should survive save/load" % id
		)


# Scenario B — Slot isolation: mutating state after loading slot A must not
# corrupt slot B's on-disk data.
func test_scenario_b_slot_isolation_prevents_cross_slot_corruption() -> void:
	var store_id: StringName = _get_test_store_id()
	if store_id.is_empty():
		pass_test("No content loaded — skip")
		return

	_apply_pre_save_state(store_id)

	var saved_a: bool = _save_manager.save_game(SLOT_A)
	var saved_b: bool = _save_manager.save_game(SLOT_B)
	assert_true(saved_a, "save_game to slot A should succeed")
	assert_true(saved_b, "save_game to slot B should succeed")

	var loaded: bool = _save_manager.load_game(SLOT_A)
	assert_true(loaded, "load_game from slot A should succeed")

	_economy._current_cash += 500.0

	assert_true(
		_save_manager.slot_exists(SLOT_B),
		"Slot B should still exist after loading from slot A"
	)
	var slot_b_meta: Dictionary = _save_manager.get_slot_metadata(SLOT_B)
	assert_has(
		slot_b_meta,
		"day_number",
		"Slot B metadata should contain day_number"
	)
	assert_eq(
		int(slot_b_meta["day_number"]),
		PRE_SAVE_DAY,
		"Slot B day_number should be unchanged after mutating state from slot A"
	)
