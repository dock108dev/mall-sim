## Boot-time content loader — scans content directory and populates ContentRegistry.
class_name DataLoader
extends Node

const CONTENT_ROOT := "res://game/content/"
const MAX_JSON_FILE_BYTES: int = 1048576

const _ROOT_TYPE_MAP: Dictionary = {
	"item_definition": "item",
	"store_definition": "store",
	"customer_profile": "customer",
	"milestone_definition": "milestone",
	"staff_definition": "staff",
	"fixture_definition": "fixture",
	"unlock_definition": "unlock",
	"economy_config": "economy",
}

const _DIR_TYPE_MAP: Dictionary = {
	"items": "item",
	"stores": "store",
	"customers": "customer",
	"fixtures": "fixture",
	"milestones": "milestone",
	"progression": "milestone",
	"staff": "staff",
	"upgrades": "upgrade",
	"economy": "economy",
	"suppliers": "supplier",
	"unlocks": "unlock",
	"endings": "ending",
}

const _TYPE_KEY_MAP: Dictionary = {
	"item_definition": "item",
	"store_definition": "store",
	"event_config": "event",
	"milestone_definition": "milestone",
	"staff_definition": "staff",
	"fixture_definition": "fixture",
	"unlock_definition": "unlock",
	"economy_config": "economy",
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
var _secret_threads: Array[Dictionary] = []
var _economy_config: EconomyConfig = null
var _difficulty_config: Dictionary = {}
var _seasonal_config: Array[Dictionary] = []
var _retro_games_config: Dictionary = {}
var _electronics_config: Dictionary = {}
var _video_rental_config: Dictionary = {}
var _named_seasons: Dictionary = {}
var _named_season_cycle_length: int = 70
var _pocket_creatures_packs: Array = []
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
	_secret_threads.clear()
	_economy_config = null
	_difficulty_config = {}
	_seasonal_config = []
	_retro_games_config = {}
	_electronics_config = {}
	_video_rental_config = {}
	_named_seasons = {}
	_pocket_creatures_packs = []
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
	path: String, economy_data: Dictionary, root: String
) -> void:
	var data: Variant = _load_json_with_error(path)
	if data == null:
		return
	var content_type: String = _detect_type(path, data, root)
	if content_type == "economy":
		if data is Dictionary:
			economy_data.merge(data, true)
		return
	if content_type == "difficulty_config":
		if data is Dictionary:
			_difficulty_config = data
		return
	if content_type == "seasonal_config":
		if data is Dictionary:
			_seasonal_config = _parse_seasonal_config(data)
		return
	if content_type == "named_seasons":
		if data is Dictionary:
			_parse_named_seasons(data)
		return
	if content_type == "secret_thread":
		_load_secret_threads(data)
		return
	if content_type == "ending":
		_load_endings(data)
		return
	if content_type == "retro_games_config":
		if data is Dictionary:
			_retro_games_config = data as Dictionary
		return
	if content_type == "retro_games_grades_data":
		return
	if content_type == "electronics_config":
		if data is Dictionary:
			_electronics_config = data as Dictionary
		return
	if content_type == "video_rental_config":
		if data is Dictionary:
			_video_rental_config = data as Dictionary
		return
	if content_type == "pocket_creatures_packs_config":
		if data is Array:
			_pocket_creatures_packs = data.duplicate()
		return
	if content_type == "personality_data":
		# personalities.json is recognized but not yet loaded; loader not implemented
		return
	if content_type == "market_trends_catalog_data":
		return
	if content_type == "audio_registry_data":
		return
	if content_type == "haggle_dialogue_data":
		return
	if content_type == "pocket_creatures_cards_data":
		return
	if content_type == "tutorial_steps_data":
		return
	if content_type == "meta_config_data":
		return
	if content_type == "onboarding_config_data":
		return
	if content_type.is_empty():
		push_warning("DataLoader: unrecognized content file, skipping: %s" % path)
		return
	var entries: Array[Dictionary] = _extract_entries(data)
	for entry: Dictionary in entries:
		_build_and_register(content_type, entry, path)


func _detect_type(path: String, data: Variant, root: String = CONTENT_ROOT) -> String:
	if data is Dictionary and data.has("type"):
		var raw_type: String = str(data["type"])
		if raw_type == "event_config":
			return _detect_event_config_type(path, data, root)
		return _ROOT_TYPE_MAP.get(
			raw_type,
			_TYPE_KEY_MAP.get(raw_type, raw_type)
		)
	var rel: String = path.replace(root, "")
	var dir_name := rel.get_slice("/", 0)
	if dir_name == "events":
		var file_name := path.get_file()
		if file_name == "seasons.json":
			return "named_seasons"
		if file_name.begins_with("seasonal"):
			return "seasonal_event"
		if file_name.begins_with("random"):
			return "random_event"
		return "market_event"
	if dir_name == "items":
		return "item"
	if dir_name == "onboarding":
		return "onboarding_config_data"
	if dir_name == "meta":
		var meta_file := path.get_file().get_basename()
		if meta_file == "regulars_threads" or meta_file == "shifts":
			return "meta_config_data"
	var file_base := path.get_file().get_basename()
	if file_base == "retro_games":
		return "retro_games_config"
	if file_base == "grades":
		# Under stores/retro_games/; loaded by retro_games.gd, not ContentRegistry.
		return "retro_games_grades_data"
	if file_base == "electronics":
		return "electronics_config"
	if file_base == "video_rental_config":
		return "video_rental_config"
	if file_base == "packs":
		return "pocket_creatures_packs_config"
	if file_base == "pocket_creatures_tournaments":
		return "tournament_event"
	if file_base == "sports_seasons":
		return "sports_season"
	if file_base == "personalities":
		return "personality_data"
	if file_base == "market_trends_catalog":
		# Loaded by MarketTrendSystem; not registered via DataLoader.
		return "market_trends_catalog_data"
	if file_base == "audio_registry":
		return "audio_registry_data"
	if file_base == "haggle_dialogue":
		return "haggle_dialogue_data"
	if file_base == "pocket_creatures_cards":
		return "pocket_creatures_cards_data"
	if file_base == "tutorial_steps":
		return "tutorial_steps_data"
	if file_base == "upgrades":
		return "upgrade"
	if _DIR_TYPE_MAP.has(dir_name):
		return _DIR_TYPE_MAP[dir_name]
	if file_base == "seasonal_config":
		return "seasonal_config"
	if file_base == "secret_threads":
		return "secret_thread"
	return ""


func _detect_event_config_type(
	path: String, data: Dictionary, root: String
) -> String:
	var file_name: String = path.get_file().to_lower()
	if file_name.begins_with("seasonal"):
		return "seasonal_event"
	if file_name.begins_with("random"):
		return "random_event"
	var entries: Array[Dictionary] = _extract_entries(data)
	if not entries.is_empty():
		var sample: Dictionary = entries[0]
		if sample.has("effect_type"):
			return "random_event"
		if sample.has("frequency_days") or sample.has("customer_traffic_multiplier"):
			return "seasonal_event"
		if sample.has("event_type"):
			return "market_event"
	var rel: String = path.replace(root, "")
	if rel.begins_with("/events/random_"):
		return "random_event"
	if rel.begins_with("/events/seasonal_"):
		return "seasonal_event"
	return "market_event"


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
			var event_type: String = _detect_event_config_type(
				source_path,
				{"entries": [data]},
				source_path.get_base_dir().get_base_dir(),
			)
			return _build_resource(event_type, data, source_path)
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


func _load_secret_threads(data: Variant) -> void:
	if data is not Array:
		_record_load_error("secret_threads root must be an Array")
		return
	for index: int in range((data as Array).size()):
		var entry: Variant = (data as Array)[index]
		if entry is not Dictionary:
			_record_load_error(
				"secret_thread entry at index %d is not a Dictionary"
				% index
			)
			continue
		var dict: Dictionary = entry as Dictionary
		if not dict.has("id"):
			_record_load_error(
				"secret_thread entry at index %d missing 'id'"
				% index
			)
			continue
		var thread_errors: Array[String] = ContentSchema.validate(
			dict, "secret_thread", "secret_threads.json"
		)
		if not thread_errors.is_empty():
			for err: String in thread_errors:
				_record_load_error(err)
			continue
		_secret_threads.append(dict)
		ContentRegistry.register_entry(dict, "secret_thread")


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
		push_error("DataLoader: %s" % message)
	return null


func _record_load_error(message: String) -> void:
	_load_errors.append(message)
	push_error("DataLoader: %s" % message)


# --- Public getters (backward-compatible API) ---


func get_item(id: String) -> ItemDefinition:
	return _items.get(id) as ItemDefinition


func get_item_definition(id: String) -> ItemDefinition:
	return get_item(id)


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


func get_store_definition(id: String) -> StoreDefinition:
	return get_store(id)


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


func get_all_secret_threads() -> Array[Dictionary]:
	return _secret_threads.duplicate()


func create_starting_inventory(
	store_id: String
) -> Array[ItemInstance]:
	if not ContentRegistry.exists(store_id):
		return []
	var canonical: StringName = ContentRegistry.resolve(store_id)
	if canonical.is_empty():
		return []
	var store: StoreDefinition = get_store(String(canonical))
	if not store:
		return []
	var instances: Array[ItemInstance] = []
	for item_id: String in store.starting_inventory:
		var def: ItemDefinition = get_item(item_id)
		if def:
			instances.append(
				ItemInstance.create_from_definition(def)
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
			ItemInstance.create_from_definition(common[i])
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


func get_named_seasons() -> Array[Dictionary]:
	var r: Array[Dictionary] = []
	r.assign(_named_seasons.values())
	return r


func get_named_season_cycle_length() -> int:
	return _named_season_cycle_length
