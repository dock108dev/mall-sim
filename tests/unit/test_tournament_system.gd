## Unit tests for TournamentSystem scheduled tournaments and resolution.
extends GutTest


const STORE_ID: String = "pocket_creatures"
const TOURNAMENT_DAY: int = 5
const WINNER_ID: StringName = &"winner_alpha"
const PRIZE_AMOUNT: float = 75.0

var _tournament: TournamentSystem
var _economy: EconomySystem
var _reputation: ReputationSystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy._current_cash = 500.0

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_ID)

	_tournament = TournamentSystem.new()
	add_child_autofree(_tournament)
	_tournament.initialize(_economy, _reputation, null, null, null)


func test_schedule_tournament_registers_event() -> void:
	var scheduled: bool = _tournament.schedule_tournament(TOURNAMENT_DAY)

	assert_true(scheduled, "schedule_tournament should return true")
	assert_true(
		_tournament.is_tournament_scheduled(TOURNAMENT_DAY),
		"Tournament day should be registered"
	)


func test_tournament_start_transitions_state() -> void:
	_tournament.schedule_tournament(TOURNAMENT_DAY)

	EventBus.day_started.emit(TOURNAMENT_DAY)

	assert_eq(
		_tournament.get_state(),
		TournamentSystem.TournamentState.ACTIVE,
		"Tournament state should be ACTIVE on the scheduled day"
	)
	assert_true(
		_tournament.is_active(),
		"Tournament should be active on the scheduled day"
	)


func test_tournament_resolves_with_winner() -> void:
	_start_scheduled_tournament()
	watch_signals(EventBus)

	var resolved: bool = _tournament.resolve_tournament(
		WINNER_ID, PRIZE_AMOUNT
	)

	assert_true(resolved, "resolve_tournament should return true")
	assert_signal_emitted(
		EventBus, "tournament_resolved",
		"tournament_resolved signal should fire"
	)
	var params: Array = get_signal_parameters(
		EventBus, "tournament_resolved"
	)
	assert_eq(params[0], WINNER_ID, "Signal should include winner_id")
	assert_almost_eq(
		params[1] as float, PRIZE_AMOUNT, 0.01,
		"Signal should include prize amount"
	)


func test_prize_added_to_economy() -> void:
	_start_scheduled_tournament()
	var cash_before: float = _economy.get_cash()

	_tournament.resolve_tournament(WINNER_ID, PRIZE_AMOUNT)

	assert_almost_eq(
		_economy.get_cash(), cash_before + PRIZE_AMOUNT, 0.01,
		"Prize amount should be added to EconomySystem cash"
	)


func test_double_schedule_no_op() -> void:
	var first: bool = _tournament.schedule_tournament(TOURNAMENT_DAY)
	var second: bool = _tournament.schedule_tournament(TOURNAMENT_DAY)
	var scheduled_days: Array[int] = (
		_tournament.get_scheduled_tournament_days()
	)

	assert_true(first, "First schedule should succeed")
	assert_false(second, "Duplicate schedule should return false")
	assert_eq(
		scheduled_days.size(), 1,
		"Duplicate scheduling should not add another entry"
	)
	assert_eq(
		scheduled_days[0], TOURNAMENT_DAY,
		"Original scheduled day should remain intact"
	)


func test_save_load_preserves_schedule() -> void:
	_tournament.schedule_tournament(TOURNAMENT_DAY)
	var save_data: Dictionary = _tournament.get_save_data()

	var fresh: TournamentSystem = TournamentSystem.new()
	add_child_autofree(fresh)
	fresh.initialize(_economy, _reputation, null, null, null)
	fresh.load_save_data(save_data)

	assert_true(
		fresh.is_tournament_scheduled(TOURNAMENT_DAY),
		"Scheduled day should survive save/load round-trip"
	)


func _start_scheduled_tournament() -> void:
	_tournament.schedule_tournament(TOURNAMENT_DAY)
	EventBus.day_started.emit(TOURNAMENT_DAY)
