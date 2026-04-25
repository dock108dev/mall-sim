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
			# JSON numbers parse as float; parser uses int().
			"slot_count": NUMERIC,
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
			"priority": [TYPE_INT, TYPE_FLOAT],
			"category": [TYPE_STRING],
		},
	},
}


## Rental item categories that require the ISSUE-009 extended schema.
const RENTAL_CATEGORIES: PackedStringArray = [
	"vhs_tapes", "dvd_titles", "vhs_classic", "vhs_new_release",
	"vhs_cult", "dvd_new_release", "dvd_classic",
]

## Required fields for rentable items (store_type == "rentals", rental category).
const RENTAL_ITEM_REQUIRED: Dictionary = {
	"rarity": [TYPE_STRING],
	"base_rental_fee": [TYPE_INT, TYPE_FLOAT],
	"late_fee_per_day": [TYPE_INT, TYPE_FLOAT],
	"release_date": [TYPE_INT, TYPE_FLOAT],
}


## Valid operator strings for ending criteria.
const VALID_OPERATORS: PackedStringArray = ["gte", "lte", "gt", "lt", "eq"]


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
	if content_type == "item":
		errors.append_array(_validate_rental_item_fields(entry, prefix))
	if content_type == "ending":
		errors.append_array(_validate_ending_criteria(entry, prefix))
	return errors


## Validates rental-specific required fields for items with store_type == "rentals"
## and a rental category. Non-rentable items (snacks, merchandise) are exempt.
static func _validate_rental_item_fields(
	entry: Dictionary, prefix: String
) -> Array[String]:
	var errors: Array[String] = []
	if str(entry.get("store_type", "")) != "rentals":
		return errors
	var cat: String = str(entry.get("category", ""))
	if cat not in RENTAL_CATEGORIES:
		return errors
	for field: String in RENTAL_ITEM_REQUIRED:
		if not entry.has(field):
			errors.append(
				"%s missing required rental field '%s'" % [prefix, field]
			)
			continue
		var accepted: Array = RENTAL_ITEM_REQUIRED[field]
		var value: Variant = entry[field]
		if not _type_matches(value, accepted):
			errors.append(
				"%s rental field '%s' has wrong type — expected %s, got %s"
				% [prefix, field, _type_names(accepted), _type_name(typeof(value))]
			)
	return errors

## Validates required_all, required_any, and forbidden_all criterion arrays
## for an ending entry. Each criterion must have stat_key (String), operator
## (one of the five valid ops), and value (numeric).
static func _validate_ending_criteria(
	entry: Dictionary, prefix: String
) -> Array[String]:
	var errors: Array[String] = []
	for list_key: String in ["required_all", "required_any", "forbidden_all"]:
		var criteria: Variant = entry.get(list_key, [])
		if criteria is not Array:
			errors.append(
				"%s field '%s' must be an Array" % [prefix, list_key]
			)
			continue
		for i: int in range((criteria as Array).size()):
			var criterion: Variant = (criteria as Array)[i]
			if criterion is not Dictionary:
				errors.append(
					"%s %s[%d] must be a Dictionary" % [prefix, list_key, i]
				)
				continue
			var cdict: Dictionary = criterion as Dictionary
			var cprefix: String = "%s %s[%d]" % [prefix, list_key, i]
			if not cdict.has("stat_key") or typeof(cdict["stat_key"]) != TYPE_STRING:
				errors.append(
					"%s missing or invalid 'stat_key' (must be String)" % cprefix
				)
			if not cdict.has("operator"):
				errors.append("%s missing 'operator'" % cprefix)
			elif typeof(cdict["operator"]) != TYPE_STRING:
				errors.append(
					"%s 'operator' must be a String" % cprefix
				)
			elif str(cdict["operator"]) not in VALID_OPERATORS:
				errors.append(
					"%s unknown operator '%s' — must be one of %s"
					% [cprefix, cdict["operator"], str(VALID_OPERATORS)]
				)
			if not cdict.has("value"):
				errors.append("%s missing 'value'" % cprefix)
			elif not _type_matches(cdict["value"], [TYPE_INT, TYPE_FLOAT]):
				errors.append(
					"%s 'value' must be numeric (int or float)" % cprefix
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
