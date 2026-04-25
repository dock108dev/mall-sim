## Focused regression tests for ISSUE-117 SaveManager slot/index/version/autosave behavior.
extends GutTest


const MANUAL_SLOT_A: int = 1
const MANUAL_SLOT_B: int = 2
const MANUAL_SLOT_C: int = 3
const _STORE_IDS: Array[StringName] = [&"sports", &"retro_games", &"electronics"]

var _save_manager: SaveManager
var _economy: EconomySystem
var _inventory: InventorySystem
var _time_system: TimeSystem
var _reputation: ReputationSystem
var _data_loader: DataLoader
var _saved_owned_stores: Array[StringName] = []
var _saved_store_id: StringName = &""


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
	_inventory.initialize(null)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_store_catalog()

	_save_manager.initialize(_economy, _inventory, _time_system)
	_save_manager.set_reputation_system(_reputation)
	_save_manager.set_store_state_manager(null)

	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_store_id = GameManager.current_store_id


func after_each() -> void:
	for slot: int in range(0, 4):
		_save_manager.delete_save(slot)
	if FileAccess.file_exists(SaveManager.SLOT_INDEX_PATH):
		DirAccess.remove_absolute(SaveManager.SLOT_INDEX_PATH)
	ContentRegistry.clear_for_testing()
	GameManager.owned_stores = _saved_owned_stores
	GameManager.current_store_id = _saved_store_id


func test_manual_save_writes_root_level_json_and_index_metadata() -> void:
	_configure_state(6, 2450.5, [&"sports", &"retro_games"], &"retro_games")

	var saved: bool = _save_manager.save_game(MANUAL_SLOT_A)
	assert_true(saved, "save_game should succeed for slot 1")
	assert_true(
		FileAccess.file_exists(_save_manager._get_slot_path(MANUAL_SLOT_A)),
		"Slot 1 should write user://save_slot_1.json"
	)

	var raw: Dictionary = _read_save(MANUAL_SLOT_A)
	assert_eq(
		int(raw.get("save_version", -1)),
		SaveManager.CURRENT_SAVE_VERSION,
		"Save file should store the current save_version"
	)

	var metadata: Dictionary = _save_manager.get_slot_metadata(MANUAL_SLOT_A)
	assert_eq(int(metadata.get("day", -1)), 6, "Index day should match the save")
	assert_almost_eq(
		float(metadata.get("cash", 0.0)),
		2450.5,
		0.01,
		"Index cash should match the save"
	)
	assert_eq(
		int(metadata.get("store_count", -1)),
		2,
		"Index store_count should match the owned store total"
	)
	assert_true(
		str(metadata.get("last_saved_at", "")).length() > 0,
		"Index should store last_saved_at"
	)


func test_load_version_0_save_is_rejected_as_too_old() -> void:
	# Version 0 predates the save_metadata block and owned-slots schema and
	# falls below MIN_SUPPORTED_SAVE_VERSION (1). Per the SaveManager class
	# docstring, v0 saves are rejected outright with the "Save too old —
	# start a new game" error and are NOT migrated. Pre-existing runtime
	# state must remain untouched.
	var legacy_data: Dictionary = {
		"save_version": 0,
		"metadata": {
			"timestamp": "2026-01-01T00:00:00",
			"day_number": 4,
			"store_type": "retro_games",
			"play_time": 12.0,
		},
		"time": {"current_day": 4},
		"economy": {"current_cash": 1550.0},
		"inventory": _inventory.get_save_data(),
		"reputation": _reputation.get_save_data(),
		"owned_stores": ["retro_games"],
	}
	_write_save(MANUAL_SLOT_A, legacy_data)

	var pre_day: int = _time_system.current_day
	var pre_cash: float = _economy.get_cash()
	var pre_owned: Array[StringName] = GameManager.owned_stores.duplicate()

	var loaded: bool = _save_manager.load_game(MANUAL_SLOT_A)
	assert_false(loaded, "Version 0 save should be rejected as too old")
	assert_eq(
		_time_system.current_day, pre_day,
		"Rejected v0 load must not mutate TimeSystem"
	)
	assert_almost_eq(
		_economy.get_cash(), pre_cash, 0.01,
		"Rejected v0 load must not mutate cash"
	)
	assert_eq(
		GameManager.owned_stores, pre_owned,
		"Rejected v0 load must not mutate owned_stores"
	)


func test_auto_save_waits_for_day_acknowledged() -> void:
	_configure_state(3, 900.0, [&"sports"], &"sports")

	EventBus.day_ended.emit(3)
	assert_false(
		_save_manager.slot_exists(SaveManager.AUTO_SAVE_SLOT),
		"Auto-save should not fire during day_ended"
	)

	EventBus.day_acknowledged.emit()
	assert_true(
		_save_manager.slot_exists(SaveManager.AUTO_SAVE_SLOT),
		"Auto-save should fire after day_acknowledged"
	)


func test_corrupt_load_emits_failure_without_overwriting_file() -> void:
	var path: String = _save_manager._get_slot_path(MANUAL_SLOT_A)
	var corrupt_contents: String = "{{corrupt"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "Should be able to create a corrupt save file")
	file.store_string(corrupt_contents)
	file.close()

	var signal_fired: Array[bool] = [false]
	var handler: Callable = func(_slot: int, _reason: String) -> void:
		signal_fired[0] = true
	EventBus.save_load_failed.connect(handler)

	var loaded: bool = _save_manager.load_game(MANUAL_SLOT_A)

	EventBus.save_load_failed.disconnect(handler)
	assert_false(loaded, "Corrupt save load should fail")
	assert_true(signal_fired[0], "Corrupt save load should emit save_load_failed")
	assert_eq(
		_read_raw_text(path),
		corrupt_contents,
		"Corrupt save contents should be left untouched after load failure"
	)


func test_three_manual_slots_remain_independent() -> void:
	_configure_state(1, 100.0, [&"sports"], &"sports")
	assert_true(_save_manager.save_game(MANUAL_SLOT_A), "Slot 1 save should succeed")

	_configure_state(2, 200.0, [&"retro_games"], &"retro_games")
	assert_true(_save_manager.save_game(MANUAL_SLOT_B), "Slot 2 save should succeed")

	_configure_state(3, 300.0, [&"electronics"], &"electronics")
	assert_true(_save_manager.save_game(MANUAL_SLOT_C), "Slot 3 save should succeed")

	assert_true(_save_manager.load_game(MANUAL_SLOT_B), "Slot 2 load should succeed")
	assert_eq(_time_system.current_day, 2, "Slot 2 should keep its own saved day")
	assert_almost_eq(
		_economy.get_cash(),
		200.0,
		0.01,
		"Slot 2 should keep its own saved cash"
	)
	assert_has(
		GameManager.owned_stores,
		&"retro_games",
		"Slot 2 should keep its own owned store list"
	)


func _register_store_catalog() -> void:
	for store_id: StringName in _STORE_IDS:
		var store_definition := StoreDefinition.new()
		store_definition.id = String(store_id)
		store_definition.store_name = "%s Test Store" % String(store_id)
		store_definition.store_type = store_id
		store_definition.backroom_capacity = 20
		store_definition.daily_rent = 0.0
		_data_loader._stores[String(store_id)] = store_definition
		ContentRegistry.register(store_id, store_definition, "store")
		ContentRegistry.register_entry(
			{
				"id": String(store_id),
				"name": "%s Test Store" % String(store_id),
				"store_name": "%s Test Store" % String(store_id),
				"backroom_capacity": 20,
			},
			"store"
		)


func _configure_state(
	day: int,
	cash: float,
	owned_stores: Array[StringName],
	active_store_id: StringName
) -> void:
	_time_system.current_day = day
	_economy._current_cash = cash
	GameManager.owned_stores = owned_stores.duplicate()
	GameManager.current_store_id = active_store_id


func _write_save(slot: int, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(
		_save_manager._get_slot_path(slot),
		FileAccess.WRITE
	)
	assert_not_null(file, "Should be able to write test save data")
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _read_save(slot: int) -> Dictionary:
	var file: FileAccess = FileAccess.open(
		_save_manager._get_slot_path(slot),
		FileAccess.READ
	)
	if not file:
		return {}
	var json := JSON.new()
	var parse_result: Error = json.parse(file.get_as_text())
	file.close()
	if parse_result != OK or json.data is not Dictionary:
		return {}
	return json.data as Dictionary


func _read_raw_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text
