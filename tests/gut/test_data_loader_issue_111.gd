## Regression tests for ISSUE-111 DataLoader boot-time discovery and validation.
extends GutTest

var _content_loaded_count: int = 0
var _content_load_errors: Array[String] = []


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	_content_loaded_count = 0
	_content_load_errors.clear()
	if not EventBus.content_loaded.is_connected(_on_content_loaded):
		EventBus.content_loaded.connect(_on_content_loaded)
	if not EventBus.content_load_failed.is_connected(_on_content_load_failed):
		EventBus.content_load_failed.connect(_on_content_load_failed)


func after_each() -> void:
	if EventBus.content_loaded.is_connected(_on_content_loaded):
		EventBus.content_loaded.disconnect(_on_content_loaded)
	if EventBus.content_load_failed.is_connected(_on_content_load_failed):
		EventBus.content_load_failed.disconnect(_on_content_load_failed)
	ContentRegistry.clear_for_testing()
	DataLoaderSingleton.load_all_content()


func test_project_registers_dataloader_before_game_manager() -> void:
	var project_file: FileAccess = FileAccess.open(
		"res://project.godot",
		FileAccess.READ
	)
	assert_not_null(project_file, "project.godot should be readable")
	var source: String = project_file.get_as_text()
	assert_true(
		source.find("DataLoaderSingleton")
		< source.find("GameManager"),
		"DataLoaderSingleton should appear before GameManager in autoload order"
	)


func test_game_manager_ready_does_not_bypass_boot_sequence() -> void:
	var script: GDScript = load("res://game/autoload/game_manager.gd")
	var source: String = script.source_code
	assert_false(
		source.contains("DataLoaderSingleton.load_all_content()"),
		"GameManager._ready() should not load content directly"
	)
	assert_false(
		source.contains("DataLoaderSingleton.load_all()"),
		"Boot scene should be the only startup entry point for DataLoader"
	)


func test_build_resource_dispatches_supported_root_types() -> void:
	var loader: DataLoader = DataLoader.new()
	add_child_autofree(loader)

	var item: Resource = loader._build_resource("item_definition", {
		"id": "wrapped_item",
		"item_name": "Wrapped Item",
		"category": "cards",
		"store_type": "wrapped_store",
		"base_price": 10.0,
		"rarity": "common",
	})
	assert_true(item is ItemDefinition, "item_definition should build ItemDefinition")

	var store: Resource = loader._build_resource("store_definition", {
		"id": "wrapped_store",
		"name": "Wrapped Store",
		"scene_path": "res://game/scenes/stores/retro_games.tscn",
	})
	assert_true(store is StoreDefinition, "store_definition should build StoreDefinition")

	var customer: Resource = loader._build_resource("customer_profile", {
		"id": "wrapped_customer",
		"name": "Wrapped Customer",
		"store_types": ["wrapped_store"],
	})
	assert_true(customer is CustomerTypeDefinition, "customer_profile should build CustomerTypeDefinition")

	var event_config: Resource = loader._build_resource(
		"event_config",
		{
			"id": "wrapped_event",
			"name": "Wrapped Event",
			"event_type": "boom",
		},
		"user://issue_111/events/market_events.json"
	)
	assert_true(event_config is MarketEventDefinition, "event_config should build a typed event resource")

	var milestone: Resource = loader._build_resource("milestone_definition", {
		"id": "wrapped_milestone",
		"display_name": "Wrapped Milestone",
		"trigger_stat_key": "sales",
	})
	assert_true(milestone is MilestoneDefinition, "milestone_definition should build MilestoneDefinition")

	var staff: Resource = loader._build_resource("staff_definition", {
		"id": "wrapped_staff",
		"name": "Wrapped Staff",
		"role": "cashier",
	})
	assert_true(staff is StaffDefinition, "staff_definition should build StaffDefinition")

	var fixture: Resource = loader._build_resource("fixture_definition", {
		"id": "wrapped_fixture",
		"display_name": "Wrapped Fixture",
		"purchase_cost": 10.0,
	})
	assert_true(fixture is FixtureDefinition, "fixture_definition should build FixtureDefinition")


func test_malformed_json_emits_content_load_failed_with_filename() -> void:
	var root: String = _make_temp_root("malformed")
	_write_json(
		root,
		"stores/store_definitions.json",
		JSON.stringify({
			"type": "store_definition",
			"entries": [{
				"id": "wrapped_store",
				"name": "Wrapped Store",
				"scene_path": "res://game/scenes/stores/retro_games.tscn",
			}],
		})
	)
	_write_json(
		root,
		"items/items.json",
		JSON.stringify({
			"type": "item_definition",
			"entries": [{
				"id": "wrapped_item",
				"item_name": "Wrapped Item",
				"category": "cards",
				"store_type": "wrapped_store",
				"base_price": 10.0,
				"rarity": "common",
			}],
		})
	)
	_write_file(root.path_join("items/bad.json"), "{\"type\": ")

	var loader: DataLoader = DataLoader.new()
	add_child_autofree(loader)
	loader.load_all_content_from_root(root)

	assert_eq(loader.get_store_count(), 1, "Valid store content should still load")
	assert_eq(loader.get_item_count(), 1, "Valid item content should still load")
	assert_gt(_content_load_errors.size(), 0, "Malformed JSON should fail the content load")
	assert_eq(_content_loaded_count, 0, "content_loaded should not fire after malformed JSON")
	var errors: Array[String] = loader.get_load_errors()
	assert_gt(errors.size(), 0, "Loader should track malformed JSON errors")
	assert_true(
		errors[0].contains("bad.json"),
		"Malformed JSON error should include filename"
	)


func test_validation_errors_emit_content_load_failed() -> void:
	var root: String = _make_temp_root("validation")
	_write_json(
		root,
		"items/items.json",
		JSON.stringify({
			"type": "item_definition",
			"entries": [{
				"id": "orphan_item",
				"item_name": "Orphan Item",
				"category": "cards",
				"store_type": "missing_store",
				"base_price": 12.0,
				"rarity": "common",
			}],
		})
	)

	var loader: DataLoader = DataLoader.new()
	add_child_autofree(loader)
	loader.load_all_content_from_root(root)

	assert_gt(_content_load_errors.size(), 0, "Validation failures should emit content_load_failed")
	var mentions_missing: bool = false
	for err: String in _content_load_errors:
		if err.contains("missing_store"):
			mentions_missing = true
			break
	assert_true(
		mentions_missing,
		"Validation error should mention the missing reference"
	)
	assert_eq(_content_loaded_count, 0, "content_loaded should not fire after validation failure")
	assert_eq(loader.get_load_errors().size(), _content_load_errors.size())


func _make_temp_root(label: String) -> String:
	var root: String = "user://issue_111_%s_%d" % [label, Time.get_ticks_usec()]
	var error: Error = DirAccess.make_dir_recursive_absolute(root)
	assert_eq(error, OK, "Temp root should be creatable")
	return root


func _write_json(root: String, relative_path: String, contents: String) -> void:
	var absolute_path: String = root.path_join(relative_path)
	_write_file(absolute_path, contents)


func _write_file(path: String, contents: String) -> void:
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	assert_eq(dir_error, OK, "Parent directory should be creatable for %s" % path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "File should open for writing: %s" % path)
	file.store_string(contents)


func _on_content_loaded() -> void:
	_content_loaded_count += 1


func _on_content_load_failed(errors: Array[String]) -> void:
	_content_load_errors = errors.duplicate()
