## Schema definitions and validator for boot-time content JSON.
##
## Each schema declares required fields and their accepted Variant types.
## DataLoader calls `validate()` for every entry before it is registered so
## missing/mis-typed fields cause a loud boot failure rather than a silent
## runtime degradation.
class_name ContentSchema
extends RefCounted

const NUMERIC: Array = [TYPE_INT, TYPE_FLOAT]
const STRING_LIKE: Array = [TYPE_STRING, TYPE_STRING_NAME]

const SCHEMAS: Dictionary = {
	"season": {
		"required": {
			"id": [TYPE_STRING],
			"name": [TYPE_STRING],
			"event_pool": [TYPE_ARRAY],
			"price_modifier_table": [TYPE_DICTIONARY],
			"visual_variant": [TYPE_STRING],
		},
	},
	"item": {
		"required": {
			"id": [TYPE_STRING],
			"store_type": [TYPE_STRING],
			"category": [TYPE_STRING],
			"base_price": [TYPE_INT, TYPE_FLOAT],
		},
		"any_of": [["item_name", "display_name", "name"]],
	},
	"store": {
		"required": {
			"id": [TYPE_STRING],
			"name": [TYPE_STRING],
			"scene_path": [TYPE_STRING],
		},
	},
	"customer": {
		"required": {
			"id": [TYPE_STRING],
		},
		"any_of": [["name", "display_name"]],
	},
	"market_event": {
		"required": {
			"id": [TYPE_STRING],
			"event_type": [TYPE_STRING],
		},
		"any_of": [["name", "display_name"]],
	},
	"seasonal_event": {
		"required": {
			"id": [TYPE_STRING],
			"start_day": [TYPE_INT, TYPE_FLOAT],
			"duration_days": [TYPE_INT, TYPE_FLOAT],
		},
		"any_of": [["name", "display_name"]],
	},
	"random_event": {
		"required": {
			"id": [TYPE_STRING],
			"effect_type": [TYPE_STRING],
		},
		"any_of": [["name", "display_name"]],
	},
	"ambient_moment": {
		"required": {
			"id": [TYPE_STRING],
			"trigger_category": [TYPE_STRING],
			"flavor_text": [TYPE_STRING],
			"store_id": [TYPE_STRING],
			"season_id": [TYPE_STRING],
			# JSON numbers parse as float in Godot; parser uses int().
			"min_day": NUMERIC,
			"max_day": NUMERIC,
			"duration_seconds": [TYPE_INT, TYPE_FLOAT],
		},
	},
	"secret_thread": {
		"required": {
			"id": [TYPE_STRING],
			"display_name": [TYPE_STRING],
			"steps": [TYPE_ARRAY],
			"trigger_conditions": [TYPE_ARRAY],
			"stages": [TYPE_ARRAY],
			"resolution_text": [TYPE_STRING],
		},
	},
	"milestone": {
		"required": {
			"id": [TYPE_STRING],
			"display_name": [TYPE_STRING],
			"trigger_type": [TYPE_STRING],
		},
	},
	"staff": {
		"required": {
			"id": [TYPE_STRING],
			"role": [TYPE_STRING],
		},
		"any_of": [["name", "display_name"]],
	},
	"fixture": {
		"required": {
			"id": [TYPE_STRING],
			"display_name": [TYPE_STRING],
			"cost": [TYPE_INT, TYPE_FLOAT],
			"slot_count": [TYPE_INT],
		},
	},
	"upgrade": {
		"required": {
			"id": [TYPE_STRING],
			"display_name": [TYPE_STRING],
			"effect_type": [TYPE_STRING],
		},
	},
	"unlock": {
		"required": {
			"id": [TYPE_STRING],
			"display_name": [TYPE_STRING],
			"effect_type": [TYPE_STRING],
		},
	},
	"supplier": {
		"required": {
			"id": [TYPE_STRING],
			"store_type": [TYPE_STRING],
		},
	},
	"ending": {
		"required": {
			"id": [TYPE_STRING],
			"title": [TYPE_STRING],
		},
	},
}


## Returns true when the registry has a schema for this content type.
static func has_schema(content_type: String) -> bool:
	return SCHEMAS.has(content_type)


## Validates an entry against its schema. Returns a list of human-readable
## errors. An empty list means the entry passes validation.
static func validate(
	entry: Dictionary, content_type: String, source: String = ""
) -> Array[String]:
	var errors: Array[String] = []
	var schema: Dictionary = SCHEMAS.get(content_type, {})
	if schema.is_empty():
		return errors
	var id_display: String = str(entry.get("id", "<missing id>"))
	var prefix: String = "%s '%s'" % [content_type, id_display]
	if not source.is_empty():
		prefix += " in %s" % source
	var required: Dictionary = schema.get("required", {})
	for field: String in required:
		if not entry.has(field):
			errors.append(
				"%s missing required field '%s'" % [prefix, field]
			)
			continue
		var accepted: Array = required[field]
		var value: Variant = entry[field]
		if not _type_matches(value, accepted):
			errors.append(
				(
					"%s field '%s' has wrong type — expected %s, got %s"
					% [prefix, field, _type_names(accepted), _type_name(typeof(value))]
				)
			)
	var any_of: Array = schema.get("any_of", [])
	for group: Array in any_of:
		var present: bool = false
		for candidate: String in group:
			if entry.has(candidate) and typeof(entry[candidate]) == TYPE_STRING:
				present = true
				break
		if not present:
			errors.append(
				"%s missing any of %s" % [prefix, str(group)]
			)
	return errors


static func _type_matches(value: Variant, accepted: Array) -> bool:
	var actual: int = typeof(value)
	for t: int in accepted:
		if actual == t:
			return true
	return false


static func _type_names(types: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for t: int in types:
		parts.append(_type_name(t))
	return "|".join(parts)


static func _type_name(t: int) -> String:
	match t:
		TYPE_STRING: return "String"
		TYPE_STRING_NAME: return "StringName"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_BOOL: return "bool"
		TYPE_NIL: return "null"
	return "type_%d" % t
