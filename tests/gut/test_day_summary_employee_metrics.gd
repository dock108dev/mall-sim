## Tests that DaySummary renders the new employee-metrics section: bars for
## customer satisfaction / employee trust / manager trust, plain labels for
## mistakes / variance / discrepancies, and the deferred hidden-thread
## consequence text.
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func _build_report(
	satisfaction: float = 1.0,
	emp_trust: float = 0.0,
	mgr_trust: float = 0.0,
	mistakes: int = 0,
	variance: float = 0.0,
	discrepancies: int = 0,
	hidden: String = "",
) -> PerformanceReport:
	var report := PerformanceReport.new()
	report.day = 1
	report.customer_satisfaction = satisfaction
	report.employee_trust = emp_trust
	report.manager_trust = mgr_trust
	report.mistakes_count = mistakes
	report.inventory_variance = variance
	report.discrepancies_flagged = discrepancies
	report.hidden_thread_consequence_text = hidden
	return report


func test_metrics_section_nodes_present() -> void:
	assert_not_null(_day_summary._customer_satisfaction_bar)
	assert_not_null(_day_summary._employee_trust_bar)
	assert_not_null(_day_summary._manager_trust_bar)
	assert_not_null(_day_summary._mistakes_label)
	assert_not_null(_day_summary._inventory_variance_label)
	assert_not_null(_day_summary._discrepancies_label)
	assert_not_null(_day_summary._hidden_thread_label)


func test_apply_employee_metrics_drives_bar_values() -> void:
	var report: PerformanceReport = _build_report(0.5, 0.7, 0.3, 0, 0.0, 0, "")
	_day_summary._apply_employee_metrics(report)
	assert_almost_eq(
		_day_summary._customer_satisfaction_bar.value, 0.5, 0.01
	)
	assert_almost_eq(_day_summary._employee_trust_bar.value, 0.7, 0.01)
	assert_almost_eq(_day_summary._manager_trust_bar.value, 0.3, 0.01)


func test_apply_employee_metrics_uses_qualitative_label_not_raw_float() -> void:
	var report: PerformanceReport = _build_report(0.85, 0.0, 0.0, 0, 0.0, 0, "")
	_day_summary._apply_employee_metrics(report)
	# Bar carries the value; the label must use a qualitative descriptor —
	# never the raw 0.85 float.
	assert_false(
		_day_summary._customer_satisfaction_label.text.contains("0.85")
	)
	assert_true(
		_day_summary._customer_satisfaction_label.text.contains("Strong")
	)


func test_metric_labels_render_counts_and_percentage() -> void:
	var report: PerformanceReport = _build_report(
		1.0, 0.0, 0.0, 4, 0.123, 2, ""
	)
	_day_summary._apply_employee_metrics(report)
	assert_eq(_day_summary._mistakes_label.text, "Mistakes: 4")
	assert_eq(
		_day_summary._inventory_variance_label.text,
		"Inventory Variance: 12.3%",
	)
	assert_eq(
		_day_summary._discrepancies_label.text,
		"Discrepancies Flagged: 2",
	)


func test_hidden_thread_text_hidden_initially_then_revealed() -> void:
	var report: PerformanceReport = _build_report(
		1.0, 0.0, 0.0, 0, 0.0, 0, "narrative_text"
	)
	_day_summary._apply_employee_metrics(report)
	# The label is hidden until the 1-second timer elapses.
	assert_false(_day_summary._hidden_thread_label.visible)
	assert_false(_day_summary._hidden_thread_separator.visible)
	# Manually fire the timeout to validate the reveal contract without
	# blocking the test on a real-time wait.
	_day_summary._on_hidden_thread_timeout()
	assert_true(_day_summary._hidden_thread_label.visible)
	assert_true(_day_summary._hidden_thread_separator.visible)
	assert_eq(_day_summary._hidden_thread_label.text, "narrative_text")


func test_hidden_thread_empty_keeps_label_hidden() -> void:
	var report: PerformanceReport = _build_report(
		1.0, 0.0, 0.0, 0, 0.0, 0, ""
	)
	_day_summary._apply_employee_metrics(report)
	_day_summary._on_hidden_thread_timeout()
	assert_false(_day_summary._hidden_thread_label.visible)
	assert_false(_day_summary._hidden_thread_separator.visible)


func test_qualitative_label_thresholds() -> void:
	assert_eq(_day_summary._qualitative_label(0.0), "Poor")
	assert_eq(_day_summary._qualitative_label(0.30), "Strained")
	assert_eq(_day_summary._qualitative_label(0.50), "Neutral")
	assert_eq(_day_summary._qualitative_label(0.70), "Steady")
	assert_eq(_day_summary._qualitative_label(0.90), "Strong")


func test_panel_layout_has_no_grid_or_table_container() -> void:
	# Single-column vertical layout requirement: every metric label / bar
	# parent must be the VBox (or a descendant container that is a VBox).
	var vbox: VBoxContainer = _day_summary.get_node(
		"Root/Panel/Margin/VBox"
	) as VBoxContainer
	for node: Node in [
		_day_summary._customer_satisfaction_label,
		_day_summary._customer_satisfaction_bar,
		_day_summary._employee_trust_label,
		_day_summary._employee_trust_bar,
		_day_summary._manager_trust_label,
		_day_summary._manager_trust_bar,
		_day_summary._mistakes_label,
		_day_summary._inventory_variance_label,
		_day_summary._discrepancies_label,
		_day_summary._hidden_thread_label,
	]:
		assert_eq(
			node.get_parent(), vbox,
			"%s parented outside single-column VBox" % node.name,
		)
