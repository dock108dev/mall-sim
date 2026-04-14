## Validates seasonal_events.json and random_events.json content files.
extends GutTest


const SEASONAL_PATH: String = (
	"res://game/content/events/seasonal_events.json"
)
const RANDOM_PATH: String = (
	"res://game/content/events/random_events.json"
)

var _seasonal_data: Array = []
var _random_data: Array = []


func before_all() -> void:
	_seasonal_data = _load_json(SEASONAL_PATH)
	_random_data = _load_json(RANDOM_PATH)


func _load_json(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Cannot open %s" % path)
		return []
	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		push_error("JSON parse error in %s: %s" % [path, json.get_error_message()])
		return []
	if json.data is Array:
		return json.data
	return []


func test_seasonal_events_parses_without_error() -> void:
	assert_gt(_seasonal_data.size(), 0, "seasonal_events.json should parse")


func test_seasonal_events_minimum_count() -> void:
	assert_gte(
		_seasonal_data.size(), 6,
		"Need at least 6 seasonal events"
	)


func test_seasonal_events_required_fields() -> void:
	var required: Array[String] = [
		"id", "name", "description", "frequency_days",
		"duration_days", "offset_days",
		"customer_traffic_multiplier", "spending_multiplier",
		"announcement_text", "active_text",
	]
	for entry: Variant in _seasonal_data:
		var d: Dictionary = entry as Dictionary
		for field: String in required:
			assert_true(
				d.has(field),
				"Seasonal event '%s' missing field '%s'" % [
					d.get("id", "UNKNOWN"), field
				]
			)


func test_seasonal_events_unique_ids() -> void:
	var ids: Dictionary = {}
	for entry: Variant in _seasonal_data:
		var d: Dictionary = entry as Dictionary
		var id: String = str(d.get("id", ""))
		assert_false(
			ids.has(id),
			"Duplicate seasonal event id: %s" % id
		)
		ids[id] = true


func test_seasonal_events_spread_across_cycle() -> void:
	var offsets: Array[int] = []
	for entry: Variant in _seasonal_data:
		var d: Dictionary = entry as Dictionary
		offsets.append(int(d.get("offset_days", 0)))
	offsets.sort()
	var has_early: bool = false
	var has_mid: bool = false
	var has_late: bool = false
	for offset: int in offsets:
		if offset < 30:
			has_early = true
		elif offset < 60:
			has_mid = true
		else:
			has_late = true
	assert_true(has_early, "Need events in early cycle (0-29)")
	assert_true(has_mid, "Need events in mid cycle (30-59)")
	assert_true(has_late, "Need events in late cycle (60+)")


func test_seasonal_events_parse_to_resources() -> void:
	for entry: Variant in _seasonal_data:
		var d: Dictionary = entry as Dictionary
		var res: SeasonalEventDefinition = (
			ContentParser.parse_seasonal_event(d)
		)
		assert_not_null(
			res,
			"Failed to parse seasonal event: %s" % d.get("id", "?")
		)


func test_random_events_parses_without_error() -> void:
	assert_gt(_random_data.size(), 0, "random_events.json should parse")


func test_random_events_minimum_count() -> void:
	assert_gte(
		_random_data.size(), 8,
		"Need at least 8 random events"
	)


func test_random_events_required_fields() -> void:
	var required: Array[String] = [
		"id", "name", "description", "effect_type",
		"duration_days", "severity", "cooldown_days",
		"probability_weight", "notification_text", "toast_message",
	]
	for entry: Variant in _random_data:
		var d: Dictionary = entry as Dictionary
		for field: String in required:
			assert_true(
				d.has(field),
				"Random event '%s' missing field '%s'" % [
					d.get("id", "UNKNOWN"), field
				]
			)


func test_random_events_unique_ids() -> void:
	var ids: Dictionary = {}
	for entry: Variant in _random_data:
		var d: Dictionary = entry as Dictionary
		var id: String = str(d.get("id", ""))
		assert_false(
			ids.has(id),
			"Duplicate random event id: %s" % id
		)
		ids[id] = true


func test_random_events_probability_weights_positive() -> void:
	for entry: Variant in _random_data:
		var d: Dictionary = entry as Dictionary
		var weight: float = float(d.get("probability_weight", 0.0))
		assert_gt(
			weight, 0.0,
			"Event '%s' probability_weight must be > 0" % d.get("id")
		)


func test_random_events_valid_effect_types() -> void:
	var valid_types: Array[String] = [
		"supply_shortage", "viral_trend", "health_inspection",
		"shoplifting", "water_leak", "celebrity_visit",
		"power_outage", "collector_convention", "bulk_order",
		"competitor_sale", "rainy_day", "estate_sale",
	]
	for entry: Variant in _random_data:
		var d: Dictionary = entry as Dictionary
		var effect: String = str(d.get("effect_type", ""))
		assert_has(
			valid_types, effect,
			"Event '%s' has invalid effect_type '%s'" % [
				d.get("id"), effect
			]
		)


func test_random_events_varied_effects() -> void:
	var types_used: Dictionary = {}
	for entry: Variant in _random_data:
		var d: Dictionary = entry as Dictionary
		types_used[str(d.get("effect_type", ""))] = true
	assert_gte(
		types_used.size(), 4,
		"Random events should use at least 4 different effect types"
	)


func test_random_events_parse_to_resources() -> void:
	for entry: Variant in _random_data:
		var d: Dictionary = entry as Dictionary
		var res: RandomEventDefinition = (
			ContentParser.parse_random_event(d)
		)
		assert_not_null(
			res,
			"Failed to parse random event: %s" % d.get("id", "?")
		)


func test_no_real_brand_names() -> void:
	var banned: Array[String] = [
		"Nintendo", "Sony", "Microsoft", "Pokemon", "Apple",
		"Samsung", "Nike", "Adidas", "Marvel", "Disney",
		"NBA", "NFL", "MLB", "NHL", "FIFA",
	]
	for entry: Variant in _seasonal_data + _random_data:
		var d: Dictionary = entry as Dictionary
		var text: String = (
			str(d.get("name", ""))
			+ str(d.get("description", ""))
			+ str(d.get("notification_text", ""))
			+ str(d.get("toast_message", ""))
		)
		for brand: String in banned:
			assert_false(
				text.containsn(brand),
				"Entry '%s' contains real brand '%s'" % [
					d.get("id"), brand
				]
			)
