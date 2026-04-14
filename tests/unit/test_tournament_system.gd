## Unit tests for TournamentSystem scheduling, state transitions, completion, and save/load.
extends GutTest


const STORE_ID: String = "pocket_creatures"

var _tournament: TournamentSystem
var _economy: EconomySystem
var _reputation: ReputationSystem
var _fixture_placement: FixturePlacementSystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy._current_cash = 500.0

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_ID)

	_fixture_placement = _create_mock_fixture_placement()
	add_child_autofree(_fixture_placement)

	_tournament = TournamentSystem.new()
	add_child_autofree(_tournament)

	GameManager.current_store_id = &"pocket_creatures"
	_tournament.initialize(
		_economy, _reputation, null, _fixture_placement, null
	)


func after_each() -> void:
	GameManager.current_store_id = &""


func test_start_tournament_registers_active() -> void:
	var result: bool = _tournament.start_tournament(
		TournamentSystem.TournamentSize.SMALL
	)
	assert_true(result, "start_tournament should return true on success")
	assert_true(
		_tournament.is_active(),
		"Tournament should be active after starting"
	)


func test_tournament_start_transitions_state() -> void:
	assert_false(
		_tournament.is_active(),
		"Tournament should not be active before starting"
	)
	watch_signals(EventBus)

	_tournament.start_tournament(TournamentSystem.TournamentSize.SMALL)

	assert_true(
		_tournament.is_active(),
		"Tournament state should transition to active"
	)
	assert_signal_emitted(
		EventBus, "tournament_started",
		"tournament_started signal should fire on start"
	)
	var params: Array = get_signal_parameters(
		EventBus, "tournament_started"
	)
	assert_gte(
		params[0] as int, TournamentSystem.MIN_PARTICIPANTS,
		"Participant count should be at least MIN_PARTICIPANTS"
	)
	assert_almost_eq(
		params[1] as float, TournamentSystem.SMALL_COST, 0.01,
		"Cost parameter should match SMALL_COST"
	)


func test_tournament_resolves_with_completion_signal() -> void:
	_tournament.start_tournament(TournamentSystem.TournamentSize.SMALL)
	watch_signals(EventBus)

	EventBus.item_sold.emit("test_card", 25.0, "pocket_creatures")
	EventBus.item_sold.emit("test_card_2", 15.0, "pocket_creatures")
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.EVENING)

	assert_signal_emitted(
		EventBus, "tournament_completed",
		"tournament_completed signal should fire at EVENING phase"
	)
	var params: Array = get_signal_parameters(
		EventBus, "tournament_completed"
	)
	assert_gte(
		params[0] as int, TournamentSystem.MIN_PARTICIPANTS,
		"Completed signal should carry participant count"
	)
	assert_almost_eq(
		params[1] as float, 40.0, 0.01,
		"Revenue should reflect sales during tournament"
	)
	assert_false(
		_tournament.is_active(),
		"Tournament should no longer be active after completion"
	)


func test_completion_applies_reputation_reward() -> void:
	var rep_before: float = _reputation.get_reputation(STORE_ID)

	_tournament.start_tournament(TournamentSystem.TournamentSize.SMALL)
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.EVENING)

	var rep_after: float = _reputation.get_reputation(STORE_ID)
	assert_gt(
		rep_after, rep_before,
		"Reputation should increase after tournament completion"
	)
	var delta: float = rep_after - rep_before
	assert_gte(
		delta, TournamentSystem.REP_REWARD_MIN,
		"Rep reward should be at least REP_REWARD_MIN"
	)
	assert_lte(
		delta, TournamentSystem.REP_REWARD_MAX,
		"Rep reward should be at most REP_REWARD_MAX"
	)


func test_double_start_is_no_op() -> void:
	var first: bool = _tournament.start_tournament(
		TournamentSystem.TournamentSize.SMALL
	)
	assert_true(first, "First start should succeed")

	var second: bool = _tournament.start_tournament(
		TournamentSystem.TournamentSize.SMALL
	)
	assert_false(second, "Second start while active should return false")
	assert_true(
		_tournament.is_active(),
		"Tournament should remain active after failed duplicate start"
	)


func test_save_load_preserves_state() -> void:
	_tournament.start_tournament(TournamentSystem.TournamentSize.LARGE)
	EventBus.item_sold.emit("card_a", 20.0, "pocket_creatures")

	var save_data: Dictionary = _tournament.get_save_data()

	var fresh: TournamentSystem = TournamentSystem.new()
	add_child_autofree(fresh)
	fresh.initialize(_economy, _reputation, null, _fixture_placement, null)
	fresh.load_save_data(save_data)

	assert_true(
		fresh.is_active(),
		"Loaded tournament should be active"
	)
	assert_eq(
		fresh.get_participant_count(),
		_tournament.get_participant_count(),
		"Participant count should survive round-trip"
	)
	assert_eq(
		fresh.get_cooldown_remaining(),
		_tournament.get_cooldown_remaining(),
		"Cooldown should survive round-trip"
	)


func test_save_load_preserves_cooldown() -> void:
	_tournament.start_tournament(TournamentSystem.TournamentSize.SMALL)
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.EVENING)

	assert_eq(
		_tournament.get_cooldown_remaining(),
		TournamentSystem.COOLDOWN_DAYS,
		"Cooldown should be set after completion"
	)

	var save_data: Dictionary = _tournament.get_save_data()
	var fresh: TournamentSystem = TournamentSystem.new()
	add_child_autofree(fresh)
	fresh.initialize(_economy, _reputation, null, _fixture_placement, null)
	fresh.load_save_data(save_data)

	assert_eq(
		fresh.get_cooldown_remaining(),
		TournamentSystem.COOLDOWN_DAYS,
		"Cooldown should survive save/load round-trip"
	)
	assert_false(
		fresh.is_active(),
		"Completed tournament should not be active after load"
	)


func test_cooldown_prevents_hosting() -> void:
	_tournament.start_tournament(TournamentSystem.TournamentSize.SMALL)
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.EVENING)

	assert_false(
		_tournament.can_host_tournament(),
		"Cannot host during cooldown"
	)
	assert_true(
		_tournament.get_block_reason().contains("Cooldown"),
		"Block reason should mention cooldown"
	)


func test_cooldown_decrements_on_day_start() -> void:
	_tournament.start_tournament(TournamentSystem.TournamentSize.SMALL)
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.EVENING)

	for day: int in range(TournamentSystem.COOLDOWN_DAYS):
		EventBus.day_started.emit(day + 1)

	assert_eq(
		_tournament.get_cooldown_remaining(), 0,
		"Cooldown should reach zero after COOLDOWN_DAYS"
	)
	assert_true(
		_tournament.can_host_tournament(),
		"Should be able to host after cooldown expires"
	)


func test_cost_deducted_from_economy() -> void:
	var cash_before: float = _economy.get_cash()
	_tournament.start_tournament(TournamentSystem.TournamentSize.SMALL)
	assert_almost_eq(
		_economy.get_cash(),
		cash_before - TournamentSystem.SMALL_COST, 0.01,
		"SMALL_COST should be deducted from player cash"
	)


func test_large_tournament_deducts_large_cost() -> void:
	var cash_before: float = _economy.get_cash()
	_tournament.start_tournament(TournamentSystem.TournamentSize.LARGE)
	assert_almost_eq(
		_economy.get_cash(),
		cash_before - TournamentSystem.LARGE_COST, 0.01,
		"LARGE_COST should be deducted from player cash"
	)


func test_insufficient_funds_prevents_start() -> void:
	_economy._current_cash = 5.0
	var result: bool = _tournament.start_tournament(
		TournamentSystem.TournamentSize.SMALL
	)
	assert_false(result, "Should fail with insufficient funds")
	assert_false(
		_tournament.is_active(),
		"Tournament should not activate on failed start"
	)


func test_revenue_accumulates_during_active_tournament() -> void:
	_tournament.start_tournament(TournamentSystem.TournamentSize.SMALL)
	EventBus.item_sold.emit("card_x", 10.0, "pocket_creatures")
	EventBus.item_sold.emit("card_y", 30.0, "pocket_creatures")

	watch_signals(EventBus)
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.EVENING)

	var params: Array = get_signal_parameters(
		EventBus, "tournament_completed"
	)
	assert_almost_eq(
		params[1] as float, 40.0, 0.01,
		"Tournament revenue should accumulate from item_sold signals"
	)


func test_revenue_does_not_accumulate_when_inactive() -> void:
	EventBus.item_sold.emit("card_z", 100.0, "pocket_creatures")

	_tournament.start_tournament(TournamentSystem.TournamentSize.SMALL)
	watch_signals(EventBus)
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.EVENING)

	var params: Array = get_signal_parameters(
		EventBus, "tournament_completed"
	)
	assert_almost_eq(
		params[1] as float, 0.0, 0.01,
		"Sales before tournament start should not count as revenue"
	)


func _create_mock_fixture_placement() -> FixturePlacementSystem:
	var fp: FixturePlacementSystem = FixturePlacementSystem.new()
	fp._occupied_cells = {Vector2i(0, 0): "fixture_001"}
	fp._placed_fixtures = {
		"fixture_001": {"fixture_type": "tournament_table"},
	}
	return fp
