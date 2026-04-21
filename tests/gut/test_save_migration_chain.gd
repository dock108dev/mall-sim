## ISSUE-011/ISSUE-014: Save file versioning and migration chain.
## Each migration function is a pure Dictionary → Dictionary transform and
## can be tested in isolation. The full-chain test loads fixture saves at
## earlier versions and asserts the output matches CURRENT_SAVE_VERSION.
extends GutTest


const FIXTURE_V0: String = "res://tests/fixtures/saves/v0_legacy.json"
const FIXTURE_V1: String = "res://tests/fixtures/saves/v1_pre_trade_removal.json"
const FIXTURE_V2: String = "res://tests/fixtures/saves/v2_pre_reputation.json"
const FIXTURE_V3: String = "res://tests/fixtures/saves/v3_current.json"

var _save_manager: SaveManager


func before_each() -> void:
	_save_manager = SaveManager.new()
	add_child_autofree(_save_manager)


func _load_fixture(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "Fixture must exist at %s" % path)
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "Fixture %s must be a JSON object" % path)
	return parsed as Dictionary


func test_migrate_v0_to_v1_produces_save_metadata_and_owned_slots() -> void:
	var raw: Dictionary = _load_fixture(FIXTURE_V0)
	var migrated: Dictionary = _save_manager._migrate_v0_to_v1(raw.duplicate(true))

	assert_true(
		migrated.has("save_metadata"),
		"v0 → v1 must materialize save_metadata"
	)
	var save_metadata: Dictionary = migrated["save_metadata"] as Dictionary
	assert_eq(
		int(save_metadata.get("day_number", -1)),
		4,
		"day_number should come from legacy metadata.day_number"
	)
	assert_eq(
		str(save_metadata.get("active_store_id", "")),
		"sports",
		"active_store_id should be copied from legacy metadata"
	)
	assert_false(
		migrated.has("owned_stores"),
		"Legacy root-level owned_stores should be removed by the chain"
	)


func test_migrate_v1_to_v2_strips_obsolete_trade_key() -> void:
	var raw: Dictionary = _load_fixture(FIXTURE_V1)
	assert_true(raw.has("trade"), "Fixture should include obsolete trade key")
	var migrated: Dictionary = _save_manager._migrate_v1_to_v2(raw.duplicate(true))

	assert_false(
		migrated.has("trade"),
		"v1 → v2 must drop the obsolete trade root key"
	)
	assert_eq(
		int(
			(migrated["save_metadata"] as Dictionary).get("save_version_tag", -1)
		),
		2,
		"v1 → v2 should tag save_metadata with the current version"
	)
	assert_eq(
		float(raw["economy"]["player_cash"]),
		float(migrated["economy"]["player_cash"]),
		"Unrelated fields should pass through unchanged"
	)


func test_migrate_v1_to_v2_is_idempotent_on_current_shape() -> void:
	var raw: Dictionary = _load_fixture(FIXTURE_V1)
	var once: Dictionary = _save_manager._migrate_v1_to_v2(raw.duplicate(true))
	var twice: Dictionary = _save_manager._migrate_v1_to_v2(once.duplicate(true))
	assert_eq(
		JSON.stringify(once),
		JSON.stringify(twice),
		"Running v1 → v2 twice should be a no-op"
	)


func test_full_chain_migrates_v0_fixture_to_current_version() -> void:
	var raw: Dictionary = _load_fixture(FIXTURE_V0)
	var result: Dictionary = _save_manager.migrate_save_data(raw)
	assert_true(bool(result.get("ok", false)), "Migration chain should succeed")
	var migrated: Dictionary = result["data"] as Dictionary
	assert_eq(
		int(migrated.get("save_version", -1)),
		SaveManager.CURRENT_SAVE_VERSION,
		"Full chain should arrive at CURRENT_SAVE_VERSION"
	)
	assert_false(migrated.has("trade"), "Obsolete trade key should be removed")
	assert_false(migrated.has("metadata"), "Legacy metadata key should be removed")
	assert_true(
		migrated.has("save_metadata"),
		"save_metadata should exist post-chain"
	)


func test_full_chain_migrates_v1_fixture_to_current_version() -> void:
	var raw: Dictionary = _load_fixture(FIXTURE_V1)
	var result: Dictionary = _save_manager.migrate_save_data(raw)
	assert_true(bool(result.get("ok", false)), "Migration chain should succeed")
	var migrated: Dictionary = result["data"] as Dictionary
	assert_eq(
		int(migrated.get("save_version", -1)),
		SaveManager.CURRENT_SAVE_VERSION,
		"Full chain should arrive at CURRENT_SAVE_VERSION"
	)
	assert_false(migrated.has("trade"), "Obsolete trade key should be removed")


func test_migrate_v2_to_v3_adds_reputation_block_when_missing() -> void:
	var raw: Dictionary = _load_fixture(FIXTURE_V2)
	assert_false(raw.has("reputation"), "v2 fixture must not have reputation block")
	var migrated: Dictionary = _save_manager._migrate_v2_to_v3(raw.duplicate(true))

	assert_true(migrated.has("reputation"), "v2 → v3 must add reputation block")
	var rep: Dictionary = migrated["reputation"] as Dictionary
	assert_true(rep.has("scores"), "reputation must have scores key")
	assert_true(rep.has("tiers"), "reputation must have tiers key")
	assert_true(rep.has("tier_locks"), "reputation must have tier_locks key")
	assert_eq(
		int((migrated["save_metadata"] as Dictionary).get("save_version_tag", -1)),
		3,
		"v2 → v3 should tag save_metadata with version 3"
	)


func test_migrate_v2_to_v3_preserves_existing_reputation_subkeys() -> void:
	var raw: Dictionary = {
		"save_version": 2,
		"save_metadata": {"save_version_tag": 2},
		"reputation": {"scores": {"retro_games": 25.0}},
	}
	var migrated: Dictionary = _save_manager._migrate_v2_to_v3(raw.duplicate(true))

	var rep: Dictionary = migrated["reputation"] as Dictionary
	assert_eq(
		float(rep.get("scores", {}).get("retro_games", 0.0)),
		25.0,
		"Existing reputation scores must be preserved"
	)
	assert_true(rep.has("tiers"), "tiers key must be added when missing")
	assert_true(rep.has("tier_locks"), "tier_locks key must be added when missing")


func test_full_chain_migrates_v2_fixture_to_current_version() -> void:
	var raw: Dictionary = _load_fixture(FIXTURE_V2)
	var result: Dictionary = _save_manager.migrate_save_data(raw)
	assert_true(bool(result.get("ok", false)), "Migration chain from v2 should succeed")
	var migrated: Dictionary = result["data"] as Dictionary
	assert_eq(
		int(migrated.get("save_version", -1)),
		SaveManager.CURRENT_SAVE_VERSION,
		"Full chain from v2 should arrive at CURRENT_SAVE_VERSION"
	)
	var rep: Dictionary = migrated.get("reputation", {}) as Dictionary
	assert_true(rep.has("scores"), "reputation.scores must exist after v2 chain")
	assert_true(rep.has("tiers"), "reputation.tiers must exist after v2 chain")
	assert_true(rep.has("tier_locks"), "reputation.tier_locks must exist after v2 chain")


func test_v3_fixture_is_already_at_current_version() -> void:
	var raw: Dictionary = _load_fixture(FIXTURE_V3)
	assert_eq(
		int(raw.get("save_version", -1)),
		SaveManager.CURRENT_SAVE_VERSION,
		"v3 fixture must match CURRENT_SAVE_VERSION"
	)
	var rep: Dictionary = raw.get("reputation", {}) as Dictionary
	assert_true(rep.has("scores"), "v3 fixture must have reputation.scores")
	assert_true(rep.has("tiers"), "v3 fixture must have reputation.tiers")
	assert_true(rep.has("tier_locks"), "v3 fixture must have reputation.tier_locks")


func test_migration_does_not_mutate_input_dictionary() -> void:
	var raw: Dictionary = _load_fixture(FIXTURE_V0)
	var original_snapshot: String = JSON.stringify(raw)
	var _result: Dictionary = _save_manager.migrate_save_data(raw)
	assert_eq(
		JSON.stringify(raw),
		original_snapshot,
		"migrate_save_data must work on a copy; input must be untouched"
	)


## ISSUE-016: migrations must copy the pre-migration file to user://backups/
## so operators can recover the original on-disk shape.
func test_backup_before_migration_writes_copy_to_backup_dir() -> void:
	var source_path: String = "user://test_issue016_source.json"
	var payload: String = JSON.stringify(
		{"save_version": 1, "marker": "original_v1"}, "\t"
	)
	var writer: FileAccess = FileAccess.open(source_path, FileAccess.WRITE)
	assert_not_null(writer, "Test fixture file must open for write")
	writer.store_string(payload)
	writer.close()

	_save_manager._backup_before_migration(source_path, 0, 1)

	var found_backup: String = ""
	var dir: DirAccess = DirAccess.open(SaveManager.BACKUP_DIR)
	assert_not_null(
		dir, "Backup directory must be created by _backup_before_migration"
	)
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("save_slot_0_v1_") and entry.ends_with(".json"):
			found_backup = SaveManager.BACKUP_DIR + entry
			break
		entry = dir.get_next()
	dir.list_dir_end()

	assert_ne(found_backup, "", "A versioned backup file must exist")
	var reader: FileAccess = FileAccess.open(found_backup, FileAccess.READ)
	assert_not_null(reader, "Backup file must be readable")
	var backup_contents: String = reader.get_as_text()
	reader.close()
	assert_eq(
		backup_contents,
		payload,
		"Backup contents must match the pre-migration source byte-for-byte"
	)

	DirAccess.remove_absolute(source_path)
	DirAccess.remove_absolute(found_backup)


func test_backup_before_migration_is_noop_when_source_missing() -> void:
	var missing_path: String = "user://does_not_exist_issue016.json"
	_save_manager._backup_before_migration(missing_path, 0, 1)
	assert_false(
		FileAccess.file_exists(missing_path),
		"Noop path must not create the source file"
	)
