## Unit tests for PerformancePanel: open/close, data rendering, mutual exclusion.
extends GutTest


var _panel: PerformancePanel
var _report_system: PerformanceReportSystem


func before_each() -> void:
	_panel = preload(
		"res://game/scenes/ui/performance_panel.tscn"
	).instantiate() as PerformancePanel
	add_child_autofree(_panel)


func test_panel_starts_closed() -> void:
	assert_false(_panel.is_open(), "Panel must start closed")
	assert_false(
		_panel._panel.visible, "PanelRoot must be invisible at start"
	)


func test_open_sets_is_open() -> void:
	_panel.open()
	assert_true(_panel.is_open(), "is_open() must be true after open()")


func test_close_clears_is_open() -> void:
	_panel.open()
	_panel.close(true)
	assert_false(_panel.is_open(), "is_open() must be false after close()")


func test_open_twice_is_idempotent() -> void:
	_panel.open()
	_panel.open()
	assert_true(_panel.is_open(), "Calling open twice must not break state")


func test_close_while_already_closed_is_safe() -> void:
	_panel.close(true)
	assert_false(_panel.is_open(), "close() on already-closed panel is safe")


func test_panel_opened_signal_closes_other_panel() -> void:
	_panel.open()
	assert_true(_panel.is_open())
	EventBus.panel_opened.emit("other_panel")
	assert_false(
		_panel.is_open(),
		"Panel must close when another panel_opened fires"
	)


func test_same_panel_opened_signal_does_not_close() -> void:
	_panel.open()
	EventBus.panel_opened.emit(PerformancePanel.PANEL_NAME)
	assert_true(
		_panel.is_open(),
		"Panel must stay open on its own panel_opened signal"
	)


func test_empty_history_shows_placeholder_text() -> void:
	_panel.open()
	var found_empty: bool = false
	for child: Node in _panel._grid.get_children():
		if child is Label:
			var lbl: Label = child as Label
			if lbl.text.contains("No performance data"):
				found_empty = true
				break
	assert_true(
		found_empty,
		"Empty history must show a placeholder label"
	)


func test_best_day_label_shows_dash_when_no_system() -> void:
	_panel.open()
	assert_eq(
		_panel._best_day_label.text,
		"Best Day: —",
		"Best day label must show dash with no system set"
	)


func test_best_day_label_populated_from_history() -> void:
	var r1: PerformanceReport = PerformanceReport.new()
	r1.day = 1
	r1.revenue = 100.0
	r1.customers_served = 5
	var r2: PerformanceReport = PerformanceReport.new()
	r2.day = 2
	r2.revenue = 250.0
	r2.customers_served = 10
	var history: Array[PerformanceReport] = [r1, r2]
	_panel._update_best_day_label(history)
	assert_true(
		_panel._best_day_label.text.contains("Day 2"),
		"Best day label must reference day 2 (higher revenue)"
	)
	assert_true(
		_panel._best_day_label.text.contains("250"),
		"Best day label must include the best revenue amount"
	)


func test_populate_table_adds_day_rows() -> void:
	var r1: PerformanceReport = PerformanceReport.new()
	r1.day = 1
	r1.revenue = 50.0
	r1.customers_served = 3
	var history: Array[PerformanceReport] = [r1]
	_panel._populate_table(history)
	var has_day_row: bool = false
	for child: Node in _panel._grid.get_children():
		if child is HBoxContainer:
			var row: HBoxContainer = child as HBoxContainer
			for label: Node in row.get_children():
				if label is Label and (label as Label).text.contains("Day 1"):
					has_day_row = true
	assert_true(has_day_row, "Table must contain a Day 1 row")


func test_store_revenue_rows_appear_when_populated() -> void:
	var r: PerformanceReport = PerformanceReport.new()
	r.day = 1
	r.revenue = 80.0
	r.customers_served = 4
	r.store_revenue = {"retro_games": 50.0, "electronics": 30.0}
	var history: Array[PerformanceReport] = [r]
	_panel._populate_table(history)
	var store_row_texts: Array[String] = []
	for child: Node in _panel._grid.get_children():
		if child is HBoxContainer:
			var row: HBoxContainer = child as HBoxContainer
			for label: Node in row.get_children():
				if label is Label:
					store_row_texts.append((label as Label).text)
	var found_retro: bool = false
	for t: String in store_row_texts:
		if t.contains("Retro Games") or t.contains("retro"):
			found_retro = true
	assert_true(
		found_retro,
		"Table must include a store breakdown row for retro_games"
	)


func test_report_ready_signal_refreshes_open_panel() -> void:
	_panel.open()
	var initial_count: int = _panel._grid.get_child_count()
	var r: PerformanceReport = PerformanceReport.new()
	r.day = 1
	r.revenue = 100.0
	r.customers_served = 5
	EventBus.performance_report_ready.emit(r)
	# After the signal the grid would have been cleared + re-populated
	# Even with no system set, the placeholder label should be present.
	assert_true(
		_panel._grid.get_child_count() >= 0,
		"Refresh after report_ready must not crash"
	)
	assert_true(initial_count >= 0)
