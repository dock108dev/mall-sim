# gdlint:disable=max-file-lines,max-public-methods,max-returns
## Boot-time content loader — scans content directory and populates ContentRegistry.
class_name DataLoader
extends Node

const CONTENT_ROOT := "res://game/content/"
const MAX_JSON_FILE_BYTES: int = 1048576

## ISSUE-021: every content JSON must declare a root "type" field. The value
## is looked up in _TYPE_ROUTES below. Missing or unknown types produce a
## per-file load error and fail boot via the error panel — no heuristic
## detection via filename or directory is permitted.
##
## Routed types fall into three buckets:
##   - "entries:<kind>" — parsed as a list of registered entries of <kind>
##   - any other non-empty string — singleton / specialized config handler
##   - "ignore" — file is recognized but not loaded by DataLoader (consumed
##     by another system)
const _TYPE_ROUTES: Dictionary = {
	# Registered entry types — stored in ContentRegistry + local dicts.
	"item": "entries:item",
	"item_definition": "entries:item",
	"store": "entries:store",
	"store_definition": "entries:store",
	"customer": "entries:customer",
	"customer_profile": "entries:customer",
	"fixture": "entries:fixture",
	"fixture_definition": "entries:fixture",
	"milestone": "entries:milestone",
	"milestone_definition": "entries:milestone",
	"staff": "entries:staff",
	"staff_definition": "entries:staff",
	"upgrade": "entries:upgrade",
	"supplier": "entries:supplier",
	"unlock": "entries:unlock",
	"unlock_definition": "entries:unlock",
	"market_event": "entries:market_event",
	"seasonal_event": "entries:seasonal_event",
	"random_event": "entries:random_event",
	"sports_season": "entries:sports_season",
	"tournament_event": "entries:tournament_event",
	"ambient_moment": "entries:ambient_moment",
	# Singleton / specialized configs.
	"economy": "economy",
	"economy_config": "economy",
	"difficulty_config": "difficulty_config",
	"seasonal_config": "seasonal_config",
	"named_seasons": "named_seasons",
	"ending": "ending",
	"retro_games_config": "retro_games_config",
	"electronics_config": "electronics_config",
	"video_rental_config": "video_rental_config",
	"pocket_creatures_packs_config": "pocket_creatures_packs_config",
	# Recognized but not consumed by DataLoader (loaded by other systems).
	"personality_data": "ignore",
	"market_trends_catalog_data": "ignore",
	"audio_registry_data": "ignore",
	"haggle_dialogue_data": "ignore",
	"pocket_creatures_cards_data": "ignore",
	"tutorial_contexts_data": "ignore",
	"meta_shifts_data": "ignore",
	"meta_config_data": "ignore",
	"onboarding_config_data": "ignore",
	"sports_grade_definitions_data": "ignore",
	"arc_unlocks_data": "ignore",
	"retro_games_grades_data": "ignore",
	"day_beats_data": "day_beats_data",
	"objectives_data": "ignore",
	"archetypes_data": "ignore",
	"regulars_threads_data": "ignore",
	"platforms_data": "ignore",
	"manager_notes_data": "ignore",
}

var _items: Dictionary = {}
var _stores: Dictionary = {}
var _customers: Dictionary = {}
var _fixtures: Dictionary = {}
var _market_events: Dictionary = {}
var _seasonal_events: Dictionary = {}
var _random_events: Dictionary = {}
var _staff_definitions: Dictionary = {}
var _milestones: Dictionary = {}
var _upgrades: Dictionary = {}
var _suppliers: Dictionary = {}
var _unlocks: Dictionary = {}
var _sports_seasons: Dictionary = {}
var _tournament_events: Dictionary = {}
var _ambient_moments: Dictionary = {}
var _economy_config: EconomyConfig = null
var _difficulty_config: Dictionary = {}
var _seasonal_config: Array[Dictionary] = []
var _retro_games_config: Dictionary = {}
var _electronics_config: Dictionary = {}
var _video_rental_config: Dictionary = {}
var _named_seasons: Dictionary = {}
var _named_season_cycle_length: int = 70
var _pocket_creatures_packs: Array = []
## Structured midday-event beat pool extracted from day_beats.json.
## Each entry retains the on-disk schema: id, min_day, max_day,
## unlock_required, cooldown_days, title, body, choices (Array of
## {label, consequence, effects}).
var _midday_events: Array = []
var _loaded: bool = false
var _load_errors: Array[String] = []


## Returns errors from the most recent load_all() call.
func get_load_errors() -> Array[String]:
	return _load_errors


func _ready() -> void:
	GameManager.data_loader = self


## Resets all internal state so load_all_content() can re-register to ContentRegistry.
func clear_for_testing() -> void:
	_items.clear()
	_stores.clear()
	_customers.clear()
	_fixtures.clear()
	_market_events.clear()
	_seasonal_events.clear()
	_random_events.clear()
	_staff_definitions.clear()
	_milestones.clear()
	_upgrades.clear()
	_suppliers.clear()
	_unlocks.clear()
	_sports_seasons.clear()
	_tournament_events.clear()
	_ambient_moments.clear()
	_economy_config = null
	_difficulty_config = {}
	_seasonal_config = []
	_retro_games_config = {}
	_electronics_config = {}
	_video_rental_config = {}
	_named_seasons = {}
	_pocket_creatures_packs = []
	_midday_events = []
	_load_errors = []
	_loaded = false


## Public entry point called by boot sequence.
func load_all() -> void:
	load_all_content()


## Public session boot entry point used by GameManager.
func run() -> void:
	load_all()


func load_all_content() -> void:
	load_all_content_from_root(CONTENT_ROOT)


## Loads and registers content from a specific root directory.
func load_all_content_from_root(root: String) -> void:
	if _loaded and ContentRegistry.is_ready():
		GameManager.data_loader = self
		return
	_prepare_for_load()
	_load_errors = []
	var files: Array[String] = _discover_json_files(root)
	var economy_data: Dictionary = {}
	for path: String in files:
		_process_file(path, economy_data, root)
	if not economy_data.is_empty():
		_economy_config = ContentParser.parse_economy_config(
			economy_data
		)
		ContentRegistry.register(
			&"economy_config", _economy_config, "economy"
		)
	_normalize_store_types()
	_validate_trend_catalog(root)
	var validation_errors: Array[String] = ContentRegistry.validate_all_references()
	for err: String in validation_errors:
		_record_load_error(err)
	if not _load_errors.is_empty():
		EventBus.content_load_failed.emit(_load_errors.duplicate())
	else:
		EventBus.content_loaded.emit()
	GameManager.data_loader = self
	_loaded = _load_errors.is_empty()


func _prepare_for_load() -> void:
	# Tests often clear only one half of the content pipeline. If the loader and
	# registry disagree about whether content is already loaded, reset both sides
	# to a clean slate before registering again.
	if _loaded and not ContentRegistry.is_ready():
		clear_for_testing()
	if not _loaded and ContentRegistry.is_ready():
		ContentRegistry.clear_for_testing()
	elif not _loaded:
		clear_for_testing()


func _discover_json_files(root: String) -> Array[String]:
	var files: Array[String] = []
	_scan_dir(root, files)
	files.sort()
	return files


func _scan_dir(path: String, files: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		_record_load_error("cannot open directory: %s" % path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path.path_join(file_name)
		if dir.current_is_dir():
			_scan_dir(full_path, files)
		elif file_name.ends_with(".json"):
			files.append(full_path)
		file_name = dir.get_next()


func _process_file(
	path: String, economy_data: Dictionary, _root: String
) -> void:
	var data: Variant = _load_json_with_error(path)
	if data == null:
		return
	if data is not Dictionary:
		_record_load_error(
			"%s: root must be a Dictionary with a 'type' field (got %s)"
			% [path, typeof_string(data)]
		)
		return
	var dict: Dictionary = data as Dictionary
	if not dict.has("type"):
		_record_load_error(
			"%s: missing required 'type' field at root" % path
		)
		return
	var content_type: String = str(dict["type"])
	if not _TYPE_ROUTES.has(content_type):
		_record_load_error(
			"%s: unknown content type '%s' (not in DataLoader._TYPE_ROUTES)"
			% [path, content_type]
		)
		return
	var route: String = str(_TYPE_ROUTES[content_type])
	if route == "ignore":
		return
	if route == "economy":
		economy_data.merge(dict, true)
		return
	if route == "difficulty_config":
		_difficulty_config = dict
		return
	if route == "seasonal_config":
		_seasonal_config = _parse_seasonal_config(dict)
		return
	if route == "named_seasons":
		_parse_named_seasons(dict)
		return
	if route == "ending":
		_load_endings(dict)
		return
	if route == "retro_games_config":
		_retro_games_config = dict
		return
	if route == "electronics_config":
		_electronics_config = dict
		return
	if route == "video_rental_config":
		_video_rental_config = dict
		return
	if route == "day_beats_data":
		var midday_raw: Variant = dict.get("midday_events", [])
		if midday_raw is Array:
			_midday_events = (midday_raw as Array).duplicate(true)
		return
	if route == "pocket_creatures_packs_config":
		var packs_data: Variant = dict.get("entries", [])
		if packs_data is Array:
			_pocket_creatures_packs = (packs_data as Array).duplicate()
		else:
			_record_load_error(
				"%s: pocket_creatures_packs_config requires 'entries' array"
				% path
			)
		return
	if route.begins_with("entries:"):
		var entry_kind: String = route.substr("entries:".length())
		var entries: Array[Dictionary] = _extract_entries(dict)
		for entry: Dictionary in entries:
			_build_and_register(entry_kind, entry, path)
		return
	_record_load_error(
		"%s: internal routing error for type '%s' (route='%s')"
		% [path, content_type, route]
	)


static func typeof_string(value: Variant) -> String:
	if value is Array:
		return "Array"
	if value is Dictionary:
		return "Dictionary"
	return "non-Dictionary (%d)" % typeof(value)


func _extract_entries(data: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if data is Array:
		for item: Variant in data:
			if item is Dictionary:
				entries.append(item)
	elif data is Dictionary:
		var parent_store_type: String = str(data.get("store_type", ""))
		for preferred_key: String in ["entries", "items", "definitions"]:
			if not data.has(preferred_key):
				continue
			var preferred_entries: Variant = data[preferred_key]
			if preferred_entries is not Array:
				continue
			for item: Variant in preferred_entries:
				if item is Dictionary:
					var preferred_entry: Dictionary = item.duplicate()
					if not parent_store_type.is_empty():
						if str(preferred_entry.get("store_type", "")).is_empty():
							preferred_entry["store_type"] = parent_store_type
					entries.append(preferred_entry)
			return entries
		for key: String in data:
			var val: Variant = data[key]
			if val is Array:
				for item: Variant in val:
					if item is Dictionary:
						var entry: Dictionary = item.duplicate()
						if not parent_store_type.is_empty():
							if str(entry.get("store_type", "")).is_empty():
								entry["store_type"] = parent_store_type
						entries.append(entry)
				return entries
		entries.append(data)
	return entries


func _build_and_register(
	content_type: String, entry: Dictionary, source_path: String = ""
) -> void:
	if not entry.has("id"):
		_record_load_error(
			"%s entry missing 'id' in %s: %s"
			% [content_type, source_path, entry]
		)
		return
	var trademark_errors: Array[String] = TrademarkValidator.validate_entry(
		entry, content_type, source_path
	)
	if not trademark_errors.is_empty():
		for err: String in trademark_errors:
			_record_load_error(err)
		return
	var schema_errors: Array[String] = ContentSchema.validate(
		entry, content_type, source_path
	)
	if not schema_errors.is_empty():
		for err: String in schema_errors:
			_record_load_error(err)
		return
	var id: String = str(entry["id"])
	var resource: Resource = _build_resource(
		content_type, entry, source_path
	)
	if resource == null:
		_record_load_error(
			"failed to parse %s '%s' from %s"
			% [content_type, id, source_path]
		)
		return
	if not _store_in_dict(content_type, id, resource):
		return
	ContentRegistry.register(
		StringName(id), resource, content_type
	)
	var reg_entry: Dictionary = entry.duplicate()
	if not reg_entry.has("name") and reg_entry.has("display_name"):
		reg_entry["name"] = reg_entry["display_name"]
	ContentRegistry.register_entry(reg_entry, content_type)


func _build_resource(
	content_type: String, data: Dictionary, source_path: String = ""
) -> Resource:
	match content_type:
		"item", "item_definition":
			return ContentParser.parse_item(data)
		"store", "store_definition":
			return ContentParser.parse_store(data)
		"customer", "customer_profile":
			return ContentParser.parse_customer(data)
		"milestone", "milestone_definition":
			return ContentParser.parse_milestone(data)
		"staff", "staff_definition":
			return ContentParser.parse_staff(data)
		"fixture", "fixture_definition":
			return ContentParser.parse_fixture(data)
		"event_config":
			# Event config files share a content_type alias; the source_path
			# disambiguates between market / seasonal / random event entries.
			var lowered: String = source_path.to_lower()
			if lowered.contains("seasonal"):
				return ContentParser.parse_seasonal_event(data)
			if lowered.contains("random"):
				return ContentParser.parse_random_event(data)
			return ContentParser.parse_market_event(data)
		_:
			return ContentParser.build_resource(content_type, data)


func _store_in_dict(
	content_type: String, id: String, resource: Resource
) -> bool:
	match content_type:
		"item":
			return _try_register(id, _items, resource)
		"store":
			return _try_register(id, _stores, resource)
		"customer":
			return _try_register(id, _customers, resource)
		"fixture":
			return _try_register(id, _fixtures, resource)
		"market_event":
			return _try_register(id, _market_events, resource)
		"seasonal_event":
			return _try_register(
				id, _seasonal_events, resource
			)
		"random_event":
			return _try_register(id, _random_events, resource)
		"staff":
			return _try_register(
				id, _staff_definitions, resource
			)
		"milestone":
			return _try_register(id, _milestones, resource)
		"upgrade":
			return _try_register(id, _upgrades, resource)
		"supplier":
			return _try_register(id, _suppliers, resource)
		"unlock":
			return _try_register(id, _unlocks, resource)
		"sports_season":
			return _try_register(id, _sports_seasons, resource)
		"tournament_event":
			return _try_register(
				id, _tournament_events, resource
			)
		"ambient_moment":
			return _try_register(
				id, _ambient_moments, resource
			)
	_record_load_error("unknown type '%s' for id '%s'" % [content_type, id])
	return false


func _try_register(
	id: String, registry: Dictionary, resource: Resource
) -> bool:
	if registry.has(id):
		_record_load_error("duplicate id '%s'" % id)
		return false
	registry[id] = resource
	return true


func _load_endings(data: Variant) -> void:
	var entries: Array[Dictionary] = _extract_entries(data)
	for entry: Dictionary in entries:
		if not entry.has("id"):
			_record_load_error("ending entry missing 'id'")
			continue
		var ending_trademark_errors: Array[String] = TrademarkValidator.validate_entry(
			entry, "ending", "ending_config"
		)
		if not ending_trademark_errors.is_empty():
			for err: String in ending_trademark_errors:
				_record_load_error(err)
			continue
		var ending_errors: Array[String] = ContentSchema.validate(
			entry, "ending", "ending_config"
		)
		if not ending_errors.is_empty():
			for err: String in ending_errors:
				_record_load_error(err)
			continue
		var reg_entry: Dictionary = entry.duplicate()
		if not reg_entry.has("name") and reg_entry.has("display_name"):
			reg_entry["name"] = reg_entry["display_name"]
		ContentRegistry.register_entry(reg_entry, "ending")


func _parse_seasonal_config(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seasons: Variant = data.get("seasons", [])
	if seasons is not Array:
		_record_load_error("seasonal_config missing 'seasons' array")
		return result
	for index: int in range((seasons as Array).size()):
		var entry: Variant = (seasons as Array)[index]
		if entry is not Dictionary:
			_record_load_error(
				"seasonal_config entry at index %d is not a Dictionary"
				% index
			)
			continue
		var season: Dictionary = entry as Dictionary
		if not season.has("index") or not season.has("store_multipliers"):
			_record_load_error(
				"seasonal_config entry at index %d missing required fields"
				% index
			)
			continue
		result.append(season)
	return result


func _parse_named_seasons(data: Dictionary) -> void:
	_named_season_cycle_length = int(data.get("cycle_length", 70))
	var seasons_arr: Variant = data.get("seasons", [])
	if seasons_arr is not Array:
		_record_load_error("seasons.json missing 'seasons' array")
		return
	for index: int in range((seasons_arr as Array).size()):
		var entry: Variant = (seasons_arr as Array)[index]
		if entry is not Dictionary:
			_record_load_error(
				"season entry at index %d is not a Dictionary"
				% index
			)
			continue
		var season: Dictionary = entry as Dictionary
		if not season.has("id") or not season.has("start_day"):
			_record_load_error(
				"season entry at index %d missing required fields"
				% index
			)
			continue
		var id: String = str(season["id"])
		var season_errors: Array[String] = ContentSchema.validate(
			season, "season", "seasons.json"
		)
		for err: String in season_errors:
			_record_load_error(err)
		_named_seasons[id] = season


func _validate_trend_catalog(root: String) -> void:
	var catalog_path: String = root.path_join("market_trends_catalog.json")
	var data: Variant = _load_json_with_error(catalog_path)
	if data == null or data is not Dictionary:
		return
	var entries_raw: Variant = (data as Dictionary).get("entries", [])
	if entries_raw is not Array:
		return
	var entries: Array = entries_raw as Array
	var known_ids: Dictionary = {}
	for entry: Variant in entries:
		if entry is not Dictionary:
			continue
		var tid: String = str((entry as Dictionary).get("id", ""))
		if not tid.is_empty():
			known_ids[tid] = true
	for entry: Variant in entries:
		if entry is not Dictionary:
			continue
		var edict: Dictionary = entry as Dictionary
		var tid: String = str(edict.get("id", "?"))
		var propagates: Variant = edict.get("cross_propagates_to", [])
		if propagates is not Array:
			continue
		for ref: Variant in (propagates as Array):
			var ref_id: String = str(ref)
			if ref_id.is_empty():
				continue
			if not known_ids.has(ref_id):
				_record_load_error(
					"%s: trend '%s' cross_propagates_to unknown trend '%s'"
					% [catalog_path, tid, ref_id]
				)


func _normalize_store_types() -> void:
	for item: ItemDefinition in _items.values():
		if item.store_type.is_empty():
			continue
		var canonical: StringName = ContentRegistry.resolve(
			item.store_type
		)
		if not canonical.is_empty():
			item.store_type = String(canonical)
	for profile: CustomerTypeDefinition in _customers.values():
		var resolved: PackedStringArray = PackedStringArray()
		for st: String in profile.store_types:
			var canonical: StringName = ContentRegistry.resolve(st)
			if not canonical.is_empty():
				resolved.append(String(canonical))
			else:
				resolved.append(st)
		profile.store_types = resolved


static func load_json(path: String) -> Variant:
	return _read_json_file(path)


## Returns the entries array for a wrapped content catalog
## ({"type": ..., "entries": [...]}). If the file legacy-parses as an Array,
## returns it directly. Returns [] on missing/invalid JSON.
static func load_catalog_entries(path: String) -> Array:
	var data: Variant = _read_json_file(path)
	if data is Dictionary:
		var dict: Dictionary = data as Dictionary
		for key: String in ["entries", "items", "definitions"]:
			if dict.has(key) and dict[key] is Array:
				return (dict[key] as Array).duplicate()
		return []
	if data is Array:
		return (data as Array).duplicate()
	return []


func _load_json_with_error(path: String) -> Variant:
	return _read_json_file(path, _record_load_error)


static func _read_json_file(
	path: String,
	on_error: Callable = Callable()
) -> Variant:
	if not FileAccess.file_exists(path):
		return _report_json_error("file not found: %s" % path, on_error)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return _report_json_error(
			"failed to open '%s' — %s"
			% [path, error_string(FileAccess.get_open_error())],
			on_error
		)
	if file.get_length() > MAX_JSON_FILE_BYTES:
		file.close()
		return _report_json_error(
			"file '%s' exceeds maximum supported size (%d bytes)"
			% [path, MAX_JSON_FILE_BYTES],
			on_error
		)
	var json_text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(json_text) != OK:
		return _report_json_error(
			"parse error in %s: %s"
			% [path, json.get_error_message()],
			on_error
		)
	return json.data


static func _report_json_error(
	message: String,
	on_error: Callable
) -> Variant:
	if on_error.is_valid():
		on_error.call(message)
	else:
		# §F-08: static callers (load_json, load_catalog_entries) check null return;
		# boot-path callers always pass _record_load_error, which escalates via EventBus.
		push_warning("DataLoader: %s" % message)
	return null


func _record_load_error(message: String) -> void:
	_load_errors.append(message)
	# §F-09: errors aggregate into _load_errors; EventBus.content_load_failed propagates
	# them all at boot-end and blocks the main-menu transition on any failure.
	push_warning("DataLoader: %s" % message)


# --- Public getters ---


func get_item(id: String) -> ItemDefinition:
	return _items.get(id) as ItemDefinition


func get_all_items() -> Array[ItemDefinition]:
	var r: Array[ItemDefinition] = []
	r.assign(_items.values())
	return r


func get_items_by_store(
	store_type: String
) -> Array[ItemDefinition]:
	var canonical: String = store_type
	if ContentRegistry.exists(store_type):
		var resolved: StringName = ContentRegistry.resolve(store_type)
		if not resolved.is_empty():
			canonical = String(resolved)
	var r: Array[ItemDefinition] = []
	for item: ItemDefinition in _items.values():
		if item.store_type == canonical:
			r.append(item)
	return r


func get_items_by_category(
	category: String
) -> Array[ItemDefinition]:
	var r: Array[ItemDefinition] = []
	for item: ItemDefinition in _items.values():
		if item.category == category:
			r.append(item)
	return r


func get_item_count() -> int:
	return _items.size()


func get_store(id: String) -> StoreDefinition:
	if not ContentRegistry.exists(id):
		return null
	var canonical: StringName = ContentRegistry.resolve(id)
	if canonical.is_empty():
		return null
	return _stores.get(String(canonical)) as StoreDefinition


func get_all_stores() -> Array[StoreDefinition]:
	var r: Array[StoreDefinition] = []
	r.assign(_stores.values())
	return r


func get_store_count() -> int:
	return _stores.size()


func get_customer_types_for_store(
	store_type: String
) -> Array[CustomerTypeDefinition]:
	var r: Array[CustomerTypeDefinition] = []
	for p: CustomerTypeDefinition in _customers.values():
		if store_type in p.store_types:
			r.append(p)
	return r


func get_customer_type_definition(id: String) -> CustomerTypeDefinition:
	return _customers.get(id) as CustomerTypeDefinition


func get_all_customers() -> Array[CustomerTypeDefinition]:
	var r: Array[CustomerTypeDefinition] = []
	r.assign(_customers.values())
	return r


func get_customer_count() -> int:
	return _customers.size()


func get_economy_config() -> EconomyConfig:
	return _economy_config


func get_difficulty_config() -> Dictionary:
	return _difficulty_config


func get_retro_games_config() -> Dictionary:
	return _retro_games_config


func get_electronics_config() -> Dictionary:
	return _electronics_config


func get_video_rental_config() -> Dictionary:
	return _video_rental_config


## Returns per-pack-type definitions loaded from pocket_creatures/packs.json.
func get_pocket_creatures_packs() -> Array:
	return _pocket_creatures_packs


func get_seasonal_config() -> Array[Dictionary]:
	return _seasonal_config


func get_fixture(id: String) -> FixtureDefinition:
	var direct: FixtureDefinition = _fixtures.get(id) as FixtureDefinition
	if direct != null:
		return direct
	var canonical: StringName = ContentRegistry.resolve(id)
	if canonical.is_empty():
		return null
	return _fixtures.get(String(canonical)) as FixtureDefinition


func get_all_fixtures() -> Array[FixtureDefinition]:
	var r: Array[FixtureDefinition] = []
	r.assign(_fixtures.values())
	return r


func get_fixtures_for_store(
	store_type: String
) -> Array[FixtureDefinition]:
	var r: Array[FixtureDefinition] = []
	var store_candidates: Dictionary = {}
	store_candidates[store_type] = true
	var canonical_store: StringName = ContentRegistry.resolve(store_type)
	if not canonical_store.is_empty():
		store_candidates[String(canonical_store)] = true
	for f: FixtureDefinition in _fixtures.values():
		if f.store_types.is_empty():
			r.append(f)
			continue
		for restricted_store: String in f.store_types:
			if store_candidates.has(restricted_store):
				r.append(f)
				break
			var canonical_restriction: StringName = ContentRegistry.resolve(
				restricted_store
			)
			if not canonical_restriction.is_empty():
				if store_candidates.has(String(canonical_restriction)):
					r.append(f)
					break
				continue
			if restricted_store == store_type:
				r.append(f)
				break
	return r


func get_fixture_count() -> int:
	return _fixtures.size()


func get_market_event(id: String) -> MarketEventDefinition:
	return _market_events.get(id) as MarketEventDefinition


func get_all_market_events() -> Array[MarketEventDefinition]:
	var r: Array[MarketEventDefinition] = []
	r.assign(_market_events.values())
	return r


func get_market_events_for_store(
	store_type: String
) -> Array[MarketEventDefinition]:
	var r: Array[MarketEventDefinition] = []
	for e: MarketEventDefinition in _market_events.values():
		if e.target_store_types.is_empty():
			r.append(e)
		elif store_type in e.target_store_types:
			r.append(e)
	return r


func get_seasonal_event(
	id: String
) -> SeasonalEventDefinition:
	return _seasonal_events.get(id) as SeasonalEventDefinition


func get_all_seasonal_events() -> Array[SeasonalEventDefinition]:
	var r: Array[SeasonalEventDefinition] = []
	r.assign(_seasonal_events.values())
	return r


func get_random_event(id: String) -> RandomEventDefinition:
	return _random_events.get(id) as RandomEventDefinition


func get_all_random_events() -> Array[RandomEventDefinition]:
	var r: Array[RandomEventDefinition] = []
	r.assign(_random_events.values())
	return r


func get_staff_definition(id: String) -> StaffDefinition:
	return _staff_definitions.get(id) as StaffDefinition


func get_all_staff_definitions() -> Array[StaffDefinition]:
	var r: Array[StaffDefinition] = []
	r.assign(_staff_definitions.values())
	return r


func get_upgrade(id: String) -> UpgradeDefinition:
	return _upgrades.get(id) as UpgradeDefinition


func get_all_upgrades() -> Array[UpgradeDefinition]:
	var r: Array[UpgradeDefinition] = []
	r.assign(_upgrades.values())
	return r


func get_upgrades_for_store(
	store_type: String
) -> Array[UpgradeDefinition]:
	var r: Array[UpgradeDefinition] = []
	for u: UpgradeDefinition in _upgrades.values():
		if u.is_universal() or u.store_type == store_type:
			r.append(u)
	return r


func get_upgrade_count() -> int:
	return _upgrades.size()


func get_supplier(id: String) -> SupplierDefinition:
	return _suppliers.get(id) as SupplierDefinition


func get_all_suppliers() -> Array[SupplierDefinition]:
	var r: Array[SupplierDefinition] = []
	r.assign(_suppliers.values())
	return r


func get_suppliers_for_store(
	store_type: String
) -> Array[SupplierDefinition]:
	var r: Array[SupplierDefinition] = []
	for s: SupplierDefinition in _suppliers.values():
		if s.store_type == store_type:
			r.append(s)
	return r


func get_suppliers_by_tier(
	store_type: String, tier: int
) -> Array[SupplierDefinition]:
	var r: Array[SupplierDefinition] = []
	for s: SupplierDefinition in _suppliers.values():
		if s.store_type == store_type and s.tier == tier:
			r.append(s)
	return r


func get_supplier_count() -> int:
	return _suppliers.size()


func get_milestone(id: String) -> MilestoneDefinition:
	return _milestones.get(id) as MilestoneDefinition


func get_all_milestones() -> Array[MilestoneDefinition]:
	var r: Array[MilestoneDefinition] = []
	r.assign(_milestones.values())
	return r


func get_all_sports_seasons() -> Array[SportsSeasonDefinition]:
	var r: Array[SportsSeasonDefinition] = []
	r.assign(_sports_seasons.values())
	return r


func get_all_tournament_events() -> Array[TournamentEventDefinition]:
	var r: Array[TournamentEventDefinition] = []
	r.assign(_tournament_events.values())
	return r


func get_all_ambient_moments() -> Array[AmbientMomentDefinition]:
	var r: Array[AmbientMomentDefinition] = []
	r.assign(_ambient_moments.values())
	return r


## Returns deterministic starter inventory from `starting_inventory` in
## store_definitions.json. Each item is built at "good" condition so Day 1
## prices, customer desirability checks, and tutorial state stay stable across
## runs. Skips entries whose category is not in the store's `allowed_categories`
## so a content typo cannot push items onto a fixture that does not exist.
##
## §F-83 — Pass 12: the three "store not found" branches `push_warning` and
## return `[]`. Caller `GameWorld._create_default_store_inventory` is the
## Day-1 critical path; a silent empty Array there cascades into an empty
## backroom and makes the tutorial loop unreachable. Surfacing the cause
## (unknown ID, unresolved canonical, missing StoreDefinition) at the source
## is required so a content-authoring regression is caught in CI / playtest
## rather than masquerading as "the player has no items today".
func create_starting_inventory(
	store_id: String
) -> Array[ItemInstance]:
	if not ContentRegistry.exists(store_id):
		push_warning(
			"DataLoader.create_starting_inventory: unknown store id '%s'"
			% store_id
		)
		return []
	var canonical: StringName = ContentRegistry.resolve(store_id)
	if canonical.is_empty():
		push_warning(
			"DataLoader.create_starting_inventory: '%s' resolved to empty canonical id"
			% store_id
		)
		return []
	var store: StoreDefinition = get_store(String(canonical))
	if not store:
		push_warning(
			"DataLoader.create_starting_inventory: no StoreDefinition for '%s' (canonical '%s')"
			% [store_id, canonical]
		)
		return []
	var allowed: PackedStringArray = store.allowed_categories
	var instances: Array[ItemInstance] = []
	for item_id: String in store.starting_inventory:
		var def: ItemDefinition = get_item(item_id)
		if not def:
			# §F-88 — Pass 13: symmetry with the category-mismatch warning
			# below. A typo'd id in `starting_inventory` would otherwise
			# silently shrink the Day-1 backroom one item at a time and
			# the empty-result `push_warning` from the caller (§F-83)
			# would only fire if every entry was a typo. Surface each
			# missing definition at the source instead.
			push_warning(
				"DataLoader: skipping starter '%s' — no ItemDefinition (typo or unloaded?)"
				% item_id
			)
			continue
		if not allowed.is_empty() and not allowed.has(def.category):
			push_warning(
				"DataLoader: skipping starter '%s' — category '%s' not in '%s' allowed_categories"
				% [item_id, def.category, canonical]
			)
			continue
		instances.append(
			ItemInstance.create_from_definition(def, "good")
		)
	return instances


func generate_starter_inventory(
	store_type: String
) -> Array[ItemInstance]:
	if not ContentRegistry.exists(store_type):
		return []
	var canonical: StringName = ContentRegistry.resolve(store_type)
	if canonical.is_empty():
		return []
	var common: Array[ItemDefinition] = []
	for item_id: StringName in ContentRegistry.get_all_ids("item"):
		var def: ItemDefinition = get_item(String(item_id))
		if def == null:
			continue
		if def.rarity != "common":
			continue
		if not ContentRegistry.exists(def.store_type):
			continue
		var item_store_id: StringName = ContentRegistry.resolve(def.store_type)
		if item_store_id != canonical:
			continue
		common.append(def)
	if common.is_empty():
		return []
	var count: int = mini(randi_range(6, 10), common.size())
	common.shuffle()
	var instances: Array[ItemInstance] = []
	for i: int in range(count):
		instances.append(
			ItemInstance.create_from_definition(common[i], "good")
		)
	return instances


func get_unlock(id: String) -> UnlockDefinition:
	return _unlocks.get(id) as UnlockDefinition


func get_all_unlocks() -> Array[UnlockDefinition]:
	var r: Array[UnlockDefinition] = []
	r.assign(_unlocks.values())
	return r


func get_unlock_count() -> int:
	return _unlocks.size()


## Returns the structured midday-event beat pool loaded from day_beats.json.
## Returns a defensive copy; mutating the result does not affect future calls.
func get_midday_events() -> Array:
	return _midday_events.duplicate(true)


func get_named_seasons() -> Array[Dictionary]:
	var r: Array[Dictionary] = []
	r.assign(_named_seasons.values())
	return r


func get_named_season_cycle_length() -> int:
	return _named_season_cycle_length
