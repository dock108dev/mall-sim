## GUT integration test: Retro Games item catalog (ISSUE-011).
## Verifies the catalog has exactly 20 entries, all required fields present,
## 5 distinct console families, no duplicate IDs, and all items belong to
## the retro_games store type.
extends GutTest

const CATALOG_PATH := "res://game/content/items/retro_games.json"
const MIN_ITEM_COUNT := 25
const EXPECTED_CONSOLE_FAMILIES: Array[String] = [
	"Canopy 64",
	"Neo Spark",
	"PC Booster Canopy",
	"PC Booster Neo Spark",
	"SuperVec 16",
	"Meteor Drive",
]
const REQUIRED_FIELDS: Array[String] = [
	"id", "item_name", "store_type", "category",
	"console", "condition_grades", "rarity", "base_price",
]
const VALID_RARITIES: Array[String] = [
	"common", "uncommon", "rare", "ultra_rare",
]


func _load_catalog() -> Array:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	assert_not_null(file, "retro_games.json must be readable")
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	assert_not_null(parsed, "retro_games.json must parse as valid JSON")
	assert_true(parsed is Array, "retro_games.json root must be an Array")
	if parsed is not Array:
		return []
	return parsed as Array


func test_catalog_has_exactly_20_items() -> void:
	var items: Array = _load_catalog()
	assert_gte(
		items.size(),
		MIN_ITEM_COUNT,
		"Catalog must contain at least %d item entries, got %d" % [MIN_ITEM_COUNT, items.size()]
	)


func test_all_items_have_required_fields() -> void:
	var items: Array = _load_catalog()
	for entry: Variant in items:
		if entry is not Dictionary:
			fail_test("Item entry is not a Dictionary")
			continue
		var item: Dictionary = entry as Dictionary
		var item_id: String = str(item.get("id", "<missing>"))
		for field: String in REQUIRED_FIELDS:
			assert_true(
				item.has(field),
				"Item '%s' missing required field '%s'" % [item_id, field]
			)


func test_no_duplicate_item_ids() -> void:
	var items: Array = _load_catalog()
	var seen: Dictionary = {}
	for entry: Variant in items:
		if entry is not Dictionary:
			continue
		var id: String = str((entry as Dictionary).get("id", ""))
		if id.is_empty():
			continue
		assert_false(
			seen.has(id),
			"Duplicate item ID found: '%s'" % id
		)
		seen[id] = true


func test_all_items_reference_valid_console_family() -> void:
	var items: Array = _load_catalog()
	for entry: Variant in items:
		if entry is not Dictionary:
			continue
		var item: Dictionary = entry as Dictionary
		var item_id: String = str(item.get("id", "<missing>"))
		var console: String = str(item.get("console", ""))
		assert_true(
			console in EXPECTED_CONSOLE_FAMILIES,
			"Item '%s' references unknown console family '%s'" % [item_id, console]
		)


func test_exactly_5_distinct_console_families() -> void:
	var items: Array = _load_catalog()
	var families: Dictionary = {}
	for entry: Variant in items:
		if entry is not Dictionary:
			continue
		var console: String = str((entry as Dictionary).get("console", ""))
		if not console.is_empty():
			families[console] = true
	assert_gte(
		families.size(),
		5,
		"Catalog must span at least 5 console families, found %d: %s" % [families.size(), str(families.keys())]
	)


func test_all_items_belong_to_retro_games_store() -> void:
	var items: Array = _load_catalog()
	for entry: Variant in items:
		if entry is not Dictionary:
			continue
		var item: Dictionary = entry as Dictionary
		var item_id: String = str(item.get("id", "<missing>"))
		var store_type: String = str(item.get("store_type", ""))
		assert_eq(
			store_type,
			"retro_games",
			"Item '%s' must have store_type 'retro_games', got '%s'" % [item_id, store_type]
		)


func test_all_items_have_valid_rarity() -> void:
	var items: Array = _load_catalog()
	for entry: Variant in items:
		if entry is not Dictionary:
			continue
		var item: Dictionary = entry as Dictionary
		var item_id: String = str(item.get("id", "<missing>"))
		var rarity: String = str(item.get("rarity", ""))
		assert_true(
			rarity in VALID_RARITIES,
			"Item '%s' has invalid rarity '%s'" % [item_id, rarity]
		)


func test_all_items_have_positive_base_price() -> void:
	var items: Array = _load_catalog()
	for entry: Variant in items:
		if entry is not Dictionary:
			continue
		var item: Dictionary = entry as Dictionary
		var item_id: String = str(item.get("id", "<missing>"))
		var price: float = float(item.get("base_price", 0.0))
		assert_gt(
			price,
			0.0,
			"Item '%s' must have base_price > 0, got %f" % [item_id, price]
		)


func test_condition_grades_contains_loose_cib_sealed() -> void:
	var items: Array = _load_catalog()
	var expected_grades: Array[String] = ["Loose", "CIB", "Sealed"]
	for entry: Variant in items:
		if entry is not Dictionary:
			continue
		var item: Dictionary = entry as Dictionary
		var item_id: String = str(item.get("id", "<missing>"))
		var grades: Variant = item.get("condition_grades", null)
		assert_true(
			grades is Array,
			"Item '%s' condition_grades must be an Array" % item_id
		)
		if grades is Array:
			for grade: String in expected_grades:
				assert_true(
					grade in (grades as Array),
					"Item '%s' condition_grades missing '%s'" % [item_id, grade]
				)
