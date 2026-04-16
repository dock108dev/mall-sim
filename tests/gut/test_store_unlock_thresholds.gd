## Tests for store unlock threshold tracking and slot eligibility.
extends GutTest


var _progression: ProgressionSystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _saved_current_store_id: StringName = &""
var _saved_day_started_connections: Array[Callable] = []
var _saved_day_ended_connections: Array[Callable] = []


func before_each() -> void:
	_saved_current_store_id = GameManager.current_store_id
	GameManager.current_store_id = &"test_store"
	_saved_day_started_connections = _disconnect_signal(EventBus.day_started)
	_saved_day_ended_connections = _disconnect_signal(EventBus.day_ended)
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)

	_progression = ProgressionSystem.new()
	add_child_autofree(_progression)
	_progression.initialize(_economy, _reputation)


func after_each() -> void:
	if _progression != null:
		_progression.free()
		_progression = null
	if _reputation != null:
		_reputation.free()
		_reputation = null
	if _economy != null:
		_economy.free()
		_economy = null
	_restore_signal(EventBus.day_started, _saved_day_started_connections)
	_restore_signal(EventBus.day_ended, _saved_day_ended_connections)
	GameManager.current_store_id = _saved_current_store_id


func _disconnect_signal(signal_ref: Signal) -> Array[Callable]:
	var callables: Array[Callable] = []
	for connection: Dictionary in signal_ref.get_connections():
		var callable: Callable = connection.get("callable", Callable()) as Callable
		if callable.is_valid():
			callables.append(callable)
			signal_ref.disconnect(callable)
	return callables


func _restore_signal(signal_ref: Signal, callables: Array[Callable]) -> void:
	for callable: Callable in callables:
		if callable.is_valid() and not signal_ref.is_connected(callable):
			signal_ref.connect(callable)


# --- Cumulative cash tracking ---


func test_cumulative_cash_increments_on_sale() -> void:
	EventBus.item_sold.emit("item_a", 100.0, "sports")
	EventBus.item_sold.emit("item_b", 200.0, "sports")

	assert_almost_eq(
		_progression.get_cumulative_cash_earned(), 300.0, 0.01,
		"Cumulative cash should sum all sale prices"
	)


func test_cumulative_cash_never_decreases() -> void:
	EventBus.item_sold.emit("item_a", 500.0, "sports")
	var after_sale: float = _progression.get_cumulative_cash_earned()

	_economy.deduct_cash(200.0, "Test expense")

	assert_almost_eq(
		_progression.get_cumulative_cash_earned(), after_sale, 0.01,
		"Cumulative cash should not decrease on expenses"
	)


# --- Mall reputation tracking ---


func test_mall_reputation_updates_on_day_ended() -> void:
	_set_owned_store_scores({
		"sports": 20.0,
		"retro_games": 40.0,
	})
	EventBus.day_ended.emit(1)

	assert_almost_eq(
		_progression.get_mall_reputation(), 30.0, 0.01,
		"Mall reputation should average owned store reputation scores"
	)


# --- Slot unlock thresholds ---


func test_slot_0_always_unlocked() -> void:
	assert_true(
		_progression.is_slot_unlocked(0),
		"Slot 0 should always be unlocked"
	)


func test_slot_1_locked_initially() -> void:
	assert_false(
		_progression.is_slot_unlocked(1),
		"Slot 1 should be locked at start"
	)


func test_slot_1_unlocks_at_threshold() -> void:
	var unlocked_slots: Array[int] = []
	var on_unlock: Callable = func(slot_index: int) -> void:
		unlocked_slots.append(slot_index)
	EventBus.store_slot_unlocked.connect(on_unlock)

	_progression._cumulative_cash_earned = 2000.0
	_set_owned_store_scores({"test_store": 25.0})
	EventBus.day_ended.emit(1)

	assert_true(
		_progression.is_slot_unlocked(1),
		"Slot 1 should unlock at rep>=25 and cash>=2000"
	)
	assert_true(
		unlocked_slots.has(1),
		"store_slot_unlocked should emit for slot 1"
	)

	EventBus.store_slot_unlocked.disconnect(on_unlock)


func test_slot_2_unlocks_at_threshold() -> void:
	_progression._cumulative_cash_earned = 6000.0
	_set_owned_store_scores({"test_store": 40.0})
	EventBus.day_ended.emit(1)

	assert_true(
		_progression.is_slot_unlocked(2),
		"Slot 2 should unlock at rep>=40 and cash>=6000"
	)


func test_slot_3_unlocks_at_threshold() -> void:
	_progression._cumulative_cash_earned = 15000.0
	_set_owned_store_scores({"test_store": 55.0})
	EventBus.day_ended.emit(1)

	assert_true(
		_progression.is_slot_unlocked(3),
		"Slot 3 should unlock at rep>=55 and cash>=15000"
	)


func test_slot_4_unlocks_at_threshold() -> void:
	_progression._cumulative_cash_earned = 35000.0
	_set_owned_store_scores({"test_store": 70.0})
	EventBus.day_ended.emit(1)

	assert_true(
		_progression.is_slot_unlocked(4),
		"Slot 4 should unlock at rep>=70 and cash>=35000"
	)


func test_slot_does_not_unlock_without_both_thresholds() -> void:
	_progression._cumulative_cash_earned = 2000.0
	_set_owned_store_scores({"test_store": 10.0})
	EventBus.day_ended.emit(1)

	assert_false(
		_progression.is_slot_unlocked(1),
		"Slot 1 should NOT unlock with only cash met"
	)

	_progression._cumulative_cash_earned = 0.0
	_set_owned_store_scores({"test_store": 25.0})
	EventBus.day_ended.emit(2)

	assert_false(
		_progression.is_slot_unlocked(1),
		"Slot 1 should NOT unlock with only reputation met"
	)


func test_unlock_signal_fires_exactly_once() -> void:
	var fire_count: Array = [0]
	var on_unlock: Callable = func(slot_index: int) -> void:
		if slot_index == 1:
			fire_count[0] += 1
	EventBus.store_slot_unlocked.connect(on_unlock)

	_progression._cumulative_cash_earned = 2000.0
	_set_owned_store_scores({"test_store": 25.0})
	EventBus.day_ended.emit(1)
	EventBus.day_ended.emit(2)

	assert_eq(
		fire_count[0], 1,
		"store_slot_unlocked should fire exactly once per slot"
	)

	EventBus.store_slot_unlocked.disconnect(on_unlock)


func test_multiple_slots_can_unlock_at_once() -> void:
	var unlocked_slots: Array[int] = []
	var on_unlock: Callable = func(slot_index: int) -> void:
		unlocked_slots.append(slot_index)
	EventBus.store_slot_unlocked.connect(on_unlock)

	_progression._cumulative_cash_earned = 6000.0
	_set_owned_store_scores({"test_store": 40.0})
	EventBus.day_ended.emit(1)

	assert_true(
		unlocked_slots.has(1),
		"Slot 1 should unlock when slot 2 thresholds met"
	)
	assert_true(
		unlocked_slots.has(2),
		"Slot 2 should unlock at rep>=40 and cash>=6000"
	)

	EventBus.store_slot_unlocked.disconnect(on_unlock)


# --- Save/load round-trip ---


func test_save_load_preserves_cumulative_cash() -> void:
	_progression._cumulative_cash_earned = 5000.0
	var save_data: Dictionary = _progression.get_save_data()

	var new_prog: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(new_prog)
	new_prog.initialize(_economy, _reputation)
	new_prog.load_save_data(save_data)

	assert_almost_eq(
		new_prog.get_cumulative_cash_earned(), 5000.0, 0.01,
		"Cumulative cash should persist across save/load"
	)


func test_save_load_preserves_unlocked_slots() -> void:
	_progression._cumulative_cash_earned = 2000.0
	_set_owned_store_scores({"test_store": 25.0})
	EventBus.day_ended.emit(1)

	assert_true(_progression.is_slot_unlocked(1))

	var save_data: Dictionary = _progression.get_save_data()

	var new_prog: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(new_prog)
	new_prog.initialize(_economy, _reputation)
	new_prog.load_save_data(save_data)

	assert_true(
		new_prog.is_slot_unlocked(1),
		"Unlocked slots should persist across save/load"
	)


func test_save_load_preserves_mall_reputation() -> void:
	_progression._mall_reputation = 45.0
	var save_data: Dictionary = _progression.get_save_data()

	var new_prog: ProgressionSystem = ProgressionSystem.new()
	add_child_autofree(new_prog)
	new_prog.initialize(_economy, _reputation)
	new_prog.load_save_data(save_data)

	assert_almost_eq(
		new_prog.get_mall_reputation(), 45.0, 0.01,
		"Mall reputation should persist across save/load"
	)


func _set_owned_store_scores(scores: Dictionary) -> void:
	var owned_slots: Dictionary = {}
	var slot_index: int = 0
	for store_id_value: Variant in scores:
		var store_id: String = str(store_id_value)
		_reputation.initialize_store(store_id)
		var current_score: float = _reputation.get_reputation(store_id)
		_reputation.add_reputation(
			store_id, float(scores[store_id]) - current_score
		)
		owned_slots[slot_index] = StringName(store_id)
		slot_index += 1
	EventBus.owned_slots_restored.emit(owned_slots)
