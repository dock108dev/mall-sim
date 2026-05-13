## BetaRunState tracks per-day reputation delta separately from the cumulative
## run total so the day-summary panel can show a single 'Reputation: +N / -N'
## line that reflects what the player did *today*. The delta is incremented
## inside apply_decision_effect, exposed by end_day(), and reset on
## advance_day() / reset_new_run(). These tests guard those four invariants.
extends GutTest


func before_each() -> void:
	BetaRunState.reset_new_run()


func after_each() -> void:
	BetaRunState.reset_new_run()


func test_end_day_includes_reputation_delta_key() -> void:
	var summary: Dictionary = BetaRunState.end_day()
	assert_true(
		summary.has("reputation_delta"),
		"end_day() return dict must include the 'reputation_delta' key so "
		+ "the summary panel can render the per-day Reputation line"
	)


func test_reputation_delta_zero_at_fresh_run_start() -> void:
	var summary: Dictionary = BetaRunState.end_day()
	assert_eq(
		int(summary.get("reputation_delta", -999)), 0,
		"A fresh run must report a zero reputation delta for day 1"
	)


func test_apply_decision_effect_accumulates_positive_reputation_delta() -> void:
	BetaRunState.apply_decision_effect(
		&"day01_test", &"clean_exchange", {"reputation": 2}
	)
	BetaRunState.apply_decision_effect(
		&"day01_test", &"upsell_bundle", {"reputation": 1}
	)

	var summary: Dictionary = BetaRunState.end_day()
	assert_eq(
		int(summary["reputation_delta"]), 3,
		"reputation_delta must accumulate across apply_decision_effect calls within a day"
	)


func test_apply_decision_effect_accumulates_negative_reputation_delta() -> void:
	BetaRunState.apply_decision_effect(
		&"day01_test", &"refuse_return", {"reputation": -3}
	)

	var summary: Dictionary = BetaRunState.end_day()
	assert_eq(
		int(summary["reputation_delta"]), -3,
		"Negative reputation effects must accumulate as a negative delta"
	)


func test_advance_day_resets_reputation_delta() -> void:
	BetaRunState.apply_decision_effect(
		&"day01_test", &"clean_exchange", {"reputation": 2}
	)
	BetaRunState.advance_day()

	var summary: Dictionary = BetaRunState.end_day()
	assert_eq(
		int(summary["reputation_delta"]), 0,
		"advance_day() must reset reputation_delta so day 2 starts fresh"
	)


func test_advance_day_preserves_cumulative_reputation() -> void:
	BetaRunState.apply_decision_effect(
		&"day01_test", &"clean_exchange", {"reputation": 2}
	)
	BetaRunState.advance_day()

	var summary: Dictionary = BetaRunState.end_day()
	assert_eq(
		int(summary["reputation"]), 2,
		"Cumulative reputation must persist across days even though the "
		+ "per-day delta resets — the run-total is what advancement / "
		+ "ending logic reads"
	)
