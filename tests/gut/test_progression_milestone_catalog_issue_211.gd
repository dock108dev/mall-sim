## Integration tests for ISSUE-211 progression milestone catalog schema and invariants.
extends GutTest

const MILESTONE_PATH := "res://game/content/progression/milestone_definitions.json"
const UNLOCKS_PATH := "res://game/content/unlocks/unlocks.json"

const VALID_TRIGGER_TYPES := {
	"transaction_completed": true,
	"day_advanced": true,
	"revenue_total": true,
	"store_owned": true,
	"reputation_reached": true,
	"customer_satisfied": true,
	"haggle_completed": true,
	"item_price_set": true,
	"random_event_resolved": true,
	"clock_in_completed": true,
	"first_restock_completed": true,
	"manager_trust_reached": true,
}

const REQUIRED_REWARD_VALUES := {
	"first_sale": {"reward_type": "cash", "reward_value": 50.0},
	"survived_day_one": {"reward_type": "reputation", "reward_value": 5.0},
	"first_fifty_revenue": {"reward_type": "cash", "reward_value": 15.0},
	"ten_transactions": {"reward_type": "cash", "reward_value": 30.0},
	"first_lease": {"reward_type": "cash", "reward_value": 100.0},
	"first_reputation_bump": {"reward_type": "cash", "reward_value": 50.0},
	"happy_customers_ten": {"reward_type": "reputation", "reward_value": 3.0},
	"haggle_winner": {"reward_type": "cash", "reward_value": 75.0},
	"first_rare_sale": {"reward_type": "cash", "reward_value": 50.0},
	"revenue_five_hundred": {"reward_type": "cash", "reward_value": 75.0},
	"revenue_one_thousand": {"reward_type": "cash", "reward_value": 150.0},
	"fifty_transactions": {"reward_type": "cash", "reward_value": 60.0},
	"own_two_stores": {"reward_type": "cash", "reward_value": 200.0},
	"happy_customers_fifty": {"reward_type": "cash", "reward_value": 100.0},
	"single_day_three_hundred": {"reward_type": "cash", "reward_value": 100.0},
	"hundred_transactions": {"reward_type": "cash", "reward_value": 150.0},
	"own_three_stores": {"reward_type": "cash", "reward_value": 300.0},
	"pricing_sweet_spot": {"reward_type": "reputation", "reward_value": 10.0},
	"market_crash_survivor": {"reward_type": "cash", "reward_value": 200.0},
	"revenue_five_thousand": {"reward_type": "cash", "reward_value": 400.0},
	"own_four_stores": {"reward_type": "cash", "reward_value": 500.0},
	"happy_customers_two_hundred": {"reward_type": "cash", "reward_value": 250.0},
	"revenue_ten_thousand": {"reward_type": "cash", "reward_value": 600.0},
	"five_hundred_transactions": {"reward_type": "cash", "reward_value": 300.0},
	"own_all_five_stores": {"reward_type": "cash", "reward_value": 1000.0},
}

const REQUIRED_UNLOCK_REWARDS := {
	"week_one_survivor": "order_catalog_expansion_1",
	"reputation_tier_three": "extended_hours_unlock",
	"full_two_weeks": "market_event_preview",
	"reputation_tier_four": "vip_customer_events",
	"revenue_twenty_five_thousand": "prestige_nameplate",
	"cash_positive_thirty": "prestige_bronze_badge",
}


func test_issue_211_catalog_meets_count_and_tier_distribution() -> void:
	var milestones: Array[Dictionary] = _load_milestones()
	assert_gte(milestones.size(), 31, "Expected at least 31 milestones")

	var visible_count := 0
	var hidden_count := 0
	var visible_by_tier := {
		"early": 0,
		"mid": 0,
		"late": 0,
	}
	for milestone: Dictionary in milestones:
		var tier := str(milestone.get("tier", ""))
		if bool(milestone.get("is_visible", false)):
			visible_count += 1
			if visible_by_tier.has(tier):
				visible_by_tier[tier] += 1
		else:
			hidden_count += 1

	assert_gte(visible_count, 26, "Expected at least 26 visible milestones")
	assert_gte(hidden_count, 5, "Expected at least 5 hidden milestones")
	assert_gte(int(visible_by_tier["early"]), 8, "Expected at least 8 early visible milestones")
	assert_gte(int(visible_by_tier["mid"]), 10, "Expected at least 10 mid visible milestones")
	assert_gte(int(visible_by_tier["late"]), 8, "Expected at least 8 late visible milestones")


func test_issue_211_required_rewards_and_unlocks_match_spec() -> void:
	var milestones_by_id: Dictionary = _load_milestones_by_id()

	for milestone_id: String in REQUIRED_REWARD_VALUES.keys():
		assert_true(
			milestones_by_id.has(milestone_id),
			"Missing required milestone: %s" % milestone_id
		)
		if not milestones_by_id.has(milestone_id):
			continue
		var milestone: Dictionary = milestones_by_id[milestone_id] as Dictionary
		var spec: Dictionary = REQUIRED_REWARD_VALUES[milestone_id] as Dictionary
		assert_eq(
			str(milestone.get("reward_type", "")),
			str(spec.get("reward_type", "")),
			"Unexpected reward_type for %s" % milestone_id
		)
		assert_almost_eq(
			float(milestone.get("reward_value", -1.0)),
			float(spec.get("reward_value", -1.0)),
			0.01,
			"Unexpected reward_value for %s" % milestone_id
		)

	for milestone_id: String in REQUIRED_UNLOCK_REWARDS.keys():
		assert_true(
			milestones_by_id.has(milestone_id),
			"Missing unlock milestone: %s" % milestone_id
		)
		if not milestones_by_id.has(milestone_id):
			continue
		var milestone: Dictionary = milestones_by_id[milestone_id] as Dictionary
		assert_eq(
			str(milestone.get("reward_type", "")),
			"unlock",
			"Expected unlock reward type for %s" % milestone_id
		)
		assert_eq(
			str(milestone.get("unlock_id", "")),
			str(REQUIRED_UNLOCK_REWARDS[milestone_id]),
			"Unexpected unlock_id for %s" % milestone_id
		)


func test_issue_211_trigger_types_and_unlock_refs_are_valid() -> void:
	var milestones: Array[Dictionary] = _load_milestones()
	var valid_unlocks: Dictionary = _load_unlock_ids()

	for milestone: Dictionary in milestones:
		var milestone_id := str(milestone.get("id", ""))
		var trigger_type := str(milestone.get("trigger_type", ""))
		assert_true(
			VALID_TRIGGER_TYPES.has(trigger_type),
			"Invalid trigger_type '%s' for milestone %s" % [trigger_type, milestone_id]
		)

		if str(milestone.get("reward_type", "")) != "unlock":
			continue

		var unlock_id := str(milestone.get("unlock_id", ""))
		assert_ne(unlock_id, "", "unlock reward milestone must define unlock_id: %s" % milestone_id)
		assert_true(
			valid_unlocks.has(unlock_id),
			"unlock_id '%s' is not present in unlocks.json" % unlock_id
		)


func test_issue_211_data_loader_loads_progression_without_errors() -> void:
	ContentRegistry.clear_for_testing()
	var loader := DataLoader.new()
	add_child_autofree(loader)

	loader.load_all_content()

	assert_eq(
		loader.get_load_errors().size(),
		0,
		"DataLoader should load all content without parse/validation errors"
	)
	assert_true(
		ContentRegistry.is_valid_id(&"week_one_survivor", "milestone"),
		"Progression milestone ids should be registered into ContentRegistry"
	)


func _load_milestones() -> Array[Dictionary]:
	var data: Array = DataLoader.load_catalog_entries(MILESTONE_PATH)
	assert_false(data.is_empty(), "Milestone definitions JSON must load entries")
	var milestones: Array[Dictionary] = []
	for entry: Variant in data:
		if entry is Dictionary:
			milestones.append(entry)
	return milestones


func _load_milestones_by_id() -> Dictionary:
	var milestones_by_id: Dictionary = {}
	for milestone: Dictionary in _load_milestones():
		var milestone_id := str(milestone.get("id", ""))
		if milestone_id != "":
			milestones_by_id[milestone_id] = milestone
	return milestones_by_id


func _load_unlock_ids() -> Dictionary:
	var data: Array = DataLoader.load_catalog_entries(UNLOCKS_PATH)
	assert_false(data.is_empty(), "Unlock definitions JSON must load entries")
	var unlock_ids: Dictionary = {}
	for entry: Variant in data:
		if entry is Dictionary and entry.has("id"):
			unlock_ids[str(entry["id"])] = true
	return unlock_ids
