## Integration test: stock→price→sell→close→summary signal loop (ISSUE-016).
## Verifies: day_started → mock sales → day_close_requested → day_closed payload.
extends GutTest

const TEST_SIGNAL_UTILS: GDScript = preload("res://game/tests/signal_utils.gd")

var _time: TimeSystem
var _economy: EconomySystem
var _staff: StaffSystem
var _progression: ProgressionSystem
var _ending_eval: EndingEvaluatorSystem
var _perf_report: PerformanceReportSystem
var _controller: DayCycleController

var _saved_state: int
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]
var _saved_first_sale_flag: bool

# Captured signal payloads
var _day_closed_payloads: Array[Dictionary] = []
var _store_day_closed_calls: Array[Dictionary] = []
var _day_started_days: Array[int] = []


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_first_sale_flag = GameState.get_flag(&"first_sale_complete")
	GameManager.current_state = GameManager.State.GAMEPLAY
	GameManager.current_store_id = &"pocket_creatures"
	GameManager.owned_stores = []
	# Pre-set the first-sale flag so any future flag-coupled assertion runs
	# against a "first sale done" session — these tests exercise day-close
	# mechanics, not the Day 1 soft-confirm gate.
	GameState.set_flag(&"first_sale_complete", true)
	# Pre-mark the loop-completed flag so the Phase-3 confirmation gate fails
	# open. These tests verify the post-confirm close path; the gate itself
	# has its own coverage in test_day_cycle_close_confirmation_gate.
	ObjectiveDirector._loop_completed_today = true

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.initialize()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(500.0)

	_staff = StaffSystem.new()
	add_child_autofree(_staff)

	_progression = ProgressionSystem.new()
	add_child_autofree(_progression)

	_ending_eval = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_eval)
	_ending_eval.initialize()

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()

	_controller = DayCycleController.new()
	add_child_autofree(_controller)
	_controller.initialize(
		_time, _economy, _staff, _progression,
		_ending_eval, _perf_report,
	)

	_day_closed_payloads = []
	_store_day_closed_calls = []
	_day_started_days = []

	EventBus.day_closed.connect(_on_day_closed)
	EventBus.store_day_closed.connect(_on_store_day_closed)
	EventBus.day_started.connect(_on_day_started)


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	GameState.set_flag(&"first_sale_complete", _saved_first_sale_flag)
	ObjectiveDirector._loop_completed_today = false
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.day_closed, _on_day_closed)
	TEST_SIGNAL_UTILS.safe_disconnect(
		EventBus.store_day_closed, _on_store_day_closed
	)
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.day_started, _on_day_started)


func _on_day_closed(day: int, summary: Dictionary) -> void:
	_day_closed_payloads.append({"day": day, "summary": summary})


func _on_store_day_closed(
	store_id: StringName, store_summary: Dictionary
) -> void:
	_store_day_closed_calls.append(
		{"store_id": store_id, "summary": store_summary}
	)


func _on_day_started(day: int) -> void:
	_day_started_days.append(day)
	# day_started resets ObjectiveDirector._loop_completed_today; re-arm it so
	# the multi-close paths in this suite continue to fail open.
	ObjectiveDirector._loop_completed_today = true


# ── Test 1: day_close_requested emits day_closed with revenue payload ─────────

func test_day_close_requested_emits_day_closed() -> void:
	_economy.add_cash(100.0, "sale at pocket_creatures")

	EventBus.day_close_requested.emit()

	assert_eq(
		_day_closed_payloads.size(), 1,
		"day_closed should fire once on day_close_requested"
	)


func test_day_closed_payload_contains_correct_revenue() -> void:
	_economy.add_cash(75.0, "sale at pocket_creatures")
	_economy.record_store_revenue("pocket_creatures", 75.0)

	EventBus.day_close_requested.emit()

	assert_eq(_day_closed_payloads.size(), 1, "day_closed should fire")
	var summary: Dictionary = _day_closed_payloads[0]["summary"]
	assert_true(
		summary.get("total_revenue", 0.0) >= 75.0,
		"total_revenue should include the mock sale"
	)


func test_day_closed_payload_has_required_keys() -> void:
	EventBus.day_close_requested.emit()

	assert_eq(_day_closed_payloads.size(), 1, "day_closed should fire")
	var summary: Dictionary = _day_closed_payloads[0]["summary"]
	for key: String in [
		"day", "total_revenue", "total_expenses",
		"net_profit", "items_sold", "rent",
		"net_cash", "store_revenue",
		"customers_served",
		"backroom_inventory_remaining",
		"shelf_inventory_remaining",
	]:
		assert_true(
			summary.has(key),
			"day_closed summary must contain key: %s" % key
		)


func test_day_closed_payload_day_number_matches() -> void:
	var expected_day: int = _time.current_day

	EventBus.day_close_requested.emit()

	assert_eq(_day_closed_payloads.size(), 1, "day_closed should fire")
	assert_eq(
		_day_closed_payloads[0]["day"], expected_day,
		"day_closed day number should match current_day"
	)


func test_day_closed_net_cash_is_current_balance() -> void:
	var balance: float = _economy.get_cash()

	EventBus.day_close_requested.emit()

	var summary: Dictionary = _day_closed_payloads[0]["summary"]
	assert_eq(
		summary.get("net_cash", -1.0), balance,
		"net_cash should be current cash balance at close"
	)


# ── Test 2: per-store revenue in payload ─────────────────────────────────────

func test_day_closed_store_revenue_dict_populated() -> void:
	_economy.record_store_revenue("pocket_creatures", 50.0)
	_economy.record_store_revenue("retro_games", 30.0)

	EventBus.day_close_requested.emit()

	var store_rev: Dictionary = (
		_day_closed_payloads[0]["summary"].get("store_revenue", {})
	)
	assert_true(
		store_rev.has("pocket_creatures"),
		"store_revenue should include pocket_creatures"
	)
	assert_true(
		store_rev.has("retro_games"),
		"store_revenue should include retro_games"
	)


# ── Test 3: day_ended also triggers day_closed ────────────────────────────────

func test_day_ended_signal_also_emits_day_closed() -> void:
	EventBus.day_ended.emit(1)

	assert_eq(
		_day_closed_payloads.size(), 1,
		"day_ended should also trigger day_closed"
	)


func test_double_close_ignored() -> void:
	EventBus.day_close_requested.emit()
	EventBus.day_close_requested.emit()

	assert_eq(
		_day_closed_payloads.size(), 1,
		"Second day_close_requested before acknowledgement should be ignored"
	)


# ── Test 4: day number increments correctly across multiple days ──────────────

func test_day_increments_across_multiple_days() -> void:
	var day_before: int = _time.current_day

	# Day 1 close
	EventBus.day_close_requested.emit()
	assert_eq(
		_day_closed_payloads[0]["day"], day_before,
		"First close should report current day"
	)
	# Acknowledge to advance
	EventBus.next_day_confirmed.emit()
	assert_eq(
		_time.current_day, day_before + 1,
		"Day should increment after acknowledgement"
	)

	# Day 2 close
	EventBus.day_close_requested.emit()
	assert_eq(
		_day_closed_payloads.size(), 2,
		"Second close should emit another day_closed"
	)
	assert_eq(
		_day_closed_payloads[1]["day"], day_before + 1,
		"Second close should report incremented day"
	)
	# Acknowledge
	EventBus.next_day_confirmed.emit()
	assert_eq(
		_time.current_day, day_before + 2,
		"Day should increment again after second acknowledgement"
	)


func test_day_started_fires_on_advance() -> void:
	EventBus.day_close_requested.emit()
	EventBus.next_day_confirmed.emit()

	assert_true(
		_day_started_days.size() >= 1,
		"day_started should fire after advancing to next day"
	)


# ── Test 5: only DayCycleController emits day_closed ─────────────────────────

func test_day_closed_emitted_exactly_once_per_close() -> void:
	EventBus.day_close_requested.emit()
	EventBus.next_day_confirmed.emit()
	EventBus.day_close_requested.emit()
	EventBus.next_day_confirmed.emit()

	assert_eq(
		_day_closed_payloads.size(), 2,
		"day_closed should fire exactly once per day close"
	)


# ── Test 6: aggregated revenue is correct ────────────────────────────────────

func test_aggregated_revenue_across_stores() -> void:
	_economy.record_store_revenue("pocket_creatures", 40.0)
	_economy.record_store_revenue("retro_games", 60.0)
	# Also add cash to bump total_revenue in daily summary
	_economy.add_cash(100.0, "mock sale")

	EventBus.day_close_requested.emit()

	var summary: Dictionary = _day_closed_payloads[0]["summary"]
	var store_rev: Dictionary = summary.get("store_revenue", {})
	assert_eq(
		store_rev.get("pocket_creatures", 0.0), 40.0,
		"pocket_creatures store revenue should be 40.0"
	)
	assert_eq(
		store_rev.get("retro_games", 0.0), 60.0,
		"retro_games store revenue should be 60.0"
	)
	assert_true(
		summary.get("total_revenue", 0.0) >= 100.0,
		"total_revenue should reflect all sales"
	)
