## Boot-time content loader — scans content directory and populates ContentRegistry.
class_name DataLoader
extends Node

const CONTENT_ROOT := "res://game/content/"

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
var _loaded: bool = false
var _load_errors: Array[String] = []


## Returns errors from the most recent load_all() call.
func get_load_errors() -> Array[String]:
	return _load_errors


func _ready() -> void:
	pass


## Public entry point called by boot sequence.
func load_all() -> void:
	load_all_content()


func load_all_content() -> void:
	if _loaded:
		return
	var files := _discover_json_files(CONTENT_ROOT)
	var economy_data: Dictionary = {}
	for path: String in files:
		_process_file(path, economy_data)
	if not economy_data.is_empty():
		_economy_config = ContentParser.parse_economy_config(
			economy_data
		)
		ContentRegistry.register(
			&"economy_config", _economy_config, "economy"
		)
	_normalize_store_types()
	var errors := ContentRegistry.validate_all_references()
	_load_errors = errors
	if not errors.is_empty():
		for err: String in errors:
			push_error("DataLoader: %s" % err)
		EventBus.content_load_failed.emit(errors)
	else:
		EventBus.content_loaded.emit()
	GameManager.data_loader = self
	_loaded = true


func _discover_json_files(root: String) -> Array[String]:
	var files: Array[String] = []
	_scan_dir(root, files)
	return files


func _scan_dir(path: String, files: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_error("DataLoader: cannot open directory: %s" % path)
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
	path: String, economy_data: Dictionary
) -> void:
	var data: Variant = load_json(path)
	if data == null:
		return
	var content_type := _detect_type(path, data)
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
	if content_type == "electronics_config":
		if data is Dictionary:
			_electronics_config = data as Dictionary
		return
	if content_type == "video_rental_config":
		if data is Dictionary:
			_video_rental_config = data as Dictionary
		return
	if content_type.is_empty():
		return
	var entries: Array[Dictionary] = _extract_entries(data)
	for entry: Dictionary in entries:
		_build_and_register(content_type, entry)


func _detect_type(path: String, data: Variant) -> String:
	if data is Dictionary and data.has("type"):
		var raw_type: String = str(data["type"])
		return _TYPE_KEY_MAP.get(raw_type, raw_type)
	var rel := path.replace(CONTENT_ROOT, "")
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
	var file_base := path.get_file().get_basename()
	if file_base == "retro_games":
		return "retro_games_config"
	if file_base == "electronics":
		return "electronics_config"
	if file_base == "video_rental_config":
		return "video_rental_config"
	if file_base == "pocket_creatures_cards":
		return "item"
	if file_base == "pocket_creatures_tournaments":
		return "tournament_event"
	if _DIR_TYPE_MAP.has(dir_name):
		return _DIR_TYPE_MAP[dir_name]
	if file_base == "seasonal_config":
		return "seasonal_config"
	if file_base == "secret_threads":
		return "secret_thread"
	if file_base == "sports_seasons":
		return "sports_season"
	return ""


func _extract_entries(data: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if data is Array:
		for item: Variant in data:
			if item is Dictionary:
				entries.append(item)
	elif data is Dictionary:
		for key: String in data:
			var val: Variant = data[key]
			if val is Array:
				for item: Variant in val:
					if item is Dictionary:
						entries.append(item)
				return entries
		entries.append(data)
	return entries


func _build_and_register(
	content_type: String, entry: Dictionary
) -> void:
	if not entry.has("id"):
		push_error(
			"DataLoader: %s entry missing 'id': %s"
			% [content_type, entry]
		)
		return
	var id: String = str(entry["id"])
	var resource: Resource = ContentParser.build_resource(
		content_type, entry
	)
	if resource == null:
		return
	if not _store_in_dict(content_type, id, resource):
		return
	ContentRegistry.register(
		StringName(id), resource, content_type
	)
	if content_type in ["store", "fixture", "ending"]:
		var reg_entry: Dictionary = entry.duplicate()
		if not reg_entry.has("name") and reg_entry.has("display_name"):
			reg_entry["name"] = reg_entry["display_name"]
		ContentRegistry.register_entry(reg_entry, content_type)


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
	push_error("DataLoader: unknown type '%s'" % content_type)
	return false


func _try_register(
	id: String, registry: Dictionary, resource: Resource
) -> bool:
	if registry.has(id):
		push_error("DataLoader: duplicate id '%s'" % id)
		return false
	registry[id] = resource
	return true


func _load_endings(data: Variant) -> void:
	var entries: Array[Dictionary] = _extract_entries(data)
	for entry: Dictionary in entries:
		if not entry.has("id"):
			push_error("DataLoader: ending entry missing 'id'")
			continue
		var reg_entry: Dictionary = entry.duplicate()
		if not reg_entry.has("name") and reg_entry.has("display_name"):
			reg_entry["name"] = reg_entry["display_name"]
		ContentRegistry.register_entry(reg_entry, "ending")


func _load_secret_threads(data: Variant) -> void:
	if data is not Array:
		return
	for entry: Variant in data:
		if entry is Dictionary:
			var dict: Dictionary = entry as Dictionary
			if dict.has("id"):
				_secret_threads.append(dict)


func _parse_seasonal_config(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seasons: Variant = data.get("seasons", [])
	if seasons is not Array:
		push_error("DataLoader: seasonal_config missing 'seasons' array")
		return result
	for entry: Variant in seasons:
		if entry is not Dictionary:
			continue
		var season: Dictionary = entry as Dictionary
		if not season.has("index") or not season.has("store_multipliers"):
			push_error(
				"DataLoader: seasonal_config entry missing required fields"
			)
			continue
		result.append(season)
	return result


func _parse_named_seasons(data: Dictionary) -> void:
	_named_season_cycle_length = int(data.get("cycle_length", 70))
	var seasons_arr: Variant = data.get("seasons", [])
	if seasons_arr is not Array:
		push_error("DataLoader: seasons.json missing 'seasons' array")
		return
	for entry: Variant in seasons_arr:
		if entry is not Dictionary:
			continue
		var season: Dictionary = entry as Dictionary
		if not season.has("id") or not season.has("start_day"):
			push_error(
				"DataLoader: season entry missing required fields"
			)
			continue
		var id: String = str(season["id"])
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
	if not FileAccess.file_exists(path):
		push_error("DataLoader: file not found: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error(
			"DataLoader: failed to open '%s' — %s"
			% [path, error_string(FileAccess.get_open_error())]
		)
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error(
			"DataLoader: parse error in %s: %s"
			% [path, json.get_error_message()]
		)
		return null
	return json.data


# --- Public getters (backward-compatible API) ---


func get_item(id: String) -> ItemDefinition:
	return _items.get(id) as ItemDefinition


func get_all_items() -> Array[ItemDefinition]:
	var r: Array[ItemDefinition] = []
	r.assign(_items.values())
	return r


func get_items_by_store(
	store_type: String
) -> Array[ItemDefinition]:
	var r: Array[ItemDefinition] = []
	for item: ItemDefinition in _items.values():
		if item.store_type == store_type:
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
	return _stores.get(id) as StoreDefinition


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


func get_seasonal_config() -> Array[Dictionary]:
	return _seasonal_config


func get_fixture(id: String) -> FixtureDefinition:
	return _fixtures.get(id) as FixtureDefinition


func get_all_fixtures() -> Array[FixtureDefinition]:
	var r: Array[FixtureDefinition] = []
	r.assign(_fixtures.values())
	return r


func get_fixtures_for_store(
	store_type: String
) -> Array[FixtureDefinition]:
	var r: Array[FixtureDefinition] = []
	for f: FixtureDefinition in _fixtures.values():
		if f.store_types.is_empty() or store_type in f.store_types:
			r.append(f)
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
	var store: StoreDefinition = get_store(store_id)
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
	var common: Array[ItemDefinition] = []
	for item: ItemDefinition in _items.values():
		if item.store_type == store_type and item.rarity == "common":
			common.append(item)
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
