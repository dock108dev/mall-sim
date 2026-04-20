## Tests fixture catalog content loading, registry resolution, and store filtering.
extends GutTest

const FIXTURE_CATALOG_PATH: String = "res://game/content/fixtures.json"

var _data_loader: DataLoader


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()


func test_fixture_count() -> void:
	var fixtures: Array[FixtureDefinition] = _data_loader.get_all_fixtures()
	assert_eq(fixtures.size(), 14, "Should load exactly 14 fixtures")


func test_fixture_json_entries_include_required_fields() -> void:
	var raw: Variant = DataLoader.load_json(FIXTURE_CATALOG_PATH)
	assert_true(raw is Dictionary, "fixtures.json should load as a dictionary")
	var entries: Array = (raw as Dictionary).get("entries", [])
	assert_eq(entries.size(), 14, "fixtures.json should include 14 entries")
	for entry_value: Variant in entries:
		assert_true(entry_value is Dictionary, "Each fixture entry must be a dictionary")
		var entry: Dictionary = entry_value as Dictionary
		for field: String in [
			"id",
			"display_name",
			"cost",
			"slot_count",
			"footprint_cells",
			"rotation_support",
			"store_type_restriction",
			"unlock_rep",
			"unlock_day",
		]:
			assert_true(entry.has(field), "Fixture entry missing field '%s'" % field)


func test_content_registry_resolves_fixture_entries() -> void:
	var wall_shelf_entry: Dictionary = ContentRegistry.get_entry(&"wall_shelf")
	assert_false(wall_shelf_entry.is_empty(), "wall_shelf should resolve from ContentRegistry")
	assert_eq(wall_shelf_entry.get("display_name"), "Wall Shelf")
	assert_eq(int(wall_shelf_entry.get("slot_count", -1)), 4)

	var demo_station_entry: Dictionary = ContentRegistry.get_entry(&"demo_station")
	assert_false(demo_station_entry.is_empty(), "demo_station should resolve from ContentRegistry")
	assert_eq(demo_station_entry.get("store_type_restriction"), "consumer_electronics")


func test_register_matches_issue_schema() -> void:
	var fixture: FixtureDefinition = _data_loader.get_fixture("register")
	assert_not_null(fixture, "register should load")
	assert_eq(fixture.cost, 90.0)
	assert_eq(fixture.slot_count, 0)
	assert_eq(fixture.footprint_cells.size(), 1)
	assert_false(fixture.rotation_support)


func test_store_specific_filter_resolves_store_aliases() -> void:
	var sports_fixtures: Array[FixtureDefinition] = _data_loader.get_fixtures_for_store("sports")
	var electronics_fixtures: Array[FixtureDefinition] = _data_loader.get_fixtures_for_store("electronics")
	var rental_fixtures: Array[FixtureDefinition] = _data_loader.get_fixtures_for_store("rentals")

	assert_true(_contains_fixture(sports_fixtures, "authentication_station"))
	assert_false(_contains_fixture(sports_fixtures, "testing_station"))
	assert_true(_contains_fixture(electronics_fixtures, "demo_station"))
	assert_false(_contains_fixture(electronics_fixtures, "authentication_station"))
	assert_true(_contains_fixture(rental_fixtures, "return_kiosk"))
	assert_false(_contains_fixture(rental_fixtures, "demo_station"))


func test_sellback_price_is_half_cost() -> void:
	var fixture: FixtureDefinition = _data_loader.get_fixture("glass_case")
	assert_not_null(fixture, "glass_case should load")
	assert_eq(fixture.get_sellback_price(), 40.0)


func _contains_fixture(
	fixtures: Array[FixtureDefinition],
	fixture_id: String
) -> bool:
	for fixture: FixtureDefinition in fixtures:
		if fixture.id == fixture_id:
			return true
	return false
