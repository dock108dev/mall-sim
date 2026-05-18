## BetaRunState tracks per-day cash deltas, while EconomySystem owns the
## player-visible wallet. Day-summary accounting must therefore derive:
## ending_cash = round(EconomySystem.get_cash())
## starting_cash = ending_cash - BetaRunState.daily_cash_delta.
## These tests guard that contract and the beta delta reset behavior.
extends GutTest

const STARTING_CASH: float = 500.0

var _economy: EconomySystem
var _saved_day: int
var _saved_tier: StringName


func before_each() -> void:
	_saved_day = GameManager.get_current_day()
	_saved_tier = DifficultySystemSingleton.get_current_tier_id()
	DifficultySystemSingleton.set_tier(&"normal")
	GameManager.set_current_day(1)
	BetaRunState.reset_new_run()
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)


func after_each() -> void:
	BetaRunState.reset_new_run()
	GameManager.set_current_day(_saved_day)
	DifficultySystemSingleton.set_tier(_saved_tier)


func test_end_day_includes_cash_delta_and_starting_cash_keys() -> void:
	var summary: Dictionary = BetaRunState.end_day()
	assert_true(
		summary.has("cash_delta"),
		"end_day() must include 'cash_delta' so the summary panel can show Sales Today"
	)
	assert_true(
		summary.has("starting_cash"),
		"end_day() must include 'starting_cash' so the summary panel can show Starting Cash"
	)


func test_cash_delta_zero_at_fresh_run_start() -> void:
	var summary: Dictionary = BetaRunState.end_day()
	assert_eq(
		int(summary.get("cash_delta", -999)), 0,
		"A fresh run must report a zero cash delta for day 1"
	)
	assert_eq(
		int(summary.get("starting_cash", -999)), int(STARTING_CASH),
		"A fresh run must report the economy starting cash for day 1"
	)
	assert_eq(
		int(summary.get("cash", -999)), int(STARTING_CASH),
		"A fresh run must report the economy wallet as ending cash"
	)
	assert_eq(
		int(summary.get("ending_cash", -999)), int(STARTING_CASH),
		"ending_cash must mirror the legacy cash summary key"
	)


func test_apply_decision_effect_accumulates_positive_cash_delta() -> void:
	BetaRunState.apply_decision_effect(
		&"day01_test", &"clean_exchange", {"cash": 15}
	)
	BetaRunState.apply_decision_effect(
		&"day01_test", &"upsell_bundle", {"cash": 18}
	)

	var summary: Dictionary = BetaRunState.end_day()
	assert_eq(
		int(summary["cash_delta"]), 33,
		"cash_delta must accumulate across apply_decision_effect calls within a day"
	)
	assert_eq(
		int(summary["starting_cash"]), int(STARTING_CASH),
		"starting_cash must equal ending_cash - cash_delta"
	)
	assert_eq(
		int(summary["cash"]), int(STARTING_CASH) + 33,
		"Summary cash must include the EconomySystem starting baseline"
	)
	assert_eq(int(summary["ending_cash"]), int(summary["cash"]))


func test_apply_decision_effect_accumulates_negative_cash_delta() -> void:
	BetaRunState.apply_decision_effect(
		&"day01_test", &"refund", {"cash": -5}
	)

	var summary: Dictionary = BetaRunState.end_day()
	assert_eq(
		int(summary["cash_delta"]), -5,
		"Negative cash effects must accumulate as a negative delta"
	)
	assert_eq(
		int(summary["starting_cash"]), int(STARTING_CASH),
		"Negative effects must still derive starting_cash from the economy wallet"
	)
	assert_eq(
		int(summary["ending_cash"]), int(STARTING_CASH) - 5,
		"Ending cash must reflect the charged economy wallet"
	)


func test_advance_day_resets_cash_delta_but_preserves_total() -> void:
	BetaRunState.apply_decision_effect(
		&"day01_test", &"clean_exchange", {"cash": 15}
	)
	BetaRunState.advance_day()

	var summary: Dictionary = BetaRunState.end_day()
	assert_eq(
		int(summary["cash_delta"]), 0,
		"advance_day() must reset cash_delta so day 2 starts fresh"
	)
	assert_eq(
		int(summary["cash"]), int(STARTING_CASH) + 15,
		"Summary cash must continue to read the visible economy wallet"
	)
	assert_eq(
		int(summary["starting_cash"]), int(STARTING_CASH) + 15,
		"On day 2 with no sales yet, starting_cash must equal ending cash"
	)


func test_reset_new_run_clears_cash_delta() -> void:
	BetaRunState.apply_decision_effect(
		&"day01_test", &"clean_exchange", {"cash": 15}
	)
	BetaRunState.reset_new_run()

	var summary: Dictionary = BetaRunState.end_day()
	assert_eq(BetaRunState.cash, 0)
	assert_eq(int(summary["cash_delta"]), 0)
	assert_eq(int(summary["cash"]), int(STARTING_CASH) + 15)
	assert_eq(int(summary["starting_cash"]), int(summary["cash"]))
