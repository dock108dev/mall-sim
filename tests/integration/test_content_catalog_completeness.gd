## Integration test: verifies all required JSON content catalogs are present and schema-valid.
extends GutTest

const ITEM_CATALOG_PATHS: Array[String] = [
	"res://game/content/items/consumer_electronics.json",
	"res://game/content/items/pocket_creatures.json",
	"res://game/content/items/retro_games.json",
	"res://game/content/items/sports_memorabilia.json",
	"res://game/content/items/video_rental.json",
]

const NON_ITEM_CATALOG_PATHS: Array[String] = [
	"res://game/content/endings/ending_config.json",
	"res://game/content/milestones/milestone_definitions.json",
	"res://game/content/suppliers/supplier_catalog.json",
	"res://game/content/staff/staff_definitions.json",
	"res://game/content/market_trends_catalog.json",
	"res://game/content/events/ambient_moments.json",
	"res://game/content/sports_seasons.json",
	"res://game/content/events/seasonal_events.json",
	"res://game/content/events/random_events.json",
	"res://game/content/fixtures/fixture_definitions.json",
	"res://game/content/economy/difficulty_config.json",
]

const ENDINGS_PATH := "res://game/content/endings/ending_config.json"
const MARKET_TRENDS_PATH := "res://game/content/market_trends_catalog.json"

const ENDINGS_MIN_COUNT := 13
const MARKET_TREND_IDS: Array[String] = [
	"fashion", "sports", "entertainment", "food", "tech"
]


# --- Item catalogs ---

func test_all_five_item_catalogs_load() -> void:
	for path: String in ITEM_CATALOG_PATHS:
		var data: Variant = DataLoaderSingleton.load_json(path)
		assert_not_null(data, "Item catalog should load: %s" % path)


func test_item_catalog_entries_have_id_field() -> void:
	for path: String in ITEM_CATALOG_PATHS:
		var data: Variant = DataLoaderSingleton.load_json(path)
		if data == null:
			continue
		var entries: Array[Dictionary] = _extract_entries(data)
		assert_gt(entries.size(), 0, "Item catalog must have entries: %s" % path)
		for entry: Dictionary in entries:
			assert_true(
				entry.has("id") and str(entry["id"]) != "",
				"Item entry missing 'id' in %s: %s" % [path.get_file(), entry]
			)


# --- Non-item catalogs: load check ---

func test_all_non_item_catalogs_load() -> void:
	for path: String in NON_ITEM_CATALOG_PATHS:
		var data: Variant = DataLoaderSingleton.load_json(path)
		assert_not_null(data, "Catalog should load: %s" % path)


func test_all_non_item_catalog_entries_have_id_field() -> void:
	for path: String in NON_ITEM_CATALOG_PATHS:
		var data: Variant = DataLoaderSingleton.load_json(path)
		if data == null:
			continue
		var entries: Array[Dictionary] = _extract_entries(data)
		assert_gt(entries.size(), 0, "Catalog must have entries: %s" % path)
		for entry: Dictionary in entries:
			assert_true(
				entry.has("id") and str(entry["id"]) != "",
				"Entry missing 'id' in %s: %s" % [path.get_file(), entry]
			)


# --- Endings-specific ---

func test_endings_catalog_meets_minimum_count() -> void:
	var data: Variant = DataLoaderSingleton.load_json(ENDINGS_PATH)
	if data == null:
		fail_test("Endings catalog did not load")
		return
	var entries: Array[Dictionary] = _extract_entries(data)
	assert_gte(
		entries.size(), ENDINGS_MIN_COUNT,
		"Endings catalog needs >= %d entries, found %d" % [ENDINGS_MIN_COUNT, entries.size()]
	)


# --- Market trends: all 5 categories present ---

func test_market_trends_has_all_five_categories() -> void:
	var data: Variant = DataLoaderSingleton.load_json(MARKET_TRENDS_PATH)
	if data == null:
		fail_test("Market trends catalog did not load")
		return
	var entries: Array[Dictionary] = _extract_entries(data)
	var found_ids: Array[String] = []
	for entry: Dictionary in entries:
		if entry.has("id"):
			found_ids.append(str(entry["id"]))
	for category: String in MARKET_TREND_IDS:
		assert_true(
			category in found_ids,
			"Market trends catalog missing category: %s" % category
		)


# --- Summary report ---

func test_print_catalog_summary() -> void:
	var all_paths: Array[String] = ITEM_CATALOG_PATHS.duplicate()
	all_paths.append_array(NON_ITEM_CATALOG_PATHS)

	print("\n=== Content Catalog Completeness Audit ===")
	var total_entries := 0
	for path: String in all_paths:
		var data: Variant = DataLoaderSingleton.load_json(path)
		if data == null:
			print("  [MISSING] %s" % path.get_file())
			assert_not_null(data, "Required catalog missing: %s" % path)
			continue
		var entries: Array[Dictionary] = _extract_entries(data)
		total_entries += entries.size()
		print("  [OK]      %-45s  %d entries" % [path.get_file(), entries.size()])
	print("  Total entries: %d" % total_entries)
	print("==========================================\n")


# --- Helpers ---

func _extract_entries(data: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if data is Array:
		for item: Variant in data:
			if item is Dictionary:
				entries.append(item)
		return entries
	if data is Dictionary:
		for key: String in data:
			var val: Variant = data[key]
			if val is Array:
				for item: Variant in val:
					if item is Dictionary:
						entries.append(item)
				return entries
		entries.append(data)
	return entries
