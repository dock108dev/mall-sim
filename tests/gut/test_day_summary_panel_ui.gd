## Tests for ISSUE-414 DaySummaryPanel UI scene.
extends GutTest


const PANEL_SCENE := preload(
	"res://game/scenes/ui/day_summary_panel.tscn"
)

var _panel: DaySummaryPanel


func before_each() -> void:
	_panel = PANEL_SCENE.instantiate() as DaySummaryPanel
	add_child_autofree(_panel)


func test_panel_hidden_on_ready() -> void:
	assert_false(_panel.visible, "Panel should start hidden")


func test_panel_shows_on_day_ended() -> void:
	EventBus.day_ended.emit(1)
	assert_true(_panel.visible, "Panel should show on day_ended")


func test_title_shows_day_number() -> void:
	EventBus.day_ended.emit(3)
	assert_eq(_panel._title_label.text, "Day 3 Complete")


func test_revenue_displayed_from_report() -> void:
	var report := _make_report(150.0, 40.0, 110.0)
	EventBus.performance_report_ready.emit(report)
	EventBus.day_ended.emit(1)
	assert_eq(_panel._revenue_label.text, "Revenue: $150.00")


func test_expenses_displayed_from_report() -> void:
	var report := _make_report(100.0, 60.0, 40.0)
	EventBus.performance_report_ready.emit(report)
	EventBus.day_ended.emit(1)
	assert_eq(_panel._expenses_label.text, "Expenses: -$60.00")


func test_wages_displayed() -> void:
	EventBus.staff_wages_paid.emit(25.0)
	EventBus.day_ended.emit(1)
	assert_eq(_panel._wages_label.text, "Wages: -$25.00")


func test_net_positive_green() -> void:
	var report := _make_report(200.0, 50.0, 150.0)
	EventBus.performance_report_ready.emit(report)
	EventBus.day_ended.emit(1)
	assert_eq(_panel._net_label.text, "NET PROFIT: +$150.00")
	var color: Color = _panel._net_label.get_theme_color("font_color")
	assert_eq(color, DaySummaryPanel.NET_POSITIVE_COLOR)


func test_net_negative_red() -> void:
	var report := _make_report(50.0, 100.0, -50.0)
	EventBus.performance_report_ready.emit(report)
	EventBus.day_ended.emit(1)
	assert_eq(_panel._net_label.text, "NET LOSS: -$50.00")
	var color: Color = _panel._net_label.get_theme_color("font_color")
	assert_eq(color, DaySummaryPanel.NET_NEGATIVE_COLOR)


func test_net_zero_white() -> void:
	var report := _make_report(100.0, 100.0, 0.0)
	EventBus.performance_report_ready.emit(report)
	EventBus.day_ended.emit(1)
	assert_eq(_panel._net_label.text, "NET PROFIT: $0.00")
	var color: Color = _panel._net_label.get_theme_color("font_color")
	assert_eq(color, DaySummaryPanel.NET_ZERO_COLOR)


func test_milestone_hidden_when_empty() -> void:
	var report := _make_report(100.0, 50.0, 50.0)
	EventBus.performance_report_ready.emit(report)
	EventBus.day_ended.emit(1)
	assert_false(
		_panel._milestone_banner.visible,
		"Milestone banner should be hidden when no milestones"
	)


func test_milestone_shown_when_present() -> void:
	var report := _make_report(100.0, 50.0, 50.0)
	report.milestones_unlocked = ["First Sale"]
	EventBus.performance_report_ready.emit(report)
	EventBus.day_ended.emit(1)
	assert_true(
		_panel._milestone_banner.visible,
		"Milestone banner should be visible"
	)
	assert_string_contains(
		_panel._milestone_banner.text, "First Sale"
	)


func test_record_high_revenue_row_tracked() -> void:
	var report := _make_report(100.0, 50.0, 50.0)
	report.record_flags = {"best_day_revenue": true}
	EventBus.performance_report_ready.emit(report)
	EventBus.day_ended.emit(1)
	assert_true(
		_panel._record_high_rows.has(_panel._revenue_label),
		"Revenue row should be tracked as record high"
	)


func test_record_low_revenue_row_tracked() -> void:
	var report := _make_report(10.0, 50.0, -40.0)
	report.record_flags = {"worst_day_revenue": true}
	EventBus.performance_report_ready.emit(report)
	EventBus.day_ended.emit(2)
	assert_true(
		_panel._record_low_rows.has(_panel._revenue_label),
		"Revenue row should be tracked as record low"
	)


func test_flash_record_rows_runs_without_error() -> void:
	var report := _make_report(100.0, 50.0, 50.0)
	report.record_flags = {"best_day_revenue": true}
	EventBus.performance_report_ready.emit(report)
	EventBus.day_ended.emit(1)
	_panel._flash_record_rows()
	assert_true(true, "Record row flash should execute")


func test_acknowledge_button_disabled_initially() -> void:
	EventBus.day_ended.emit(1)
	assert_true(
		_panel._acknowledge_button.disabled,
		"Acknowledge button should be disabled for 1 second"
	)


func test_next_day_emits_next_day_confirmed() -> void:
	EventBus.day_ended.emit(1)
	_panel._acknowledge_button.disabled = false
	var signal_fired: Array = [false]
	EventBus.next_day_confirmed.connect(
		func() -> void: signal_fired[0] = true
	)
	_panel._on_acknowledge_pressed()
	assert_true(
		signal_fired[0],
		"next_day_confirmed should fire on next day press"
	)


func test_acknowledge_closes_panel() -> void:
	EventBus.day_ended.emit(1)
	_panel._acknowledge_button.disabled = false
	_panel._on_acknowledge_pressed()
	await get_tree().create_timer(0.5).timeout
	assert_false(
		_panel.visible,
		"Panel should close after acknowledge"
	)


func test_day_acknowledged_emits_after_panel_dismisses() -> void:
	EventBus.day_ended.emit(1)
	_panel._acknowledge_button.disabled = false
	var signal_fired: Array = [false]
	var dismissed_fired: Array = [false]
	EventBus.day_acknowledged.connect(
		func() -> void: signal_fired[0] = true
	)
	_panel.dismissed.connect(
		func() -> void: dismissed_fired[0] = true
	)
	_panel._on_acknowledge_pressed()
	assert_false(
		signal_fired[0],
		"day_acknowledged should wait until the panel is dismissed"
	)
	await get_tree().create_timer(0.5).timeout
	assert_true(dismissed_fired[0], "dismissed should fire after the panel closes")
	assert_true(
		signal_fired[0],
		"day_acknowledged should fire after the panel closes"
	)


func test_day_acknowledged_signal_exists() -> void:
	assert_true(
		EventBus.has_signal("day_acknowledged"),
		"EventBus must have day_acknowledged signal"
	)


func test_show_summary_dictionary_populates_sales_fields() -> void:
	_panel.show_summary({
		"day": 4,
		"revenue": 250.0,
		"expenses": 75.0,
		"net_profit": 175.0,
		"total_items_sold": 9,
		"bestseller": {"item_name": "Foil Starter", "quantity": 3},
		"bestseller_quantity": 3,
		"haggle_wins": 2,
		"haggle_losses": 1,
	})
	assert_eq(_panel._title_label.text, "Day 4 Complete")
	assert_eq(_panel._revenue_label.text, "Revenue: $250.00")
	assert_eq(_panel._net_label.text, "NET PROFIT: +$175.00")
	assert_eq(_panel._report_detail_labels[0].text, "Items Sold: 9")
	assert_eq(
		_panel._report_detail_labels[5].text,
		"Top Seller: Foil Starter (x3)"
	)
	assert_eq(
		_panel._report_detail_labels[6].text,
		"Haggling: 2 won / 1 lost"
	)


func test_show_summary_uses_net_profit_without_recomputing() -> void:
	_panel.show_summary({
		"day": 4,
		"revenue": 250.0,
		"expenses": 75.0,
		"net_profit": -10.0,
	})
	assert_eq(_panel._net_label.text, "NET LOSS: -$10.00")


func test_review_inventory_closes_and_emits_request() -> void:
	EventBus.day_ended.emit(1)
	var signal_fired: Array = [false]
	_panel.review_inventory_requested.connect(
		func() -> void: signal_fired[0] = true
	)
	_panel._on_review_inventory_pressed()
	assert_true(signal_fired[0], "review inventory request should emit")


func test_reputation_shows_indicator() -> void:
	var report := _make_report(100.0, 50.0, 50.0)
	report.reputation_delta = 5.0
	EventBus.performance_report_ready.emit(report)
	EventBus.day_ended.emit(1)
	var children: Array[Node] = (
		_panel._reputation_container.get_children()
	)
	assert_gt(
		children.size(), 0,
		"Reputation container should have children"
	)


func _make_report(
	revenue: float, expenses: float, profit: float
) -> PerformanceReport:
	var report := PerformanceReport.new()
	report.day = 1
	report.revenue = revenue
	report.expenses = expenses
	report.profit = profit
	return report
