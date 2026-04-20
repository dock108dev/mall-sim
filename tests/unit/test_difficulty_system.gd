## Unit tests for DifficultySystem — modifier lookup, tier persistence, assisted flag, and default tier.
extends GutTest


var _ds: Node
var _saved_settings_path: String = ""
var _temp_settings_path: String = ""


func before_each() -> void:
	DataLoaderSingleton.load_all_content()
	_saved_settings_path = Settings.settings_path
	_temp_settings_path = "user://test_difficulty_system_%d.cfg" % Time.get_ticks_usec()
	Settings.settings_path = _temp_settings_path
	_ds = Node.new()
	_ds.set_script(preload("res://game/autoload/difficulty_system.gd"))
	add_child_autofree(_ds)


func after_each() -> void:
	Settings.settings_path = _saved_settings_path
	if FileAccess.file_exists(_temp_settings_path):
		DirAccess.remove_absolute(_temp_settings_path)


# --- Default tier ---

func test_default_tier_is_normal_before_set_tier() -> void:
	assert_eq(
		_ds.get_current_tier_id(), &"normal",
		"Default tier should be normal before any set_tier call"
	)


# --- set_tier persistence ---

func test_set_tier_hard_changes_current_tier_id() -> void:
	_ds.set_tier(&"hard")
	assert_eq(
		_ds.get_current_tier_id(), &"hard",
		"set_tier(hard) should change current tier to hard"
	)


func test_set_tier_does_not_overwrite_corrupt_settings_file() -> void:
	var corrupt_contents: String = "[display\nfullscreen=true"
	var file: FileAccess = FileAccess.open(
		_temp_settings_path, FileAccess.WRITE
	)
	assert_not_null(file, "Precondition: temp settings file should be writable")
	file.store_string(corrupt_contents)
	file.close()

	_ds.set_tier(&"hard")

	var verify_file: FileAccess = FileAccess.open(
		_temp_settings_path, FileAccess.READ
	)
	assert_not_null(
		verify_file,
		"Corrupt settings file should remain readable after persistence failure"
	)
	var persisted_contents: String = verify_file.get_as_text()
	verify_file.close()
	assert_eq(
		persisted_contents,
		corrupt_contents,
		"Difficulty persistence should not overwrite a corrupt settings file"
	)


# --- Signal emission ---

func test_set_tier_emits_difficulty_selected_with_tier_id() -> void:
	watch_signals(_ds)
	_ds.set_tier(&"hard")
	assert_signal_emitted_with_parameters(_ds, "difficulty_selected", [&"hard"])


# --- Modifier lookup: all 18 keys, all three tiers ---

func test_get_modifier_easy_all_keys() -> void:
	_ds.set_tier(&"easy")
	var expected: Dictionary = {
		&"starting_cash_multiplier": 1.50,
		&"daily_rent_multiplier": 0.70,
		&"wholesale_cost_multiplier": 0.85,
		&"foot_traffic_multiplier": 1.30,
		&"purchase_probability_multiplier": 1.25,
		&"customer_budget_multiplier": 1.20,
		&"haggle_success_rate_multiplier": 1.30,
		&"haggle_acceptance_base_rate": 0.60,
		&"haggle_concession_ceiling": 0.20,
		&"market_floor_multiplier": 1.10,
		&"rarity_scale_multiplier": 0.90,
		&"trend_duration_multiplier": 1.40,
		&"staff_wage_multiplier": 0.85,
		&"morale_decay_multiplier": 0.70,
		&"staff_quit_threshold": 0.15,
		&"supplier_lead_time_multiplier": 0.80,
		&"daily_order_limit_multiplier": 1.25,
		&"stockout_probability_multiplier": 0.60,
	}
	for key: StringName in expected:
		assert_almost_eq(
			_ds.get_modifier(key),
			expected[key] as float,
			0.001,
			"Easy %s should be %.2f" % [key, expected[key]]
		)


func test_get_modifier_normal_all_keys() -> void:
	_ds.set_tier(&"normal")
	var expected: Dictionary = {
		&"starting_cash_multiplier": 1.00,
		&"daily_rent_multiplier": 1.00,
		&"wholesale_cost_multiplier": 1.00,
		&"foot_traffic_multiplier": 1.00,
		&"purchase_probability_multiplier": 1.00,
		&"customer_budget_multiplier": 1.00,
		&"haggle_success_rate_multiplier": 1.00,
		&"haggle_acceptance_base_rate": 0.45,
		&"haggle_concession_ceiling": 0.15,
		&"market_floor_multiplier": 1.00,
		&"rarity_scale_multiplier": 1.00,
		&"trend_duration_multiplier": 1.00,
		&"staff_wage_multiplier": 1.00,
		&"morale_decay_multiplier": 1.00,
		&"staff_quit_threshold": 0.25,
		&"supplier_lead_time_multiplier": 1.00,
		&"daily_order_limit_multiplier": 1.00,
		&"stockout_probability_multiplier": 1.00,
	}
	for key: StringName in expected:
		assert_almost_eq(
			_ds.get_modifier(key),
			expected[key] as float,
			0.001,
			"Normal %s should be %.2f" % [key, expected[key]]
		)


func test_get_modifier_hard_all_keys() -> void:
	_ds.set_tier(&"hard")
	var expected: Dictionary = {
		&"starting_cash_multiplier": 0.70,
		&"daily_rent_multiplier": 1.35,
		&"wholesale_cost_multiplier": 1.15,
		&"foot_traffic_multiplier": 0.75,
		&"purchase_probability_multiplier": 0.70,
		&"customer_budget_multiplier": 0.80,
		&"haggle_success_rate_multiplier": 0.65,
		&"haggle_acceptance_base_rate": 0.30,
		&"haggle_concession_ceiling": 0.08,
		&"market_floor_multiplier": 0.85,
		&"rarity_scale_multiplier": 1.20,
		&"trend_duration_multiplier": 0.70,
		&"staff_wage_multiplier": 1.20,
		&"morale_decay_multiplier": 1.40,
		&"staff_quit_threshold": 0.35,
		&"supplier_lead_time_multiplier": 1.30,
		&"daily_order_limit_multiplier": 0.75,
		&"stockout_probability_multiplier": 1.50,
	}
	for key: StringName in expected:
		assert_almost_eq(
			_ds.get_modifier(key),
			expected[key] as float,
			0.001,
			"Hard %s should be %.2f" % [key, expected[key]]
		)


func test_get_modifier_unknown_key_returns_one_point_zero() -> void:
	# Implementation calls push_error for unknown keys; observable outcome is 1.0.
	var result: float = _ds.get_modifier(&"nonexistent_modifier_key")
	assert_almost_eq(result, 1.0, 0.001, "Unknown modifier key should return 1.0")


# --- Flag lookup ---

func test_get_flag_easy_emergency_cash_injection_enabled_true() -> void:
	_ds.set_tier(&"easy")
	assert_true(
		_ds.get_flag(&"emergency_cash_injection_enabled"),
		"Easy tier emergency_cash_injection_enabled should be true"
	)


func test_get_flag_hard_emergency_cash_injection_enabled_false() -> void:
	_ds.set_tier(&"hard")
	assert_false(
		_ds.get_flag(&"emergency_cash_injection_enabled"),
		"Hard tier emergency_cash_injection_enabled should be false"
	)


func test_get_flag_unknown_key_returns_false() -> void:
	# Implementation calls push_error for unknown keys; observable outcome is false.
	var result: bool = _ds.get_flag(&"nonexistent_flag_key")
	assert_false(result, "Unknown flag key should return false")


# --- Assisted mode ---

func test_is_assisted_false_on_fresh_instance() -> void:
	assert_false(_ds.is_assisted(), "Fresh instance should not be in assisted mode")


func test_is_assisted_true_after_downgrade_to_easier_tier_on_day_greater_than_one() -> void:
	var original_day: int = GameManager.current_day
	_ds.set_tier(&"hard")
	GameManager.current_day = 2
	_ds.set_tier(&"easy")
	assert_true(
		_ds.is_assisted(),
		"Switching to an easier tier after day 1 should activate assisted mode"
	)
	GameManager.current_day = original_day


# --- Display names ---

func test_get_tier_display_name_easy() -> void:
	_ds.set_tier(&"easy")
	assert_eq(
		_ds.get_tier_display_name(), "Chill Mode",
		"Easy tier display name should be 'Chill Mode'"
	)


func test_get_tier_display_name_normal() -> void:
	_ds.set_tier(&"normal")
	assert_eq(
		_ds.get_tier_display_name(), "Mall Life",
		"Normal tier display name should be 'Mall Life'"
	)


func test_get_tier_display_name_hard() -> void:
	_ds.set_tier(&"hard")
	assert_eq(
		_ds.get_tier_display_name(), "Going Out of Business",
		"Hard tier display name should be 'Going Out of Business'"
	)
