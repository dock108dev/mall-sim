## Central content registry for canonical ID resolution across all systems.
extends Node

const ID_PATTERN := "^[a-z][a-z0-9_]{0,63}$"

var _entries: Dictionary = {}
var _aliases: Dictionary = {}
var _scene_map: Dictionary = {}
var _display_names: Dictionary = {}
var _types: Dictionary = {}
var _resources: Dictionary = {}
var _id_regex: RegEx
var _ready_flag: bool = false


func _ready() -> void:
	_id_regex = RegEx.new()
	_id_regex.compile(ID_PATTERN)


## Returns true when at least one entry has been registered.
func is_ready() -> bool:
	return _ready_flag


## Resolves any raw ID string to its canonical StringName form.
func resolve(raw: String) -> StringName:
	if raw.is_empty():
		return &""
	var normalized: StringName = _normalize(raw)
	if _entries.has(normalized):
		return normalized
	if _aliases.has(normalized):
		return _aliases[normalized]
	push_error(
		"ContentRegistry: unknown ID '%s' (normalized: '%s')"
		% [raw, normalized]
	)
	return &""


## Returns true if the ID (or an alias for it) exists.
func exists(raw: String) -> bool:
	if raw.is_empty():
		return false
	var normalized: StringName = _normalize(raw)
	return (
		_entries.has(normalized)
		or _aliases.has(normalized)
	)


## Returns the full entry dictionary for a canonical or alias ID.
func get_entry(id: StringName) -> Dictionary:
	var canonical: StringName = _resolve_internal(id)
	if canonical.is_empty():
		return {}
	return _entries.get(canonical, {})


## Returns the display name for a canonical or alias ID.
func get_display_name(id: StringName) -> String:
	var canonical: StringName = _resolve_internal(id)
	if canonical.is_empty():
		return String(id)
	return _display_names.get(canonical, String(canonical))


## Returns the scene path for a canonical or alias ID.
func get_scene_path(id: StringName) -> String:
	var canonical: StringName = _resolve_internal(id)
	if canonical.is_empty():
		return ""
	return _scene_map.get(canonical, "")


## Returns all canonical IDs of a given content type.
func get_all_ids(content_type: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _types:
		if _types[id] == content_type:
			result.append(id)
	return result


## Stores a typed resource by canonical ID.
func register(
	id: StringName, resource: Resource, content_type: String
) -> void:
	_resources[id] = resource
	if not _types.has(id):
		_types[id] = content_type


## Registers a raw entry dictionary for ID resolution and aliases.
func register_entry(
	entry: Dictionary, content_type: String
) -> void:
	_register_entry(entry, content_type)


## Checks cross-references between registered resources.
func validate_all_references() -> Array[String]:
	var errors: Array[String] = []
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
			push_warning(
				"ContentRegistry: scene '%s' for ID '%s' not found"
				% [path, scene_id]
			)
	return errors


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
	while result.contains("__"):
		result = result.replace("__", "_")
	return StringName(result)


func _register_entry(
	entry: Dictionary, content_type: String
) -> void:
	if not entry.has("id"):
		push_error("ContentRegistry: entry missing 'id' field")
		return
	var raw_id: String = str(entry["id"])
	var id: StringName = StringName(raw_id)
	if not _id_regex.search(raw_id):
		push_error(
			"ContentRegistry: ID '%s' does not match format %s"
			% [raw_id, ID_PATTERN]
		)
		return
	if _entries.has(id):
		push_error("ContentRegistry: duplicate ID '%s'" % raw_id)
		return
	_entries[id] = entry
	_types[id] = content_type
	_ready_flag = true
	var display_name: String = str(entry.get("name", raw_id))
	_display_names[id] = display_name
	if entry.has("scene_path"):
		_scene_map[id] = str(entry["scene_path"])
	_register_alias(_normalize(display_name), id)
	if entry.has("aliases"):
		var aliases: Array = entry["aliases"]
		for alias: Variant in aliases:
			_register_alias(_normalize(str(alias)), id)


func _register_alias(
	alias: StringName, canonical: StringName
) -> void:
	if alias == canonical:
		return
	if _entries.has(alias):
		push_error(
			"ContentRegistry: alias '%s' collides with existing ID"
			% alias
		)
		return
	if _aliases.has(alias) and _aliases[alias] != canonical:
		push_error(
			"ContentRegistry: alias '%s' maps to both '%s' and '%s'"
			% [alias, _aliases[alias], canonical]
		)
		return
	_aliases[alias] = canonical
