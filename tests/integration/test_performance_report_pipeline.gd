## Integration test: day_ended → revenue snapshot → report_ready with correct financial figures.
extends GutTest

const STARTING_CASH: float = 1000.0
const FLOAT_EPSILON: float = 0.01

var _economy: EconomySystem
var _perf_report: PerformanceReportSystem

var _saved_state: GameManager.State
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()

	GameManager.current_state = GameManager.State.GAMEPLAY
	GameManager.current_store_id = &""
	# No owned stores so rent deductions do not pollute expense totals.
	GameManager.owned_stores = []

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	# PerformanceReportSystem connects after EconomySystem so that
	# daily_financials_snapshot is cached before _build_report runs.
	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores


## Scenario 1: Seeded revenue and expenses produce correct figures in the emitted report.
func test_revenue_and_expenses_match_seeded_transactions() -> void:
	var revenue: float = 350.0
	var expenses: float = 120.0
	_economy.add_cash(revenue, "test_sales")
	_economy.force_deduct_cash(expenses, "test_expenses")

	watch_signals(EventBus)
	EventBus.day_ended.emit(1)

	assert_signal_emitted(
		EventBus,
		"performance_report_ready",
		"performance_report_ready must fire after day_ended"
	)

	var history: Array[PerformanceReport] = _perf_report.get_history()
	assert_eq(history.size(), 1, "Exactly one report must be in history")

	var report: PerformanceReport = history.back()
	assert_almost_eq(
		report.revenue, revenue, FLOAT_EPSILON,
		"report.revenue must equal seeded revenue total"
	)
	assert_almost_eq(
		report.expenses, expenses, FLOAT_EPSILON,
		"report.expenses must equal seeded expense total"
	)
	assert_almost_eq(
		report.profit, revenue - expenses, FLOAT_EPSILON,
		"report.profit must equal revenue minus expenses"
	)


## Scenario 2: Zero-transaction day produces a report with all financial values at 0.
func test_zero_transaction_day_report() -> void:
	watch_signals(EventBus)
	EventBus.day_ended.emit(1)

	assert_signal_emitted(
		EventBus,
		"performance_report_ready",
		"performance_report_ready must fire even on a zero-transaction day"
	)

	var history: Array[PerformanceReport] = _perf_report.get_history()
	assert_eq(history.size(), 1, "One report must be generated")

	var report: PerformanceReport = history.back()
	assert_almost_eq(
		report.revenue, 0.0, FLOAT_EPSILON,
		"report.revenue must be 0 on a zero-transaction day"
	)
	assert_almost_eq(
		report.expenses, 0.0, FLOAT_EPSILON,
		"report.expenses must be 0 on a zero-transaction day"
	)
	assert_almost_eq(
		report.profit, 0.0, FLOAT_EPSILON,
		"report.profit must be 0 on a zero-transaction day"
	)


## Scenario 3: Expenses exceeding revenue yield a negative profit without clamping.
func test_negative_net_profit_not_clamped() -> void:
	var revenue: float = 50.0
	var expenses: float = 200.0
	_economy.add_cash(revenue, "test_sales")
	_economy.force_deduct_cash(expenses, "test_expenses")

	watch_signals(EventBus)
	EventBus.day_ended.emit(1)

	assert_signal_emitted(
		EventBus,
		"performance_report_ready",
		"performance_report_ready must fire when expenses exceed revenue"
	)

	var history: Array[PerformanceReport] = _perf_report.get_history()
	assert_eq(history.size(), 1, "One report must be generated")

	var report: PerformanceReport = history.back()
	assert_true(
		report.profit < 0.0,
		"report.profit must be negative when expenses exceed revenue"
	)
	assert_almost_eq(
		report.profit, revenue - expenses, FLOAT_EPSILON,
		"report.profit must equal revenue - expenses without clamping"
	)


## Scenario 4: report_ready fires exactly once per day_ended emission.
func test_report_ready_fires_exactly_once_per_day() -> void:
	watch_signals(EventBus)
	EventBus.day_ended.emit(1)

	assert_signal_emit_count(
		EventBus,
		"performance_report_ready",
		1,
		"performance_report_ready must fire exactly once per day_ended"
	)
