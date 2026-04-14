## Unit tests for ProgressionSystem — mall reputation tracking, cumulative cash, and slot unlock signals.
extends GutTest


var _prog: ProgressionSystem


func before_each() -> void:
	_prog = ProgressionSystem.new()
	add_child_autofree(_prog)
	_prog.initialize(null, null)


func test_initial_cumulative_cash_is_zero() -> void:
	assert_almost_eq(
		_prog.get_cumulative_cash_earned(), 0.0, 0.01,
		"Fresh ProgressionSystem should have zero cumulative cash"
	)


func test_initial_mall_reputation_is_zero() -> void:
	assert_almost_eq(
		_prog.get_mall_reputation(), 0.0, 0.01,
		"Fresh ProgressionSystem should have zero mall reputation"
	)


func test_item_sold_increments_cumulative_cash() -> void:
	_prog._on_item_sold("item_001", 150.0, "retro_games")
	assert_almost_eq(
		_prog.get_cumulative_cash_earned(), 150.0, 0.01,
		"cumulative_cash_earned should increase by sale price"
	)


func test_item_sold_accumulates_across_multiple_sales() -> void:
	_prog._on_item_sold("item_001", 100.0, "retro_games")
	_prog._on_item_sold("item_002", 75.0, "consumer_electronics")
	assert_almost_eq(
		_prog.get_cumulative_cash_earned(), 175.0, 0.01,
		"cumulative_cash_earned should sum all sale prices"
	)


func test_reputation_changed_updates_current_reputation() -> void:
	_prog._on_reputation_changed("retro_games", 40.0)
	assert_almost_eq(
		_prog._current_reputation, 40.0, 0.01,
		"_current_reputation should update to new value from reputation_changed"
	)


func test_reputation_changed_to_higher_value_updates_correctly() -> void:
	_prog._on_reputation_changed("sports_memorabilia", 25.0)
	_prog._on_reputation_changed("sports_memorabilia", 55.0)
	assert_almost_eq(
		_prog._current_reputation, 55.0, 0.01,
		"_current_reputation should reflect the latest reputation_changed value"
	)


func test_store_slot_unlocked_fires_when_threshold_crossed() -> void:
	watch_signals(EventBus)
	_prog._cumulative_cash_earned = 2000.0
	_prog._mall_reputation = 25.0
	_prog._check_store_unlock_thresholds()
	assert_signal_emitted(
		EventBus, "store_slot_unlocked",
		"store_slot_unlocked should fire when reputation and cash thresholds are met"
	)
	var params: Array = get_signal_parameters(EventBus, "store_slot_unlocked")
	assert_eq(params[0] as int, 1, "First unlockable slot index should be 1")


func test_store_slot_unlocked_fires_exactly_once_per_threshold() -> void:
	_prog._cumulative_cash_earned = 2000.0
	_prog._mall_reputation = 25.0
	_prog._check_store_unlock_thresholds()

	watch_signals(EventBus)
	_prog._cumulative_cash_earned = 3000.0
	_prog._check_store_unlock_thresholds()
	assert_signal_not_emitted(
		EventBus, "store_slot_unlocked",
		"store_slot_unlocked must not re-fire for an already-unlocked slot"
	)


func test_store_slot_not_unlocked_below_reputation_threshold() -> void:
	watch_signals(EventBus)
	_prog._cumulative_cash_earned = 2000.0
	_prog._mall_reputation = 24.9
	_prog._check_store_unlock_thresholds()
	assert_signal_not_emitted(
		EventBus, "store_slot_unlocked",
		"store_slot_unlocked must not fire when reputation is below threshold"
	)


func test_store_slot_not_unlocked_below_cash_threshold() -> void:
	watch_signals(EventBus)
	_prog._cumulative_cash_earned = 1999.9
	_prog._mall_reputation = 25.0
	_prog._check_store_unlock_thresholds()
	assert_signal_not_emitted(
		EventBus, "store_slot_unlocked",
		"store_slot_unlocked must not fire when cumulative cash is below threshold"
	)


func test_is_slot_unlocked_returns_true_after_unlock() -> void:
	_prog._cumulative_cash_earned = 2000.0
	_prog._mall_reputation = 25.0
	_prog._check_store_unlock_thresholds()
	assert_true(
		_prog.is_slot_unlocked(1),
		"is_slot_unlocked(1) should return true after threshold crossed"
	)


func test_slot_zero_always_unlocked() -> void:
	assert_true(
		_prog.is_slot_unlocked(0),
		"Slot 0 is always unlocked regardless of state"
	)


func test_get_save_data_contains_cumulative_cash() -> void:
	_prog._cumulative_cash_earned = 500.0
	var data: Dictionary = _prog.get_save_data()
	assert_true(
		data.has("cumulative_cash_earned"),
		"get_save_data() must include cumulative_cash_earned key"
	)
	assert_almost_eq(
		float(data["cumulative_cash_earned"]), 500.0, 0.01,
		"cumulative_cash_earned value should match internal state"
	)


func test_get_save_data_contains_mall_reputation() -> void:
	_prog._mall_reputation = 30.0
	var data: Dictionary = _prog.get_save_data()
	assert_true(
		data.has("mall_reputation"),
		"get_save_data() must include mall_reputation key"
	)
	assert_almost_eq(
		float(data["mall_reputation"]), 30.0, 0.01,
		"mall_reputation value should match internal state"
	)


func test_get_save_data_contains_unlocked_slot_indices() -> void:
	_prog._unlocked_slot_indices[1] = true
	var data: Dictionary = _prog.get_save_data()
	assert_true(
		data.has("unlocked_slot_indices"),
		"get_save_data() must include unlocked_slot_indices key"
	)
	var slots: Array = data["unlocked_slot_indices"] as Array
	assert_true(slots.has(1), "Saved slot indices should include slot 1")


func test_load_save_data_restores_cumulative_cash() -> void:
	_prog._cumulative_cash_earned = 4200.0
	var data: Dictionary = _prog.get_save_data()

	var fresh: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(fresh)
	fresh.load_save_data(data)

	assert_almost_eq(
		fresh.get_cumulative_cash_earned(), 4200.0, 0.01,
		"Restored cumulative_cash_earned should match saved value"
	)


func test_load_save_data_restores_mall_reputation() -> void:
	_prog._mall_reputation = 62.5
	var data: Dictionary = _prog.get_save_data()

	var fresh: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(fresh)
	fresh.load_save_data(data)

	assert_almost_eq(
		fresh.get_mall_reputation(), 62.5, 0.01,
		"Restored mall_reputation should match saved value"
	)


func test_load_save_data_restores_unlocked_slots() -> void:
	_prog._unlocked_slot_indices[1] = true
	_prog._unlocked_slot_indices[2] = true
	var data: Dictionary = _prog.get_save_data()

	var fresh: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(fresh)
	fresh.load_save_data(data)

	assert_true(
		fresh.is_slot_unlocked(1),
		"Slot 1 should remain unlocked after load"
	)
	assert_true(
		fresh.is_slot_unlocked(2),
		"Slot 2 should remain unlocked after load"
	)


func test_load_save_data_does_not_emit_store_slot_unlocked() -> void:
	_prog._unlocked_slot_indices[1] = true
	var data: Dictionary = _prog.get_save_data()

	var fresh: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(fresh)

	watch_signals(EventBus)
	fresh.load_save_data(data)
	assert_signal_not_emitted(
		EventBus, "store_slot_unlocked",
		"load_save_data must not re-emit store_slot_unlocked for previously unlocked slots"
	)


func test_load_save_data_does_not_unlock_unmet_thresholds() -> void:
	var data: Dictionary = _prog.get_save_data()

	var fresh: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(fresh)
	fresh.load_save_data(data)

	assert_false(
		fresh.is_slot_unlocked(1),
		"Slot 1 should remain locked after restoring a state that never crossed the threshold"
	)
