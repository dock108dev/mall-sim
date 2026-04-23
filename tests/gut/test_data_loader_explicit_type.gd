## ISSUE-021 — every content JSON must declare an explicit root "type" field.
## DataLoader must fail boot with a precise per-entry error when the field is
## missing or the value is not in _TYPE_ROUTES. No filename / folder / field
## heuristic detection is permitted.
extends GutTest

const _TEST_ROOT := "user://test_data_loader_explicit_type/"


func before_each() -> void:
	DataLoaderSingleton.clear_for_testing()
	ContentRegistry.clear_for_testing()
	_clear_test_root()


func after_all() -> void:
	_clear_test_root()
	DataLoaderSingleton.clear_for_testing()
	ContentRegistry.clear_for_testing()
	# Restore the canonical content set for other tests.
	DataLoaderSingleton.load_all_content()


func test_missing_type_field_records_precise_error() -> void:
	var path: String = _write_json("missing_type.json", {
		"entries": [
			{"id": "anything", "name": "Whatever"}
		]
	})
	DataLoaderSingleton.load_all_content_from_root(_TEST_ROOT)
	var errors: Array[String] = DataLoaderSingleton.get_load_errors()
	assert_true(
		_has_error_mentioning(errors, path, "missing required 'type' field"),
		"Expected load error mentioning %s and \"missing required 'type' field\"; got: %s"
		% [path, errors]
	)


func test_unknown_type_field_records_precise_error() -> void:
	var path: String = _write_json("unknown_type.json", {
		"type": "not_a_real_type_xyz",
		"entries": [{"id": "x"}],
	})
	DataLoaderSingleton.load_all_content_from_root(_TEST_ROOT)
	var errors: Array[String] = DataLoaderSingleton.get_load_errors()
	assert_true(
		_has_error_mentioning(errors, path, "unknown content type 'not_a_real_type_xyz'"),
		"Expected load error mentioning %s and unknown type; got: %s"
		% [path, errors]
	)


func test_array_rooted_file_is_rejected_as_non_dict() -> void:
	var path: String = _write_raw("array_root.json", "[{\"id\": \"x\"}]")
	DataLoaderSingleton.load_all_content_from_root(_TEST_ROOT)
	var errors: Array[String] = DataLoaderSingleton.get_load_errors()
	assert_true(
		_has_error_mentioning(errors, path, "root must be a Dictionary"),
		"Expected load error mentioning %s and non-Dictionary root; got: %s"
		% [path, errors]
	)


func test_heuristic_detection_helpers_are_deleted() -> void:
	# Guard against reintroduction: source must not reference the deleted maps.
	var source_path: String = "res://game/autoload/data_loader.gd"
	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	assert_not_null(file, "Should open data_loader.gd")
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	for banned: String in [
		"_DIR_TYPE_MAP",
		"_ROOT_TYPE_MAP",
		"_TYPE_KEY_MAP",
		"_detect_type",
		"_detect_event_config_type",
	]:
		assert_false(
			text.contains(banned),
			"DataLoader must not reference heuristic detector '%s'" % banned
		)


func test_canonical_content_loads_without_errors() -> void:
	# Sanity: the on-disk content set must satisfy the explicit-type rule.
	DataLoaderSingleton.load_all_content()
	var errors: Array[String] = DataLoaderSingleton.get_load_errors()
	assert_eq(
		errors.size(), 0,
		"Canonical content must load without type errors; got: %s" % [errors]
	)


# --- helpers ---

func _write_json(name: String, data: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(_TEST_ROOT)
	var path: String = _TEST_ROOT + name
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	return path


func _write_raw(name: String, body: String) -> String:
	DirAccess.make_dir_recursive_absolute(_TEST_ROOT)
	var path: String = _TEST_ROOT + name
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(body)
	f.close()
	return path


func _has_error_mentioning(
	errors: Array[String], path: String, needle: String
) -> bool:
	for e: String in errors:
		if e.contains(path) and e.contains(needle):
			return true
	return false


func _clear_test_root() -> void:
	if not DirAccess.dir_exists_absolute(_TEST_ROOT):
		return
	var dir: DirAccess = DirAccess.open(_TEST_ROOT)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			DirAccess.remove_absolute(_TEST_ROOT + entry)
		entry = dir.get_next()
	DirAccess.remove_absolute(_TEST_ROOT)
