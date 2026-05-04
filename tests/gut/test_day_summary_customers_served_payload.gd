## Day summary must surface customers_served from the day_closed payload so
## the BRAINDUMP 'Customers Served: 1' field is self-contained (no need to
## also subscribe to performance_report_ready). DayCycleController populates
## the key from PerformanceReportSystem.get_daily_customers_served().
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func test_customers_served_label_present_in_scene() -> void:
	var label: Label = _day_summary.get_node_or_null(
		"Root/Panel/Margin/VBox/CustomersServedLabel"
	)
	assert_not_null(
		label,
		"DaySummary must include CustomersServedLabel for the BRAINDUMP "
		+ "'Customers Served' field"
	)


func test_customers_served_populated_from_day_closed_payload() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 100.0,
		"items_sold": 3,
		"customers_served": 4,
		"store_revenue": {},
	}
	EventBus.day_closed.emit(1, payload)
	assert_string_contains(
		_day_summary._customers_served_label.text, "4",
		"CustomersServedLabel must reflect customers_served from "
		+ "EventBus.day_closed payload"
	)


func test_customers_served_payload_handles_zero() -> void:
	_day_summary.show_summary(1, 0.0, 0.0, 0.0, 0)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 0.0,
		"items_sold": 0,
		"customers_served": 0,
		"store_revenue": {},
	}
	EventBus.day_closed.emit(1, payload)
	assert_string_contains(
		_day_summary._customers_served_label.text, "0",
		"CustomersServedLabel must show 0 when no customers were served"
	)
