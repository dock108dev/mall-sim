## Regression: After a Day 1 sale, pressing Close Day must surface a
## DaySummary panel whose rendered labels show "Day 1", a non-zero items
## sold count, and the live revenue value — not placeholders or the
## previous day's snapshot. Walks the full path from item_sold +
## customer_purchased through the close-day gate.
extends GutTest

const STARTING_CASH: float = 200.0
const SALE_PRICE: float = 25.0
const STORE_ID: String = "test_store_day1_summary"
const FLOAT_EPSILON: float = 0.01

var _time: TimeSystem
var _economy: EconomySystem
var _perf_report: PerformanceReportSystem
var _staff: StaffSystem
var _data_loader: DataLoader
var _day_cycle: DayCycleController
var _summary_panel: DaySummary
var _ending_evaluator: EndingEvaluatorSystem
var _reputation: ReputationSystem

var _saved_state: GameManager.State
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]
var _saved_first_sale_flag: bool
var _saved_current_day: int
var _saved_objective_sold: bool


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_first_sale_flag = GameState.get_flag(&"first_sale_complete")
	_saved_current_day = GameManager.get_current_day()
	_saved_objective_sold = ObjectiveDirector._sold

	GameState.reset_new_game()
	GameManager.current_state = GameManager.State.GAMEPLAY
	GameManager.current_store_id = StringName(STORE_ID)
	GameManager.owned_stores = [StringName(STORE_ID)]
	GameManager.set_current_day(1)
	# ObjectiveDirector is an autoload; if a prior test already triggered a
	# first sale its `_sold` latch persists, which would skip the
	# GameState.set_flag(...) branch and leave the gate active.
	ObjectiveDirector._sold = false

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.current_day = 1

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation.initialize_store(STORE_ID)

	_staff = StaffSystem.new()
	add_child_autofree(_staff)
	_staff.initialize(_economy, _reputation, null, _data_loader)

	_ending_evaluator = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_evaluator)
	_ending_evaluator.initialize()

	var panel_scene: PackedScene = load(
		"res://game/scenes/ui/day_summary.tscn"
	)
	_summary_panel = panel_scene.instantiate() as DaySummary
	add_child_autofree(_summary_panel)

	# ProgressionSystem omitted: its milestone evaluation grants cash bonuses
	# on item_sold, which would amplify the asserted sale revenue.
	# DayCycleController._evaluate_milestones() guards against null progression.
	_day_cycle = DayCycleController.new()
	add_child_autofree(_day_cycle)
	_day_cycle.initialize(
		_time, _economy, _staff, null, _ending_evaluator, _perf_report
	)
	_day_cycle.set_day_summary(_summary_panel)


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	GameState.set_flag(&"first_sale_complete", _saved_first_sale_flag)
	GameManager.set_current_day(_saved_current_day)
	ObjectiveDirector._sold = _saved_objective_sold
	GameState.reset_new_game()


## item_sold + customer_purchased on Day 1, then day_close_requested,
## must render Day 1, the live items_sold count, and the live revenue
## into the summary's label text fields.
func test_close_day_renders_live_sale_into_summary_labels() -> void:
	# item_stocked + item_sold reach ObjectiveDirector and complete the
	# stock→sell loop so the Phase-3 close-day gate fails open.
	EventBus.item_stocked.emit("test_item", "shelf_1")
	EventBus.item_sold.emit("test_item", SALE_PRICE, "electronics")
	# customer_purchased credits cash → records a REVENUE transaction summed
	# into total_revenue by EconomySystem.get_daily_summary().
	EventBus.customer_purchased.emit(
		StringName(STORE_ID), &"test_item", SALE_PRICE, &"customer_a"
	)

	assert_true(
		GameState.get_flag(&"first_sale_complete"),
		"item_sold must propagate through ObjectiveDirector to set "
		+ "first_sale_complete before the close-day gate is exercised"
	)

	EventBus.day_close_requested.emit()

	assert_true(
		_summary_panel.visible,
		"DaySummary must be visible after a Day 1 close once the first sale is recorded"
	)
	assert_string_contains(
		_summary_panel._day_label.text, "Day 1",
		"Day label must render Day 1, not a stale or default value"
	)
	# "Items Sold: 1" — the rendered count must reflect the live sale.
	assert_string_contains(
		_summary_panel._items_sold_label.text, "1",
		"Items Sold label text must reflect the live sale count"
	)
	# "Revenue: $25.00" — the rendered revenue must match the sale price.
	assert_string_contains(
		_summary_panel._revenue_label.text, "25",
		"Revenue label text must reflect the live sale price"
	)
	# Snapshot args populated before the panel rendered.
	assert_almost_eq(
		float(_summary_panel._last_summary_args.get("revenue", 0.0)),
		SALE_PRICE, FLOAT_EPSILON,
		"Snapshot revenue must equal the sale price"
	)
	assert_eq(
		int(_summary_panel._last_summary_args.get("day", 0)), 1,
		"Snapshot day must equal 1"
	)


## Phase-3 close-day confirmation gate: when `day_close_requested` reaches the
## controller before the player has completed a stock→sell loop, the controller
## detours through `day_close_confirmation_requested` instead of opening the
## summary. After the player confirms via the modal, `day_close_confirmed`
## drives the same close path so the summary still renders correctly.
func test_close_day_on_day1_renders_summary_after_soft_confirm() -> void:
	GameState.set_flag(&"first_sale_complete", false)
	ObjectiveDirector._sold = false
	ObjectiveDirector._stocked = false
	ObjectiveDirector._loop_completed_today = false
	ObjectiveDirector._current_day = 1

	EventBus.day_close_requested.emit()
	assert_false(
		_summary_panel.visible,
		"DaySummary must NOT render until the player confirms the gate"
	)

	EventBus.day_close_confirmed.emit()

	assert_true(
		_summary_panel.visible,
		"DaySummary must show after the player confirms the close-day modal"
	)
