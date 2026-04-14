## Unit tests for ContentRegistry: resolve() normalization, missing-ID guard,
## alias collision, entry retrieval, and StringName contract.
extends GutTest


var _registry: Node

const _SPORTS_ENTRY: Dictionary = {
	"id": "sports_memorabilia",
	"name": "Sports Memorabilia",
	"display_name": "Sports Memorabilia",
	"scene_path": "res://game/scenes/stores/sports_memorabilia.tscn",
}

const _RETRO_ENTRY: Dictionary = {
	"id": "retro_games",
	"name": "Retro Games",
	"display_name": "Retro Games",
	"scene_path": "res://game/scenes/stores/retro_games.tscn",
}

const _POCKET_ENTRY: Dictionary = {
	"id": "pocket_creatures",
	"name": "Pocket Creatures",
	"display_name": "Pocket Creatures",
	"aliases": ["pocket_cards"],
	"scene_path": "res://game/scenes/stores/pocket_creatures.tscn",
}


func before_each() -> void:
	_registry = Node.new()
	_registry.set_script(
		preload("res://game/autoload/content_registry.gd")
	)
	add_child_autofree(_registry)
	_registry.register_entry(_SPORTS_ENTRY, "store")
	_registry.register_entry(_RETRO_ENTRY, "store")
	_registry.register_entry(_POCKET_ENTRY, "store")


func test_resolve_canonical_returns_unchanged() -> void:
	var result: StringName = _registry.resolve("sports_memorabilia")
	assert_eq(
		result, &"sports_memorabilia",
		"Canonical snake_case ID returns unchanged"
	)


func test_resolve_display_name_normalizes_to_canonical() -> void:
	var result: StringName = _registry.resolve("Sports Memorabilia")
	assert_eq(
		result, &"sports_memorabilia",
		"Display name normalizes to canonical snake_case StringName"
	)


func test_resolve_unknown_id_returns_empty() -> void:
	var result: StringName = _registry.resolve("nonexistent_store")
	assert_eq(
		result, &"",
		"Unknown ID returns empty StringName without crash"
	)


func test_get_entry_valid_id_has_required_keys() -> void:
	var entry: Dictionary = _registry.get_entry(&"sports_memorabilia")
	assert_false(entry.is_empty(), "Valid ID returns non-empty dict")
	assert_true(
		entry.has("id"),
		"Entry should contain 'id' key"
	)
	assert_true(
		entry.has("display_name"),
		"Entry should contain 'display_name' key"
	)
	assert_true(
		entry.has("scene_path"),
		"Entry should contain 'scene_path' key"
	)


func test_get_entry_unknown_id_returns_empty() -> void:
	var entry: Dictionary = _registry.get_entry(&"bad_id")
	assert_true(
		entry.is_empty(),
		"Unknown ID returns empty Dictionary without crash"
	)


func test_get_display_name_valid() -> void:
	var display: String = _registry.get_display_name(&"retro_games")
	assert_false(
		display.is_empty(),
		"Valid ID returns non-empty display name"
	)
	assert_eq(display, "Retro Games")


func test_get_scene_path_valid_ends_with_tscn() -> void:
	var path: String = _registry.get_scene_path(&"retro_games")
	assert_false(path.is_empty(), "Valid ID returns non-empty path")
	assert_true(
		path.ends_with(".tscn"),
		"Scene path should end with '.tscn'"
	)


func test_resolve_idempotent() -> void:
	var first: StringName = _registry.resolve("sports_memorabilia")
	var second: StringName = _registry.resolve("sports_memorabilia")
	assert_eq(
		first, second,
		"Calling resolve() twice returns identical result"
	)
	assert_eq(
		first, &"sports_memorabilia",
		"Idempotent resolve returns canonical ID"
	)


func test_resolve_returns_string_name_type() -> void:
	var result: StringName = _registry.resolve("sports_memorabilia")
	assert_eq(
		typeof(result), TYPE_STRING_NAME,
		"resolve() must return StringName, not String"
	)


func test_resolve_unknown_returns_string_name_type() -> void:
	var result: StringName = _registry.resolve("nonexistent")
	assert_eq(
		typeof(result), TYPE_STRING_NAME,
		"resolve() returns StringName even for unknown IDs"
	)


func test_resolve_display_name_returns_string_name_type() -> void:
	var result: StringName = _registry.resolve("Retro Games")
	assert_eq(
		typeof(result), TYPE_STRING_NAME,
		"resolve() from display name returns StringName"
	)
	assert_eq(
		result, &"retro_games",
		"Display name resolves to correct canonical ID"
	)


func test_resolve_alias_returns_canonical() -> void:
	var result: StringName = _registry.resolve("pocket_cards")
	assert_eq(
		result, &"pocket_creatures",
		"Alias resolves to canonical ID"
	)


func test_resolve_empty_string_returns_empty() -> void:
	var result: StringName = _registry.resolve("")
	assert_eq(result, &"", "Empty input returns empty StringName")
