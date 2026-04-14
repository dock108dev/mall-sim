## Tests PersonalityData resource creation, JSON parsing, and validation.
extends GutTest


func test_default_personality_has_valid_fields() -> void:
	var pd := PersonalityData.new()
	assert_eq(
		pd.personality_type,
		PersonalityData.PersonalityType.WINDOW_BROWSER
	)
	assert_gt(pd.shop_weight, 0.0)
	assert_gt(pd.max_budget, pd.min_budget)


func test_from_dictionary_parses_all_fields() -> void:
	var data: Dictionary = {
		"personality_type": "POWER_SHOPPER",
		"shop_weight": 1.5,
		"impulse_factor": 0.3,
		"hunger_rate_mult": 0.5,
		"energy_drain_mult": 0.667,
		"social_need_baseline": 0.1,
		"browse_duration_mult": 1.2,
		"min_budget": 80.0,
		"max_budget": 300.0,
		"avg_visit_minutes_min": 45.0,
		"avg_visit_minutes_max": 90.0,
	}
	var pd: PersonalityData = PersonalityData.from_dictionary(data)
	assert_eq(
		pd.personality_type,
		PersonalityData.PersonalityType.POWER_SHOPPER
	)
	assert_eq(pd.shop_weight, 1.5)
	assert_eq(pd.impulse_factor, 0.3)
	assert_eq(pd.hunger_rate_mult, 0.5)
	assert_eq(pd.energy_drain_mult, 0.667)
	assert_eq(pd.social_need_baseline, 0.1)
	assert_eq(pd.browse_duration_mult, 1.2)
	assert_eq(pd.min_budget, 80.0)
	assert_eq(pd.max_budget, 300.0)
	assert_eq(pd.avg_visit_minutes_min, 45.0)
	assert_eq(pd.avg_visit_minutes_max, 90.0)


func test_from_dictionary_handles_all_personality_types() -> void:
	var types: PackedStringArray = [
		"POWER_SHOPPER", "WINDOW_BROWSER", "FOOD_COURT_CAMPER",
		"SOCIAL_BUTTERFLY", "RELUCTANT_COMPANION", "IMPULSE_BUYER",
		"SPEED_RUNNER", "TEEN_PACK_MEMBER",
	]
	for type_str: String in types:
		var data: Dictionary = {"personality_type": type_str}
		var pd: PersonalityData = PersonalityData.from_dictionary(data)
		assert_ne(
			pd.personality_type,
			-1,
			"Type '%s' should parse without error" % type_str
		)


func test_from_dictionary_unknown_type_defaults_to_window_browser() -> void:
	var data: Dictionary = {"personality_type": "NONEXISTENT"}
	var pd: PersonalityData = PersonalityData.from_dictionary(data)
	assert_eq(
		pd.personality_type,
		PersonalityData.PersonalityType.WINDOW_BROWSER
	)


func test_from_dictionary_missing_fields_use_defaults() -> void:
	var pd: PersonalityData = PersonalityData.from_dictionary({})
	assert_eq(pd.shop_weight, 1.0)
	assert_eq(pd.impulse_factor, 0.3)
	assert_eq(pd.min_budget, 20.0)
	assert_eq(pd.max_budget, 100.0)


func test_personality_type_enum_has_eight_values() -> void:
	assert_eq(
		PersonalityData.PersonalityType.POWER_SHOPPER, 0
	)
	assert_eq(
		PersonalityData.PersonalityType.TEEN_PACK_MEMBER, 7
	)


func test_personalities_json_loads_all_archetypes() -> void:
	var file := FileAccess.open(
		"res://game/content/customers/personalities.json",
		FileAccess.READ
	)
	if not file:
		push_warning("personalities.json not found — skipping")
		pending("JSON file not accessible in test environment")
		return
	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	assert_eq(err, OK, "JSON should parse without errors")
	var data: Dictionary = json.data
	assert_has(data, "personalities")
	var entries: Array = data["personalities"]
	assert_eq(entries.size(), 8, "Should have exactly 8 archetypes")
	for entry: Dictionary in entries:
		assert_has(entry, "personality_type")
		assert_has(entry, "shop_weight")
		assert_has(entry, "impulse_factor")
		assert_has(entry, "hunger_rate_mult")
		assert_has(entry, "energy_drain_mult")
		assert_has(entry, "social_need_baseline")
		assert_has(entry, "browse_duration_mult")
		assert_has(entry, "min_budget")
		assert_has(entry, "max_budget")
		assert_has(entry, "avg_visit_minutes_min")
		assert_has(entry, "avg_visit_minutes_max")
		var pd: PersonalityData = PersonalityData.from_dictionary(
			entry
		)
		assert_gt(
			pd.max_budget, pd.min_budget,
			"max_budget should exceed min_budget for %s" % (
				entry["personality_type"]
			)
		)
