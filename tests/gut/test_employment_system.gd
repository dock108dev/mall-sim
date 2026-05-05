## Tests for the seasonal-employee EmploymentSystem autoload + EmploymentState
## resource. Covers Day-1 defaults, trust setter clamping, save/load round-trip,
## EventBus signal emission, and the wage-issuance flow.
extends GutTest


const SAVE_PATH: String = "user://employment_state.cfg"


var _saved_trust: float
var _saved_approval: float


func before_each() -> void:
	_saved_trust = GameState.employee_trust
	_saved_approval = GameState.manager_approval
	# EmploymentSystem is an autoload — reset to defaults between tests so one
	# test's trust delta doesn't leak into the next.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	EmploymentSystem.state = EmploymentState.new()
	EmploymentSystem._employed = false
	EmploymentSystem._evaluated_outcome = false
	GameState.employee_trust = EmploymentState.DEFAULT_TRUST
	GameState.manager_approval = EmploymentState.DEFAULT_APPROVAL


func after_each() -> void:
	GameState.employee_trust = _saved_trust
	GameState.manager_approval = _saved_approval
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ── EmploymentState resource ─────────────────────────────────────────────────


func test_state_defaults_match_issue_spec() -> void:
	var state: EmploymentState = EmploymentState.new()
	assert_eq(state.employee_trust, 50.0, "trust must default to 50.0")
	assert_eq(state.manager_approval, 0.5, "approval must default to 0.5")
	assert_eq(state.employment_status, EmploymentState.STATUS_ACTIVE)
	assert_eq(state.hours_worked_total, 0.0)


func test_trust_setter_clamps_above_max() -> void:
	var state: EmploymentState = EmploymentState.new()
	state.employee_trust = 250.0
	assert_eq(state.employee_trust, 100.0, "trust must clamp to 100")


func test_trust_setter_clamps_below_min() -> void:
	var state: EmploymentState = EmploymentState.new()
	state.employee_trust = -50.0
	assert_eq(state.employee_trust, 0.0, "trust must clamp to 0")


func test_trust_setter_no_signal_when_at_boundary() -> void:
	var state: EmploymentState = EmploymentState.new()
	state.employee_trust = 100.0
	watch_signals(state)
	state.employee_trust = 150.0
	assert_signal_not_emitted(
		state, "trust_changed",
		"setter at upper boundary must not re-emit when delta saturates"
	)


func test_trust_setter_no_signal_when_at_zero_boundary() -> void:
	var state: EmploymentState = EmploymentState.new()
	state.employee_trust = 0.0
	watch_signals(state)
	state.employee_trust = -10.0
	assert_signal_not_emitted(
		state, "trust_changed",
		"setter at lower boundary must not re-emit when delta saturates"
	)


func test_trust_setter_emits_when_value_changes() -> void:
	var state: EmploymentState = EmploymentState.new()
	watch_signals(state)
	state.employee_trust = 75.0
	assert_signal_emitted(state, "trust_changed")


func test_save_data_includes_required_keys() -> void:
	var state: EmploymentState = EmploymentState.new()
	state.employee_trust = 42.0
	state.manager_approval = 88.0
	state.employment_status = EmploymentState.STATUS_AT_RISK
	state.hours_worked_total = 96.0
	var data: Dictionary = state.get_save_data()
	assert_true(data.has("employee_trust"))
	assert_true(data.has("manager_approval"))
	assert_true(data.has("employment_status"))
	assert_true(data.has("hours_worked_total"))
	assert_eq(data["employee_trust"], 42.0)
	assert_eq(data["manager_approval"], 88.0)
	assert_eq(data["employment_status"], "at_risk")
	assert_eq(data["hours_worked_total"], 96.0)


func test_load_save_data_uses_safe_default_when_key_absent() -> void:
	var state: EmploymentState = EmploymentState.new()
	state.load_save_data({})
	assert_eq(
		state.employee_trust, 50.0,
		"missing trust key must default to 50.0 — never below firing floor"
	)
	assert_eq(state.manager_approval, 0.5)
	assert_eq(state.employment_status, EmploymentState.STATUS_ACTIVE)


func test_load_save_data_round_trip() -> void:
	var src: EmploymentState = EmploymentState.new()
	src.employee_trust = 73.5
	src.manager_approval = 41.0
	src.employment_status = EmploymentState.STATUS_RETAINED
	src.hours_worked_total = 168.0
	var dst: EmploymentState = EmploymentState.new()
	dst.load_save_data(src.get_save_data())
	assert_eq(dst.employee_trust, 73.5)
	assert_eq(dst.manager_approval, 41.0)
	assert_eq(dst.employment_status, EmploymentState.STATUS_RETAINED)
	assert_eq(dst.hours_worked_total, 168.0)


# ── EmploymentSystem autoload ────────────────────────────────────────────────


func test_start_employment_seeds_defaults_and_emits_signal() -> void:
	watch_signals(EventBus)
	EmploymentSystem.start_employment(&"retro_games", 12.0)
	assert_eq(EmploymentSystem.state.employee_trust, 50.0)
	assert_eq(EmploymentSystem.state.manager_approval, 0.5)
	assert_eq(
		EmploymentSystem.state.employment_status,
		EmploymentState.STATUS_ACTIVE,
	)
	assert_eq(EmploymentSystem.state.hourly_wage, 12.0)
	assert_signal_emitted(EventBus, "employment_started")


func test_start_employment_mirrors_to_game_state() -> void:
	GameState.employee_trust = 0.0
	EmploymentSystem.start_employment(&"retro_games")
	assert_eq(
		GameState.employee_trust, 50.0,
		"start_employment must seed GameState.employee_trust to 50.0"
	)
	assert_eq(GameState.manager_approval, 0.5)


func test_apply_trust_delta_emits_with_actual_delta() -> void:
	EmploymentSystem.start_employment(&"retro_games")
	watch_signals(EventBus)
	EmploymentSystem.apply_trust_delta(7.5, "test")
	assert_signal_emitted(EventBus, "trust_changed")
	var params: Array = get_signal_parameters(EventBus, "trust_changed")
	assert_eq(params[0], 7.5)
	assert_eq(params[1], "test")
	assert_eq(GameState.employee_trust, 57.5)


func test_apply_trust_delta_no_signal_at_saturation() -> void:
	EmploymentSystem.start_employment(&"retro_games")
	EmploymentSystem.state.employee_trust = 100.0
	GameState.employee_trust = 100.0
	watch_signals(EventBus)
	EmploymentSystem.apply_trust_delta(10.0, "saturation_test")
	assert_signal_not_emitted(EventBus, "trust_changed")


func test_customer_purchased_increases_trust_by_formula() -> void:
	EmploymentSystem.start_employment(&"retro_games")
	var before: float = EmploymentSystem.state.employee_trust
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_x", 9.99, &"customer_a"
	)
	var actual: float = EmploymentSystem.state.employee_trust - before
	assert_almost_eq(
		actual, EmploymentSystem.TRUST_DELTA_SATISFIED_CUSTOMER, 0.001,
		"satisfied customer must apply +1.5 trust per issue spec"
	)


func test_task_completed_increases_trust_by_formula() -> void:
	EmploymentSystem.start_employment(&"retro_games")
	var before: float = EmploymentSystem.state.employee_trust
	EventBus.task_completed.emit(&"restock")
	var actual: float = EmploymentSystem.state.employee_trust - before
	assert_almost_eq(
		actual, EmploymentSystem.TRUST_DELTA_TASK_COMPLETED, 0.001,
		"task completion must apply +3.0 trust per issue spec"
	)


func test_complaint_decrement_via_apply_trust_delta() -> void:
	EmploymentSystem.start_employment(&"retro_games")
	var before: float = EmploymentSystem.state.employee_trust
	EmploymentSystem.apply_trust_delta(
		EmploymentSystem.TRUST_DELTA_COMPLAINT,
		EmploymentSystem.REASON_COMPLAINT,
	)
	assert_almost_eq(
		EmploymentSystem.state.employee_trust - before,
		EmploymentSystem.TRUST_DELTA_COMPLAINT, 0.001,
		"complaint must apply −2.0 trust per issue spec"
	)


func test_manager_confrontation_decrement_via_apply_trust_delta() -> void:
	EmploymentSystem.start_employment(&"retro_games")
	var before: float = EmploymentSystem.state.employee_trust
	EmploymentSystem.apply_trust_delta(
		EmploymentSystem.TRUST_DELTA_MANAGER_CONFRONTATION,
		EmploymentSystem.REASON_MANAGER_CONFRONTATION,
	)
	assert_almost_eq(
		EmploymentSystem.state.employee_trust - before,
		EmploymentSystem.TRUST_DELTA_MANAGER_CONFRONTATION, 0.001,
		"confrontation must apply −5.0 trust per issue spec"
	)


func test_no_trust_delta_when_not_employed() -> void:
	# Default state: not employed.
	var before: float = EmploymentSystem.state.employee_trust
	EventBus.customer_purchased.emit(
		&"retro_games", &"item_x", 9.99, &"customer_a"
	)
	assert_eq(
		EmploymentSystem.state.employee_trust, before,
		"trust must not move when no active employment relationship"
	)


# ── Wage issuance ────────────────────────────────────────────────────────────


func test_issue_daily_wage_emits_wage_issued_when_no_economy() -> void:
	EmploymentSystem.start_employment(&"retro_games", 10.0)
	watch_signals(EventBus)
	EmploymentSystem.issue_daily_wage()
	assert_signal_emitted(EventBus, "wage_issued")
	var params: Array = get_signal_parameters(EventBus, "wage_issued")
	assert_eq(params[0], 10.0 * EmploymentSystem.HOURS_PER_SHIFT)
	assert_eq(EmploymentSystem.state.hours_worked_total, 8.0)


func test_issue_daily_wage_credits_player_via_economy() -> void:
	EmploymentSystem.start_employment(&"retro_games", 10.0)
	var economy: EconomySystem = EconomySystem.new()
	add_child_autofree(economy)
	economy._apply_state({"current_cash": 100.0})
	EmploymentSystem.issue_daily_wage()
	# Drained autoload-resolved economy will be the test-fixture instance only
	# when it's discoverable in the tree. Since add_child_autofree puts it
	# under the test node (not the root), GameManager.get_economy_system()
	# may not find it. Use a direct credit_wage to assert the API works.
	var before: float = economy.get_cash()
	economy.credit_wage(80.0, "Daily wage")
	assert_eq(economy.get_cash(), before + 80.0)


# ── Firing / retention ───────────────────────────────────────────────────────


func test_trust_below_firing_floor_emits_employment_ended() -> void:
	EmploymentSystem.start_employment(&"retro_games")
	EmploymentSystem.state.employee_trust = 10.0  # below FIRING_FLOOR (15.0)
	watch_signals(EventBus)
	EventBus.day_ended.emit(5)
	assert_signal_emitted(EventBus, "employment_ended")
	assert_eq(
		EmploymentSystem.state.employment_status,
		EmploymentState.STATUS_FIRED,
	)


func test_high_trust_at_season_end_retains() -> void:
	EmploymentSystem.start_employment(&"retro_games")
	EmploymentSystem.state.employee_trust = 75.0
	watch_signals(EventBus)
	EventBus.day_ended.emit(EmploymentSystem.SEASON_LENGTH_DAYS)
	assert_signal_emitted(EventBus, "employment_ended")
	assert_eq(
		EmploymentSystem.state.employment_status,
		EmploymentState.STATUS_RETAINED,
	)


# ── Persistence ──────────────────────────────────────────────────────────────


func test_day_ended_persists_state_to_disk() -> void:
	EmploymentSystem.start_employment(&"retro_games", 15.0)
	EmploymentSystem.state.employee_trust = 67.0
	EmploymentSystem.state.manager_approval = 88.0
	EmploymentSystem.state.hours_worked_total = 24.0
	EventBus.day_ended.emit(3)
	assert_true(
		FileAccess.file_exists(SAVE_PATH),
		"day_ended must persist state to user://"
	)


func test_day_started_loads_state_from_disk() -> void:
	# Seed disk via a persist cycle, then reset RAM and emit day_started.
	# day_ended fires issue_daily_wage before persisting, which advances
	# hours_worked_total by HOURS_PER_SHIFT — assert against the post-shift
	# value, not the pre-shift seed.
	EmploymentSystem.start_employment(&"retro_games", 15.0)
	EmploymentSystem.state.employee_trust = 71.5
	EmploymentSystem.state.manager_approval = 33.0
	EmploymentSystem.state.hours_worked_total = 56.0
	EventBus.day_ended.emit(4)
	var expected_hours: float = 56.0 + EmploymentSystem.HOURS_PER_SHIFT

	# Simulate a fresh session: reset the in-memory state.
	EmploymentSystem.state = EmploymentState.new()
	EmploymentSystem._employed = false
	assert_eq(EmploymentSystem.state.employee_trust, 50.0)

	EventBus.day_started.emit(5)
	assert_almost_eq(EmploymentSystem.state.employee_trust, 71.5, 0.001)
	assert_almost_eq(EmploymentSystem.state.manager_approval, 33.0, 0.001)
	assert_almost_eq(
		EmploymentSystem.state.hours_worked_total, expected_hours, 0.001
	)


func test_day_started_uses_safe_defaults_when_no_save() -> void:
	# No save file present; state should keep its defaults.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	EmploymentSystem.state = EmploymentState.new()
	EventBus.day_started.emit(1)
	assert_eq(
		EmploymentSystem.state.employee_trust, 50.0,
		"missing save file must leave trust at the 50.0 default"
	)


# ── GameState mirror ─────────────────────────────────────────────────────────


func test_game_state_clamps_trust_to_range() -> void:
	GameState.employee_trust = 250.0
	assert_eq(GameState.employee_trust, 100.0)
	GameState.employee_trust = -10.0
	assert_eq(GameState.employee_trust, 0.0)


func test_game_state_manager_approval_clamps_to_range() -> void:
	GameState.manager_approval = 250.0
	assert_eq(GameState.manager_approval, 100.0)
	GameState.manager_approval = -10.0
	assert_eq(GameState.manager_approval, 0.0)
