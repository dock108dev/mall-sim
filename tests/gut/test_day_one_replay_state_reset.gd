## Regression: replaying Day 1 via DaySummary's restart path (which routes
## through `GameManager.start_new_game()` → `begin_new_run()`) must leave
## every per-run flag and chain sentinel in its first-play state. The two
## flags that previously survived a replay and silently changed behavior
## are `tutorial_skipped` (hid the tutorial overlay) and
## `first_sale_complete` (disabled the Day 1 first-sale guarantee and the
## checkout-declined forced-spawn re-arm path). ObjectiveDirector's
## `_loop_completed` sentinel previously survived as well; on Day 1 itself
## it was inert (gated on `_current_day > 3`), but it would have re-armed
## the auto-hide path mid-replay once the player passed Day 3.
extends GutTest


var _saved_current_day: int
var _saved_state: GameManager.State
var _saved_store_id: StringName
var _saved_pending_load_slot: int
var _saved_unlock_valid_ids: Dictionary
var _saved_unlock_grants: Dictionary


func before_each() -> void:
	_saved_current_day = GameManager.get_current_day()
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_pending_load_slot = GameManager.pending_load_slot
	_saved_unlock_valid_ids = UnlockSystemSingleton._valid_ids.duplicate(true)
	_saved_unlock_grants = UnlockSystemSingleton._granted.duplicate(true)
	GameState.reset_new_game()
	AuditLog.clear()
	BetaRunState.reset_new_run()


func after_each() -> void:
	GameManager.set_current_day(_saved_current_day)
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.pending_load_slot = _saved_pending_load_slot
	UnlockSystemSingleton._valid_ids = _saved_unlock_valid_ids.duplicate(true)
	UnlockSystemSingleton._granted = _saved_unlock_grants.duplicate(true)
	GameState.reset_new_game()
	BetaRunState.reset_new_run()


func test_begin_new_run_clears_tutorial_skipped_flag() -> void:
	GameState.set_flag(&"tutorial_skipped", true)
	assert_true(
		GameState.get_flag(&"tutorial_skipped"),
		"precondition: tutorial_skipped must be set before replay"
	)
	GameManager.begin_new_run()
	assert_false(
		GameState.get_flag(&"tutorial_skipped"),
		"begin_new_run() must clear tutorial_skipped so the tutorial"
		+ " overlay renders on replay"
	)


func test_begin_new_run_clears_first_sale_complete_flag() -> void:
	GameState.set_flag(&"first_sale_complete", true)
	assert_true(
		GameState.get_flag(&"first_sale_complete"),
		"precondition: first_sale_complete must be set before replay"
	)
	GameManager.begin_new_run()
	assert_false(
		GameState.get_flag(&"first_sale_complete"),
		"begin_new_run() must clear first_sale_complete so the Day 1"
		+ " first-sale guarantee re-activates on replay"
	)


func test_begin_new_run_clears_arbitrary_run_flags() -> void:
	# `GameState.reset_new_game()` clears the whole flags dict, so any
	# future per-run flag (midday hidden-thread keys, scapegoat_risk,
	# etc.) is covered by the same code path. Pin that contract here so
	# a regression that swaps the call for explicit keyed clears can't
	# silently leave a flag behind.
	GameState.set_flag(&"some_other_run_flag", true)
	GameManager.begin_new_run()
	assert_false(
		GameState.get_flag(&"some_other_run_flag"),
		"begin_new_run() must clear every entry in GameState.flags"
	)


func test_begin_new_run_resets_game_state_money() -> void:
	GameState.money = 999
	GameManager.begin_new_run()
	assert_eq(
		GameState.money, GameState.DEFAULT_MONEY,
		"begin_new_run() must reset transient GameState money"
	)


func test_begin_new_run_clears_unlock_grants() -> void:
	UnlockSystemSingleton._valid_ids = {&"register_access": true}
	UnlockSystemSingleton._granted = {&"register_access": true}
	GameManager.begin_new_run()
	assert_true(
		UnlockSystemSingleton.get_all_granted().is_empty(),
		"begin_new_run() must clear unlock grants for a fresh beta run"
	)


func test_objective_director_loop_completed_resets_on_day_started_one() -> void:
	ObjectiveDirector._loop_completed = true
	ObjectiveDirector._on_day_started(1)
	assert_false(
		ObjectiveDirector._loop_completed,
		"day_started(1) must clear _loop_completed so the auto-hide"
		+ " sentinel does not carry over from a prior run"
	)


func test_objective_director_loop_completed_survives_other_days() -> void:
	# The sentinel must only reset on Day 1 — clearing it on every day
	# would break the post-Day-3 auto-hide behavior that the flag exists
	# to drive.
	ObjectiveDirector._loop_completed = true
	ObjectiveDirector._on_day_started(4)
	assert_true(
		ObjectiveDirector._loop_completed,
		"day_started on a non-Day-1 boundary must not clear"
		+ " _loop_completed"
	)


# ── BetaRunState defaults restored on replay ──────────────────────────────────
# `GameManager.begin_new_run()` calls `BetaRunState.reset_new_run()` to zero
# every per-run accumulator (day / cash / reputation / event lists / flags /
# carry flag). Without this contract, Day 1 numbers carry into the replay
# and the day-summary panel renders cumulative-since-last-replay totals
# instead of fresh Day 1 values.


func test_begin_new_run_resets_beta_run_state_day_to_one() -> void:
	BetaRunState.day = 2
	GameManager.begin_new_run()
	assert_eq(
		BetaRunState.day, 1,
		"begin_new_run() must reset BetaRunState.day to 1"
	)


func test_begin_new_run_resets_beta_run_state_cash_and_reputation() -> void:
	BetaRunState.cash = 250
	BetaRunState.daily_cash_delta = 75
	BetaRunState.reputation = 5
	BetaRunState.daily_reputation_delta = 3
	GameManager.begin_new_run()
	assert_eq(BetaRunState.cash, 0, "begin_new_run() must zero BetaRunState.cash")
	assert_eq(
		BetaRunState.daily_cash_delta, 0,
		"begin_new_run() must zero BetaRunState.daily_cash_delta"
	)
	assert_eq(
		BetaRunState.reputation, 0,
		"begin_new_run() must zero BetaRunState.reputation"
	)
	assert_eq(
		BetaRunState.daily_reputation_delta, 0,
		"begin_new_run() must zero BetaRunState.daily_reputation_delta"
	)


func test_begin_new_run_clears_beta_run_state_event_lists_and_flags() -> void:
	BetaRunState.completed_events.append(&"day01_wrong_console_parent")
	BetaRunState.daily_events_resolved.append(&"day01_wrong_console_parent")
	BetaRunState.hidden_thread_signals_seen.append(&"some_signal")
	BetaRunState.flags[&"some_flag"] = true
	GameManager.begin_new_run()
	assert_true(
		BetaRunState.completed_events.is_empty(),
		"begin_new_run() must clear BetaRunState.completed_events"
	)
	assert_true(
		BetaRunState.daily_events_resolved.is_empty(),
		"begin_new_run() must clear BetaRunState.daily_events_resolved"
	)
	assert_true(
		BetaRunState.hidden_thread_signals_seen.is_empty(),
		"begin_new_run() must clear BetaRunState.hidden_thread_signals_seen"
	)
	assert_true(
		BetaRunState.flags.is_empty(),
		"begin_new_run() must clear BetaRunState.flags"
	)


func test_begin_new_run_clears_beta_run_state_carrying_stock() -> void:
	BetaRunState.carrying_stock = true
	GameManager.begin_new_run()
	assert_false(
		BetaRunState.carrying_stock,
		"begin_new_run() must clear BetaRunState.carrying_stock so replay starts unencumbered"
	)


func test_begin_new_run_resets_beta_run_state_counters_and_input() -> void:
	BetaRunState.manager_trust = 4
	BetaRunState.hidden_thread_score = 3
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DECISION_CARD)
	GameManager.begin_new_run()
	assert_eq(BetaRunState.manager_trust, 0)
	assert_eq(BetaRunState.hidden_thread_score, 0)
	assert_eq(BetaRunState.input_mode, BetaRunState.INPUT_MODE_GAMEPLAY)
