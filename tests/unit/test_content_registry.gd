## Unit tests for ContentRegistry resolve() normalization and unknown-ID behavior.
extends GutTest


const MockContentRegistryScript := preload(
	"res://tests/unit/mock_content_registry.gd"
)

var _registry: Variant

const _SPORTS_ENTRY: Dictionary = {
	"id": "sports",
	"name": "Sports Memorabilia",
	"display_name": "Sports Memorabilia",
	"aliases": ["sports_memorabilia", "sports_cards"],
	"scene_path": "res://game/scenes/stores/sports_memorabilia.tscn",
}


func before_each() -> void:
	_registry = MockContentRegistryScript.new()
	add_child_autofree(_registry)
	_registry.register_entry(_SPORTS_ENTRY, "store")
	var store_definition := StoreDefinition.new()
	store_definition.id = "sports"
	_registry.register(&"sports", store_definition, "store")


func test_resolve_canonical_returns_unchanged() -> void:
	var result: StringName = _registry.resolve("sports")
	assert_eq(
		result, &"sports",
		"Canonical snake_case ID returns unchanged"
	)


func test_resolve_mixed_case_and_alias_inputs_return_canonical() -> void:
	var mixed_case_result: StringName = _registry.resolve("Sports Memorabilia")
	var alias_result: StringName = _registry.resolve("sports_memorabilia")
	assert_eq(
		mixed_case_result, &"sports",
		"Display name normalizes to canonical snake_case StringName"
	)
	assert_eq(
		alias_result, &"sports",
		"Alias resolves to the canonical StringName"
	)


func test_resolve_unknown_id_returns_empty_and_records_error() -> void:
	var result: StringName = _registry.resolve("nonexistent_store")
	assert_eq(
		result, &"",
		"Unknown ID returns empty StringName"
	)
	assert_eq(
		_registry.warning_messages.size(), 1,
		"Unknown ID should emit exactly one warning"
	)
	assert_string_contains(
		_registry.warning_messages[0],
		"unknown ID 'nonexistent_store' (normalized: 'nonexistent_store')",
		"Unknown ID warning should include the raw and normalized forms"
	)


func test_two_aliases_mapping_to_same_canonical_each_resolve() -> void:
	var first_alias_result: StringName = _registry.resolve("sports_memorabilia")
	var second_alias_result: StringName = _registry.resolve("sports_cards")
	assert_eq(
		first_alias_result, &"sports",
		"First alias resolves to canonical ID"
	)
	assert_eq(
		second_alias_result, &"sports",
		"Second alias resolves to canonical ID"
	)


func test_get_entry_valid_canonical_id_returns_non_empty_dictionary() -> void:
	var entry: Dictionary = _registry.get_entry(&"sports")
	assert_false(entry.is_empty(), "Valid ID returns non-empty dict")
	assert_eq(str(entry.get("id", "")), "sports")


func test_get_entry_invalid_id_returns_empty_and_records_error() -> void:
	var entry: Dictionary = _registry.get_entry(&"bad_id")
	assert_true(
		entry.is_empty(),
		"Unknown ID returns empty Dictionary"
	)
	assert_eq(
		_registry.warning_messages.size(), 1,
		"Invalid get_entry should emit exactly one warning"
	)
	assert_string_contains(
		_registry.warning_messages[0],
		"unknown ID 'bad_id' (normalized: 'bad_id')",
		"Invalid get_entry should report the unknown ID"
	)


func test_get_display_name_invalid_id_returns_raw_and_warns_once() -> void:
	var first_result: String = _registry.get_display_name(&"bad_id")
	var second_result: String = _registry.get_display_name(&"bad_id")
	assert_eq(first_result, "bad_id", "Unknown IDs should fall back to raw display text")
	assert_eq(
		second_result, "bad_id",
		"Repeated unknown lookups should keep the same fallback text"
	)
	assert_eq(
		_registry.warning_messages.size(), 1,
		"Unknown display-name fallback should warn once"
	)
	assert_string_contains(
		_registry.warning_messages[0],
		"get_display_name fallback for unknown ID 'bad_id'",
		"Warning should describe the helper fallback"
	)


func test_get_scene_path_invalid_id_returns_empty_and_warns_once() -> void:
	var first_result: String = _registry.get_scene_path(&"bad_id")
	var second_result: String = _registry.get_scene_path(&"bad_id")
	assert_eq(first_result, "", "Unknown IDs should return an empty scene path")
	assert_eq(
		second_result, "",
		"Repeated unknown scene-path lookups should keep the empty fallback"
	)
	assert_eq(
		_registry.warning_messages.size(), 1,
		"Unknown scene-path fallback should warn once"
	)
	assert_string_contains(
		_registry.warning_messages[0],
		"get_scene_path fallback for unknown ID 'bad_id'",
		"Warning should describe the missing scene-path lookup"
	)


func test_get_scene_path_registered_store_without_scene_warns_once() -> void:
	_registry.register_entry(
		{
			"id": "scene_less_store",
			"name": "Scene-less Store",
		},
		"store"
	)
	var first_result: String = _registry.get_scene_path(&"scene_less_store")
	var second_result: String = _registry.get_scene_path(&"scene_less_store")
	assert_eq(first_result, "", "Registered stores without a scene should still return empty")
	assert_eq(
		second_result, "",
		"Repeated scene-less store lookups should keep the empty fallback"
	)
	assert_eq(
		_registry.warning_messages.size(), 1,
		"Missing registered scene paths should warn once"
	)
	assert_string_contains(
		_registry.warning_messages[0],
		"get_scene_path fallback for ID 'scene_less_store' — no scene path is registered",
		"Warning should explain that the store has no registered scene"
	)


func test_get_item_definition_type_mismatch_returns_null_and_records_error() -> void:
	var result: ItemDefinition = _registry.get_item_definition(&"sports")
	assert_null(result, "Type mismatch should return null")
	assert_eq(
		_registry.error_messages.size(),
		1,
		"Type mismatch should emit exactly one error"
	)
	assert_string_contains(
		_registry.error_messages[0],
		"type mismatch for 'sports' — expected 'item', got 'store'",
		"Type mismatch error should include the canonical ID and both types"
	)


func test_store_scene_path_outside_store_scene_root_is_rejected() -> void:
	_registry.error_messages.clear()
	_registry.register_entry(
		{
			"id": "rogue_store",
			"name": "Rogue Store",
			"scene_path": "res://game/scenes/ui/settings_panel.tscn",
		},
		"store"
	)
	assert_eq(
		_registry.get_scene_path(&"rogue_store"),
		"",
		"Store entries should not retain scene paths outside the store scene root"
	)
	assert_eq(
		_registry.error_messages.size(),
		1,
		"Invalid store scene path should emit exactly one error"
	)
	assert_string_contains(
		_registry.error_messages[0],
		"store scene path 'res://game/scenes/ui/settings_panel.tscn'",
		"Error should describe the rejected store scene path"
	)


func test_resolve_empty_string_returns_empty() -> void:
	var result: StringName = _registry.resolve("")
	assert_eq(result, &"", "Empty input returns empty StringName")
