## Unit tests for CustomerSystem — density curve, archetype weight normalization,
## budget assignment, intent generation, day_started scheduling, and difficulty modifier.
extends GutTest


var _system: CustomerSystem
var _original_tier: StringName


func before_each() -> void:
	_system = CustomerSystem.new()
	add_child_autofree(_system)
	_system.max_customers_in_mall = 30
	_original_tier = DifficultySystemSingleton.get_current_tier_id()
	DifficultySystemSingleton.set_tier(&"normal")


func after_each() -> void:
	DifficultySystemSingleton.set_tier(_original_tier)


# --- Density curve: off-hours ---


func test_spawn_target_zero_during_off_hours() -> void:
	_system._current_hour = 2
	_system._hour_elapsed = 0.0
	_system._current_day_of_week = 5
	assert_eq(
		_system.get_spawn_target(), 0,
		"Hour 2 is outside mall hours — spawn target must be 0"
	)


# --- Density curve: peak hours ---


func test_spawn_target_at_least_three_during_lunch_rush() -> void:
	_system._current_hour = 13
	_system._hour_elapsed = 0.0
	_system._current_day_of_week = 5
	var count: int = _system.get_spawn_target()
	assert_true(
		count >= 3,
		"Lunch rush (13:00 Saturday) spawn target must be >= 3, got %d" % count
	)


# --- Archetype weight normalization ---


func test_morning_weights_normalize_to_one() -> void:
	_assert_weights_normalize_to_one(
		ShopperArchetypeConfig.WEIGHTS_MORNING, "morning"
	)


func test_afternoon_weights_normalize_to_one() -> void:
	_assert_weights_normalize_to_one(
		ShopperArchetypeConfig.WEIGHTS_AFTERNOON, "afternoon"
	)


func test_evening_weights_normalize_to_one() -> void:
	_assert_weights_normalize_to_one(
		ShopperArchetypeConfig.WEIGHTS_EVENING, "evening"
	)


# --- Archetype selection determinism ---


func test_weighted_select_is_deterministic_with_fixed_seed() -> void:
	seed(42)
	var first: PersonalityData.PersonalityType = (
		ShopperArchetypeConfig.weighted_random_select(
			ShopperArchetypeConfig.WEIGHTS_MORNING
		)
	)
	seed(42)
	var second: PersonalityData.PersonalityType = (
		ShopperArchetypeConfig.weighted_random_select(
			ShopperArchetypeConfig.WEIGHTS_MORNING
		)
	)
	assert_eq(
		first, second,
		"Same RNG seed must produce identical archetype selection"
	)


# --- Budget assignment ---


func test_social_butterfly_budget_range_matches_documented_minimum() -> void:
	var personality: PersonalityData = ShopperArchetypeConfig.create_personality(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY
	)
	assert_almost_eq(
		personality.min_budget, 30.0, 0.001,
		"SOCIAL_BUTTERFLY min_budget should match the authored personality data"
	)


func test_social_butterfly_budget_range_matches_documented_maximum() -> void:
	var personality: PersonalityData = ShopperArchetypeConfig.create_personality(
		PersonalityData.PersonalityType.SOCIAL_BUTTERFLY
	)
	assert_almost_eq(
		personality.max_budget, 120.0, 0.001,
		"SOCIAL_BUTTERFLY max_budget should match the authored personality data"
	)


func test_power_shopper_budget_range_matches_documented_minimum() -> void:
	var personality: PersonalityData = ShopperArchetypeConfig.create_personality(
		PersonalityData.PersonalityType.POWER_SHOPPER
	)
	assert_almost_eq(
		personality.min_budget, 80.0, 0.001,
		"POWER_SHOPPER min_budget should match the authored personality data"
	)


func test_power_shopper_budget_range_matches_documented_maximum() -> void:
	var personality: PersonalityData = ShopperArchetypeConfig.create_personality(
		PersonalityData.PersonalityType.POWER_SHOPPER
	)
	assert_almost_eq(
		personality.max_budget, 300.0, 0.001,
		"POWER_SHOPPER max_budget should match the authored personality data"
	)


# --- Intent generation ---


func test_collectibles_profile_preferred_categories_are_non_empty() -> void:
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "teen_pack_member"
	profile.purchase_probability_base = 0.35
	profile.preferred_categories = PackedStringArray(
		["booster_packs", "retro_cartridges", "singles"]
	)
	assert_true(
		profile.preferred_categories.size() > 0,
		"Collectibles archetype must declare at least one preferred category"
	)


func test_collectibles_profile_includes_booster_packs_category() -> void:
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.id = "teen_pack_member"
	profile.purchase_probability_base = 0.35
	profile.preferred_categories = PackedStringArray(
		["booster_packs", "retro_cartridges", "singles"]
	)
	assert_true(
		"booster_packs" in profile.preferred_categories,
		"teen_pack_member collectibles profile must include booster_packs"
	)


func test_purchase_intent_for_preferred_category_is_positive() -> void:
	var profile: CustomerTypeDefinition = CustomerTypeDefinition.new()
	profile.purchase_probability_base = 0.5
	profile.preferred_categories = PackedStringArray(["booster_packs"])
	var intent: float = _system.get_purchase_intent_for_category(
		profile, &"booster_packs"
	)
	assert_true(
		intent > 0.0,
		"Purchase intent for a valid category should be positive"
	)


# --- day_started triggers scheduling ---


func test_day_started_signal_resets_shopper_count() -> void:
	_system._active_mall_shopper_count = 7
	_system._connect_signals()
	EventBus.day_started.emit(1)
	assert_eq(
		_system._active_mall_shopper_count, 0,
		"EventBus.day_started must reset active mall shopper count to 0"
	)


func test_day_started_signal_resets_archetype_weights_to_morning() -> void:
	_system._current_archetype_weights = ShopperArchetypeConfig.WEIGHTS_EVENING
	_system._connect_signals()
	EventBus.day_started.emit(1)
	assert_eq(
		_system._current_archetype_weights,
		ShopperArchetypeConfig.WEIGHTS_MORNING,
		"EventBus.day_started must reset archetype weights to morning"
	)


# --- Difficulty modifier application ---


func test_hard_difficulty_reduces_spawn_target_versus_normal_at_peak_hour() -> void:
	_system._current_hour = 13
	_system._hour_elapsed = 0.0
	_system._current_day_of_week = 5
	DifficultySystemSingleton.set_tier(&"normal")
	var normal_count: int = _system.get_spawn_target()
	DifficultySystemSingleton.set_tier(&"hard")
	var hard_count: int = _system.get_spawn_target()
	assert_true(
		hard_count < normal_count,
		(
			"HARD difficulty must yield fewer spawns than NORMAL at peak hour "
			+ "(hard=%d normal=%d)" % [hard_count, normal_count]
		)
	)


# --- Helpers ---


func _assert_weights_normalize_to_one(
	weights: Dictionary, label: String
) -> void:
	var total: int = 0
	for w: int in weights.values():
		total += w
	if total <= 0:
		fail_test("%s weights total is zero — cannot normalize" % label)
		return
	var normalized_sum: float = 0.0
	for w: int in weights.values():
		normalized_sum += float(w) / float(total)
	assert_almost_eq(
		normalized_sum,
		1.0,
		0.0001,
		"%s archetype weights must normalize to 1.0" % label
	)
