## BetaRunState tracks per-day cash delta separately from the cumulative
## run total so the day-summary panel can render Starting Cash / Sales Today
## / Ending Cash. The delta is incremented inside apply_decision_effect,
## exposed by end_day() (alongside a derived starting_cash), and reset on
## advance_day() / reset_new_run(). These tests guard those invariants.
extends GutTest


func before_each() -> void:
	BetaRunState.reset_new_run()


func after_each() -> void:
	BetaRunState.reset_new_run()


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
		int(summary.get("starting_cash", -999)), 0,
		"A fresh run must report a zero starting cash for day 1"
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
		int(summary["starting_cash"]), 0,
		"starting_cash must equal cash - cash_delta (0 for fresh run)"
	)
	assert_eq(
		int(summary["cash"]), 33,
		"Cumulative cash must equal the accumulated deltas on a fresh run"
	)


func test_apply_decision_effect_accumulates_negative_cash_delta() -> void:
	BetaRunState.apply_decision_effect(
		&"day01_test", &"refund", {"cash": -5}
	)

	var summary: Dictionary = BetaRunState.end_day()
	assert_eq(
		int(summary["cash_delta"]), -5,
		"Negative cash effects must accumulate as a negative delta"
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
		int(summary["cash"]), 15,
		"Cumulative cash must persist across days"
	)
	assert_eq(
		int(summary["starting_cash"]), 15,
		"On day 2 with no sales yet, starting_cash must equal the carried cumulative cash"
	)


func test_reset_new_run_clears_cash_delta() -> void:
	BetaRunState.apply_decision_effect(
		&"day01_test", &"clean_exchange", {"cash": 15}
	)
	BetaRunState.reset_new_run()

	var summary: Dictionary = BetaRunState.end_day()
	assert_eq(int(summary["cash"]), 0)
	assert_eq(int(summary["cash_delta"]), 0)
	assert_eq(int(summary["starting_cash"]), 0)
