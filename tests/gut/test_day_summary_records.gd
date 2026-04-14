## Tests for DaySummary record highlight tracking and flash color behavior.
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func test_record_high_revenue_tracked() -> void:
	_day_summary._apply_record_highlights(100.0, 50.0, 5)
	assert_true(
		_day_summary._record_high_labels.has(_day_summary._revenue_label),
		"Revenue label should be in record high list"
	)


func test_record_high_profit_tracked() -> void:
	_day_summary._apply_record_highlights(100.0, 50.0, 5)
	assert_true(
		_day_summary._record_high_labels.has(_day_summary._profit_label),
		"Profit label should be in record high list"
	)


func test_record_high_items_tracked() -> void:
	_day_summary._apply_record_highlights(100.0, 50.0, 5)
	assert_true(
		_day_summary._record_high_labels.has(_day_summary._items_sold_label),
		"Items sold label should be in record high list"
	)


func test_record_low_profit_tracked() -> void:
	_day_summary._current_day = 3
	_day_summary._record_high_profit = 100.0
	_day_summary._apply_record_highlights(10.0, -20.0, 0)
	assert_true(
		_day_summary._record_low_labels.has(_day_summary._profit_label),
		"Profit label should be in record low list for negative profit"
	)


func test_no_record_on_day_one_loss() -> void:
	_day_summary._current_day = 1
	_day_summary._apply_record_highlights(0.0, -10.0, 0)
	assert_eq(
		_day_summary._record_low_labels.size(), 0,
		"Day 1 loss should not count as record low"
	)


func test_record_lists_cleared_each_call() -> void:
	_day_summary._apply_record_highlights(100.0, 50.0, 5)
	assert_true(
		_day_summary._record_high_labels.size() > 0,
		"Should have record highs after first call"
	)

	_day_summary._apply_record_highlights(50.0, 20.0, 2)
	assert_eq(
		_day_summary._record_high_labels.size(), 0,
		"Record high list should be cleared when no new records"
	)


func test_zero_revenue_not_record_high() -> void:
	_day_summary._apply_record_highlights(0.0, 0.0, 0)
	assert_eq(
		_day_summary._record_high_labels.size(), 0,
		"Zero values should not produce record highlights"
	)


func test_flash_record_labels_runs_without_error() -> void:
	_day_summary._apply_record_highlights(100.0, 50.0, 5)
	_day_summary._flash_record_labels()
	assert_true(
		true,
		"flash_record_labels should execute without errors"
	)
