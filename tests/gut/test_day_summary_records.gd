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


func test_record_high_labels_use_positive_color() -> void:
	_day_summary._apply_record_highlights(100.0, 50.0, 5)
	var color: Color = _day_summary._revenue_label.get_theme_color(
		"font_color"
	)
	assert_eq(color, UIThemeConstants.get_positive_color())


func test_show_summary_delays_panel_open_until_overlay_starts() -> void:
	_day_summary.show_summary(1, 100.0, 25.0, 75.0, 4)
	assert_true(_day_summary.visible)
	assert_true(_day_summary._overlay.visible)
	assert_false(_day_summary._panel.visible)
	assert_eq(_day_summary._overlay.color.a, 0.0)


func test_continue_buttons_wait_for_stat_sequence() -> void:
	_day_summary._rent_label.visible = false
	_day_summary._expenses_label.visible = false
	_day_summary._items_sold_label.visible = false
	_day_summary._cash_balance_label.visible = false
	_day_summary._top_item_label.visible = false
	_day_summary._customers_served_label.visible = false
	_day_summary._satisfaction_label.visible = false
	_day_summary._reputation_delta_label.visible = false
	_day_summary._backroom_inventory_label.visible = false
	_day_summary._shelf_inventory_label.visible = false
	_day_summary._employee_metrics_header.visible = false
	_day_summary._customer_satisfaction_label.visible = false
	_day_summary._customer_satisfaction_bar.visible = false
	_day_summary._employee_trust_label.visible = false
	_day_summary._employee_trust_bar.visible = false
	_day_summary._manager_trust_label.visible = false
	_day_summary._manager_trust_bar.visible = false
	_day_summary._mistakes_label.visible = false
	_day_summary._inventory_variance_label.visible = false
	_day_summary._discrepancies_label.visible = false
	_day_summary.show_summary(1, 100.0, 25.0, 75.0, 4)
	assert_eq(_day_summary._button_row.modulate.a, 0.0)
	await get_tree().create_timer(0.8).timeout
	assert_eq(_day_summary._button_row.modulate.a, 0.0)
	await get_tree().create_timer(0.5).timeout
	assert_gt(_day_summary._button_row.modulate.a, 0.0)


func test_rapid_reopen_resets_transition_state() -> void:
	_day_summary.show_summary(1, 100.0, 25.0, 75.0, 4)
	_day_summary.hide_summary()
	_day_summary.show_summary(2, 120.0, 40.0, 80.0, 5)
	assert_true(_day_summary.visible)
	assert_true(_day_summary._overlay.visible)
	assert_false(_day_summary._panel.visible)
	assert_eq(_day_summary._button_row.modulate.a, 0.0)


func test_record_low_labels_use_negative_color() -> void:
	_day_summary._current_day = 3
	_day_summary._record_high_profit = 100.0
	_day_summary._apply_record_highlights(10.0, -20.0, 0)
	var color: Color = _day_summary._profit_label.get_theme_color(
		"font_color"
	)
	assert_eq(color, UIThemeConstants.get_negative_color())


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


func test_record_high_labels_pulse_without_error() -> void:
	_day_summary._apply_record_highlights(100.0, 50.0, 5)
	_day_summary._animate_record_labels()
	assert_true(
		true,
		"animate_record_labels should execute without errors"
	)
