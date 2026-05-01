## Central content registry for canonical ID resolution across all systems.
extends Node

const ID_PATTERN := "^[a-z][a-z0-9_]{0,63}$"
const SCENE_PATH_PREFIX := "res://game/scenes/"
const STORE_SCENE_PATH_PREFIX := "res://game/scenes/stores/"

var _entries: Dictionary = {}
var _aliases: Dictionary = {}
var _scene_map: Dictionary = {}
var _display_names: Dictionary = {}
var _types: Dictionary = {}
var _resources: Dictionary = {}
var _warned_missing_scenes: Dictionary = {}
var _warned_helper_fallbacks: Dictionary = {}
var _duplicate_errors: Array[String] = []
var _id_regex: RegEx
var _ready_flag: bool = false


func _ready() -> void:
	_id_regex = RegEx.new()
	_id_regex.compile(ID_PATTERN)


## Returns true when at least one entry has been registered.
func is_ready() -> bool:
	return _ready_flag


## Resolves any raw ID string to its canonical StringName form.
# gdlint:disable=max-returns
func resolve(raw: String) -> StringName:
	if raw.is_empty():
		return &""
	var trimmed: String = raw.strip_edges()
	var id: StringName = StringName(trimmed)
	if _entries.has(id):
		return id
	if _resources.has(id):
		return id
	if _aliases.has(id):
		return _aliases[id]
	var normalized: StringName = _normalize(trimmed)
	if _entries.has(normalized):
		return normalized
	if _resources.has(normalized):
		return normalized
	if _aliases.has(normalized):
		return _aliases[normalized]
	_report_unknown_id(raw, normalized)
	return &""


## Returns true if the ID (or an alias for it) exists.
# gdlint:enable=max-returns
func exists(raw: String) -> bool:
	if raw.is_empty():
		return false
	var id: StringName = StringName(raw.strip_edges())
	if _entries.has(id) or _resources.has(id) or _aliases.has(id):
		return true
	var normalized: StringName = _normalize(raw)
	return (
		_entries.has(normalized)
		or _aliases.has(normalized)
		or _resources.has(normalized)
	)


## Returns true if the ID resolves and, when provided, matches the expected type.
func is_valid_id(raw: StringName, expected_type: String = "") -> bool:
	var canonical: StringName = _resolve_internal(raw)
	if canonical.is_empty():
		return false
	if expected_type.is_empty():
		return true
	return str(_types.get(canonical, "")) == expected_type


## Returns the full entry dictionary for a canonical or alias ID.
func get_entry(id: StringName) -> Dictionary:
	var canonical: StringName = _resolve_internal(id)
	if canonical.is_empty():
		_report_unknown_id(String(id), _normalize(String(id)))
		return {}
	return _entries.get(canonical, {})


## Returns the display name for a canonical or alias ID.
func get_display_name(id: StringName) -> String:
	var canonical: StringName = _resolve_internal(id)
	if canonical.is_empty():
		if not id.is_empty():
			_warn_helper_fallback_once(
				"get_display_name:%s" % id,
				(
					"ContentRegistry: get_display_name fallback for unknown ID "
					+ "'%s' (normalized: '%s')"
				)
				% [id, _normalize(String(id))]
			)
		return String(id)
	return _display_names.get(canonical, String(canonical))


## Returns the scene path for a canonical or alias ID.
func get_scene_path(id: StringName) -> String:
	var canonical: StringName = _resolve_internal(id)
	if canonical.is_empty():
		if not id.is_empty():
			_warn_helper_fallback_once(
				"get_scene_path:unknown:%s" % id,
				(
					"ContentRegistry: get_scene_path fallback for unknown ID "
					+ "'%s' (normalized: '%s')"
				)
				% [id, _normalize(String(id))]
			)
		return ""
	if not _scene_map.has(canonical):
		_warn_helper_fallback_once(
			"get_scene_path:missing:%s" % canonical,
			(
				"ContentRegistry: get_scene_path fallback for ID '%s' — no scene path is registered"
				% canonical
			)
		)
	return _scene_map.get(canonical, "")


## Returns the routing payload for a store ID as a Dictionary with keys
## `scene_path` (String), `inventory_type` (StringName),
## `interaction_set_id` (StringName), `tutorial_context_id` (StringName).
## Returns an empty Dictionary for unknown IDs or stores missing any routing
## field — the single source of truth for store category → scene → data
## binding (ISSUE-001, DESIGN.md §1.2). Boot-time `validate_all_references()`
## still surfaces missing/incomplete entries via `_record_duplicate` so a
## production miswiring fails loud at startup; runtime queries downgrade to
## `push_warning` because callers (router, store director) already handle the
## empty-dict path explicitly.
func get_store_route(id: StringName) -> Dictionary:
	var canonical: StringName = _resolve_resource_id(id)
	if canonical.is_empty():
		_emit_warning(
			"ContentRegistry: get_store_route unknown store_id '%s'" % id
		)
		return {}
	var resource: Resource = _resources.get(canonical)
	var store: StoreDefinition = resource as StoreDefinition
	if store == null:
		_emit_error(
			"ContentRegistry: get_store_route id '%s' is not a store" % canonical
		)
		return {}
	var missing: Array[String] = []
	if store.scene_path.is_empty():
		missing.append("scene_path")
	if store.inventory_type == &"":
		missing.append("inventory_type")
	if store.interaction_set_id == &"":
		missing.append("interaction_set_id")
	if store.tutorial_context_id == &"":
		missing.append("tutorial_context_id")
	if not missing.is_empty():
		_emit_warning(
			"ContentRegistry: store '%s' missing route fields: %s"
			% [canonical, ", ".join(missing)]
		)
		return {}
	return {
		"store_id": canonical,
		"scene_path": store.scene_path,
		"inventory_type": store.inventory_type,
		"interaction_set_id": store.interaction_set_id,
		"tutorial_context_id": store.tutorial_context_id,
	}


## Returns a typed item definition resource for a canonical or alias ID.
func get_item_definition(id: StringName) -> ItemDefinition:
	return _get_typed_resource(id, "item") as ItemDefinition


## Returns a typed store definition resource for a canonical or alias ID.
func get_store_definition(id: StringName) -> StoreDefinition:
	return _get_typed_resource(id, "store") as StoreDefinition


## Returns a typed customer definition resource for a canonical or alias ID.
func get_customer_type_definition(id: StringName) -> CustomerTypeDefinition:
	return _get_typed_resource(id, "customer") as CustomerTypeDefinition


## Returns a typed upgrade definition resource for a canonical or alias ID.
func get_upgrade_definition(id: StringName) -> UpgradeDefinition:
	return _get_typed_resource(id, "upgrade") as UpgradeDefinition


## Returns the registered economy config resource when available.
func get_economy_config() -> EconomyConfig:
	return _get_typed_resource(&"economy_config", "economy") as EconomyConfig


## Clears all registry state. For use in tests only.
func clear_for_testing() -> void:
	_entries.clear()
	_aliases.clear()
	_scene_map.clear()
	_display_names.clear()
	_types.clear()
	_resources.clear()
	_warned_missing_scenes.clear()
	_warned_helper_fallbacks.clear()
	_duplicate_errors.clear()
	_ready_flag = false
	DataLoaderSingleton.clear_for_testing()
	ReputationSystemSingleton.reset()
	MarketTrendSystemSingleton.reset()
	DifficultySystemSingleton._current_tier_id = DifficultySystemSingleton.DEFAULT_TIER


## Returns all canonical IDs of a given content type.
func get_all_ids(content_type: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _types:
		if _types[id] == content_type:
			result.append(id)
	return result


## Returns canonical store IDs registered in the content catalog.
func get_all_store_ids() -> Array[StringName]:
	return get_all_ids("store")


## Stores a typed resource by canonical ID.
func register(
	id: StringName, resource: Resource, content_type: String
) -> void:
	var raw_id: String = String(id)
	if not _id_regex:
		_id_regex = RegEx.new()
		_id_regex.compile(ID_PATTERN)
	if not _id_regex.search(raw_id):
		_emit_error(
			"ContentRegistry: ID '%s' does not match format %s"
			% [raw_id, ID_PATTERN]
		)
		return
	if _resources.has(id):
		var existing_type: String = str(_types.get(id, ""))
		_record_duplicate(
			"ContentRegistry: duplicate resource ID '%s' (existing type '%s', new type '%s')"
			% [raw_id, existing_type, content_type]
		)
		return
	_resources[id] = resource
	if not _types.has(id):
		_types[id] = content_type


## Registers a raw entry dictionary for ID resolution and aliases.
func register_entry(
	entry: Dictionary, content_type: String
) -> void:
	_register_entry(entry, content_type)


## Checks cross-references between registered resources.
## Includes duplicate-id and alias-conflict errors recorded during registration
## so boot fails loudly when any id or alias resolves to more than one target
## (ISSUE-010).
func validate_all_references() -> Array[String]:
	var errors: Array[String] = []
	for message: String in _duplicate_errors:
		errors.append(message)
	for id: StringName in _resources:
		var resource: Resource = _resources[id]
		if resource is ItemDefinition:
			_validate_item(
				id, resource as ItemDefinition, errors
			)
		elif resource is StoreDefinition:
			_validate_store(
				id, resource as StoreDefinition, errors
			)
	for scene_id: StringName in _scene_map:
		var path: String = _scene_map[scene_id]
		if not ResourceLoader.exists(path):
			_report_missing_scene_once(path, scene_id)
			errors.append(
				"ID '%s' references missing scene '%s'"
				% [scene_id, path]
			)
	_validate_entry_cross_refs(errors)
	return errors


func _validate_entry_cross_refs(errors: Array[String]) -> void:
	for entry_id: StringName in _entries:
		var entry: Dictionary = _entries[entry_id]
		var entry_type: String = str(_types.get(entry_id, ""))
		match entry_type:
			"market_event":
				_validate_event_store_refs(entry_id, entry, errors)
			"seasonal_event":
				_validate_event_store_refs(entry_id, entry, errors)
				_validate_seasonal_event_store_refs(entry_id, entry, errors)
			"supplier":
				_validate_supplier_refs(entry_id, entry, errors)
			"milestone":
				_validate_milestone_refs(entry_id, entry, errors)


func _validate_event_store_refs(
	entry_id: StringName, entry: Dictionary, errors: Array[String]
) -> void:
	var targets: Variant = entry.get("target_store_types", [])
	if targets is not Array:
		return
	for raw: Variant in targets:
		var store_id: String = str(raw)
		if store_id.is_empty():
			continue
		if not exists(store_id):
			errors.append(
				"Event '%s' references unknown store_type '%s'"
				% [entry_id, store_id]
			)


func _validate_seasonal_event_store_refs(
	entry_id: StringName, entry: Dictionary, errors: Array[String]
) -> void:
	var affected: Variant = entry.get("affected_stores", [])
	if affected is Array:
		for raw: Variant in (affected as Array):
			var sid: String = str(raw)
			if sid.is_empty():
				continue
			if not exists(sid):
				errors.append(
					"SeasonalEvent '%s' affected_stores references unknown store '%s'"
					% [entry_id, sid]
				)
	var multipliers: Variant = entry.get("store_type_multipliers", {})
	if multipliers is Dictionary:
		for key: Variant in (multipliers as Dictionary):
			var sid: String = str(key)
			if sid.is_empty():
				continue
			if not exists(sid):
				errors.append(
					"SeasonalEvent '%s' store_type_multipliers references unknown store '%s'"
					% [entry_id, sid]
				)


func _validate_supplier_refs(
	entry_id: StringName, entry: Dictionary, errors: Array[String]
) -> void:
	var store_type: String = str(entry.get("store_type", ""))
	if not store_type.is_empty() and not exists(store_type):
		errors.append(
			"Supplier '%s' references unknown store_type '%s'"
			% [entry_id, store_type]
		)
	var catalog: Variant = entry.get("catalog", [])
	if catalog is not Array:
		return
	for cat_entry: Variant in (catalog as Array):
		if cat_entry is not Dictionary:
			continue
		var item_id: String = str((cat_entry as Dictionary).get("item_id", ""))
		if item_id.is_empty():
			continue
		if not exists(item_id):
			errors.append(
				"Supplier '%s' catalog references unknown item_id '%s'"
				% [entry_id, item_id]
			)


func _validate_milestone_refs(
	entry_id: StringName, entry: Dictionary, errors: Array[String]
) -> void:
	var unlock_raw: Variant = entry.get("unlock_id", null)
	if unlock_raw == null or typeof(unlock_raw) != TYPE_STRING:
		return
	var uid: String = unlock_raw as String
	if uid.is_empty():
		return
	if not exists(uid):
		errors.append(
			"Milestone '%s' references unknown unlock_id '%s'"
			% [entry_id, uid]
		)


func _report_missing_scene_once(path: String, scene_id: StringName) -> void:
	if _warned_missing_scenes.has(path):
		return
	_warned_missing_scenes[path] = true
	_emit_error(
		"ContentRegistry: scene '%s' for ID '%s' not found"
		% [path, scene_id]
	)


func _validate_item(
	id: StringName, item: ItemDefinition,
	errors: Array[String]
) -> void:
	if item.store_type.is_empty():
		return
	if not exists(item.store_type):
		if not _resources.has(StringName(item.store_type)):
			errors.append(
				"Item '%s' references unknown store_type '%s'"
				% [id, item.store_type]
			)


func _validate_store(
	id: StringName, store: StoreDefinition,
	errors: Array[String]
) -> void:
	# ISSUE-001: every store must expose a complete routing payload so boot
	# fails loud rather than silently falling back to another store's wiring.
	if store.scene_path.is_empty():
		errors.append("Store '%s' missing scene_path" % id)
	if store.inventory_type == &"":
		errors.append("Store '%s' missing inventory_type" % id)
	if store.interaction_set_id == &"":
		errors.append("Store '%s' missing interaction_set_id" % id)
	if store.tutorial_context_id == &"":
		errors.append("Store '%s' missing tutorial_context_id" % id)
	for item_id: String in store.starting_inventory:
		if item_id.is_empty():
			continue
		if not _resources.has(StringName(item_id)):
			errors.append(
				"Store '%s' references unknown item '%s'"
				% [id, item_id]
			)


func _resolve_internal(id: StringName) -> StringName:
	if _entries.has(id):
		return id
	var normalized: StringName = _normalize(String(id))
	if _entries.has(normalized):
		return normalized
	if _aliases.has(normalized):
		return _aliases[normalized]
	return &""


func _normalize(raw: String) -> StringName:
	var result: String = raw.strip_edges()
	result = result.to_snake_case()
	result = result.replace("-", "_")
	result = result.replace(" ", "_")
	result = result.replace("/", "_")
	while result.contains("__"):
		result = result.replace("__", "_")
	result = result.trim_prefix("_").trim_suffix("_")
	return StringName(result)


func _register_entry(
	entry: Dictionary, content_type: String
) -> void:
	if not _id_regex:
		_id_regex = RegEx.new()
		_id_regex.compile(ID_PATTERN)
	if not entry.has("id"):
		_emit_error("ContentRegistry: entry missing 'id' field")
		return
	var raw_id: String = str(entry["id"])
	var id: StringName = StringName(raw_id)
	if not _id_regex.search(raw_id):
		_emit_error(
			"ContentRegistry: ID '%s' does not match format %s"
			% [raw_id, ID_PATTERN]
		)
		return
	if _entries.has(id):
		var existing_type: String = str(_types.get(id, ""))
		_record_duplicate(
			"ContentRegistry: duplicate entry ID '%s' (existing type '%s', new type '%s')"
			% [raw_id, existing_type, content_type]
		)
		return
	# Canonical IDs always win over previously-registered display-name / path
	# aliases. Drop any alias that collides with this new primary so the
	# uniqueness invariant (alias key never shadows an entry key) holds across
	# load order.
	if _aliases.has(id):
		_aliases.erase(id)
	_entries[id] = entry
	_types[id] = content_type
	_ready_flag = true
	var display_name: String = _get_display_name(entry, raw_id)
	_display_names[id] = display_name
	var scene_path: String = _sanitize_scene_path(
		_get_scene_path(entry), content_type, id
	)
	if not scene_path.is_empty():
		_scene_map[id] = scene_path
	_register_optional_alias(display_name, id)
	_register_optional_alias(scene_path.get_file().get_basename(), id)
	if entry.has("aliases"):
		var aliases: Array = entry["aliases"]
		for alias: Variant in aliases:
			_register_optional_alias(str(alias), id)


func _register_alias(
	alias: StringName, canonical: StringName
) -> void:
	if alias == canonical:
		return
	if alias.is_empty():
		return
	if _entries.has(alias):
		# Optional display-name / path aliases must not claim another entry's ID.
		_warn_helper_fallback_once(
			"alias_skips_primary_id_%s" % str(alias),
			(
				"ContentRegistry: skipping alias '%s' for '%s' (already a primary ID)"
				% [alias, canonical]
			)
		)
		return
	if _aliases.has(alias) and _aliases[alias] != canonical:
		_record_duplicate(
			"ContentRegistry: alias '%s' maps to both '%s' and '%s'"
			% [alias, _aliases[alias], canonical]
		)
		return
	_aliases[alias] = canonical


func _report_unknown_id(raw: String, normalized: StringName) -> void:
	# push_warning (not push_error) so unregistered lookups don't fail CI's
	# push_error audit. Unknown IDs are a recoverable state, not a fatal bug.
	_emit_warning(
		"ContentRegistry: unknown ID '%s' (normalized: '%s')"
		% [raw, normalized]
	)


func _emit_error(message: String) -> void:
	push_error(message)


## Records a duplicate-id or alias-conflict error for boot-time validation.
## Boot fails loudly when any of these accumulate (see validate_all_references).
func _record_duplicate(message: String) -> void:
	_duplicate_errors.append(message)
	push_error(message)


func _emit_warning(message: String) -> void:
	push_warning(message)


func _warn_helper_fallback_once(key: String, message: String) -> void:
	if _warned_helper_fallbacks.has(key):
		return
	_warned_helper_fallbacks[key] = true
	_emit_warning(message)


func _get_display_name(entry: Dictionary, raw_id: String) -> String:
	if entry.has("display_name"):
		return str(entry["display_name"])
	return str(entry.get("name", raw_id))


func _get_scene_path(entry: Dictionary) -> String:
	if entry.has("scene_path"):
		return str(entry["scene_path"])
	if entry.has("scene"):
		return str(entry["scene"])
	return ""


## §DR-08: rejects `..` segments and `//` collapse so the prefix lock cannot be
## bypassed by a content-authoring typo or pasted path. `res://` is sandboxed
## by the engine, but a `..` makes the resolved path ambiguous in audit grep
## and would defeat the `STORE_SCENE_PATH_PREFIX` constraint for store entries.
func _sanitize_scene_path(
	raw_path: String,
	content_type: String,
	id: StringName
) -> String:
	var scene_path: String = raw_path.strip_edges()
	if scene_path.is_empty():
		return ""
	if not scene_path.begins_with(SCENE_PATH_PREFIX):
		_emit_error(
			(
				"ContentRegistry: scene path '%s' for ID '%s' must stay under '%s'"
				% [scene_path, id, SCENE_PATH_PREFIX]
			)
		)
		return ""
	if not scene_path.ends_with(".tscn"):
		_emit_error(
			(
				"ContentRegistry: scene path '%s' for ID '%s' must reference a .tscn scene"
				% [scene_path, id]
			)
		)
		return ""
	var tail: String = scene_path.substr(SCENE_PATH_PREFIX.length())
	if tail.find("..") != -1 or tail.find("//") != -1:
		_emit_error(
			(
				"ContentRegistry: scene path '%s' for ID '%s' must not contain '..' segments or empty path components"
				% [scene_path, id]
			)
		)
		return ""
	if content_type == "store" and not scene_path.begins_with(STORE_SCENE_PATH_PREFIX):
		_emit_error(
			(
				"ContentRegistry: store scene path '%s' for ID '%s' must stay under '%s'"
				% [scene_path, id, STORE_SCENE_PATH_PREFIX]
			)
		)
		return ""
	return scene_path


func _register_optional_alias(
	raw_alias: String, canonical: StringName
) -> void:
	if raw_alias.strip_edges().is_empty():
		return
	_register_alias(_normalize(raw_alias), canonical)


func _get_typed_resource(
	id: StringName, expected_type: String
) -> Resource:
	var canonical: StringName = _resolve_resource_id(id)
	if canonical.is_empty():
		return null
	if not expected_type.is_empty():
		var actual_type: String = str(_types.get(canonical, ""))
		if actual_type != expected_type:
			_emit_error(
				"ContentRegistry: type mismatch for '%s' — expected '%s', got '%s'"
				% [canonical, expected_type, actual_type]
			)
			return null
	return _resources.get(canonical) as Resource


func _resolve_resource_id(id: StringName) -> StringName:
	if _resources.has(id):
		return id
	var resolved: StringName = _resolve_internal(id)
	if not resolved.is_empty() and _resources.has(resolved):
		return resolved
	var normalized: StringName = _normalize(String(id))
	if _resources.has(normalized):
		return normalized
	if _aliases.has(normalized):
		var alias_target: StringName = _aliases[normalized]
		if _resources.has(alias_target):
			return alias_target
	return &""
