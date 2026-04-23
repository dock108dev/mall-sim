## ISSUE-024: schema_version field is the canonical version key. Loads must
## accept matching versions, migrate lower versions, and reject higher versions
## with a non-fatal failure signal — never partial-load.
extends GutTest


const TEST_SLOT: int = 1
const STORE_ID: StringName = &"sports"

var _save_manager: SaveManager
var _economy: EconomySystem
var _inventory: InventorySystem
var _time_system: TimeSystem
var _reputation: ReputationSystem
var _store_state_manager: StoreStateManager
var _data_loader: DataLoader
var _failed_signal_payload: Dictionary = {}


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	_failed_signal_payload = {}

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

	EventBus.save_load_failed.connect(_on_save_load_failed)


func after_each() -> void:
	if EventBus.save_load_failed.is_connected(_on_save_load_failed):
		EventBus.save_load_failed.disconnect(_on_save_load_failed)
	for slot: int in range(0, 4):
		_save_manager.delete_save(slot)
	if FileAccess.file_exists(SaveManager.SLOT_INDEX_PATH):
		DirAccess.remove_absolute(SaveManager.SLOT_INDEX_PATH)
	ContentRegistry.clear_for_testing()


func _on_save_load_failed(slot: int, reason: String) -> void:
	_failed_signal_payload = {"slot": slot, "reason": reason}


func _seed_minimal_save() -> void:
	_store_state_manager.register_slot_ownership(0, STORE_ID)
	_store_state_manager.set_active_store(STORE_ID, false)
	assert_true(_save_manager.save_game(TEST_SLOT), "Precondition: seed save succeeds")


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


func _read_raw(slot: int) -> Dictionary:
	var path: String = _save_manager._get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "Save file must exist at %s" % path)
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	assert_eq(json.parse(text), OK, "Save file must be valid JSON")
	return json.data as Dictionary


func _write_raw(slot: int, data: Dictionary) -> void:
	var path: String = _save_manager._get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "Save file must open for write at %s" % path)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func test_written_save_contains_schema_version_field() -> void:
	_seed_minimal_save()
	var data: Dictionary = _read_raw(TEST_SLOT)
	assert_has(data, "schema_version", "Save must include canonical schema_version")
	assert_eq(
		int(data["schema_version"]),
		SaveManager.CURRENT_SAVE_VERSION,
		"schema_version must equal CURRENT_SAVE_VERSION"
	)
	# Legacy alias still written for older readers.
	assert_has(data, "save_version", "Legacy save_version alias must still be written")
	assert_eq(
		int(data["save_version"]),
		int(data["schema_version"]),
		"save_version alias must equal schema_version"
	)


func test_matching_schema_version_loads_successfully() -> void:
	_seed_minimal_save()
	_economy._current_cash = 0.0
	var loaded: bool = _save_manager.load_game(TEST_SLOT)
	assert_true(loaded, "Matching schema_version save must load")
	assert_true(_failed_signal_payload.is_empty(), "No failure signal on matching version")


func test_higher_schema_version_is_rejected_with_signal() -> void:
	_seed_minimal_save()
	var data: Dictionary = _read_raw(TEST_SLOT)
	data["schema_version"] = SaveManager.CURRENT_SAVE_VERSION + 1
	data["save_version"] = SaveManager.CURRENT_SAVE_VERSION + 1
	_write_raw(TEST_SLOT, data)

	var loaded: bool = _save_manager.load_game(TEST_SLOT)
	assert_false(loaded, "Higher-than-supported schema_version must be rejected")
	assert_eq(
		int(_failed_signal_payload.get("slot", -1)),
		TEST_SLOT,
		"save_load_failed must fire for the rejected slot"
	)
	var reason: String = str(_failed_signal_payload.get("reason", ""))
	assert_true(
		reason.contains("newer"),
		"Failure reason should mention newer-than-supported version (got '%s')" % reason
	)


func test_lower_schema_version_is_migrated_and_loads() -> void:
	_seed_minimal_save()
	var data: Dictionary = _read_raw(TEST_SLOT)
	# Force the canonical key to a prior, supported version. The migration chain
	# from 2 → CURRENT is well-covered by test_save_migration_chain.gd.
	data["schema_version"] = 2
	data["save_version"] = 2
	# Strip post-v2 fields that v2 saves would not have, so the migration step
	# is exercised rather than skipped.
	data.erase("reputation")
	_write_raw(TEST_SLOT, data)

	var loaded: bool = _save_manager.load_game(TEST_SLOT)
	assert_true(loaded, "Lower schema_version save must migrate and load")
	assert_true(
		_failed_signal_payload.is_empty(),
		"Migration path must not emit save_load_failed"
	)


func test_schema_version_takes_precedence_over_legacy_save_version() -> void:
	_seed_minimal_save()
	var data: Dictionary = _read_raw(TEST_SLOT)
	# Disagreeing keys: canonical says current, legacy claims an unsupportable
	# future version. Loader must trust schema_version.
	data["schema_version"] = SaveManager.CURRENT_SAVE_VERSION
	data["save_version"] = SaveManager.CURRENT_SAVE_VERSION + 99
	_write_raw(TEST_SLOT, data)

	var loaded: bool = _save_manager.load_game(TEST_SLOT)
	assert_true(loaded, "schema_version must be preferred over legacy save_version")
