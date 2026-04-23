## Boot-time parody-name validator (DESIGN.md non-negotiable #5).
##
## Scans content-entry string values for real-world trademarked terms that
## would break the parody framing. Matches the denylist in
## `tests/validate_original_content.sh` (scene/script guard) so JSON content
## and authored scenes share one source of truth.
##
## Matching is case-insensitive substring. False positives are preferred over
## false negatives: if a legitimate string collides with a denylisted term,
## rename the content rather than weaken the check.
class_name TrademarkValidator
extends RefCounted

const DENYLIST: Array[String] = [
	"Nike",
	"Adidas",
	"Reebok",
	"Puma",
	"Jordan Brand",
	"Air Jordan",
	"Converse",
	"Foot Locker",
	"Footlocker",
	"New Balance",
	"Under Armour",
	"Yeezy",
]


## Returns an array of human-readable error messages. Empty array means clean.
## Each error names the source file, the entry id (when available), the field,
## and the offending term.
static func validate_entry(
	entry: Dictionary, content_type: String, source_path: String
) -> Array[String]:
	var errors: Array[String] = []
	var entry_id: String = str(entry.get("id", "<no-id>"))
	_scan_value(entry, entry_id, content_type, source_path, "", errors)
	return errors


static func _scan_value(
	value: Variant,
	entry_id: String,
	content_type: String,
	source_path: String,
	field_path: String,
	errors: Array[String],
) -> void:
	if value is String:
		_scan_string(
			value as String,
			entry_id,
			content_type,
			source_path,
			field_path,
			errors,
		)
		return
	if value is StringName:
		_scan_string(
			String(value as StringName),
			entry_id,
			content_type,
			source_path,
			field_path,
			errors,
		)
		return
	if value is Dictionary:
		for key: Variant in (value as Dictionary):
			var sub_path: String = (
				"%s.%s" % [field_path, str(key)] if not field_path.is_empty()
				else str(key)
			)
			_scan_value(
				(value as Dictionary)[key],
				entry_id,
				content_type,
				source_path,
				sub_path,
				errors,
			)
		return
	if value is Array:
		for i: int in (value as Array).size():
			var sub_path: String = "%s[%d]" % [field_path, i]
			_scan_value(
				(value as Array)[i],
				entry_id,
				content_type,
				source_path,
				sub_path,
				errors,
			)


static func _scan_string(
	text: String,
	entry_id: String,
	content_type: String,
	source_path: String,
	field_path: String,
	errors: Array[String],
) -> void:
	if text.is_empty():
		return
	var lower: String = text.to_lower()
	for term: String in DENYLIST:
		if lower.find(term.to_lower()) == -1:
			continue
		errors.append(
			(
				"trademark '%s' found in %s (%s id='%s', field='%s', value='%s')"
				% [
					term,
					source_path,
					content_type,
					entry_id,
					field_path if not field_path.is_empty() else "<root>",
					text,
				]
			)
		)
