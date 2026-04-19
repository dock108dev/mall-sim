## ISSUE-011: Save file versioning and migration chain.
## Each migration function is a pure Dictionary → Dictionary transform and
## can be tested in isolation. The full-chain test loads fixture saves at
## earlier versions and asserts the output matches CURRENT_SAVE_VERSION.
extends GutTest


const FIXTURE_V0: String = "res://tests/fixtures/saves/v0_legacy.json"
const FIXTURE_V1: String = "res://tests/fixtures/saves/v1_pre_trade_removal.json"

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


func test_migration_does_not_mutate_input_dictionary() -> void:
	var raw: Dictionary = _load_fixture(FIXTURE_V0)
	var original_snapshot: String = JSON.stringify(raw)
	var _result: Dictionary = _save_manager.migrate_save_data(raw)
	assert_eq(
		JSON.stringify(raw),
		original_snapshot,
		"migrate_save_data must work on a copy; input must be untouched"
	)
