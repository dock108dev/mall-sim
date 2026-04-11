## Tests for SaveManager save/load round-trip, versioning, and error handling.
extends GutTest


var _save_manager: SaveManager
var _economy: EconomySystem
var _inventory: InventorySystem
var _time_system: TimeSystem
var _reputation: ReputationSystem
var _test_slot: int = 1
var _saved_owned_stores: Array[String] = []
var _saved_store_id: String = ""


func before_each() -> void:
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
	_reputation.initialize()

	_save_manager.initialize(_economy, _inventory, _time_system, _reputation)

	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_store_id = GameManager.current_store_id


func after_each() -> void:
	_save_manager.delete_save(_test_slot)
	_save_manager.delete_save(2)
	_save_manager.delete_save(3)
	_save_manager.delete_save(SaveManager.AUTO_SAVE_SLOT)
	GameManager.owned_stores = _saved_owned_stores
	GameManager.current_store_id = _saved_store_id


# --- Save creates file ---


func test_save_creates_file_slot_1() -> void:
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"
	var result: bool = _save_manager.save_game(1)
	assert_true(result, "save_game should return true")
	assert_true(
		_save_manager.slot_exists(1),
		"Slot 1 should exist after saving"
	)


func test_save_creates_file_slot_2() -> void:
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"
	var result: bool = _save_manager.save_game(2)
	assert_true(result, "save_game should return true for slot 2")
	assert_true(
		_save_manager.slot_exists(2),
		"Slot 2 should exist after saving"
	)


func test_save_creates_file_slot_3() -> void:
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"
	var result: bool = _save_manager.save_game(3)
	assert_true(result, "save_game should return true for slot 3")
	assert_true(
		_save_manager.slot_exists(3),
		"Slot 3 should exist after saving"
	)


func test_save_creates_auto_save_slot() -> void:
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"
	var result: bool = _save_manager.save_game(SaveManager.AUTO_SAVE_SLOT)
	assert_true(result, "save_game should return true for auto-save slot")
	assert_true(
		_save_manager.slot_exists(SaveManager.AUTO_SAVE_SLOT),
		"Auto-save slot should exist after saving"
	)


# --- Round-trip preserves state ---


func test_round_trip_preserves_cash_reputation_day_inventory() -> void:
	_economy._current_cash = 1234.56
	_time_system.current_day = 7
	_reputation._score = 42.5
	GameManager.owned_stores = ["retro_games", "sports_memorabilia"]
	GameManager.current_store_id = "retro_games"

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_economy._current_cash = 0.0
	_time_system.current_day = 1
	_reputation._score = 0.0
	GameManager.owned_stores = []

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")

	assert_almost_eq(
		_economy._current_cash, 1234.56, 0.01,
		"Cash should be restored after round-trip"
	)
	assert_eq(
		_time_system.current_day, 7,
		"Day number should be restored after round-trip"
	)
	assert_almost_eq(
		_reputation._score, 42.5, 0.01,
		"Reputation score should be restored after round-trip"
	)
	assert_has(
		GameManager.owned_stores, "retro_games",
		"Owned stores should include retro_games after round-trip"
	)
	assert_has(
		GameManager.owned_stores, "sports_memorabilia",
		"Owned stores should include sports_memorabilia after round-trip"
	)


# --- Save version ---


func test_save_file_contains_correct_version() -> void:
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"
	_save_manager.save_game(_test_slot)

	var data: Dictionary = _read_save_file_raw(_test_slot)
	assert_has(data, "save_version", "Save data must contain save_version")
	assert_eq(
		int(data["save_version"]),
		SaveManager.CURRENT_SAVE_VERSION,
		"save_version should match CURRENT_SAVE_VERSION"
	)


# --- Error handling: missing file ---


func test_load_nonexistent_file_returns_false() -> void:
	_save_manager.delete_save(_test_slot)
	var result: bool = _save_manager.load_game(_test_slot)
	assert_false(
		result,
		"Loading a nonexistent save should return false"
	)


# --- Error handling: corrupt file ---


func test_load_corrupt_file_returns_false() -> void:
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"
	_save_manager.save_game(_test_slot)

	var path: String = SaveManager.SAVE_DIR + "slot_%d.json" % _test_slot
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "Should be able to open save file for corruption")
	file.store_string("{{{not valid json at all!!!")
	file.close()

	var result: bool = _save_manager.load_game(_test_slot)
	assert_false(
		result,
		"Loading a corrupt save file should return false"
	)


# --- Slot metadata ---


func test_slot_metadata_contains_timestamp_and_store() -> void:
	GameManager.owned_stores = ["retro_games"]
	GameManager.current_store_id = "retro_games"
	_time_system.current_day = 15

	_save_manager.save_game(_test_slot)
	var metadata: Dictionary = _save_manager.get_slot_metadata(_test_slot)

	assert_has(
		metadata, "timestamp",
		"Metadata should contain timestamp"
	)
	assert_true(
		str(metadata["timestamp"]).length() > 0,
		"Timestamp should not be empty"
	)
	assert_has(
		metadata, "store_type",
		"Metadata should contain store_type"
	)
	assert_eq(
		str(metadata["store_type"]), "retro_games",
		"Metadata store_type should match the saved store"
	)
	assert_has(
		metadata, "day_number",
		"Metadata should contain day_number"
	)
	assert_eq(
		int(metadata["day_number"]), 15,
		"Metadata day_number should match the saved day"
	)


func test_slot_metadata_returns_empty_for_missing_slot() -> void:
	_save_manager.delete_save(_test_slot)
	var metadata: Dictionary = _save_manager.get_slot_metadata(_test_slot)
	assert_eq(
		metadata.size(), 0,
		"Metadata for nonexistent slot should be empty"
	)


# --- Auto-save on day_ended ---


func test_auto_save_triggers_on_day_ended() -> void:
	_save_manager.set_store_state_manager(null)
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"
	_time_system.current_day = 3

	EventBus.day_ended.emit(3)

	assert_true(
		_save_manager.slot_exists(SaveManager.AUTO_SAVE_SLOT),
		"Auto-save slot should exist after day_ended signal"
	)
	var metadata: Dictionary = _save_manager.get_slot_metadata(
		SaveManager.AUTO_SAVE_SLOT
	)
	assert_eq(
		int(metadata.get("day_number", -1)), 3,
		"Auto-save metadata day should match emitted day"
	)


# --- Invalid slot ---


func test_save_rejects_invalid_slot() -> void:
	var result: bool = _save_manager.save_game(99)
	assert_false(result, "Save with invalid slot should return false")


func test_load_rejects_invalid_slot() -> void:
	var result: bool = _save_manager.load_game(-1)
	assert_false(result, "Load with invalid slot should return false")


# --- Load non-dict root ---


func test_load_non_dict_root_returns_false() -> void:
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"
	_save_manager.save_game(_test_slot)

	var path: String = SaveManager.SAVE_DIR + "slot_%d.json" % _test_slot
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()

	var result: bool = _save_manager.load_game(_test_slot)
	assert_false(
		result,
		"Loading a file with array root should return false"
	)


# --- Helpers ---


func _read_save_file_raw(slot: int) -> Dictionary:
	var path: String = SaveManager.SAVE_DIR + "slot_%d.json" % slot
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
