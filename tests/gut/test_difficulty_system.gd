## Tests DifficultySystem: tier selection, modifiers, flags, assisted mode.
extends GutTest


var _ds: Node


func before_each() -> void:
	_ds = Node.new()
	_ds.set_script(
		preload("res://game/autoload/difficulty_system.gd")
	)
	add_child_autofree(_ds)


func test_default_tier_is_normal() -> void:
	assert_eq(
		_ds.get_current_tier_id(), &"normal",
		"Default tier should be normal"
	)


func test_get_modifier_easy_starting_cash() -> void:
	_ds.set_tier(&"easy")
	assert_almost_eq(
		_ds.get_modifier(&"starting_cash_multiplier"), 1.50, 0.001,
		"Easy starting_cash_multiplier should be 1.50"
	)


func test_get_modifier_normal_starting_cash() -> void:
	_ds.set_tier(&"normal")
	assert_almost_eq(
		_ds.get_modifier(&"starting_cash_multiplier"), 1.0, 0.001,
		"Normal starting_cash_multiplier should be 1.0"
	)


func test_get_modifier_hard_starting_cash() -> void:
	_ds.set_tier(&"hard")
	assert_almost_eq(
		_ds.get_modifier(&"starting_cash_multiplier"), 0.70, 0.001,
		"Hard starting_cash_multiplier should be 0.70"
	)


func test_get_modifier_unknown_key_returns_default() -> void:
	var result: float = _ds.get_modifier(&"nonexistent_key")
	assert_almost_eq(
		result, 1.0, 0.001,
		"Unknown modifier key should return 1.0"
	)


func test_get_flag_easy_emergency_cash() -> void:
	_ds.set_tier(&"easy")
	assert_true(
		_ds.get_flag(&"emergency_cash_injection_enabled"),
		"Easy tier should have emergency cash enabled"
	)


func test_get_flag_hard_emergency_cash() -> void:
	_ds.set_tier(&"hard")
	assert_false(
		_ds.get_flag(&"emergency_cash_injection_enabled"),
		"Hard tier should have emergency cash disabled"
	)


func test_get_flag_unknown_key_returns_false() -> void:
	var result: bool = _ds.get_flag(&"nonexistent_flag")
	assert_false(result, "Unknown flag key should return false")


func test_set_tier_emits_signal() -> void:
	watch_signals(_ds)
	_ds.set_tier(&"hard")
	assert_signal_emitted_with_parameters(
		_ds, "difficulty_selected", [&"hard"]
	)


func test_get_tier_display_name() -> void:
	_ds.set_tier(&"easy")
	assert_eq(
		_ds.get_tier_display_name(), "Chill Mode",
		"Easy display name should be 'Chill Mode'"
	)


func test_is_assisted_false_on_fresh_game() -> void:
	assert_false(
		_ds.is_assisted(),
		"Fresh game should not be assisted"
	)


func test_set_tier_invalid_id_no_crash() -> void:
	_ds.set_tier(&"nonexistent")
	assert_eq(
		_ds.get_current_tier_id(), &"normal",
		"Invalid tier should not change current tier"
	)


# --- apply_difficulty_change ---

func test_apply_difficulty_change_updates_tier() -> void:
	_ds.set_tier(&"normal")
	_ds.apply_difficulty_change(&"hard")
	assert_eq(
		_ds.get_current_tier_id(), &"hard",
		"apply_difficulty_change should update current tier"
	)


func test_apply_difficulty_change_emits_difficulty_changed() -> void:
	_ds.set_tier(&"normal")
	watch_signals(EventBus)
	_ds.apply_difficulty_change(&"hard")
	assert_signal_emitted(
		EventBus, "difficulty_changed",
		"apply_difficulty_change should emit difficulty_changed"
	)


func test_apply_difficulty_change_emits_correct_indices() -> void:
	_ds.set_tier(&"normal")
	watch_signals(EventBus)
	_ds.apply_difficulty_change(&"hard")
	var params: Array = get_signal_parameters(
		EventBus, "difficulty_changed"
	)
	assert_eq(params[0], 1, "Old tier index should be 1 (normal)")
	assert_eq(params[1], 2, "New tier index should be 2 (hard)")


func test_apply_difficulty_change_same_tier_no_signal() -> void:
	_ds.set_tier(&"normal")
	watch_signals(EventBus)
	_ds.apply_difficulty_change(&"normal")
	assert_signal_not_emitted(
		EventBus, "difficulty_changed",
		"Same tier should not emit difficulty_changed"
	)


func test_apply_difficulty_change_invalid_tier_no_crash() -> void:
	_ds.set_tier(&"normal")
	_ds.apply_difficulty_change(&"nonexistent")
	assert_eq(
		_ds.get_current_tier_id(), &"normal",
		"Invalid tier should not change current tier"
	)


# --- is_downgrade ---

func test_is_downgrade_hard_to_normal() -> void:
	_ds.set_tier(&"hard")
	assert_true(
		_ds.is_downgrade(&"normal"),
		"Hard to Normal should be a downgrade"
	)


func test_is_downgrade_normal_to_hard() -> void:
	_ds.set_tier(&"normal")
	assert_false(
		_ds.is_downgrade(&"hard"),
		"Normal to Hard should not be a downgrade"
	)


func test_is_downgrade_hard_to_easy() -> void:
	_ds.set_tier(&"hard")
	assert_true(
		_ds.is_downgrade(&"easy"),
		"Hard to Easy should be a downgrade"
	)


# --- used_difficulty_downgrade ---

func test_used_difficulty_downgrade_false_on_fresh() -> void:
	assert_false(
		_ds.used_difficulty_downgrade,
		"Fresh instance should not have downgrade flag"
	)


# --- get_tier_ids ---

func test_get_tier_ids_returns_all_tiers() -> void:
	var ids: Array[StringName] = _ds.get_tier_ids()
	assert_eq(ids.size(), 3, "Should have 3 tiers")
	assert_eq(ids[0], &"easy", "First tier should be easy")
	assert_eq(ids[1], &"normal", "Second tier should be normal")
	assert_eq(ids[2], &"hard", "Third tier should be hard")


# --- get_display_name_for_tier ---

func test_get_display_name_for_tier_easy() -> void:
	assert_eq(
		_ds.get_display_name_for_tier(&"easy"), "Chill Mode",
		"Easy display name should be 'Chill Mode'"
	)


# --- save/load round-trip ---

func test_save_data_contains_current_tier() -> void:
	_ds.set_tier(&"hard")
	var data: Dictionary = _ds.get_save_data()
	assert_eq(
		data["current_tier"], "hard",
		"Save data should contain current tier"
	)


func test_save_data_contains_downgrade_flag() -> void:
	_ds.used_difficulty_downgrade = true
	var data: Dictionary = _ds.get_save_data()
	assert_true(
		data["used_difficulty_downgrade"],
		"Save data should contain downgrade flag"
	)


func test_load_save_data_restores_tier() -> void:
	_ds.set_tier(&"hard")
	var data: Dictionary = _ds.get_save_data()
	var fresh: Node = Node.new()
	fresh.set_script(
		preload("res://game/autoload/difficulty_system.gd")
	)
	add_child_autofree(fresh)
	fresh.load_save_data(data)
	assert_eq(
		fresh.get_current_tier_id(), &"hard",
		"Loaded tier should match saved tier"
	)


func test_load_save_data_restores_downgrade_flag() -> void:
	_ds.used_difficulty_downgrade = true
	var data: Dictionary = _ds.get_save_data()
	var fresh: Node = Node.new()
	fresh.set_script(
		preload("res://game/autoload/difficulty_system.gd")
	)
	add_child_autofree(fresh)
	fresh.load_save_data(data)
	assert_true(
		fresh.used_difficulty_downgrade,
		"Loaded downgrade flag should match saved"
	)


func test_load_save_data_empty_dict_no_crash() -> void:
	_ds.set_tier(&"hard")
	_ds.load_save_data({})
	assert_eq(
		_ds.get_current_tier_id(), &"hard",
		"Empty data should not change current tier"
	)
