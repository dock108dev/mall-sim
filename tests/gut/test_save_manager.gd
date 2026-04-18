## GUT coverage for SaveManager save paths, round-trips, errors, auto-save, and metadata.
extends GutTest


const STORE_ID: StringName = &"sports"
const ITEM_ID: StringName = &"test_signed_ball"
const CUSTOM_STORE_NAME: String = "Champions Corner"

var _save_manager: SaveManager
var _economy: EconomySystem
var _inventory: InventorySystem
var _time_system: TimeSystem
var _reputation: ReputationSystem
var _store_state_manager: StoreStateManager
var _data_loader: DataLoader
var _item_definition: ItemDefinition

var _saved_data_loader = null
var _saved_difficulty_config: Dictionary = {}
var _saved_difficulty_tiers: Dictionary = {}
var _saved_difficulty_order: Array[StringName] = []
var _saved_difficulty_tier_id: StringName = &""
var _saved_difficulty_assisted: bool = false
var _saved_difficulty_initialized: bool = false
var _saved_difficulty_downgrade_used: bool = false


func before_each() -> void:
	if is_instance_valid(GameManager.data_loader):
		_saved_data_loader = GameManager.data_loader
	else:
		_saved_data_loader = null
	_saved_difficulty_config = DataLoaderSingleton._difficulty_config.duplicate(true)
	_saved_difficulty_tiers = DifficultySystemSingleton._tiers.duplicate(true)
	_saved_difficulty_order = DifficultySystemSingleton._tier_order.duplicate()
	_saved_difficulty_tier_id = DifficultySystemSingleton._current_tier_id
	_saved_difficulty_assisted = DifficultySystemSingleton._assisted
	_saved_difficulty_initialized = DifficultySystemSingleton._initialized
	_saved_difficulty_downgrade_used = (
		DifficultySystemSingleton.used_difficulty_downgrade
	)

	ContentRegistry.clear_for_testing()
	_configure_difficulty()
	_register_catalog()
	_create_systems()
	_seed_store_state()


func after_each() -> void:
	for slot: int in range(
		SaveManager.AUTO_SAVE_SLOT,
		SaveManager.MAX_MANUAL_SLOTS + 1
	):
		if _save_manager:
			_save_manager.delete_save(slot)
	if FileAccess.file_exists(SaveManager.SLOT_INDEX_PATH):
		DirAccess.remove_absolute(SaveManager.SLOT_INDEX_PATH)

	ContentRegistry.clear_for_testing()
	if is_instance_valid(_saved_data_loader):
		GameManager.data_loader = _saved_data_loader
	else:
		GameManager.data_loader = null

	DataLoaderSingleton._difficulty_config = _saved_difficulty_config.duplicate(true)
	DifficultySystemSingleton._tiers = _saved_difficulty_tiers.duplicate(true)
	DifficultySystemSingleton._tier_order = _saved_difficulty_order.duplicate()
	DifficultySystemSingleton._current_tier_id = _saved_difficulty_tier_id
	DifficultySystemSingleton._assisted = _saved_difficulty_assisted
	DifficultySystemSingleton._initialized = _saved_difficulty_initialized
	DifficultySystemSingleton.used_difficulty_downgrade = (
		_saved_difficulty_downgrade_used
	)


func test_save_game_creates_valid_file_for_each_slot() -> void:
	_seed_round_trip_state()

	for slot: int in range(
		SaveManager.AUTO_SAVE_SLOT,
		SaveManager.MAX_MANUAL_SLOTS + 1
	):
		assert_true(
			_save_manager.save_game(slot),
			"save_game should succeed for slot %d" % slot
		)
		assert_true(
			FileAccess.file_exists(_save_manager._get_slot_path(slot)),
			"Slot %d should create a file at the expected path" % slot
		)
		var raw: Dictionary = _read_raw_save(slot)
		var save_metadata: Dictionary = raw.get("save_metadata", {}) as Dictionary
		assert_eq(
			int(save_metadata.get("day_number", 0)),
			7,
			"Slot %d should persist metadata.day_number" % slot
		)


func test_save_and_load_round_trip_restores_core_state() -> void:
	var original_item: ItemInstance = _seed_round_trip_state()
	var expected_reputation: float = _reputation.get_reputation(String(STORE_ID))

	assert_true(_save_manager.save_game(1), "Precondition: save should succeed")

	_economy._current_cash = 0.0
	_time_system.current_day = 1
	_reputation.reset()
	_inventory.load_save_data({})
	_store_state_manager.owned_slots = {}
	_store_state_manager.active_store_id = &""

	assert_true(_save_manager.load_game(1), "Load should succeed")

	assert_almost_eq(
		_economy.get_cash(),
		4321.75,
		0.01,
		"Player cash should survive the round-trip"
	)
	assert_eq(
		_time_system.current_day,
		7,
		"Day number should survive the round-trip"
	)
	assert_almost_eq(
		_reputation.get_reputation(String(STORE_ID)),
		expected_reputation,
		0.01,
		"Reputation should survive the round-trip"
	)
	assert_eq(
		_inventory.get_item_count(),
		1,
		"Inventory item count should survive the round-trip"
	)
	var loaded_item: ItemInstance = _inventory.get_item(String(original_item.instance_id))
	assert_not_null(loaded_item, "Saved inventory item should be restored")
	assert_eq(
		String(loaded_item.definition.id),
		String(ITEM_ID),
		"Inventory item definition should survive the round-trip"
	)
	assert_eq(
		loaded_item.current_location,
		"shelf:front_1",
		"Inventory location should survive the round-trip"
	)


func test_save_file_contains_current_save_version() -> void:
	_seed_round_trip_state()

	assert_true(_save_manager.save_game(1), "Precondition: save should succeed")

	var raw: Dictionary = _read_raw_save(1)
	assert_eq(
		int(raw.get("save_version", -1)),
		SaveManager.CURRENT_SAVE_VERSION,
		"save_version should match CURRENT_SAVE_VERSION"
	)


func test_load_missing_file_returns_error_without_crashing() -> void:
	watch_signals(EventBus)

	assert_false(
		_save_manager.load_game(2),
		"Loading a missing slot should return false"
	)
	assert_signal_emitted(
		EventBus,
		"save_load_failed",
		"Missing save should emit save_load_failed"
	)


func test_load_corrupt_file_returns_error_without_crashing() -> void:
	_write_raw_text(2, "{ invalid_json")
	watch_signals(EventBus)

	assert_false(
		_save_manager.load_game(2),
		"Loading a corrupt slot should return false"
	)
	assert_signal_emitted(
		EventBus,
		"save_load_failed",
		"Corrupt save should emit save_load_failed"
	)


func test_auto_save_writes_to_auto_save_slot_after_day_acknowledged() -> void:
	_seed_round_trip_state()
	_time_system.current_day = 11

	_save_manager._on_day_ended(11)
	assert_false(
		_save_manager.slot_exists(SaveManager.AUTO_SAVE_SLOT),
		"Auto-save should not run until day_acknowledged is emitted"
	)

	_save_manager._on_day_acknowledged()
	assert_true(
		_save_manager.slot_exists(SaveManager.AUTO_SAVE_SLOT),
		"Auto-save should write to slot 0 after day_acknowledged"
	)

	var metadata: Dictionary = _save_manager.get_slot_metadata(
		SaveManager.AUTO_SAVE_SLOT
	)
	assert_eq(
		int(metadata.get("day", 0)),
		11,
		"Auto-save metadata should reflect the current day"
	)


func test_slot_listing_returns_timestamp_and_store_name_metadata() -> void:
	_seed_round_trip_state()

	assert_true(_save_manager.save_game(3), "Precondition: save should succeed")

	var metadata: Dictionary = _save_manager.get_slot_metadata(3)
	var listing: Dictionary = _save_manager.get_all_slot_metadata()
	assert_true(
		listing.has(3),
		"Slot listing should include slot 3 metadata"
	)
	assert_false(
		str(metadata.get("timestamp", "")).is_empty(),
		"Slot metadata should include a timestamp"
	)
	assert_eq(
		str(metadata.get("store_name", "")),
		CUSTOM_STORE_NAME,
		"Slot metadata should include the saved store name"
	)
	assert_eq(
		str((listing[3] as Dictionary).get("store_name", "")),
		CUSTOM_STORE_NAME,
		"Slot listing should return the stored store name"
	)


func _configure_difficulty() -> void:
	DataLoaderSingleton._difficulty_config = {
		"tiers": [
			{
				"id": "normal",
				"display_name": "Normal",
				"modifiers": {
					"starting_cash_multiplier": 1.0,
					"daily_rent_multiplier": 1.0,
					"staff_wage_multiplier": 1.0,
					"morale_decay_multiplier": 1.0,
					"staff_quit_threshold": 0.0,
					"wholesale_cost_multiplier": 1.0,
				},
				"flags": {
					"emergency_cash_injection_enabled": false,
				},
			},
		],
	}
	DifficultySystemSingleton._load_config()
	DifficultySystemSingleton._current_tier_id = &"normal"
	DifficultySystemSingleton._assisted = false
	DifficultySystemSingleton._initialized = true
	DifficultySystemSingleton.used_difficulty_downgrade = false


func _register_catalog() -> void:
	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)

	var store_definition := StoreDefinition.new()
	store_definition.id = String(STORE_ID)
	store_definition.store_name = "Test Sports"
	store_definition.store_type = STORE_ID
	store_definition.backroom_capacity = 20
	store_definition.daily_rent = 0.0
	_data_loader._stores[String(STORE_ID)] = store_definition
	ContentRegistry.register(STORE_ID, store_definition, "store")
	ContentRegistry.register_entry(
		{
			"id": String(STORE_ID),
			"name": "Test Sports",
			"store_name": "Test Sports",
			"backroom_capacity": 20,
		},
		"store"
	)

	_item_definition = ItemDefinition.new()
	_item_definition.id = String(ITEM_ID)
	_item_definition.item_name = "Signed Ball"
	_item_definition.store_type = STORE_ID
	_item_definition.base_price = 12.5
	_item_definition.rarity = "common"
	_item_definition.condition_range = PackedStringArray(["good"])
	_data_loader._items[String(ITEM_ID)] = _item_definition
	ContentRegistry.register(ITEM_ID, _item_definition, "item")
	ContentRegistry.register_entry(
		{
			"id": String(ITEM_ID),
			"name": "Signed Ball",
			"store_type": String(STORE_ID),
		},
		"item"
	)


func _create_systems() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()

	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)

	_store_state_manager = StoreStateManager.new()
	add_child_autofree(_store_state_manager)
	_store_state_manager.initialize(_inventory, _economy)

	_save_manager = SaveManager.new()
	add_child_autofree(_save_manager)
	_save_manager.initialize(_economy, _inventory, _time_system)
	_save_manager.set_reputation_system(_reputation)
	_save_manager.set_store_state_manager(_store_state_manager)


func _seed_store_state() -> void:
	_store_state_manager.register_slot_ownership(1, STORE_ID)
	_store_state_manager.set_store_name(STORE_ID, CUSTOM_STORE_NAME)
	_store_state_manager.set_active_store(STORE_ID, false)


func _seed_round_trip_state() -> ItemInstance:
	_seed_store_state()
	_economy._current_cash = 4321.75
	_time_system.current_day = 7
	_reputation.initialize_store(String(STORE_ID))
	_reputation.add_reputation(String(STORE_ID), 15.0)

	var item: ItemInstance = ItemInstance.create(
		_item_definition,
		"good",
		4,
		9.5
	)
	_inventory.add_item(STORE_ID, item)
	_inventory.assign_to_shelf(STORE_ID, item.instance_id, &"front_1")
	return item


func _read_raw_save(slot: int) -> Dictionary:
	var path: String = _save_manager._get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data as Dictionary
	return {}


func _write_raw_text(slot: int, contents: String) -> void:
	var path: String = _save_manager._get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "Test precondition: corrupt save file should be writable")
	file.store_string(contents)
	file.close()
