## Regression tests for ISSUE-011 — parody-name validator boot-time hard-fail.
extends GutTest

const _TMP_ROOT: String = "user://test_trademark_validator/"


func before_each() -> void:
	_clean_tmp_root()


func after_each() -> void:
	_clean_tmp_root()
	ContentRegistry.clear_for_testing()
	DataLoaderSingleton.clear_for_testing()
	DataLoaderSingleton.load_all_content()


func test_validate_entry_accepts_clean_content() -> void:
	var errors: Array[String] = TrademarkValidator.validate_entry(
		{
			"id": "sneaker_citadel_heat_03",
			"item_name": "Heat Runners",
			"description": "Parody hypebeast kicks.",
		},
		"item",
		"res://test/path.json",
	)
	assert_eq(errors.size(), 0, "clean entry should produce no errors")


func test_validate_entry_flags_trademarked_item_name() -> void:
	var errors: Array[String] = TrademarkValidator.validate_entry(
		{
			"id": "bad_item_42",
			"item_name": "Nike Air Max",
		},
		"item",
		"res://content/items/fake.json",
	)
	assert_eq(errors.size(), 1, "exactly one trademark hit expected")
	var msg: String = errors[0]
	assert_true(
		msg.contains("Nike"),
		"error must name the offending term: %s" % msg,
	)
	assert_true(
		msg.contains("bad_item_42"),
		"error must name the offending entry id: %s" % msg,
	)
	assert_true(
		msg.contains("res://content/items/fake.json"),
		"error must name the source file: %s" % msg,
	)


func test_validate_entry_is_case_insensitive_and_recursive() -> void:
	var errors: Array[String] = TrademarkValidator.validate_entry(
		{
			"id": "nested_bad",
			"display_name": "Totally Original",
			"variants": [
				{"label": "special ADIDAS edition"},
			],
		},
		"item",
		"src.json",
	)
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("Adidas"))


func test_data_loader_records_trademark_error_with_file_and_entry_context() -> void:
	var content_root: String = _TMP_ROOT
	var items_dir: String = content_root.path_join("items")
	DirAccess.make_dir_recursive_absolute(items_dir)
	var store_path: String = content_root.path_join("stores/test_store.json")
	DirAccess.make_dir_recursive_absolute(content_root.path_join("stores"))
	_write_json(
		store_path,
		{
			"type": "store_definition",
			"id": "test_store",
			"name": "Test Parody Store",
			"scene_path": "res://game/scenes/stores/retro_games.tscn",
		},
	)
	var bad_item_path: String = items_dir.path_join("bad_item.json")
	_write_json(
		bad_item_path,
		{
			"type": "item_definition",
			"id": "bad_sneaker_01",
			"item_name": "Nike Authentic",
			"category": "shoes",
			"store_type": "test_store",
			"base_price": 50.0,
			"rarity": "common",
		},
	)

	var loader: DataLoader = DataLoader.new()
	add_child_autofree(loader)
	ContentRegistry.clear_for_testing()
	loader.load_all_content_from_root(content_root)

	var errors: Array[String] = loader.get_load_errors()
	var matched: bool = false
	for err: String in errors:
		if (
			err.contains("Nike")
			and err.contains("bad_sneaker_01")
			and err.contains(bad_item_path)
		):
			matched = true
			break
	assert_true(
		matched,
		(
			"expected a trademark error naming file+entry id. Got: %s"
			% str(errors)
		),
	)


func test_boot_checks_load_errors_before_store_count() -> void:
	# Acceptance: trademark errors surface even when they would also cause
	# the <5 stores invariant to trip. Verified structurally: boot.gd
	# evaluates get_load_errors() and returns before the store count check.
	var boot_source: String = FileAccess.get_file_as_string(
		"res://game/scripts/core/boot.gd"
	)
	var load_errors_idx: int = boot_source.find("get_load_errors()")
	var store_count_idx: int = boot_source.find("store_ids.size() < 5")
	assert_true(load_errors_idx >= 0, "boot.gd must call get_load_errors()")
	assert_true(store_count_idx >= 0, "boot.gd must check store count")
	assert_lt(
		load_errors_idx,
		store_count_idx,
		"load-errors check must come before <5 stores check",
	)


func _write_json(path: String, data: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(f, "failed to open %s for write" % path)
	f.store_string(JSON.stringify(data))
	f.close()


func _clean_tmp_root() -> void:
	if not DirAccess.dir_exists_absolute(_TMP_ROOT):
		return
	_rm_rf(_TMP_ROOT)


func _rm_rf(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var child: String = path.path_join(name)
		if dir.current_is_dir():
			_rm_rf(child)
		else:
			DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
