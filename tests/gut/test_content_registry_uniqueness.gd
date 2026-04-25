## ISSUE-010: enforces that ContentRegistry rejects duplicate ids and
## conflicting aliases at boot-time validation time.
extends GutTest


var _registry: Node


const _SPORTS_ENTRY: Dictionary = {
	"id": "sports",
	"name": "Sports Memorabilia",
	"aliases": ["sports_memorabilia"],
	"scene_path": "res://game/scenes/stores/sports_memorabilia.tscn",
}

const _RETRO_ENTRY: Dictionary = {
	"id": "retro_games",
	"name": "Retro Games",
	"scene_path": "res://game/scenes/stores/retro_games.tscn",
}


func before_each() -> void:
	_registry = Node.new()
	_registry.set_script(
		preload("res://game/autoload/content_registry.gd")
	)
	add_child_autofree(_registry)


func test_clean_registration_has_no_duplicate_errors() -> void:
	_registry.register_entry(_SPORTS_ENTRY, "store")
	_registry.register_entry(_RETRO_ENTRY, "store")
	var errors: Array[String] = _registry.validate_all_references()
	var duplicate_errors: Array[String] = []
	for err: String in errors:
		if err.contains("duplicate"):
			duplicate_errors.append(err)
	assert_true(
		duplicate_errors.is_empty(),
		"Unexpected duplicate errors from clean registration: %s"
		% str(duplicate_errors)
	)


func test_duplicate_entry_id_is_recorded_as_validation_error() -> void:
	_registry.register_entry(_SPORTS_ENTRY, "store")
	var second: Dictionary = _SPORTS_ENTRY.duplicate()
	second["name"] = "Sports Alt"
	_registry.register_entry(second, "store")
	var errors: Array[String] = _registry.validate_all_references()
	var found: bool = false
	for err: String in errors:
		if err.contains("duplicate entry ID 'sports'"):
			found = true
			break
	assert_true(
		found,
		"Expected duplicate entry ID error in validate_all_references, got: %s"
		% str(errors)
	)


func test_duplicate_resource_id_is_recorded_as_validation_error() -> void:
	var store_a: StoreDefinition = StoreDefinition.new()
	var store_b: StoreDefinition = StoreDefinition.new()
	_registry.register(&"sports", store_a, "store")
	_registry.register(&"sports", store_b, "store")
	var errors: Array[String] = _registry.validate_all_references()
	var found: bool = false
	for err: String in errors:
		if err.contains("duplicate resource ID 'sports'"):
			found = true
			break
	assert_true(
		found,
		"Expected duplicate resource ID error, got: %s" % str(errors)
	)


func test_conflicting_alias_is_recorded_as_validation_error() -> void:
	_registry.register_entry(_SPORTS_ENTRY, "store")
	var conflicting: Dictionary = {
		"id": "retro_games",
		"name": "Retro Games",
		"aliases": ["sports_memorabilia"],
		"scene_path": "res://game/scenes/stores/retro_games.tscn",
	}
	_registry.register_entry(conflicting, "store")
	var errors: Array[String] = _registry.validate_all_references()
	var found: bool = false
	for err: String in errors:
		if err.contains("alias 'sports_memorabilia'") and err.contains("maps to both"):
			found = true
			break
	assert_true(
		found,
		"Expected alias conflict error, got: %s" % str(errors)
	)


func test_no_id_or_alias_collides_across_registered_content() -> void:
	# Boot-time invariant: after full content load, every canonical id and
	# every alias must resolve to exactly one target. This runs against the
	# live autoload registry, populated by the normal boot sequence.
	var registry: Node = get_node_or_null("/root/ContentRegistry")
	assert_not_null(
		registry,
		"ContentRegistry autoload must be present for this test"
	)
	if registry == null:
		return
	var entries: Dictionary = registry.get("_entries") as Dictionary
	var resources: Dictionary = registry.get("_resources") as Dictionary
	var aliases: Dictionary = registry.get("_aliases") as Dictionary
	var duplicate_errors: Array = registry.get("_duplicate_errors") as Array
	assert_eq(
		duplicate_errors.size(), 0,
		"Boot registration recorded duplicate-id errors: %s"
		% str(duplicate_errors)
	)
	for alias: StringName in aliases.keys():
		var target: StringName = aliases[alias]
		assert_true(
			entries.has(target) or resources.has(target),
			"Alias '%s' points to unknown canonical id '%s'" % [alias, target]
		)
		assert_false(
			entries.has(alias) and aliases[alias] != alias,
			"Alias '%s' also registered as a canonical entry id" % alias
		)
