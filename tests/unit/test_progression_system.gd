## Unit tests for ProgressionSystem mall-wide cash, reputation, and slot unlock state.
extends GutTest


var _progression: ProgressionSystem


func before_each() -> void:
	_progression = ProgressionSystem.new()
	add_child_autofree(_progression)
	_progression.initialize(null, null)


func test_initial_cash_and_reputation_start_at_zero() -> void:
	assert_almost_eq(
		_progression.get_cumulative_cash_earned(), 0.0, 0.01,
		"Fresh ProgressionSystem should start with zero cumulative cash"
	)
	assert_almost_eq(
		_progression.get_mall_reputation(), 0.0, 0.01,
		"Fresh ProgressionSystem should start with zero mall reputation"
	)


func test_transaction_completed_accumulates_successful_sales() -> void:
	EventBus.transaction_completed.emit(150.0, true, "card sale")
	EventBus.transaction_completed.emit(75.0, true, "poster sale")
	EventBus.transaction_completed.emit(80.0, false, "failed sale")
	EventBus.transaction_completed.emit(200.0, true, "restock")

	assert_almost_eq(
		_progression.get_cumulative_cash_earned(), 225.0, 0.01,
		"Only successful sale transactions should increase cumulative cash"
	)


func test_reputation_changed_updates_mall_reputation_to_latest_tier_score() -> void:
	EventBus.reputation_changed.emit("retro_games", 0.0, 25.0)
	assert_almost_eq(
		_progression.get_mall_reputation(), 25.0, 0.01,
		"Mall reputation should reflect the emitted threshold score"
	)

	EventBus.reputation_changed.emit("retro_games", 0.0, 55.0)
	assert_almost_eq(
		_progression.get_mall_reputation(), 55.0, 0.01,
		"Mall reputation should update when a higher reputation tier is reached"
	)


func test_store_slot_unlocked_fires_when_cash_crosses_threshold() -> void:
	EventBus.reputation_changed.emit("retro_games", 0.0, 25.0)
	watch_signals(EventBus)

	EventBus.transaction_completed.emit(2000.0, true, "grand sale")

	assert_signal_emitted(
		EventBus, "store_slot_unlocked",
		"Crossing the first configured threshold should unlock slot 1"
	)
	var params: Array = get_signal_parameters(EventBus, "store_slot_unlocked")
	assert_eq(params[0] as int, 1, "First unlocked slot index should be 1")


func test_store_slot_unlocked_fires_only_once_per_threshold() -> void:
	EventBus.reputation_changed.emit("retro_games", 0.0, 25.0)
	EventBus.transaction_completed.emit(2000.0, true, "grand sale")

	watch_signals(EventBus)
	EventBus.transaction_completed.emit(250.0, true, "extra sale")

	assert_signal_not_emitted(
		EventBus, "store_slot_unlocked",
		"Additional sales above an unlocked threshold must not re-emit"
	)


func test_serialize_returns_cash_reputation_and_unlocked_slots() -> void:
	EventBus.reputation_changed.emit("retro_games", 0.0, 25.0)
	EventBus.transaction_completed.emit(2000.0, true, "grand sale")

	var data: Dictionary = _progression.serialize()

	assert_true(
		data.has("cumulative_cash"),
		"serialize() should include cumulative_cash"
	)
	assert_true(
		data.has("mall_reputation"),
		"serialize() should include mall_reputation"
	)
	assert_true(
		data.has("unlocked_slots"),
		"serialize() should include unlocked_slots"
	)
	assert_almost_eq(
		float(data["cumulative_cash"]), 2000.0, 0.01,
		"serialize() should persist cumulative cash"
	)
	assert_almost_eq(
		float(data["mall_reputation"]), 25.0, 0.01,
		"serialize() should persist mall reputation"
	)
	var unlocked_slots: Array = data["unlocked_slots"] as Array
	assert_true(
		unlocked_slots.has(1),
		"serialize() should persist unlocked slot indices"
	)


func test_deserialize_restores_state_without_reemitting_unlocks() -> void:
	var saved_state: Dictionary = {
		"cumulative_cash": 2000.0,
		"mall_reputation": 25.0,
		"unlocked_slots": [1],
	}
	var restored: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(restored)
	restored.initialize(null, null)

	watch_signals(EventBus)
	restored.deserialize(saved_state)
	assert_signal_not_emitted(
		EventBus, "store_slot_unlocked",
		"deserialize() must not replay prior slot unlock signals"
	)

	assert_almost_eq(
		restored.get_cumulative_cash_earned(), 2000.0, 0.01,
		"deserialize() should restore cumulative cash"
	)
	assert_almost_eq(
		restored.get_mall_reputation(), 25.0, 0.01,
		"deserialize() should restore mall reputation"
	)
	assert_true(
		restored.is_slot_unlocked(1),
		"Restored state should mark saved slots as unlocked"
	)
	assert_false(
		restored.is_slot_unlocked(2),
		"deserialize() should not unlock unsaved slots"
	)

	EventBus.transaction_completed.emit(100.0, true, "extra sale")
	assert_signal_not_emitted(
		EventBus, "store_slot_unlocked",
		"Already-unlocked thresholds must stay silent after restore"
	)
