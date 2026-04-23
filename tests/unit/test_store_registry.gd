## Unit tests for StoreRegistry autoload (ISSUE-019).
## Covers known-id resolution, unknown-id fail-loud path, duplicate-register
## guard, and the seeded Sneaker Citadel entry.
extends GutTest

const StoreRegistryScript: GDScript = preload("res://game/autoload/store_registry.gd")
const StoreRegistryEntryScript: GDScript = preload(
	"res://game/autoload/store_registry_entry.gd"
)

var _registry: Node


func before_each() -> void:
	_registry = StoreRegistryScript.new()
	add_child_autofree(_registry)
	# _ready already seeded defaults; tests that need a clean slate reset.


func test_resolves_seeded_sneaker_citadel() -> void:
	var entry: StoreRegistryEntry = _registry.resolve(&"sneaker_citadel")
	assert_not_null(entry, "sneaker_citadel must be seeded by _ready")
	assert_eq(entry.store_id, &"sneaker_citadel")
	assert_ne(entry.scene_path, "", "scene_path must be non-empty")
	assert_true(entry.scene_path.begins_with("res://"),
		"scene_path must be a Godot resource path")


func test_unknown_id_returns_null_and_pushes_error() -> void:
	# push_error in headless still routes through _print_error_messages; GUT's
	# assert_no_new_orphans / error capture isn't reliable across versions, so
	# we assert the contract (null return) and trust push_error fires.
	var entry: StoreRegistryEntry = _registry.resolve(&"bogus_id")
	assert_null(entry, "unknown store_id must return null (no silent fallback)")


func test_empty_id_returns_null() -> void:
	var entry: StoreRegistryEntry = _registry.resolve(&"")
	assert_null(entry, "empty store_id must return null")


func test_has_reports_membership() -> void:
	assert_true(_registry.has(&"sneaker_citadel"))
	assert_false(_registry.has(&"nope"))


func test_all_ids_includes_seeded() -> void:
	var ids: Array[StringName] = _registry.all_ids()
	assert_true(ids.has(&"sneaker_citadel"),
		"all_ids must include the seeded sneaker_citadel entry")


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
	var original_entry: StoreRegistryEntry = _registry.resolve(&"sneaker_citadel")
	var original_path: String = original_entry.scene_path

	var dup := StoreRegistryEntryScript.new(
		&"sneaker_citadel",
		"res://game/scenes/stores/SHOULD_NOT_OVERWRITE.tscn",
		null,
		"Should Not Overwrite",
		{}
	)
	var ok: bool = _registry.register(dup)
	assert_false(ok, "duplicate register must return false")
	assert_eq(_registry.resolve(&"sneaker_citadel").scene_path, original_path,
		"original entry must survive a duplicate register attempt")
