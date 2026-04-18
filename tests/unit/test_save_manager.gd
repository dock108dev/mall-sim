## Unit tests for SaveManager slot management, serialization, and version compat.
extends GutTest


const STORE_ID: StringName = &"sports"

var _save_manager: SaveManager
var _economy: EconomySystem
var _inventory: InventorySystem
var _time_system: TimeSystem
var _reputation: ReputationSystem
var _store_state_manager: StoreStateManager
var _data_loader: DataLoader


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	_save_manager = SaveManager.new()
	add_child_autofree(_save_manager)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()

	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_store_catalog()
	_inventory.initialize(_data_loader)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)

	_store_state_manager = StoreStateManager.new()
	add_child_autofree(_store_state_manager)
	_store_state_manager.initialize(_inventory, _economy)

	_save_manager.initialize(_economy, _inventory, _time_system)
	_save_manager.set_reputation_system(_reputation)
	_save_manager.set_store_state_manager(_store_state_manager)


func after_each() -> void:
	for slot: int in range(0, 4):
		_save_manager.delete_save(slot)
	if FileAccess.file_exists(SaveManager.SLOT_INDEX_PATH):
		DirAccess.remove_absolute(SaveManager.SLOT_INDEX_PATH)
	ContentRegistry.clear_for_testing()


# --- Slot path generation ---


func test_get_save_slot_path_returns_correct_path() -> void:
	var path_0: String = _save_manager._get_slot_path(0)
	assert_eq(
		path_0, SaveManager.SAVE_DIR + "save_slot_0.json",
		"Slot 0 (auto-save) should return save_slot_0.json path"
	)

	var path_1: String = _save_manager._get_slot_path(1)
	assert_eq(
		path_1, SaveManager.SAVE_DIR + "save_slot_1.json",
		"Slot 1 should return save_slot_1.json path"
	)

	var path_2: String = _save_manager._get_slot_path(2)
	assert_eq(
		path_2, SaveManager.SAVE_DIR + "save_slot_2.json",
		"Slot 2 should return save_slot_2.json path"
	)

	var path_3: String = _save_manager._get_slot_path(3)
	assert_eq(
		path_3, SaveManager.SAVE_DIR + "save_slot_3.json",
		"Slot 3 should return save_slot_3.json path"
	)


# --- Fresh slot does not exist ---


func test_save_slot_exists_returns_false_for_fresh_slot() -> void:
	assert_false(
		_save_manager.slot_exists(1),
		"Unwritten slot 1 should not exist"
	)
	assert_false(
		_save_manager.slot_exists(2),
		"Unwritten slot 2 should not exist"
	)
	assert_false(
		_save_manager.slot_exists(3),
		"Unwritten slot 3 should not exist"
	)


# --- Round-trip serialization ---


func test_save_and_load_round_trip_preserves_dictionary() -> void:
	_economy._current_cash = 999.99
	_time_system.current_day = 12
	_reputation.initialize_store("sports")
	_reputation.add_reputation("sports", 10.0)
	_store_state_manager.register_slot_ownership(0, &"sports")
	_store_state_manager.set_active_store(&"sports", false)

	var pre_economy: Dictionary = _economy.get_save_data()
	var pre_time: Dictionary = _time_system.get_save_data()

	var saved: bool = _save_manager.save_game(1)
	assert_true(saved, "Save should succeed")

	_economy._current_cash = 0.0
	_time_system.current_day = 1
	_reputation.reset()
	_store_state_manager.owned_slots = {}
	_store_state_manager.active_store_id = &""

	var loaded: bool = _save_manager.load_game(1)
	assert_true(loaded, "Load should succeed")

	var post_economy: Dictionary = _economy.get_save_data()
	var post_time: Dictionary = _time_system.get_save_data()

	_assert_dict_match(pre_economy, post_economy, "economy")
	_assert_dict_match(pre_time, post_time, "time")
	assert_almost_eq(
		_economy._current_cash, 999.99, 0.01,
		"Cash should survive round-trip"
	)
	assert_eq(
		_time_system.current_day, 12,
		"Day should survive round-trip"
	)


# --- Load nonexistent slot ---


func test_load_nonexistent_slot_returns_null() -> void:
	var result: bool = _save_manager.load_game(1)
	assert_false(
		result,
		"Loading a slot with no file should return false"
	)


# --- Delete save slot ---


func test_delete_save_slot_removes_file() -> void:
	_store_state_manager.register_slot_ownership(0, &"sports")
	_store_state_manager.set_active_store(&"sports", false)
	_save_manager.save_game(1)
	assert_true(
		_save_manager.slot_exists(1),
		"Slot should exist after saving"
	)

	var deleted: bool = _save_manager.delete_save(1)
	assert_true(deleted, "delete_save should return true")
	assert_false(
		_save_manager.slot_exists(1),
		"Slot should not exist after deletion"
	)


# --- Slot metadata ---


func test_get_slot_metadata_returns_day_and_cash() -> void:
	_economy._current_cash = 250.0
	_time_system.current_day = 5
	_store_state_manager.register_slot_ownership(0, &"sports")
	_store_state_manager.set_active_store(&"sports", false)

	_save_manager.save_game(1)
	var metadata: Dictionary = _save_manager.get_slot_metadata(1)

	assert_has(metadata, "day", "Metadata should have day")
	assert_eq(
		int(metadata["day"]), 5,
		"day should be 5"
	)
	assert_has(metadata, "cash", "Metadata should have cash")
	assert_almost_eq(
		float(metadata["cash"]), 250.0, 0.01,
		"cash should reflect the saved EconomySystem cash"
	)
	assert_has(
		metadata, "owned_stores",
		"Metadata should have owned_stores"
	)
	assert_eq(
		(metadata["owned_stores"] as Array).size(), 1,
		"owned_stores should include the saved store"
	)
	assert_has(metadata, "saved_at", "Metadata should have saved_at")
	assert_has(metadata, "active_store_id", "Metadata should have active_store_id")
	assert_has(
		metadata, "timestamp",
		"Metadata should have timestamp"
	)
	assert_has(
		metadata, "play_time",
		"Metadata should have play_time"
	)


func test_save_file_contains_top_level_save_metadata() -> void:
	_economy._current_cash = 800.0
	_time_system.current_day = 9
	_store_state_manager.register_slot_ownership(0, &"sports")
	_store_state_manager.set_active_store(&"sports", false)

	assert_true(_save_manager.save_game(1), "Save should succeed")

	var data: Dictionary = _read_save_file_raw(1)
	assert_has(data, "save_metadata", "Save must contain save_metadata")
	var metadata: Dictionary = data["save_metadata"] as Dictionary
	assert_eq(int(metadata.get("day", 0)), 9, "day should be saved")
	assert_almost_eq(
		float(metadata.get("cash", 0.0)), 800.0, 0.01,
		"cash should be saved"
	)
	assert_eq(
		(metadata.get("owned_stores", []) as Array).size(), 1,
		"owned_stores should be saved"
	)
	assert_false(
		str(metadata.get("saved_at", "")).is_empty(),
		"saved_at should be saved"
	)


func test_get_slot_metadata_ignores_stale_slot_index() -> void:
	_economy._current_cash = 250.0
	_time_system.current_day = 5
	_store_state_manager.register_slot_ownership(0, &"sports")
	_store_state_manager.set_active_store(&"sports", false)

	assert_true(_save_manager.save_game(1), "Save should succeed")

	var config := ConfigFile.new()
	config.load(SaveManager.SLOT_INDEX_PATH)
	config.set_value("slot_1", "day", 99)
	config.set_value("slot_1", "cash", 1.0)
	config.set_value("slot_1", "owned_stores", [])
	config.save(SaveManager.SLOT_INDEX_PATH)

	var metadata: Dictionary = _save_manager.get_slot_metadata(1)
	assert_eq(
		int(metadata.get("day", 0)), 5,
		"Slot metadata should come from save_metadata in the save file"
	)
	assert_almost_eq(
		float(metadata.get("cash", 0.0)), 250.0, 0.01,
		"Slot metadata should not use stale index cash"
	)


# --- Save version field ---


func test_save_version_field_is_written() -> void:
	_store_state_manager.register_slot_ownership(0, &"sports")
	_store_state_manager.set_active_store(&"sports", false)
	_save_manager.save_game(1)

	var data: Dictionary = _read_save_file_raw(1)
	assert_has(data, "save_version", "Save must contain save_version")
	assert_eq(
		int(data["save_version"]),
		SaveManager.CURRENT_SAVE_VERSION,
		"save_version should equal CURRENT_SAVE_VERSION"
	)


# --- Slot independence ---


func test_all_three_slots_are_independent() -> void:
	_economy._current_cash = 100.0
	_time_system.current_day = 1
	_store_state_manager.register_slot_ownership(0, &"sports")
	_store_state_manager.set_active_store(&"sports", false)
	_save_manager.save_game(1)

	_economy._current_cash = 200.0
	_time_system.current_day = 2
	_save_manager.save_game(2)

	_economy._current_cash = 300.0
	_time_system.current_day = 3
	_save_manager.save_game(3)

	_economy._current_cash = 0.0
	_time_system.current_day = 0

	_save_manager.load_game(1)
	assert_almost_eq(
		_economy._current_cash, 100.0, 0.01,
		"Slot 1 should restore cash=100"
	)
	assert_eq(
		_time_system.current_day, 1,
		"Slot 1 should restore day=1"
	)

	_save_manager.load_game(2)
	assert_almost_eq(
		_economy._current_cash, 200.0, 0.01,
		"Slot 2 should restore cash=200"
	)
	assert_eq(
		_time_system.current_day, 2,
		"Slot 2 should restore day=2"
	)

	_save_manager.load_game(3)
	assert_almost_eq(
		_economy._current_cash, 300.0, 0.01,
		"Slot 3 should restore cash=300"
	)
	assert_eq(
		_time_system.current_day, 3,
		"Slot 3 should restore day=3"
	)

	assert_false(
		_save_manager.slot_exists(0),
		"Auto-save slot should be empty (not written)"
	)


# --- Out-of-range slot index ---


func test_slot_index_out_of_range_returns_error() -> void:
	var save_neg: bool = _save_manager.save_game(-1)
	assert_false(save_neg, "Negative slot should fail")

	var save_high: bool = _save_manager.save_game(4)
	assert_false(save_high, "Slot 4 (above max) should fail")

	var load_neg: bool = _save_manager.load_game(-1)
	assert_false(load_neg, "Loading negative slot should fail")

	var load_high: bool = _save_manager.load_game(99)
	assert_false(load_high, "Loading slot 99 should fail")

	assert_false(
		_save_manager.slot_exists(-1),
		"slot_exists with -1 should return false"
	)
	assert_false(
		_save_manager.slot_exists(5),
		"slot_exists with 5 should return false"
	)

	var del_neg: bool = _save_manager.delete_save(-1)
	assert_false(del_neg, "delete_save with -1 should return false")


# --- Helpers ---


func _assert_dict_match(
	expected: Dictionary,
	actual: Dictionary,
	label: String
) -> void:
	for key: String in expected:
		assert_true(
			actual.has(key),
			"%s: missing key '%s' after load" % [label, key]
		)
		if actual.has(key):
			assert_eq(
				str(actual[key]), str(expected[key]),
				"%s.%s mismatch" % [label, key]
			)


func _register_store_catalog() -> void:
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


func _read_save_file_raw(slot: int) -> Dictionary:
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
