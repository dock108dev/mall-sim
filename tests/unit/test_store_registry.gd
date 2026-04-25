## Unit tests for StoreRegistry autoload.
## Covers content-registry-driven seeding, known-id resolution, unknown-id
## fail-loud path, and the duplicate-register guard.
## The registry is a runtime cache of `store_definitions.json` per
## `docs/decisions/0007-remove-sneaker-citadel.md`; it no longer hardcodes
## a seed entry.
extends GutTest

const StoreRegistryScript: GDScript = preload("res://game/autoload/store_registry.gd")
const StoreRegistryEntryScript: GDScript = preload(
	"res://game/autoload/store_registry_entry.gd"
)

var _registry: Node


func before_each() -> void:
	_registry = StoreRegistryScript.new()
	add_child_autofree(_registry)


func test_resolves_all_definitions_from_content_registry() -> void:
	# The registry is seeded from ContentRegistry.get_all_store_ids() — every
	# id declared in store_definitions.json must resolve to a non-empty scene
	# path (SSOT: game/content/stores/store_definitions.json).
	var ids: Array[StringName] = ContentRegistry.get_all_store_ids()
	assert_gt(ids.size(), 0, "ContentRegistry must expose at least one store id")
	for store_id: StringName in ids:
		var entry: StoreRegistryEntry = _registry.resolve(store_id)
		assert_not_null(
			entry, "store '%s' must resolve through the registry" % store_id
		)
		assert_eq(entry.store_id, store_id)
		assert_ne(entry.scene_path, "", "scene_path must be non-empty")
		assert_true(
			entry.scene_path.begins_with("res://"),
			"scene_path must be a Godot resource path"
		)


func test_unknown_id_returns_null_and_pushes_error() -> void:
	var entry: StoreRegistryEntry = _registry.resolve(&"bogus_id")
	assert_null(entry, "unknown store_id must return null (no silent fallback)")


func test_empty_id_returns_null() -> void:
	var entry: StoreRegistryEntry = _registry.resolve(&"")
	assert_null(entry, "empty store_id must return null")


func test_has_reports_membership() -> void:
	var ids: Array[StringName] = ContentRegistry.get_all_store_ids()
	if ids.size() > 0:
		assert_true(_registry.has(ids[0]))
	assert_false(_registry.has(&"nope"))


func test_all_ids_matches_content_registry() -> void:
	var ids: Array[StringName] = _registry.all_ids()
	var source_ids: Array[StringName] = ContentRegistry.get_all_store_ids()
	assert_eq(
		ids.size(), source_ids.size(),
		"registry must seed every ContentRegistry store id"
	)


func test_register_new_entry_resolves() -> void:
	_registry.register(StoreRegistryEntryScript.new(
		&"unit_fixture",
		"res://game/scenes/stores/unit_fixture.tscn",
		null,
		"Unit Fixture",
		{}
	))
	var entry: StoreRegistryEntry = _registry.resolve(&"unit_fixture")
	assert_not_null(entry)
	assert_eq(entry.display_name, "Unit Fixture")


func test_duplicate_register_is_rejected_and_keeps_original() -> void:
	var ids: Array[StringName] = ContentRegistry.get_all_store_ids()
	if ids.is_empty():
		pass_test("no content-registry store ids available in this fixture")
		return
	var seed_id: StringName = ids[0]
	var original_entry: StoreRegistryEntry = _registry.resolve(seed_id)
	var original_path: String = original_entry.scene_path

	var dup: StoreRegistryEntry = StoreRegistryEntryScript.new(
		seed_id,
		"res://game/scenes/stores/SHOULD_NOT_OVERWRITE.tscn",
		null,
		"Should Not Overwrite",
		{}
	)
	var ok: bool = _registry.register(dup)
	assert_false(ok, "duplicate register must return false")
	assert_eq(
		_registry.resolve(seed_id).scene_path, original_path,
		"original entry must survive a duplicate register attempt"
	)
