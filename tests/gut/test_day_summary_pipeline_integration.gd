## Integration test: day_ended → EconomySystem snapshot → DaySummaryPanel display.
## Covers ISSUE-467: verifies the full data pipeline from real transactions to UI labels.
extends GutTest


const PANEL_SCENE := preload("res://game/scenes/ui/day_summary_panel.tscn")

var _economy: EconomySystem
var _perf_report: PerformanceReportSystem
var _panel: DaySummaryPanel
var _saved_tier: StringName = &"normal"
var _saved_owned_stores: Array = []
var _saved_current_store_id: StringName = &""
var _saved_day_started_connections: Array[Callable] = []
var _saved_day_ended_connections: Array[Callable] = []


func before_each() -> void:
	_saved_tier = DifficultySystemSingleton.get_current_tier_id()
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_current_store_id = GameManager.current_store_id
	DifficultySystemSingleton.set_tier(&"normal")
	GameManager.owned_stores = []
	GameManager.current_store_id = &""
	_saved_day_started_connections = _disconnect_signal(EventBus.day_started)
	_saved_day_ended_connections = _disconnect_signal(EventBus.day_ended)
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(10000.0)

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()

	_panel = PANEL_SCENE.instantiate() as DaySummaryPanel
	add_child_autofree(_panel)


func after_each() -> void:
	if _panel != null:
		_panel.free()
		_panel = null
	if _perf_report != null:
		_perf_report.free()
		_perf_report = null
	if _economy != null:
		_economy.free()
		_economy = null
	_restore_signal(EventBus.day_started, _saved_day_started_connections)
	_restore_signal(EventBus.day_ended, _saved_day_ended_connections)
	GameManager.owned_stores = _saved_owned_stores.duplicate()
	GameManager.current_store_id = _saved_current_store_id
	DifficultySystemSingleton.set_tier(_saved_tier)


func _disconnect_signal(signal_ref: Signal) -> Array[Callable]:
	var callables: Array[Callable] = []
	for connection: Dictionary in signal_ref.get_connections():
		var callable: Callable = connection.get("callable", Callable()) as Callable
		if callable.is_valid():
			callables.append(callable)
			signal_ref.disconnect(callable)
	return callables


func _restore_signal(signal_ref: Signal, callables: Array[Callable]) -> void:
	for callable: Callable in callables:
		if callable.is_valid() and not signal_ref.is_connected(callable):
			signal_ref.connect(callable)


func test_revenue_label_shows_sum_of_customer_purchases() -> void:
	EventBus.day_started.emit(1)
	EventBus.customer_purchased.emit(&"sports", &"item_a", 100.0, &"cust_1")
	EventBus.customer_purchased.emit(&"sports", &"item_b", 50.0, &"cust_2")
	EventBus.day_ended.emit(1)
	assert_eq(
		_panel._revenue_label.text, "Revenue: $150.00",
		"Revenue label must match sum of customer purchases"
	)


func test_expenses_label_shows_stock_and_maintenance_charges() -> void:
	EventBus.day_started.emit(1)
	_economy.charge(75.0, "Stock purchase")
	_economy.charge(25.0, "Maintenance")
	EventBus.day_ended.emit(1)
	assert_eq(
		_panel._expenses_label.text, "Expenses: -$100.00",
		"Expenses label must match sum of charges"
	)


func test_wages_label_matches_staff_wages_paid_signal() -> void:
	EventBus.day_started.emit(1)
	EventBus.staff_wages_paid.emit(80.0)
	EventBus.day_ended.emit(1)
	assert_eq(
		_panel._wages_label.text, "Wages: -$80.00",
		"Wages label must match staff_wages_paid amount"
	)


func test_net_label_positive_with_green_color() -> void:
	EventBus.day_started.emit(1)
	EventBus.customer_purchased.emit(&"sports", &"item_a", 200.0, &"cust_1")
	_economy.charge(50.0, "Stock purchase")
	EventBus.day_ended.emit(1)
	assert_eq(
		_panel._net_label.text, "NET PROFIT: +$150.00",
		"Net label must show positive sign when revenue > expenses"
	)
	var color: Color = _panel._net_label.get_theme_color("font_color")
	assert_eq(
		color, DaySummaryPanel.NET_POSITIVE_COLOR,
		"Positive net must use green color"
	)


func test_net_label_negative_with_red_color() -> void:
	EventBus.day_started.emit(1)
	EventBus.customer_purchased.emit(&"sports", &"item_a", 30.0, &"cust_1")
	_economy.charge(80.0, "Stock purchase")
	EventBus.day_ended.emit(1)
	assert_eq(
		_panel._net_label.text, "NET LOSS: -$50.00",
		"Net label must show negative sign when expenses > revenue"
	)
	var color: Color = _panel._net_label.get_theme_color("font_color")
	assert_eq(
		color, DaySummaryPanel.NET_NEGATIVE_COLOR,
		"Negative net must use red color"
	)


func test_next_day_emits_next_day_confirmed_and_hides_panel() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_ended.emit(1)
	_panel._acknowledge_button.disabled = false

	var signal_fired: Array = [false]
	EventBus.next_day_confirmed.connect(
		func() -> void: signal_fired[0] = true
	)
	_panel._on_acknowledge_pressed()

	assert_true(
		signal_fired[0],
		"next_day_confirmed must emit when next day is pressed"
	)
	await get_tree().create_timer(0.5).timeout
	assert_false(
		_panel.visible,
		"Panel must hide after acknowledge is pressed"
	)


func test_zero_transaction_day_shows_all_zeros_without_errors() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_ended.emit(1)
	assert_eq(
		_panel._revenue_label.text, "Revenue: $0.00",
		"Revenue must be zero when no sales occurred"
	)
	assert_eq(
		_panel._expenses_label.text, "Expenses: -$0.00",
		"Expenses must be zero when no charges occurred"
	)
	assert_eq(
		_panel._wages_label.text, "Wages: -$0.00",
		"Wages must be zero when no wages were paid"
	)
	assert_eq(
		_panel._net_label.text, "NET PROFIT: $0.00",
		"Net must be zero when no transactions occurred"
	)
	var color: Color = _panel._net_label.get_theme_color("font_color")
	assert_eq(color, DaySummaryPanel.NET_ZERO_COLOR)
	assert_true(_panel.visible, "Panel must be visible even on zero-transaction day")
