## Unit tests for StoreCustomizationSystem — daily reset, cycle behavior,
## unlock gating, spawn-weight + demand multipliers, and the manager-trust
## hint-match path.
##
## Tests target the project autoload (StoreCustomizationSystem) and reset
## state between cases so EventBus emissions are not double-handled.
class_name TestStoreCustomizationSystem
extends GutTest


var _sys: Node


func before_each() -> void:
	_sys = (
		Engine.get_main_loop().root.get_node("StoreCustomizationSystem")
	)
	_sys.reset_for_testing()
	# Reset granted unlocks so featured-display gating is the test's choice.
	UnlockSystemSingleton._granted = {}
	# Make sure employee_display_authority is a recognised unlock id even when
	# the registered content list hasn't loaded under unit-test isolation.
	UnlockSystemSingleton._valid_ids[&"employee_display_authority"] = true
	ManagerRelationshipManager.reset_for_testing()


# ── Initial state ────────────────────────────────────────────────────────────


func test_initial_state_is_null_category_and_null_poster() -> void:
	assert_eq(
		_sys.current_featured_category,
		_sys.FEATURED_CATEGORY_NONE,
		"featured category must default to none",
	)
	assert_eq(
		_sys.current_poster_id,
		_sys.POSTER_NONE,
		"poster must default to none",
	)


func test_no_selection_returns_unit_multipliers() -> void:
	assert_almost_eq(
		_sys.get_spawn_weight_bonus(&"hype_teen"), 1.0, 0.0001
	)
	assert_almost_eq(
		_sys.get_demand_multiplier(&"vecforce_hd"), 1.0, 0.0001
	)


# ── day_started reset ────────────────────────────────────────────────────────


func test_day_started_resets_category_and_poster() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	_sys.set_featured_category(&"new_console_hype")
	_sys.set_poster(&"new_releases")
	assert_eq(_sys.current_featured_category, &"new_console_hype")
	assert_eq(_sys.current_poster_id, &"new_releases")
	EventBus.day_started.emit(2)
	assert_eq(
		_sys.current_featured_category,
		_sys.FEATURED_CATEGORY_NONE,
		"day_started must reset featured category to none",
	)
	assert_eq(
		_sys.current_poster_id,
		_sys.POSTER_NONE,
		"day_started must reset poster to none",
	)


# ── Featured category cycling + unlock gating ────────────────────────────────


func test_featured_cycle_walks_six_categories() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	var seen: Array[StringName] = []
	for _i: int in range(_sys.FEATURED_CATEGORY_ORDER.size()):
		seen.append(_sys.cycle_featured_category())
	for category: StringName in _sys.FEATURED_CATEGORY_ORDER:
		assert_true(
			seen.has(category),
			"category %s must appear in the cycle" % category,
		)


func test_featured_cycle_no_op_without_unlock() -> void:
	# Unlock not granted — cycle must reject and leave state untouched.
	var result: StringName = _sys.cycle_featured_category()
	assert_eq(
		result,
		_sys.FEATURED_CATEGORY_NONE,
		"cycle must return none when unlock is missing",
	)
	assert_eq(
		_sys.current_featured_category,
		_sys.FEATURED_CATEGORY_NONE,
		"current featured category must stay none when gated",
	)


func test_can_set_featured_category_tracks_unlock() -> void:
	assert_false(
		_sys.can_set_featured_category(),
		"unlock missing — featured display is gated",
	)
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	assert_true(
		_sys.can_set_featured_category(),
		"unlock granted — featured display is open",
	)


# ── Poster cycling (no unlock) ───────────────────────────────────────────────


func test_poster_cycle_works_without_unlock() -> void:
	var seen: Array[StringName] = []
	for _i: int in range(_sys.POSTER_ORDER.size()):
		seen.append(_sys.cycle_poster())
	for poster: StringName in _sys.POSTER_ORDER:
		assert_true(
			seen.has(poster), "poster %s must appear in the cycle" % poster
		)


# ── Spawn-weight bonuses ─────────────────────────────────────────────────────


func test_new_console_hype_boosts_hype_teen_spawn_weight() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	_sys.set_featured_category(&"new_console_hype")
	assert_almost_eq(
		_sys.get_spawn_weight_bonus(&"hype_teen"), 1.25, 0.0001
	)


func test_old_gen_clearance_boosts_confused_parent_and_bargain_hunter() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	_sys.set_featured_category(&"old_gen_clearance")
	assert_almost_eq(
		_sys.get_spawn_weight_bonus(&"confused_parent"), 1.20, 0.0001
	)
	assert_almost_eq(
		_sys.get_spawn_weight_bonus(&"bargain_hunter"), 1.20, 0.0001
	)


func test_sports_games_boosts_sports_regular() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	_sys.set_featured_category(&"sports_games")
	assert_almost_eq(
		_sys.get_spawn_weight_bonus(&"sports_regular"), 1.25, 0.0001
	)


func test_unrelated_archetype_returns_unit_multiplier() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	_sys.set_featured_category(&"new_console_hype")
	assert_almost_eq(
		_sys.get_spawn_weight_bonus(&"sports_regular"), 1.0, 0.0001
	)


func test_poster_applies_subtle_2_percent_shift() -> void:
	_sys.set_poster(&"new_releases")
	assert_almost_eq(
		_sys.get_spawn_weight_bonus(&"hype_teen"), 1.02, 0.0001
	)


func test_poster_and_featured_compose_multiplicatively() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	_sys.set_featured_category(&"new_console_hype")
	_sys.set_poster(&"new_releases")
	# 1.25 * 1.02 = 1.275
	assert_almost_eq(
		_sys.get_spawn_weight_bonus(&"hype_teen"), 1.275, 0.0001
	)


# ── Demand multipliers ───────────────────────────────────────────────────────


func test_new_console_hype_lifts_vecforce_hd_demand() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	_sys.set_featured_category(&"new_console_hype")
	assert_almost_eq(
		_sys.get_demand_multiplier(&"vecforce_hd"), 1.10, 0.0001
	)


func test_demand_multiplier_unaffected_by_other_categories() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	_sys.set_featured_category(&"old_gen_clearance")
	assert_almost_eq(
		_sys.get_demand_multiplier(&"vecforce_hd"), 1.0, 0.0001
	)


# ── Manager trust hint match ─────────────────────────────────────────────────


func test_hint_match_applies_trust_delta() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	var before_trust: float = ManagerRelationshipManager.manager_trust
	_sys._set_morning_note_hint_for_testing(&"used_bundles")
	_sys.set_featured_category(&"used_bundles")
	var after_trust: float = ManagerRelationshipManager.manager_trust
	assert_almost_eq(
		after_trust - before_trust, _sys.TRUST_DELTA_HINT_MATCH, 0.0001
	)


func test_hint_match_fires_at_most_once_per_day() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	_sys._set_morning_note_hint_for_testing(&"used_bundles")
	_sys.set_featured_category(&"used_bundles")
	var first_trust: float = ManagerRelationshipManager.manager_trust
	# Cycle off and back to the matching category — must not double-apply.
	_sys.set_featured_category(&"sports_games")
	_sys.set_featured_category(&"used_bundles")
	var second_trust: float = ManagerRelationshipManager.manager_trust
	assert_almost_eq(second_trust, first_trust, 0.0001)


func test_hint_mismatch_applies_no_delta() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	var before_trust: float = ManagerRelationshipManager.manager_trust
	_sys._set_morning_note_hint_for_testing(&"used_bundles")
	_sys.set_featured_category(&"sports_games")
	var after_trust: float = ManagerRelationshipManager.manager_trust
	assert_almost_eq(after_trust, before_trust, 0.0001)


func test_manager_note_shown_parses_category_token() -> void:
	# Tier×category note ids follow {tier}_{category}_{variant}.
	EventBus.manager_note_shown.emit("cold_sales_a", "body", true)
	assert_eq(
		_sys.get_morning_note_hint(),
		_sys.FEATURED_CATEGORY_USED_BUNDLES,
		"sales note must map to the used bundles featured category",
	)
	EventBus.manager_note_shown.emit("warm_operational_b", "body", true)
	assert_eq(
		_sys.get_morning_note_hint(),
		_sys.FEATURED_CATEGORY_OLD_GEN_CLEARANCE,
		"operational note must map to old-gen clearance",
	)
	EventBus.manager_note_shown.emit("neutral_staff_a", "body", true)
	assert_eq(
		_sys.get_morning_note_hint(),
		_sys.FEATURED_CATEGORY_FAMILY_FRIENDLY,
		"staff note must map to family-friendly",
	)


func test_override_note_id_does_not_set_hint() -> void:
	EventBus.manager_note_shown.emit("note_override_day_1", "body", false)
	assert_eq(
		_sys.get_morning_note_hint(),
		StringName(""),
		"override note must not produce a hint — its category token is unparseable",
	)


# ── Featured category change signal ──────────────────────────────────────────


func test_featured_category_changed_emits_on_set() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	watch_signals(_sys)
	_sys.set_featured_category(&"new_console_hype")
	assert_signal_emitted_with_parameters(
		_sys,
		"featured_category_changed",
		[StringName("new_console_hype")],
	)


func test_poster_changed_emits_on_set() -> void:
	watch_signals(_sys)
	_sys.set_poster(&"sports_season")
	assert_signal_emitted_with_parameters(
		_sys, "poster_changed", [StringName("sports_season")]
	)


# ── Unknown id rejection ─────────────────────────────────────────────────────


func test_set_featured_unknown_category_is_rejected() -> void:
	UnlockSystemSingleton.grant_unlock(&"employee_display_authority")
	_sys.set_featured_category(&"not_a_real_category")
	assert_eq(
		_sys.current_featured_category,
		_sys.FEATURED_CATEGORY_NONE,
		"unknown category must leave state untouched",
	)


func test_set_poster_unknown_id_is_rejected() -> void:
	_sys.set_poster(&"not_a_real_poster")
	assert_eq(
		_sys.current_poster_id,
		_sys.POSTER_NONE,
		"unknown poster id must leave state untouched",
	)
