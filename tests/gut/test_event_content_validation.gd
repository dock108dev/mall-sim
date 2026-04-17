## Validates seasonal_events.json and random_events.json content files.
extends GutTest


const SEASONAL_PATH: String = (
	"res://game/content/events/seasonal_events.json"
)
const RANDOM_PATH: String = (
	"res://game/content/events/random_events.json"
)
const DAYS_PER_YEAR: int = 90
const REQUIRED_SEASONAL_SPECS: Dictionary = {
	"grand_opening_week": {
		"start_day": 1,
		"duration_days": 7,
		"first_trigger_day": 1,
		"store_type_multipliers": {
			"sports": 1.3,
			"retro_games": 1.3,
			"rentals": 1.3,
			"pocket_creatures": 1.3,
			"electronics": 1.3,
		},
	},
	"sports_season_kickoff": {
		"start_day": 20,
		"duration_days": 16,
		"first_trigger_day": 20,
		"store_type_multipliers": {"sports": 1.5},
	},
	"collectors_convention_weekend": {
		"start_day": 45,
		"duration_days": 4,
		"first_trigger_day": 45,
		"store_type_multipliers": {
			"pocket_creatures": 1.8,
			"retro_games": 1.3,
		},
	},
	"back_to_school_rush": {
		"start_day": 55,
		"duration_days": 16,
		"first_trigger_day": 55,
		"store_type_multipliers": {
			"electronics": 1.4,
			"retro_games": 1.2,
		},
	},
	"holiday_shopping_season": {
		"start_day": 75,
		"duration_days": 16,
		"first_trigger_day": 75,
		"store_type_multipliers": {
			"sports": 1.6,
			"retro_games": 1.6,
			"rentals": 1.6,
			"pocket_creatures": 1.6,
			"electronics": 1.6,
		},
	},
	"post_holiday_slump": {
		"start_day": 1,
		"duration_days": 10,
		"first_trigger_day": 91,
		"store_type_multipliers": {
			"sports": 0.7,
			"retro_games": 0.7,
			"rentals": 0.7,
			"pocket_creatures": 0.7,
			"electronics": 0.7,
		},
	},
}

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
		"id", "display_name", "start_day", "duration_days",
		"store_type_multipliers", "description",
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
	var start_days: Array[int] = []
	for entry: Variant in _seasonal_data:
		var d: Dictionary = entry as Dictionary
		start_days.append(int(d.get("start_day", 0)))
	start_days.sort()
	var has_early: Array = [false]
	var has_mid: Array = [false]
	var has_late: Array = [false]
	for start_day: int in start_days:
		if start_day <= 30:
			has_early[0] = true
		elif start_day <= 60:
			has_mid[0] = true
		else:
			has_late[0] = true
	assert_true(has_early[0], "Need events in early cycle (1-30)")
	assert_true(has_mid[0], "Need events in mid cycle (31-60)")
	assert_true(has_late[0], "Need events in late cycle (61+)")


func test_seasonal_events_use_canonical_store_ids() -> void:
	var valid_store_ids: Array[String] = _load_store_ids()
	for entry: Variant in _seasonal_data:
		var d: Dictionary = entry as Dictionary
		var multipliers: Variant = d.get("store_type_multipliers", {})
		assert_true(
			multipliers is Dictionary,
			"Seasonal event '%s' multipliers must be a dictionary" % d.get("id", "UNKNOWN")
		)
		if multipliers is not Dictionary:
			continue
		for store_id: Variant in (multipliers as Dictionary).keys():
			assert_has(
				valid_store_ids,
				str(store_id),
				"Seasonal event '%s' uses unknown store id '%s'" % [d.get("id", "UNKNOWN"), store_id]
			)


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


func test_required_seasonal_event_specs() -> void:
	for event_id: String in REQUIRED_SEASONAL_SPECS.keys():
		var entry: Dictionary = _find_entry(_seasonal_data, event_id)
		assert_false(entry.is_empty(), "Missing required seasonal event: %s" % event_id)
		if entry.is_empty():
			continue
		var spec: Dictionary = REQUIRED_SEASONAL_SPECS[event_id] as Dictionary
		assert_eq(
			int(entry.get("start_day", 0)),
			int(spec.get("start_day", 0)),
			"Seasonal event '%s' start_day should match issue spec" % event_id
		)
		assert_eq(
			int(entry.get("duration_days", 0)),
			int(spec.get("duration_days", 0)),
			"Seasonal event '%s' duration_days should match issue spec" % event_id
		)
		assert_eq(
			_first_trigger_day(entry),
			int(spec.get("first_trigger_day", -1)),
			"Seasonal event '%s' should trigger on the intended calendar day" % event_id
		)
		var actual_multipliers: Dictionary = (
			entry.get("store_type_multipliers", {}) as Dictionary
		)
		var expected_multipliers: Dictionary = (
			spec.get("store_type_multipliers", {}) as Dictionary
		)
		assert_eq(
			actual_multipliers.size(),
			expected_multipliers.size(),
			"Seasonal event '%s' should target the expected stores" % event_id
		)
		for store_id: String in expected_multipliers.keys():
			assert_true(
				actual_multipliers.has(store_id),
				"Seasonal event '%s' missing multiplier for '%s'" % [event_id, store_id]
			)
			if not actual_multipliers.has(store_id):
				continue
			assert_almost_eq(
				float(actual_multipliers[store_id]),
				float(expected_multipliers[store_id]),
				0.001,
				"Seasonal event '%s' multiplier for '%s' should match issue spec"
				% [event_id, store_id]
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
		"id", "display_name", "trigger_probability", "duration_days",
		"effect_type", "effect_target", "effect_magnitude", "description",
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


func test_random_events_probability_bounds() -> void:
	for entry: Variant in _random_data:
		var d: Dictionary = entry as Dictionary
		var probability: float = float(d.get("trigger_probability", -1.0))
		assert_gte(
			probability, 0.0,
			"Event '%s' trigger_probability must be >= 0" % d.get("id")
		)
		assert_lte(
			probability, 1.0,
			"Event '%s' trigger_probability must be <= 1" % d.get("id")
		)


func test_random_events_use_canonical_store_ids() -> void:
	var valid_store_ids: Array[String] = _load_store_ids()
	for entry: Variant in _random_data:
		var d: Dictionary = entry as Dictionary
		assert_has(
			valid_store_ids,
			str(d.get("effect_target", "")),
			"Random event '%s' uses unknown effect_target '%s'" % [
				d.get("id", "UNKNOWN"),
				d.get("effect_target", "")
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
	var boundary_rx: RegEx = RegEx.new()
	for entry: Variant in _seasonal_data + _random_data:
		var d: Dictionary = entry as Dictionary
		var text: String = (
			str(d.get("display_name", d.get("name", "")))
			+ " " + str(d.get("description", ""))
			+ " " + str(d.get("notification_text", ""))
			+ " " + str(d.get("toast_message", ""))
		)
		for brand: String in banned:
			boundary_rx.compile("(?i)\\b" + brand + "\\b")
			assert_false(
				boundary_rx.search(text) != null,
				"Entry '%s' contains real brand '%s'" % [
					d.get("id"), brand
				]
			)


func _load_store_ids() -> Array[String]:
	var data: Array = _load_json(
		"res://game/content/stores/store_definitions.json"
	)
	var ids: Array[String] = []
	for entry: Variant in data:
		var d: Dictionary = entry as Dictionary
		ids.append(str(d.get("id", "")))
	return ids


func _find_entry(data: Array, entry_id: String) -> Dictionary:
	for entry: Variant in data:
		var d: Dictionary = entry as Dictionary
		if str(d.get("id", "")) == entry_id:
			return d
	return {}


func _first_trigger_day(entry: Dictionary) -> int:
	var frequency: int = int(entry.get("frequency_days", 30))
	var offset: int = int(entry.get("offset_days", 0))
	for day: int in range(1, (DAYS_PER_YEAR * 2) + 1):
		var adjusted: int = day - offset
		if adjusted > 0 and adjusted % frequency == 0:
			return day
	return -1
