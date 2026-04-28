## Regression: Day Summary panel must display non-zero revenue and items_sold
## after a real sale, captured at day_ended time before any reset fires.
## Locks in the snapshot pattern: DayCycleController reads economy data on
## EventBus.day_ended and pushes it by-value into DaySummary.show_summary()
## before EconomySystem._on_day_started → reset_daily_totals() can zero state.
extends GutTest

const STARTING_CASH: float = 200.0
const SALE_PRICE: float = 25.0
const STORE_ID: String = "test_store"
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


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()

	GameManager.current_state = GameManager.State.GAMEPLAY
	GameManager.current_store_id = StringName(STORE_ID)
	GameManager.owned_stores = [StringName(STORE_ID)]

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

	var panel_scene: PackedScene = load("res://game/scenes/ui/day_summary.tscn")
	_summary_panel = panel_scene.instantiate() as DaySummary
	add_child_autofree(_summary_panel)

	# ProgressionSystem intentionally omitted: its milestone evaluation grants
	# cash bonuses on item_sold, which would amplify the asserted sale revenue.
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


func _emit_completed_sale() -> void:
	# CheckoutSystem._execute_normal_sale emits both signals on a real sale:
	# item_sold increments _items_sold_today; customer_purchased credits cash
	# (which records a REVENUE transaction summed by get_daily_summary()).
	EventBus.item_sold.emit("test_item", SALE_PRICE, "electronics")
	EventBus.customer_purchased.emit(
		StringName(STORE_ID), &"test_item", SALE_PRICE, &"customer_a"
	)


## After a completed sale, the panel must show items_sold >= 1 and
## revenue > 0.0 — both values captured at day_ended time.
func test_day_summary_displays_revenue_and_items_after_sale() -> void:
	_emit_completed_sale()

	assert_eq(
		_economy.get_items_sold_today(), 1,
		"Sanity: item_sold signal should increment items_sold_today"
	)
	assert_almost_eq(
		_economy.get_daily_summary().get("total_revenue", 0.0),
		SALE_PRICE, FLOAT_EPSILON,
		"Sanity: customer_purchased should credit revenue via _apply_credit"
	)

	EventBus.day_ended.emit(1)

	var args: Dictionary = _summary_panel._last_summary_args
	assert_gt(
		int(args.get("items_sold", 0)), 0,
		"DaySummary items_sold must be >=1 after a completed sale"
	)
	assert_gt(
		float(args.get("revenue", 0.0)), 0.0,
		"DaySummary revenue must be >0 after a completed sale"
	)
	assert_almost_eq(
		float(args.get("revenue", 0.0)), SALE_PRICE, FLOAT_EPSILON,
		"DaySummary revenue should match the sale price"
	)


## Acknowledging the day must not flash zero values into the labels even
## though EconomySystem.reset_daily_totals() fires as part of day_started.
## Labels are populated from snapshot args and must remain stable.
func test_acknowledge_does_not_flash_zero_into_summary_labels() -> void:
	_emit_completed_sale()
	EventBus.day_ended.emit(1)

	var revenue_text_before: String = _summary_panel._revenue_label.text
	var items_text_before: String = _summary_panel._items_sold_label.text

	# Continue → hide animation kicks off, next_day_confirmed fires,
	# DayCycleController._on_day_acknowledged calls advance_to_next_day,
	# which fires day_started → EconomySystem.reset_daily_totals().
	_summary_panel.hide_summary()
	EventBus.next_day_confirmed.emit()

	assert_eq(
		_economy.get_items_sold_today(), 0,
		"Sanity: economy state must be reset after day_started fires"
	)
	assert_eq(
		_summary_panel._revenue_label.text, revenue_text_before,
		"Revenue label text must not change after acknowledgement"
	)
	assert_eq(
		_summary_panel._items_sold_label.text, items_text_before,
		"Items sold label text must not change after acknowledgement"
	)
