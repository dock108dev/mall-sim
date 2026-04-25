## Tests that DaySummary shows customer-count delta vs previous day.
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func _make_report(day: int, customers: int) -> PerformanceReport:
	var r := PerformanceReport.new()
	r.day = day
	r.customers_served = customers
	r.revenue = 0.0
	r.profit = 0.0
	return r


func test_no_delta_on_first_report() -> void:
	EventBus.performance_report_ready.emit(_make_report(1, 10))
	assert_false(
		_day_summary._customers_served_label.text.contains("vs yesterday"),
		"First report must not show a delta"
	)
	assert_true(
		_day_summary._customers_served_label.text.contains("10"),
		"First report must show the customer count"
	)


func test_positive_delta_shown_on_second_report() -> void:
	EventBus.performance_report_ready.emit(_make_report(1, 10))
	EventBus.performance_report_ready.emit(_make_report(2, 15))
	assert_true(
		_day_summary._customers_served_label.text.contains("+5"),
		"Positive delta must show +N"
	)
	assert_true(
		_day_summary._customers_served_label.text.contains("vs yesterday"),
		"Delta must include 'vs yesterday'"
	)


func test_negative_delta_shown_correctly() -> void:
	EventBus.performance_report_ready.emit(_make_report(1, 20))
	EventBus.performance_report_ready.emit(_make_report(2, 14))
	var text: String = _day_summary._customers_served_label.text
	assert_true(
		text.contains("-6") or text.contains("6"),
		"Negative delta must include the count difference"
	)
	assert_true(
		text.contains("vs yesterday"),
		"Negative delta must include 'vs yesterday'"
	)


func test_flat_delta_shown_correctly() -> void:
	EventBus.performance_report_ready.emit(_make_report(1, 8))
	EventBus.performance_report_ready.emit(_make_report(2, 8))
	assert_true(
		_day_summary._customers_served_label.text.contains("flat"),
		"Flat customer count must show 'flat'"
	)


func test_same_day_report_does_not_advance_prev() -> void:
	EventBus.performance_report_ready.emit(_make_report(1, 10))
	EventBus.performance_report_ready.emit(_make_report(1, 12))
	assert_false(
		_day_summary._customers_served_label.text.contains("vs yesterday"),
		"Re-emitting for the same day must not set a delta"
	)
