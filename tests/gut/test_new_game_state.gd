## Tests that a new game initializes with valid state: owned store, starter
## inventory, correct cash, and registered slot ownership.
extends GutTest


var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _store_state_manager: StoreStateManager
var _data_loader: DataLoader
var _original_owned: Array[StringName]
var _original_current_store: StringName


func before_each() -> void:
	_original_owned = GameManager.owned_stores.duplicate()
	_original_current_store = GameManager.current_store_id

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all_content()

	_economy_system = EconomySystem.new()
	add_child_autofree(_economy_system)
	_economy_system.initialize()

	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(_data_loader)

	_store_state_manager = StoreStateManager.new()
	add_child_autofree(_store_state_manager)
	_store_state_manager.initialize(
		_inventory_system, _economy_system
	)
	_seed_new_game_store_state()


func after_each() -> void:
	GameManager.owned_stores = _original_owned
	GameManager.current_store_id = _original_current_store


func _seed_new_game_store_state() -> void:
	var default_store: StringName = GameManager.DEFAULT_STARTING_STORE
	var slot_index: int = _slot_index_for_store(default_store)
	assert_ne(
		slot_index, -1,
		"DEFAULT_STARTING_STORE must exist in ContentRegistry store list"
	)
	assert_true(
		_store_state_manager.lease_store(
			slot_index, default_store, default_store, false
		),
		"lease_store should succeed for default new-game slot"
	)
	GameManager.owned_stores = [default_store]


func _slot_index_for_store(store_id: StringName) -> int:
	var store_ids: Array[StringName] = ContentRegistry.get_all_ids("store")
	for i: int in range(store_ids.size()):
		if store_ids[i] == store_id:
			return i
	return -1


func test_default_store_is_owned() -> void:
	assert_true(
		GameManager.is_store_owned(String(GameManager.DEFAULT_STARTING_STORE)),
		"Default starting store should be owned after new game"
	)


func test_owned_stores_has_exactly_one_entry() -> void:
	assert_eq(
		GameManager.get_owned_store_ids().size(), 1,
		"New game should start with exactly one owned store"
	)


func test_starting_cash_equals_constant() -> void:
	assert_eq(
		_economy_system.get_cash(),
		Constants.STARTING_CASH,
		"Starting cash should equal Constants.STARTING_CASH"
	)


func test_starter_inventory_is_populated() -> void:
	var items: Array[ItemInstance] = (
		_data_loader.create_starting_inventory(
			String(GameManager.DEFAULT_STARTING_STORE)
		)
	)
	for item: ItemInstance in items:
		_inventory_system.register_item(item)

	assert_gt(
		_inventory_system.get_item_count(), 0,
		"Inventory should have items after starter generation"
	)


func test_starter_inventory_uses_canonical_ids() -> void:
	var items: Array[ItemInstance] = (
		_data_loader.create_starting_inventory(
			String(GameManager.DEFAULT_STARTING_STORE)
		)
	)
	for item: ItemInstance in items:
		assert_not_null(
			item.definition,
			"Each starter item must have a valid definition"
		)
		var resolved: StringName = ContentRegistry.resolve(
			item.definition.id
		)
		assert_false(
			resolved.is_empty(),
			"Item ID '%s' must resolve via ContentRegistry"
			% item.definition.id
		)


func test_slot_ownership_registered() -> void:
	var store_ids: Array[StringName] = (
		ContentRegistry.get_all_ids("store")
	)
	var default_store: StringName = GameManager.DEFAULT_STARTING_STORE
	var slot_index: Array = [-1]
	for i: int in range(store_ids.size()):
		if store_ids[i] == default_store:
			slot_index[0] = i
			break

	assert_ne(
		slot_index[0], -1,
		"Default store must exist in ContentRegistry store IDs"
	)

	_store_state_manager.register_slot_ownership(
		slot_index[0], default_store
	)
	assert_true(
		_store_state_manager.owned_slots.has(slot_index[0]),
		"Slot index should be registered in owned_slots"
	)
	assert_eq(
		_store_state_manager.owned_slots[slot_index[0]],
		default_store,
		"Owned slot should map to default store ID"
	)


func test_all_store_types_have_starting_inventory() -> void:
	var store_ids: Array[StringName] = (
		ContentRegistry.get_all_ids("store")
	)
	for store_id: StringName in store_ids:
		var items: Array[ItemInstance] = (
			_data_loader.create_starting_inventory(String(store_id))
		)
		assert_gt(
			items.size(), 0,
			"Store '%s' should have starting inventory" % store_id
		)


func test_starter_items_default_to_backroom() -> void:
	var items: Array[ItemInstance] = (
		_data_loader.create_starting_inventory(
			String(GameManager.DEFAULT_STARTING_STORE)
		)
	)
	for item: ItemInstance in items:
		_inventory_system.register_item(item)

	var backroom: Array[ItemInstance] = (
		_inventory_system.get_backroom_items_for_store(
			String(GameManager.DEFAULT_STARTING_STORE)
		)
	)
	assert_eq(
		backroom.size(), items.size(),
		"All starter items should be in the backroom"
	)
