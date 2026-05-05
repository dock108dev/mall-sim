## Day summary must surface the per-reason customer breakdown and a derived
## total-customers count (BRAINDUMP step 30: 'Customer count' + 'Any failed
## customer reasons'). The breakdown comes from the shift_summary sub-dict
## of the day_closed payload (customers_happy / customers_no_stock /
## customers_timeout / customers_price), populated from
## CustomerSystem.get_leave_counts().
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func test_total_customers_label_present_after_ready() -> void:
	assert_not_null(
		_day_summary._total_customers_label,
		"DaySummary must instantiate _total_customers_label so the panel can "
		+ "show the BRAINDUMP step-30 'Customer count' field"
	)


func test_customer_breakdown_label_present_after_ready() -> void:
	assert_not_null(
		_day_summary._customer_breakdown_label,
		"DaySummary must instantiate _customer_breakdown_label so the panel "
		+ "can show the BRAINDUMP step-30 'failed customer reasons' field"
	)


func test_total_customers_populated_from_shift_summary() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 100.0,
		"items_sold": 3,
		"store_revenue": {},
		"shift_summary": {
			"customers_happy": 2,
			"customers_no_stock": 1,
			"customers_timeout": 1,
			"customers_price": 0,
		},
	}
	EventBus.day_closed.emit(1, payload)
	assert_true(
		_day_summary._total_customers_label.visible,
		"TotalCustomersLabel must be visible when any customer was tracked"
	)
	assert_string_contains(
		_day_summary._total_customers_label.text, "4",
		"TotalCustomersLabel must equal the sum of customers_happy + "
		+ "customers_no_stock + customers_timeout + customers_price"
	)


func test_customer_breakdown_lists_nonzero_reasons() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 100.0,
		"items_sold": 3,
		"store_revenue": {},
		"shift_summary": {
			"customers_happy": 3,
			"customers_no_stock": 2,
			"customers_timeout": 0,
			"customers_price": 1,
		},
	}
	EventBus.day_closed.emit(1, payload)
	assert_true(
		_day_summary._customer_breakdown_label.visible,
		"CustomerBreakdownLabel must be visible when any reason has a count"
	)
	var text: String = _day_summary._customer_breakdown_label.text
	assert_string_contains(
		text, "3", "Breakdown must show the happy count"
	)
	assert_string_contains(
		text, "2", "Breakdown must show the no_stock count"
	)
	assert_string_contains(
		text, "1", "Breakdown must show the price count"
	)
	assert_false(
		"out of patience" in text,
		"Breakdown must omit reason rows whose count is zero"
	)


func test_breakdown_hidden_when_no_customers() -> void:
	# Defensive: legacy/test payloads with no shift_summary or all zero
	# breakdown must still render cleanly with the breakdown rows hidden.
	_day_summary.show_summary(1, 0.0, 0.0, 0.0, 0)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 0.0,
		"items_sold": 0,
		"store_revenue": {},
	}
	EventBus.day_closed.emit(1, payload)
	assert_false(
		_day_summary._total_customers_label.visible,
		"TotalCustomersLabel must hide when no customers are tracked"
	)
	assert_false(
		_day_summary._customer_breakdown_label.visible,
		"CustomerBreakdownLabel must hide when no customers are tracked"
	)
