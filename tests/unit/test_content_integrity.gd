## Parameterized content-integrity check that walks every JSON file under
## `res://game/content/` and asserts each entry matches the ContentSchema.
## This guards ISSUE-009's "no silent gaps" acceptance criterion — if a new
## content file ships with a missing required field, this test fails loudly.
extends GutTest

const CONTENT_ROOT := "res://game/content/"


func test_schema_validates_malformed_item() -> void:
	var bad_item: Dictionary = {
		"id": "broken_item",
		"category": "misc",
		"base_price": 1.0,
	}
	var errors: Array[String] = ContentSchema.validate(bad_item, "item", "test")
	assert_gt(
		errors.size(), 0,
		"ContentSchema must flag item missing 'store_type'"
	)


func test_schema_validates_wrong_type() -> void:
	var bad_item: Dictionary = {
		"id": "wrong_type_item",
		"item_name": "x",
		"store_type": "retro_games",
		"category": "cartridges",
		"base_price": "not_a_number",
	}
	var errors: Array[String] = ContentSchema.validate(bad_item, "item", "test")
	assert_gt(
		errors.size(), 0,
		"ContentSchema must flag base_price with string value"
	)


func test_schema_accepts_valid_item() -> void:
	var ok_item: Dictionary = {
		"id": "fine_item",
		"item_name": "Fine Item",
		"store_type": "retro_games",
		"category": "cartridges",
		"base_price": 9.99,
	}
	var errors: Array[String] = ContentSchema.validate(ok_item, "item", "test")
	assert_eq(
		errors.size(), 0,
		"Well-formed item should pass ContentSchema validation"
	)


func test_every_content_file_passes_schema() -> void:
	var paths: Array[String] = []
	_scan(CONTENT_ROOT, paths)
	assert_gt(paths.size(), 0, "No content JSON files discovered")
	var total_errors: Array[String] = []
	for path: String in paths:
		var data: Variant = DataLoader.load_json(path)
		if data == null:
			total_errors.append("failed to parse %s" % path)
			continue
		var content_type: String = _classify(path, data)
		if content_type.is_empty() or not ContentSchema.has_schema(content_type):
			continue
		var entries: Array = _extract(data)
		for entry: Variant in entries:
			if entry is not Dictionary:
				continue
			var errs: Array[String] = ContentSchema.validate(
				entry as Dictionary, content_type, path
			)
			for err: String in errs:
				total_errors.append(err)
	assert_eq(
		total_errors.size(), 0,
		"Content integrity errors found:\n" + "\n".join(total_errors)
	)


func _scan(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full: String = dir_path.path_join(name)
		if dir.current_is_dir():
			_scan(full, out)
		elif name.ends_with(".json"):
			out.append(full)
		name = dir.get_next()


func _classify(path: String, data: Variant) -> String:
	var rel: String = path.replace(CONTENT_ROOT, "")
	var dir_name: String = rel.get_slice("/", 0)
	var file_base: String = path.get_file().get_basename()
	if dir_name == "events":
		if path.get_file() == "seasons.json":
			return ""
		if file_base.begins_with("seasonal"):
			return "seasonal_event"
		if file_base.begins_with("random"):
			return "random_event"
		if file_base.begins_with("ambient"):
			return "ambient_moment"
		return "market_event"
	if dir_name == "items":
		return "item"
	if file_base == "pocket_creatures_cards":
		return ""
	if dir_name == "customers":
		if file_base == "personalities":
			return ""
		return "customer"
	if dir_name == "stores":
		if file_base == "store_definitions":
			return "store"
		return ""
	if dir_name == "progression" or dir_name == "milestones":
		if file_base == "arc_unlocks":
			return ""
		return "milestone"
	if dir_name == "staff":
		return "staff"
	if dir_name == "suppliers":
		return "supplier"
	if dir_name == "unlocks":
		return "unlock"
	if dir_name == "endings":
		return "ending"
	if file_base == "fixtures":
		return "fixture"
	if file_base == "upgrades":
		return "upgrade"
	return ""


func _extract(data: Variant) -> Array:
	if data is Array:
		return data
	if data is Dictionary:
		for key: String in ["entries", "items", "definitions", "moments", "endings", "seasons", "suppliers"]:
			var val: Variant = (data as Dictionary).get(key, null)
			if val is Array:
				return val
		return [data]
	return []
