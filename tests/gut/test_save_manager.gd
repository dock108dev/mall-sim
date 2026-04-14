## Tests for SaveManager save/load round-trip, versioning, and error handling.
extends GutTest


var _save_manager: SaveManager
var _economy: EconomySystem
var _inventory: InventorySystem
var _time_system: TimeSystem
var _reputation: ReputationSystem
var _store_state_manager: StoreStateManager
var _test_slot: int = 1
var _saved_owned_stores: Array[StringName] = []
var _saved_store_id: StringName = &""


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

	_store_state_manager = StoreStateManager.new()
	add_child_autofree(_store_state_manager)
	_store_state_manager.initialize(_inventory, _economy)

	_save_manager.initialize(_economy, _inventory, _time_system)
	_save_manager.set_reputation_system(_reputation)
	_save_manager.set_store_state_manager(_store_state_manager)

	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_store_id = GameManager.current_store_id


func after_each() -> void:
	_save_manager.delete_save(_test_slot)
	_save_manager.delete_save(2)
	_save_manager.delete_save(3)
	_save_manager.delete_save(SaveManager.AUTO_SAVE_SLOT)
	if FileAccess.file_exists(SaveManager.SLOT_INDEX_PATH):
		DirAccess.remove_absolute(SaveManager.SLOT_INDEX_PATH)
	GameManager.owned_stores = _saved_owned_stores
	GameManager.current_store_id = _saved_store_id


# --- Save creates file ---


func test_save_creates_file_slot_1() -> void:
	GameManager.owned_stores = ["sports"]
	GameManager.current_store_id = "sports"
	var result: bool = _save_manager.save_game(1)
	assert_true(result, "save_game should return true")
	assert_true(
		_save_manager.slot_exists(1),
		"Slot 1 should exist after saving"
	)


func test_save_creates_file_slot_2() -> void:
	GameManager.owned_stores = ["sports"]
	GameManager.current_store_id = "sports"
	var result: bool = _save_manager.save_game(2)
	assert_true(result, "save_game should return true for slot 2")
	assert_true(
		_save_manager.slot_exists(2),
		"Slot 2 should exist after saving"
	)


func test_save_creates_file_slot_3() -> void:
	GameManager.owned_stores = ["sports"]
	GameManager.current_store_id = "sports"
	var result: bool = _save_manager.save_game(3)
	assert_true(result, "save_game should return true for slot 3")
	assert_true(
		_save_manager.slot_exists(3),
		"Slot 3 should exist after saving"
	)


func test_save_creates_auto_save_slot() -> void:
	GameManager.owned_stores = ["sports"]
	GameManager.current_store_id = "sports"
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
	_reputation.initialize_store("sports")
	_reputation.add_reputation("sports", -7.5)
	_store_state_manager.register_slot_ownership(0, &"sports")
	_store_state_manager.register_slot_ownership(1, &"retro_games")
	GameManager.owned_stores = [&"retro_games", &"sports"]
	GameManager.current_store_id = &"retro_games"

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_economy._current_cash = 0.0
	_time_system.current_day = 1
	_reputation.reset()
	_store_state_manager.owned_slots = {}
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
		_reputation.get_reputation("sports"), 42.5, 0.01,
		"Reputation score should be restored after round-trip"
	)
	assert_has(
		GameManager.owned_stores, &"retro_games",
		"Owned stores should include retro_games after round-trip"
	)
	assert_has(
		GameManager.owned_stores, &"sports",
		"Owned stores should include sports after round-trip"
	)


# --- Save version ---


func test_save_file_contains_correct_version() -> void:
	GameManager.owned_stores = ["sports"]
	GameManager.current_store_id = "sports"
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
	GameManager.owned_stores = ["sports"]
	GameManager.current_store_id = "sports"
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
		metadata, "day",
		"Metadata should contain day"
	)
	assert_eq(
		int(metadata["day"]), 15,
		"Metadata day should match the saved day"
	)
	assert_has(
		metadata, "cash",
		"Metadata should contain cash"
	)
	assert_has(
		metadata, "owned_stores",
		"Metadata should contain owned_stores"
	)
	assert_has(
		metadata, "saved_at",
		"Metadata should contain saved_at"
	)
	assert_true(
		str(metadata["saved_at"]).length() > 0,
		"saved_at should not be empty"
	)


func test_slot_metadata_includes_used_difficulty_downgrade_true() -> void:
	var slot: int = 3
	var path: String = SaveManager.SAVE_DIR + "slot_%d.json" % slot
	var mock_data: Dictionary = {
		"save_version": SaveManager.CURRENT_SAVE_VERSION,
		"save_metadata": {
			"day": 5,
			"cash": 2000.0,
			"owned_stores": ["retro_games"],
			"saved_at": "2026-01-01T00:00:00",
		},
		"difficulty": {
			"current_tier": "easy",
			"used_difficulty_downgrade": true,
		},
	}
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "Should be able to write mock save file")
	file.store_string(JSON.stringify(mock_data))
	file.close()

	var metadata: Dictionary = _save_manager.get_slot_metadata(slot)
	DirAccess.remove_absolute(path)

	assert_has(
		metadata, "used_difficulty_downgrade",
		"Metadata should contain used_difficulty_downgrade"
	)
	assert_true(
		bool(metadata["used_difficulty_downgrade"]),
		"used_difficulty_downgrade should be true when set in save file"
	)


func test_slot_metadata_includes_used_difficulty_downgrade_false() -> void:
	var slot: int = 3
	var path: String = SaveManager.SAVE_DIR + "slot_%d.json" % slot
	var mock_data: Dictionary = {
		"save_version": SaveManager.CURRENT_SAVE_VERSION,
		"save_metadata": {
			"day": 5,
			"cash": 2000.0,
			"owned_stores": [],
			"saved_at": "2026-01-01T00:00:00",
		},
		"difficulty": {
			"current_tier": "normal",
			"used_difficulty_downgrade": false,
		},
	}
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "Should be able to write mock save file")
	file.store_string(JSON.stringify(mock_data))
	file.close()

	var metadata: Dictionary = _save_manager.get_slot_metadata(slot)
	DirAccess.remove_absolute(path)

	assert_has(
		metadata, "used_difficulty_downgrade",
		"Metadata should contain used_difficulty_downgrade"
	)
	assert_false(
		bool(metadata["used_difficulty_downgrade"]),
		"used_difficulty_downgrade should be false when set false in save file"
	)


func test_slot_metadata_used_difficulty_downgrade_defaults_false_when_key_absent() -> void:
	var slot: int = 3
	var path: String = SaveManager.SAVE_DIR + "slot_%d.json" % slot
	var mock_data: Dictionary = {
		"save_version": SaveManager.CURRENT_SAVE_VERSION,
		"save_metadata": {
			"day": 3,
			"cash": 500.0,
			"owned_stores": [],
			"saved_at": "2026-01-01T00:00:00",
		},
	}
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "Should be able to write mock save file")
	file.store_string(JSON.stringify(mock_data))
	file.close()

	var metadata: Dictionary = _save_manager.get_slot_metadata(slot)
	DirAccess.remove_absolute(path)

	var flag: bool = bool(metadata.get("used_difficulty_downgrade", false))
	assert_false(
		flag,
		"used_difficulty_downgrade should default to false when absent from save file"
	)


func test_slot_metadata_returns_empty_for_missing_slot() -> void:
	_save_manager.delete_save(_test_slot)
	var metadata: Dictionary = _save_manager.get_slot_metadata(_test_slot)
	assert_eq(
		metadata.size(), 0,
		"Metadata for nonexistent slot should be empty"
	)


# --- Auto-save after day summary dismissed ---


func test_auto_save_not_on_day_ended_alone() -> void:
	GameManager.owned_stores = ["sports"]
	GameManager.current_store_id = "sports"
	_time_system.current_day = 3

	EventBus.day_ended.emit(3)

	assert_false(
		_save_manager.slot_exists(SaveManager.AUTO_SAVE_SLOT),
		"Auto-save should NOT fire on day_ended alone"
	)


func test_auto_save_triggers_after_next_day_confirmed() -> void:
	GameManager.owned_stores = ["sports"]
	GameManager.current_store_id = "sports"
	_time_system.current_day = 3

	EventBus.day_ended.emit(3)
	EventBus.next_day_confirmed.emit()

	assert_true(
		_save_manager.slot_exists(SaveManager.AUTO_SAVE_SLOT),
		"Auto-save slot should exist after next_day_confirmed"
	)
	var metadata: Dictionary = _save_manager.get_slot_metadata(
		SaveManager.AUTO_SAVE_SLOT
	)
	assert_eq(
		int(metadata.get("day", -1)), 3,
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
	GameManager.owned_stores = ["sports"]
	GameManager.current_store_id = "sports"
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


# --- Owned slots round-trip ---


func test_owned_slots_round_trip() -> void:
	_store_state_manager.register_slot_ownership(0, &"retro_games")
	_store_state_manager.register_slot_ownership(2, &"electronics")
	GameManager.owned_stores = [&"retro_games", &"electronics"]
	GameManager.current_store_id = &"retro_games"

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_store_state_manager.owned_slots = {}
	GameManager.owned_stores = []

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")

	assert_eq(
		_store_state_manager.owned_slots.size(), 2,
		"Should have 2 owned slots after load"
	)
	assert_eq(
		_store_state_manager.owned_slots.get(0, &""),
		&"retro_games",
		"Slot 0 should be retro_games"
	)
	assert_eq(
		_store_state_manager.owned_slots.get(2, &""),
		&"electronics",
		"Slot 2 should be electronics"
	)
	assert_has(
		GameManager.owned_stores, &"retro_games",
		"GameManager.owned_stores should contain retro_games"
	)
	assert_has(
		GameManager.owned_stores, &"electronics",
		"GameManager.owned_stores should contain electronics"
	)


func test_v1_save_migration_converts_array_to_slots() -> void:
	GameManager.owned_stores = [&"retro_games", &"sports"]
	GameManager.current_store_id = &"retro_games"

	var v1_data: Dictionary = {
		"save_version": 1,
		"metadata": {
			"timestamp": "2026-01-01T00:00:00",
			"day_number": 1,
			"store_type": "retro_games",
			"play_time": 0.0,
		},
		"time": _time_system.get_save_data(),
		"economy": _economy.get_save_data(),
		"inventory": _inventory.get_save_data(),
		"reputation": _reputation.get_save_data(),
		"owned_stores": ["retro_games", "sports"],
	}

	var path: String = SaveManager.SAVE_DIR + "slot_%d.json" % _test_slot
	var json_string: String = JSON.stringify(v1_data, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(json_string)
	file.close()

	_store_state_manager.owned_slots = {}
	GameManager.owned_stores = []

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Loading v1 save should succeed")

	assert_true(
		_store_state_manager.owned_slots.size() > 0,
		"owned_slots should be populated after v1 migration"
	)
	assert_has(
		GameManager.owned_stores, &"retro_games",
		"retro_games should survive v1 migration"
	)
	assert_has(
		GameManager.owned_stores, &"sports",
		"sports should survive v1 migration"
	)


# --- Round-trip state parity ---


func test_round_trip_state_dict_parity() -> void:
	_economy._current_cash = 5000.0
	_economy._items_sold_today = 12
	_economy._daily_rent = 75.0
	_economy._daily_rent_total = 150.0
	_economy._trades_today = 3
	_economy._demand_modifiers = {"cards": 1.2, "tapes": 0.8}
	_economy._drift_factors = {"item_a": 1.05, "item_b": 0.92}
	_economy._today_sales = {"cards": 5, "tapes": 3}

	_time_system.current_day = 5
	_time_system.game_time_minutes = 840.0
	_time_system.current_hour = 14
	_time_system.current_phase = TimeSystem.DayPhase.AFTERNOON
	_time_system._total_play_time = 1800.0
	_time_system.speed_multiplier = 3.0

	_reputation.initialize_store("sports")
	_reputation.add_reputation("sports", 15.0)

	_store_state_manager.register_slot_ownership(0, &"sports")
	_store_state_manager.register_slot_ownership(2, &"retro_games")
	GameManager.owned_stores = [&"sports", &"retro_games"]
	GameManager.current_store_id = &"sports"

	var pre_save_time: Dictionary = _time_system.get_save_data()
	var pre_save_economy: Dictionary = _economy.get_save_data()
	var pre_save_reputation: Dictionary = _reputation.get_save_data()
	var pre_save_inventory: Dictionary = _inventory.get_save_data()
	var pre_save_store_states: Dictionary = (
		_store_state_manager.get_save_data()
	)

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_economy._current_cash = 0.0
	_economy._items_sold_today = 0
	_economy._demand_modifiers = {}
	_economy._drift_factors = {}
	_time_system.current_day = 1
	_time_system.current_hour = 7
	_time_system.game_time_minutes = 420.0
	_time_system._total_play_time = 0.0
	_reputation.reset()
	_store_state_manager.owned_slots = {}
	GameManager.owned_stores = []

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")

	var post_load_time: Dictionary = _time_system.get_save_data()
	var post_load_economy: Dictionary = _economy.get_save_data()
	var post_load_reputation: Dictionary = (
		_reputation.get_save_data()
	)
	var post_load_inventory: Dictionary = (
		_inventory.get_save_data()
	)
	var post_load_store_states: Dictionary = (
		_store_state_manager.get_save_data()
	)

	_assert_dict_match(pre_save_time, post_load_time, "time")
	_assert_dict_match(
		pre_save_economy, post_load_economy, "economy"
	)
	_assert_dict_match(
		pre_save_reputation, post_load_reputation, "reputation"
	)
	_assert_dict_match(
		pre_save_inventory, post_load_inventory, "inventory"
	)
	_assert_dict_match(
		pre_save_store_states, post_load_store_states,
		"store_states"
	)

	assert_eq(
		_store_state_manager.owned_slots.size(), 2,
		"Should have 2 owned slots after round-trip"
	)
	assert_has(
		GameManager.owned_stores, &"sports",
		"sports should be owned after round-trip"
	)
	assert_has(
		GameManager.owned_stores, &"retro_games",
		"retro_games should be owned after round-trip"
	)


# --- Slot index file ---


func test_save_writes_slot_index() -> void:
	GameManager.owned_stores = ["sports"]
	GameManager.current_store_id = "sports"
	_time_system.current_day = 5

	_save_manager.save_game(_test_slot)

	var all_meta: Dictionary = _save_manager.get_all_slot_metadata()
	assert_has(
		all_meta, _test_slot,
		"Slot index should contain saved slot"
	)
	var meta: Dictionary = all_meta[_test_slot]
	assert_eq(
		int(meta.get("day_number", -1)), 5,
		"Slot index day_number should match saved day"
	)


func test_delete_removes_from_slot_index() -> void:
	GameManager.owned_stores = ["sports"]
	GameManager.current_store_id = "sports"
	_save_manager.save_game(_test_slot)

	_save_manager.delete_save(_test_slot)

	var all_meta: Dictionary = _save_manager.get_all_slot_metadata()
	assert_does_not_have(
		all_meta, _test_slot,
		"Slot index should not contain deleted slot"
	)


func test_slot_index_readable_without_full_load() -> void:
	GameManager.owned_stores = ["retro_games"]
	GameManager.current_store_id = "retro_games"
	_time_system.current_day = 10

	_save_manager.save_game(1)
	_save_manager.save_game(2)

	var all_meta: Dictionary = _save_manager.get_all_slot_metadata()
	assert_eq(
		all_meta.size() >= 2, true,
		"Slot index should have at least 2 entries"
	)


# --- save_load_failed signal ---


func test_load_missing_file_emits_save_load_failed() -> void:
	_save_manager.delete_save(_test_slot)
	var signal_fired: Array = [false]
	var captured_slot: Array = [-1]
	var captured_reason: Array = [""]

	var handler: Callable = func(
		slot: int, reason: String
	) -> void:
		signal_fired[0] = true
		captured_slot[0] = slot
		captured_reason[0] = reason
	EventBus.save_load_failed.connect(handler)

	_save_manager.load_game(_test_slot)

	EventBus.save_load_failed.disconnect(handler)
	assert_true(signal_fired[0], "save_load_failed should fire on missing file")
	assert_eq(captured_slot[0], _test_slot, "Slot should match")
	assert_true(
		captured_reason[0].length() > 0,
		"Reason should not be empty"
	)


func test_load_corrupt_file_emits_save_load_failed() -> void:
	GameManager.owned_stores = ["sports"]
	GameManager.current_store_id = "sports"
	_save_manager.save_game(_test_slot)

	var path: String = SaveManager.SAVE_DIR + "slot_%d.json" % _test_slot
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{{{corrupt json!!!")
	file.close()

	var signal_fired: Array = [false]
	var handler: Callable = func(
		_slot: int, _reason: String
	) -> void:
		signal_fired[0] = true
	EventBus.save_load_failed.connect(handler)

	var result: bool = _save_manager.load_game(_test_slot)

	EventBus.save_load_failed.disconnect(handler)
	assert_false(result, "Load should fail on corrupt file")
	assert_true(
		signal_fired[0],
		"save_load_failed should fire on corrupt file"
	)


# --- Save metadata preview ---


func test_save_metadata_contains_required_fields() -> void:
	_economy._current_cash = 5000.0
	_time_system.current_day = 12
	_store_state_manager.register_slot_ownership(0, &"sports")
	_store_state_manager.register_slot_ownership(1, &"retro_games")
	GameManager.owned_stores = [&"sports", &"retro_games"]
	GameManager.current_store_id = &"sports"

	_save_manager.save_game(_test_slot)

	var raw: Dictionary = _read_save_file_raw(_test_slot)
	assert_has(
		raw, "save_metadata",
		"Save file must have top-level save_metadata key"
	)
	var sm: Dictionary = raw["save_metadata"] as Dictionary
	assert_eq(int(sm["day"]), 12, "save_metadata.day should be 12")
	assert_almost_eq(
		float(sm["cash"]), 5000.0, 0.01,
		"save_metadata.cash should be 5000"
	)
	assert_true(
		sm["owned_stores"] is Array,
		"save_metadata.owned_stores should be an Array"
	)
	var stores: Array = sm["owned_stores"] as Array
	assert_eq(
		stores.size(), 2,
		"save_metadata.owned_stores should have 2 entries"
	)
	assert_has(stores, "sports", "owned_stores should include sports")
	assert_has(
		stores, "retro_games",
		"owned_stores should include retro_games"
	)
	assert_true(
		str(sm["saved_at"]).length() > 0,
		"save_metadata.saved_at should not be empty"
	)


func test_save_metadata_cash_reflects_current_balance() -> void:
	_economy._current_cash = 42.99
	_time_system.current_day = 1
	GameManager.owned_stores = []
	GameManager.current_store_id = &""

	_save_manager.save_game(_test_slot)

	var meta: Dictionary = _save_manager.get_slot_metadata(_test_slot)
	assert_almost_eq(
		float(meta.get("cash", 0.0)), 42.99, 0.01,
		"get_slot_metadata cash should match current balance"
	)


func test_save_metadata_empty_slot_returns_empty() -> void:
	_save_manager.delete_save(_test_slot)
	var meta: Dictionary = _save_manager.get_slot_metadata(_test_slot)
	assert_eq(
		meta.size(), 0,
		"Empty slot should return empty dictionary"
	)


func test_save_metadata_no_owned_stores() -> void:
	_economy._current_cash = 100.0
	_time_system.current_day = 1
	GameManager.owned_stores = []
	GameManager.current_store_id = &""

	_save_manager.save_game(_test_slot)

	var raw: Dictionary = _read_save_file_raw(_test_slot)
	var sm: Dictionary = raw["save_metadata"] as Dictionary
	var stores: Array = sm["owned_stores"] as Array
	assert_eq(
		stores.size(), 0,
		"owned_stores should be empty when no stores owned"
	)


func test_save_metadata_atomic_with_full_save() -> void:
	_economy._current_cash = 999.0
	_time_system.current_day = 7
	_store_state_manager.register_slot_ownership(0, &"sports")
	GameManager.owned_stores = [&"sports"]
	GameManager.current_store_id = &"sports"

	_save_manager.save_game(_test_slot)

	var raw: Dictionary = _read_save_file_raw(_test_slot)
	assert_has(raw, "save_metadata", "save_metadata must exist")
	assert_has(raw, "economy", "economy data must exist")
	assert_has(raw, "time", "time data must exist")

	var sm: Dictionary = raw["save_metadata"] as Dictionary
	var econ: Dictionary = raw["economy"] as Dictionary
	assert_almost_eq(
		float(sm["cash"]),
		float(econ.get("current_cash", 0.0)),
		0.01,
		"save_metadata.cash must match economy.current_cash"
	)


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
			var expected_str: String = str(expected[key])
			var actual_str: String = str(actual[key])
			assert_eq(
				actual_str, expected_str,
				"%s.%s mismatch" % [label, key]
			)


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
