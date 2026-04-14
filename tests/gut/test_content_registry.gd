## Tests ContentRegistry: ID normalization, alias lookup, unknown ID handling,
## entry retrieval, and type-filtered get_all_ids.
extends GutTest


var _registry: Node

const _SPORTS_ENTRY: Dictionary = {
	"id": "sports",
	"name": "Sports Memorabilia",
	"aliases": ["sports_memorabilia", "sports_cards"],
	"scene_path": "res://game/scenes/stores/sports_memorabilia.tscn",
}

const _RETRO_ENTRY: Dictionary = {
	"id": "retro_games",
	"name": "Retro Games",
	"scene_path": "res://game/scenes/stores/retro_games.tscn",
}

const _RENTALS_ENTRY: Dictionary = {
	"id": "rentals",
	"name": "Video Rental",
	"aliases": ["video_rental", "video_rentals"],
	"scene_path": "res://game/scenes/stores/video_rental.tscn",
}

const _ELECTRONICS_ENTRY: Dictionary = {
	"id": "electronics",
	"name": "Consumer Electronics",
	"aliases": ["consumer_electronics"],
	"scene_path": "res://game/scenes/stores/consumer_electronics.tscn",
}

const _POCKET_ENTRY: Dictionary = {
	"id": "pocket_creatures",
	"name": "Pocket Creatures",
	"aliases": ["pocket_creatures_cards"],
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
	_registry.register_entry(_RENTALS_ENTRY, "store")
	_registry.register_entry(_ELECTRONICS_ENTRY, "store")
	_registry.register_entry(_POCKET_ENTRY, "store")


func test_resolve_canonical_id_unchanged() -> void:
	var result: StringName = _registry.resolve("sports")
	assert_eq(result, &"sports", "Valid snake_case ID returns unchanged")


func test_resolve_another_canonical_id() -> void:
	var result: StringName = _registry.resolve("retro_games")
	assert_eq(
		result, &"retro_games",
		"Multi-word snake_case ID returns unchanged"
	)


func test_resolve_alias_to_canonical() -> void:
	var result: StringName = _registry.resolve("sports_memorabilia")
	assert_eq(
		result, &"sports",
		"Alias resolves to canonical ID"
	)


func test_resolve_video_rental_alias() -> void:
	var result: StringName = _registry.resolve("video_rental")
	assert_eq(
		result, &"rentals",
		"video_rental alias resolves to rentals"
	)


func test_resolve_consumer_electronics_alias() -> void:
	var result: StringName = _registry.resolve("consumer_electronics")
	assert_eq(
		result, &"electronics",
		"consumer_electronics alias resolves to electronics"
	)


func test_resolve_display_name_mixed_case() -> void:
	var result: StringName = _registry.resolve("Sports Memorabilia")
	assert_eq(
		result, &"sports",
		"Display name with spaces resolves to canonical"
	)


func test_resolve_kebab_case_normalizes() -> void:
	var result: StringName = _registry.resolve("retro-games")
	assert_eq(
		result, &"retro_games",
		"Kebab-case normalizes to snake_case"
	)


func test_resolve_pascal_case_normalizes() -> void:
	var result: StringName = _registry.resolve("RetroGames")
	assert_eq(
		result, &"retro_games",
		"PascalCase normalizes to snake_case"
	)


func test_resolve_whitespace_stripped() -> void:
	var result: StringName = _registry.resolve("  Retro Games  ")
	assert_eq(
		result, &"retro_games",
		"Leading/trailing whitespace stripped before resolve"
	)


func test_resolve_unknown_id_returns_empty() -> void:
	var result: StringName = _registry.resolve("nonexistent_store")
	assert_eq(
		result, &"",
		"Unknown ID returns empty StringName"
	)


func test_resolve_empty_string_returns_empty() -> void:
	var result: StringName = _registry.resolve("")
	assert_eq(result, &"", "Empty input returns empty StringName")


func test_two_aliases_same_canonical() -> void:
	var result_a: StringName = _registry.resolve("sports_memorabilia")
	var result_b: StringName = _registry.resolve("sports_cards")
	assert_eq(
		result_a, &"sports",
		"First alias resolves to canonical"
	)
	assert_eq(
		result_b, &"sports",
		"Second alias resolves to same canonical"
	)
	assert_eq(
		result_a, result_b,
		"Both aliases resolve to identical canonical ID"
	)


func test_two_aliases_rentals() -> void:
	var result_a: StringName = _registry.resolve("video_rental")
	var result_b: StringName = _registry.resolve("video_rentals")
	assert_eq(result_a, &"rentals")
	assert_eq(result_b, &"rentals")


func test_exists_canonical() -> void:
	assert_true(
		_registry.exists("sports"),
		"Canonical ID should exist"
	)


func test_exists_alias() -> void:
	assert_true(
		_registry.exists("sports_memorabilia"),
		"Alias should report as existing"
	)


func test_exists_unknown() -> void:
	assert_false(
		_registry.exists("fake_store_xyz"),
		"Unknown ID should not exist"
	)


func test_get_entry_valid_canonical() -> void:
	var entry: Dictionary = _registry.get_entry(&"sports")
	assert_false(entry.is_empty(), "Valid ID returns non-empty dict")
	assert_eq(
		str(entry.get("id", "")), "sports",
		"Entry has correct id field"
	)
	assert_eq(
		str(entry.get("name", "")), "Sports Memorabilia",
		"Entry has correct name field"
	)


func test_get_entry_via_alias() -> void:
	var entry: Dictionary = _registry.get_entry(&"sports_memorabilia")
	assert_false(entry.is_empty(), "Alias returns non-empty dict")
	assert_eq(
		str(entry.get("id", "")), "sports",
		"Alias resolves to correct entry"
	)


func test_get_entry_invalid_returns_empty() -> void:
	var entry: Dictionary = _registry.get_entry(&"nonexistent")
	assert_true(entry.is_empty(), "Unknown ID returns empty dict")


func test_get_display_name() -> void:
	var display: String = _registry.get_display_name(&"sports")
	assert_eq(display, "Sports Memorabilia")


func test_get_display_name_via_alias() -> void:
	var display: String = _registry.get_display_name(
		&"consumer_electronics"
	)
	assert_eq(display, "Consumer Electronics")


func test_get_scene_path() -> void:
	var path: String = _registry.get_scene_path(&"sports")
	assert_eq(
		path,
		"res://game/scenes/stores/sports_memorabilia.tscn"
	)


func test_get_scene_path_via_alias() -> void:
	var path: String = _registry.get_scene_path(&"video_rental")
	assert_eq(
		path,
		"res://game/scenes/stores/video_rental.tscn"
	)


func test_get_all_ids_store() -> void:
	var ids: Array[StringName] = _registry.get_all_ids("store")
	assert_eq(ids.size(), 5, "Should return all 5 store IDs")
	assert_has(ids, &"sports")
	assert_has(ids, &"retro_games")
	assert_has(ids, &"rentals")
	assert_has(ids, &"pocket_creatures")
	assert_has(ids, &"electronics")


func test_get_all_ids_unknown_type() -> void:
	var ids: Array[StringName] = _registry.get_all_ids("widget")
	assert_eq(ids.size(), 0, "Unknown type returns empty array")


func test_all_stores_have_scene_paths() -> void:
	var ids: Array[StringName] = _registry.get_all_ids("store")
	for id: StringName in ids:
		var path: String = _registry.get_scene_path(id)
		assert_false(
			path.is_empty(),
			"Store '%s' should have a scene path" % id
		)


func test_is_ready_after_registration() -> void:
	assert_true(
		_registry.is_ready(),
		"Registry should be ready after entries registered"
	)


func test_is_ready_before_registration() -> void:
	var empty_reg: Node = Node.new()
	empty_reg.set_script(
		preload("res://game/autoload/content_registry.gd")
	)
	add_child_autofree(empty_reg)
	assert_false(
		empty_reg.is_ready(),
		"Fresh registry should not be ready"
	)
