## GUT integration tests for DayManager 30-day arc.
## Covers: phase classification, arc unlocks (once per run), win/loss conditions.
extends GutTest

var _day_manager: DayManager
var _economy: EconomySystem
var _collected_unlocks: Array = []
var _collected_endings: Array = []
var _on_unlock: Callable
var _on_ended: Callable


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()

	_day_manager = DayManager.new()
	add_child_autofree(_day_manager)
	_day_manager.initialize(_economy)

	_collected_unlocks = []
	_collected_endings = []

	_on_unlock = func(uid: String, day: int) -> void:
		_collected_unlocks.append({"unlock_id": uid, "day": day})
	_on_ended = func(outcome: String, stats: Dictionary) -> void:
		_collected_endings.append({"outcome": outcome, "stats": stats})

	EventBus.arc_unlock_triggered.connect(_on_unlock)
	EventBus.game_ended.connect(_on_ended)


func after_each() -> void:
	if EventBus.arc_unlock_triggered.is_connected(_on_unlock):
		EventBus.arc_unlock_triggered.disconnect(_on_unlock)
	if EventBus.game_ended.is_connected(_on_ended):
		EventBus.game_ended.disconnect(_on_ended)


# ── Arc phase classification ──────────────────────────────────────────────────

func test_phase_slow_open_day_1() -> void:
	assert_eq(
		_day_manager._phase_for_day(1), "slow_open",
		"Day 1 must be slow_open"
	)


func test_phase_slow_open_day_7() -> void:
	assert_eq(
		_day_manager._phase_for_day(7), "slow_open",
		"Day 7 must still be slow_open"
	)


func test_phase_main_stretch_day_8() -> void:
	assert_eq(
		_day_manager._phase_for_day(8), "main_stretch",
		"Day 8 is the first main_stretch day"
	)


func test_phase_main_stretch_day_21() -> void:
	assert_eq(
		_day_manager._phase_for_day(21), "main_stretch",
		"Day 21 is the last main_stretch day"
	)


func test_phase_crunch_day_22() -> void:
	assert_eq(
		_day_manager._phase_for_day(22), "crunch",
		"Day 22 is the first crunch day"
	)


func test_phase_crunch_day_30() -> void:
	assert_eq(
		_day_manager._phase_for_day(30), "crunch",
		"Day 30 is a crunch day"
	)


# ── Arc unlock threshold sequence ─────────────────────────────────────────────

func test_no_unlocks_before_day_3() -> void:
	_day_manager._check_arc_unlocks(1)
	_day_manager._check_arc_unlocks(2)
	assert_eq(_collected_unlocks.size(), 0, "No unlocks before day 3")


func test_regulars_unlock_at_day_3() -> void:
	_day_manager._check_arc_unlocks(3)
	assert_eq(_collected_unlocks.size(), 1, "One unlock fires at day 3")
	assert_eq(
		_collected_unlocks[0]["unlock_id"], "regulars_enabled",
		"regulars_enabled fires at day 3"
	)


func test_full_sequence_1_3_10_14_30() -> void:
	for day: int in [1, 3, 10, 14, 30]:
		_day_manager._check_arc_unlocks(day)

	assert_eq(_collected_unlocks.size(), 2, "Exactly 2 unlocks in sequence")

	var ids: Array = []
	for entry: Dictionary in _collected_unlocks:
		ids.append(entry["unlock_id"])

	assert_true(ids.has("regulars_enabled"), "regulars_enabled must fire")
	assert_true(ids.has("tournament_events"), "tournament_events must fire")


func test_each_unlock_fires_exactly_once() -> void:
	# Call the same day multiple times.
	for _i: int in range(3):
		_day_manager._check_arc_unlocks(3)
	assert_eq(
		_collected_unlocks.size(), 1,
		"regulars_enabled fires exactly once regardless of repeated calls"
	)


func test_unlock_not_retroactively_fired_on_later_days() -> void:
	_day_manager._check_arc_unlocks(30)
	# All three thresholds (3, 10, 14) should fire together at day 30 since
	# it's the first call and day >= all thresholds.
	assert_eq(_collected_unlocks.size(), 3, "All past-threshold unlocks fire on first check")
	# Calling again must not re-fire.
	_collected_unlocks.clear()
	_day_manager._check_arc_unlocks(30)
	assert_eq(_collected_unlocks.size(), 0, "No re-fire on repeat call")


# ── Win / Loss conditions ─────────────────────────────────────────────────────

func test_loss_fires_when_cash_negative() -> void:
	_day_manager.evaluate_day_end(5, -1.0)
	assert_eq(_collected_endings.size(), 1, "game_ended fires for negative cash")
	assert_eq(_collected_endings[0]["outcome"], "loss", "outcome must be 'loss'")


func test_loss_does_not_fire_when_cash_zero() -> void:
	_day_manager.evaluate_day_end(5, 0.0)
	assert_eq(_collected_endings.size(), 0, "No loss when cash is exactly 0")


func test_loss_does_not_fire_when_cash_positive() -> void:
	_day_manager.evaluate_day_end(5, 100.0)
	assert_eq(_collected_endings.size(), 0, "No loss when cash is positive")


func test_win_fires_at_day_30_above_threshold() -> void:
	_day_manager.evaluate_day_end(30, 5000.0)
	assert_eq(_collected_endings.size(), 1, "game_ended fires at day 30 with enough cash")
	assert_eq(_collected_endings[0]["outcome"], "win", "outcome must be 'win'")


func test_win_does_not_fire_below_cash_threshold() -> void:
	_day_manager.evaluate_day_end(30, 4999.0)
	assert_eq(_collected_endings.size(), 0, "No win when cash is below threshold")


func test_win_does_not_fire_before_day_30() -> void:
	_day_manager.evaluate_day_end(29, 10000.0)
	assert_eq(_collected_endings.size(), 0, "No win before day 30")


func test_game_ended_fires_at_most_once() -> void:
	_day_manager.evaluate_day_end(5, -100.0)
	_day_manager.evaluate_day_end(5, -200.0)
	_day_manager.evaluate_day_end(30, 9999.0)
	assert_eq(_collected_endings.size(), 1, "game_ended fires at most once per run")


func test_stats_dict_contains_required_keys() -> void:
	_day_manager.evaluate_day_end(30, 5000.0)
	assert_eq(_collected_endings.size(), 1)
	var stats: Dictionary = _collected_endings[0]["stats"]
	assert_true(stats.has("final_cash"), "stats must contain final_cash")
	assert_true(stats.has("days_survived"), "stats must contain days_survived")
	assert_true(stats.has("items_sold_per_store"), "stats must contain items_sold_per_store")
	assert_true(stats.has("endings_unlocked"), "stats must contain endings_unlocked")


func test_loss_stats_record_correct_day() -> void:
	_day_manager.evaluate_day_end(12, -50.0)
	assert_eq(
		int(_collected_endings[0]["stats"]["days_survived"]), 12,
		"days_survived must match the day argument"
	)


func test_win_stats_record_correct_cash() -> void:
	_day_manager.evaluate_day_end(30, 7500.0)
	assert_almost_eq(
		float(_collected_endings[0]["stats"]["final_cash"]),
		7500.0,
		0.01,
		"final_cash must match the cash argument"
	)
