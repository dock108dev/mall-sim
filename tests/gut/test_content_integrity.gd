## Parameterized content integrity tests.
##
## Iterates every JSON file under game/content/ and asserts required fields
## are present and correctly typed, per content type. Fails loud on any
## missing required field so content regressions surface immediately.
extends GutTest


const CONTENT_ROOT := "res://game/content/"

const AMBIENT_REQUIRED: Array[String] = [
	"id", "trigger_category", "flavor_text",
	"store_id", "season_id", "min_day", "max_day", "duration_seconds",
]

const SEASON_REQUIRED: Array[String] = [
	"id", "name", "event_pool", "price_modifier_table", "visual_variant",
]

const ITEM_REQUIRED: Array[String] = [
	"id", "store_type", "category", "base_price",
]

const ITEM_NAME_ANY_OF: Array[String] = ["item_name", "display_name", "name"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _collect_json_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and entry != "." and entry != "..":
			_collect_json_files(dir_path.path_join(entry), out)
		elif entry.ends_with(".json"):
			out.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()


func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var result: Variant
	result = JSON.parse_string(text)
	return result


func _assert_fields(entry: Dictionary, required: Array[String], label: String) -> void:
	for field in required:
		assert_true(
			entry.has(field),
			"%s missing required field '%s'" % [label, field]
		)


func _ambient_label(entry: Dictionary) -> String:
	return "ambient_moment '%s'" % str(entry.get("id", "<missing>"))


func _item_label(entry: Dictionary) -> String:
	return "item '%s'" % str(entry.get("id", "<missing>"))


func _season_label(entry: Dictionary) -> String:
	return "season '%s'" % str(entry.get("id", "<missing>"))


# ---------------------------------------------------------------------------
# Ambient moments
# ---------------------------------------------------------------------------

func test_ambient_moments_have_required_fields() -> void:
	var path := CONTENT_ROOT + "events/ambient_moments.json"
	var data: Variant = _load_json(path)
	assert_not_null(data, "ambient_moments.json failed to parse")
	if data == null:
		return
	assert_true(data is Dictionary, "ambient_moments.json root must be a Dictionary")
	var moments: Variant = (data as Dictionary).get("moments", null)
	assert_not_null(moments, "ambient_moments.json missing 'moments' key")
	if moments == null:
		return
	assert_true(moments is Array, "'moments' must be an Array")
	var arr: Array = moments as Array
	assert_true(arr.size() >= 20, "Need >= 20 ambient moments, got %d" % arr.size())
	for entry: Variant in arr:
		assert_true(entry is Dictionary, "ambient moment entry is not a Dictionary")
		if entry is Dictionary:
			_assert_fields(entry as Dictionary, AMBIENT_REQUIRED, _ambient_label(entry as Dictionary))


func test_ambient_moments_count() -> void:
	var path := CONTENT_ROOT + "events/ambient_moments.json"
	var data: Variant = _load_json(path)
	if data == null or data is not Dictionary:
		fail_test("Could not load ambient_moments.json")
		return
	var moments: Variant = (data as Dictionary).get("moments", [])
	assert_true(
		(moments as Array).size() >= 20,
		"Expected >= 20 ambient moments, got %d" % (moments as Array).size()
	)


# ---------------------------------------------------------------------------
# Seasons
# ---------------------------------------------------------------------------

func test_seasons_have_required_fields() -> void:
	var path := CONTENT_ROOT + "events/seasons.json"
	var data: Variant = _load_json(path)
	assert_not_null(data, "seasons.json failed to parse")
	if data == null:
		return
	assert_true(data is Dictionary, "seasons.json root must be a Dictionary")
	var seasons: Variant = (data as Dictionary).get("seasons", null)
	assert_not_null(seasons, "seasons.json missing 'seasons' key")
	if seasons == null:
		return
	assert_true(seasons is Array, "'seasons' must be an Array")
	var arr: Array = seasons as Array
	assert_true(arr.size() >= 4, "Need >= 4 seasons, got %d" % arr.size())
	for entry: Variant in arr:
		assert_true(entry is Dictionary, "season entry is not a Dictionary")
		if entry is Dictionary:
			var season: Dictionary = entry as Dictionary
			_assert_fields(season, SEASON_REQUIRED, _season_label(season))
			var pool: Variant = season.get("event_pool", null)
			assert_true(
				pool is Array,
				"%s: event_pool must be an Array" % _season_label(season)
			)
			var table: Variant = season.get("price_modifier_table", null)
			assert_true(
				table is Dictionary,
				"%s: price_modifier_table must be a Dictionary" % _season_label(season)
			)


func test_seasons_count() -> void:
	var path := CONTENT_ROOT + "events/seasons.json"
	var data: Variant = _load_json(path)
	if data == null or data is not Dictionary:
		fail_test("Could not load seasons.json")
		return
	var seasons: Variant = (data as Dictionary).get("seasons", [])
	assert_true(
		(seasons as Array).size() >= 4,
		"Expected >= 4 seasons, got %d" % (seasons as Array).size()
	)


# ---------------------------------------------------------------------------
# Inventory — minimum item counts per store
# ---------------------------------------------------------------------------

const STORE_ITEM_FILES: Dictionary = {
	"sports": "items/sports_memorabilia.json",
	"retro_games": "items/retro_games.json",
	"video_rental": "items/video_rental.json",
	"pocket_creatures": "items/pocket_creatures.json",
	"consumer_electronics": "items/consumer_electronics.json",
}

const MIN_ITEMS_PER_STORE: int = 10


func test_inventory_minimum_counts() -> void:
	for store_id: String in STORE_ITEM_FILES:
		var rel_path: String = STORE_ITEM_FILES[store_id]
		var path := CONTENT_ROOT + rel_path
		var items: Array = DataLoader.load_catalog_entries(path)
		assert_true(
			items.size() >= MIN_ITEMS_PER_STORE,
			"Store '%s' has %d items, need >= %d" % [store_id, items.size(), MIN_ITEMS_PER_STORE]
		)


func test_inventory_items_have_required_fields() -> void:
	for store_id: String in STORE_ITEM_FILES:
		var rel_path: String = STORE_ITEM_FILES[store_id]
		var path := CONTENT_ROOT + rel_path
		var items: Array = DataLoader.load_catalog_entries(path)
		for entry: Variant in items:
			if entry is not Dictionary:
				continue
			var item: Dictionary = entry as Dictionary
			_assert_fields(item, ITEM_REQUIRED, _item_label(item))
			var has_name := false
			for candidate: String in ITEM_NAME_ANY_OF:
				if item.has(candidate):
					has_name = true
					break
			assert_true(
				has_name,
				"%s missing any of %s" % [_item_label(item), str(ITEM_NAME_ANY_OF)]
			)


# ---------------------------------------------------------------------------
# Broad scan — no unknown JSON files silently skip validation
# ---------------------------------------------------------------------------

func test_all_content_json_files_parseable() -> void:
	var all_files: Array[String] = []
	_collect_json_files(CONTENT_ROOT, all_files)
	assert_true(all_files.size() > 0, "No JSON files found under %s" % CONTENT_ROOT)
	for path: String in all_files:
		var data: Variant = _load_json(path)
		assert_not_null(
			data,
			"JSON parse failed for %s" % path.replace(CONTENT_ROOT, "")
		)
