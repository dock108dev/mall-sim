## Tests fixture JSON loading, FixtureDefinition fields, ContentRegistry
## fixture resolution, and FixtureCatalog panel unlock/filtering logic.
extends GutTest


var _data_loader: DataLoader


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()


func test_fixture_count() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	assert_eq(all.size(), 14, "Should load exactly 14 fixtures")


func test_universal_fixture_count() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	var universal_count: int = 0
	for f: FixtureDefinition in all:
		if f.category == "universal":
			universal_count += 1
	assert_gte(
		universal_count, 3,
		"Should have at least 3 universal fixtures"
	)


func test_store_specific_fixture_count() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	var specific_count: int = 0
	for f: FixtureDefinition in all:
		if f.category == "store_specific":
			specific_count += 1
	assert_gte(
		specific_count, 5,
		"Should have at least 5 store-specific fixtures"
	)


func test_wall_shelf_fields() -> void:
	var f: FixtureDefinition = _data_loader.get_fixture("wall_shelf")
	assert_not_null(f, "wall_shelf should exist")
	assert_eq(f.display_name, "Wall Shelf")
	assert_eq(f.cost, 30.0)
	assert_eq(f.slot_count, 4)
	assert_eq(f.grid_size, Vector2i(2, 1))
	assert_eq(f.footprint_cells.size(), 2)
	assert_eq(f.rotation_support, true)
	assert_eq(f.store_type_restriction, "")
	assert_eq(f.unlock_rep, 0.0)
	assert_eq(f.unlock_day, 0)
	assert_eq(f.visual_category, "shelf")
	assert_false(f.scene_path.is_empty(), "scene_path should be set")


func test_register_fields() -> void:
	var f: FixtureDefinition = _data_loader.get_fixture("register")
	assert_not_null(f, "register should exist")
	assert_eq(f.cost, 90.0)
	assert_eq(f.slot_count, 2)
	assert_eq(f.grid_size, Vector2i(1, 1))
	assert_eq(f.rotation_support, false)


func test_store_specific_restriction() -> void:
	var f: FixtureDefinition = _data_loader.get_fixture(
		"authentication_station"
	)
	assert_not_null(f, "authentication_station should exist")
	assert_eq(f.store_type_restriction, "sports_memorabilia")
	assert_eq(f.category, "store_specific")
	assert_true(
		"sports_memorabilia" in f.store_types,
		"store_types should contain the restriction"
	)


func test_fixtures_for_store_filtering() -> void:
	var retro: Array[FixtureDefinition] = (
		_data_loader.get_fixtures_for_store("retro_games")
	)
	var has_testing: bool = false
	var has_repair: bool = false
	var has_auth: bool = false
	for f: FixtureDefinition in retro:
		if f.id == "testing_station":
			has_testing = true
		if f.id == "repair_workbench":
			has_repair = true
		if f.id == "authentication_station":
			has_auth = true
	assert_true(has_testing, "retro_games should include testing_station")
	assert_true(has_repair, "retro_games should include repair_workbench")
	assert_false(
		has_auth,
		"retro_games should NOT include authentication_station"
	)


func test_universal_fixtures_appear_for_all_stores() -> void:
	var stores: Array[String] = [
		"sports_memorabilia", "retro_games", "video_rental",
		"pocket_creatures", "consumer_electronics",
	]
	for store_type: String in stores:
		var fixtures: Array[FixtureDefinition] = (
			_data_loader.get_fixtures_for_store(store_type)
		)
		var has_wall_shelf: bool = false
		for f: FixtureDefinition in fixtures:
			if f.id == "wall_shelf":
				has_wall_shelf = true
				break
		assert_true(
			has_wall_shelf,
			"wall_shelf should appear for %s" % store_type
		)


func test_sellback_price() -> void:
	var f: FixtureDefinition = _data_loader.get_fixture("glass_case")
	assert_not_null(f, "glass_case should exist")
	assert_eq(
		f.get_sellback_price(), 40.0,
		"Sell-back should be 50%% of cost ($80 -> $40)"
	)


func test_unlock_rep_and_day() -> void:
	var f: FixtureDefinition = _data_loader.get_fixture(
		"repair_workbench"
	)
	assert_not_null(f, "repair_workbench should exist")
	assert_eq(f.unlock_rep, 15.0)
	assert_eq(f.unlock_day, 3)


func test_endcap_unlock_rep() -> void:
	var f: FixtureDefinition = _data_loader.get_fixture("endcap")
	assert_not_null(f, "endcap should exist")
	assert_eq(f.unlock_rep, 10.0)
	assert_eq(f.unlock_day, 0)


func test_footprint_cells_match_grid_size() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	for f: FixtureDefinition in all:
		var expected_count: int = f.grid_size.x * f.grid_size.y
		assert_eq(
			f.footprint_cells.size(), expected_count,
			"%s footprint_cells count should match grid_size"
			% f.id
		)


func test_name_equals_display_name() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	for f: FixtureDefinition in all:
		assert_eq(
			f.name, f.display_name,
			"%s name should equal display_name" % f.id
		)


func test_cost_equals_price() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	for f: FixtureDefinition in all:
		assert_eq(
			f.price, f.cost,
			"%s price should equal cost" % f.id
		)


func test_all_fixture_ids_present() -> void:
	var expected_ids: Array[String] = [
		"wall_shelf", "glass_case", "floor_rack", "counter",
		"register", "endcap", "storage_unit",
		"authentication_station", "testing_station", "return_kiosk",
		"tournament_table", "demo_station", "card_binder",
		"repair_workbench",
	]
	for fixture_id: String in expected_ids:
		var f: FixtureDefinition = _data_loader.get_fixture(fixture_id)
		assert_not_null(
			f, "Fixture '%s' should be loadable" % fixture_id
		)


func test_all_visual_categories_represented() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	var categories: Dictionary = {}
	for f: FixtureDefinition in all:
		categories[f.visual_category] = true
	var required: Array[String] = [
		"shelf", "case", "rack", "counter", "display",
	]
	for cat: String in required:
		assert_true(
			categories.has(cat),
			"visual_category '%s' should be represented" % cat
		)


func test_item_capacity_range() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	for f: FixtureDefinition in all:
		assert_gte(
			f.slot_count, 2,
			"%s item_capacity should be >= 2" % f.id
		)
		assert_lte(
			f.slot_count, 12,
			"%s item_capacity should be <= 12" % f.id
		)


func test_purchase_cost_range() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	for f: FixtureDefinition in all:
		assert_gte(
			f.cost, 25.0,
			"%s purchase_cost should be >= $25" % f.id
		)
		assert_lte(
			f.cost, 150.0,
			"%s purchase_cost should be <= $150" % f.id
		)


func test_grid_size_variants_present() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	var has_1x1: bool = false
	var has_2x1: bool = false
	var has_1x2: bool = false
	for f: FixtureDefinition in all:
		if f.grid_size == Vector2i(1, 1):
			has_1x1 = true
		if f.grid_size == Vector2i(2, 1):
			has_2x1 = true
		if f.grid_size == Vector2i(1, 2):
			has_1x2 = true
	assert_true(has_1x1, "Should have at least one 1x1 fixture")
	assert_true(has_2x1, "Should have at least one 2x1 fixture")
	assert_true(has_1x2, "Should have at least one 1x2 fixture")


func test_scene_paths_set() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	for f: FixtureDefinition in all:
		assert_false(
			f.scene_path.is_empty(),
			"%s should have a scene_path" % f.id
		)
		assert_true(
			f.scene_path.begins_with("res://"),
			"%s scene_path should be a res:// path" % f.id
		)


func test_each_store_has_specific_fixture() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	var store_covered: Dictionary = {}
	for f: FixtureDefinition in all:
		if f.category == "store_specific":
			for st: String in f.store_types:
				store_covered[st] = true
	var required_stores: Array[String] = [
		"sports_memorabilia", "retro_games", "video_rental",
		"pocket_creatures", "consumer_electronics",
	]
	for store_id: String in required_stores:
		assert_true(
			store_covered.has(store_id),
			"Store '%s' should have a specific fixture" % store_id
		)


func test_no_real_brand_names() -> void:
	var all: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	var banned: Array[String] = [
		"IKEA", "Steelcase", "Herman Miller", "Staples",
		"Pottery Barn", "Crate & Barrel", "West Elm",
	]
	for f: FixtureDefinition in all:
		for brand: String in banned:
			assert_false(
				f.display_name.containsn(brand),
				"%s display_name should not reference '%s'"
				% [f.id, brand]
			)
			assert_false(
				f.description.containsn(brand),
				"%s description should not reference '%s'"
				% [f.id, brand]
			)
