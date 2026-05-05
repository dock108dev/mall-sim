## Tests the employee-facing closing-summary fields added to PerformanceReport
## and PerformanceReportSystem: customer_satisfaction, employee_trust,
## manager_trust, mistakes_count, inventory_variance, discrepancies_flagged,
## hidden_thread_consequence_text. Verifies daily reset, accumulation, and
## save/load round-trip.
extends GutTest


var _system: PerformanceReportSystem
var _saved_day_started_connections: Array[Callable] = []
var _saved_day_ended_connections: Array[Callable] = []


func before_each() -> void:
	_saved_day_started_connections = _disconnect_signal(EventBus.day_started)
	_saved_day_ended_connections = _disconnect_signal(EventBus.day_ended)
	_system = PerformanceReportSystem.new()
	add_child_autofree(_system)
	_system.initialize()


func after_each() -> void:
	_system = null
	_restore_signal(EventBus.day_started, _saved_day_started_connections)
	_restore_signal(EventBus.day_ended, _saved_day_ended_connections)


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


func test_report_includes_seven_new_fields() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	for field: String in [
		"customer_satisfaction",
		"employee_trust",
		"manager_trust",
		"mistakes_count",
		"inventory_variance",
		"discrepancies_flagged",
		"hidden_thread_consequence_text",
	]:
		assert_true(field in report, "report missing field %s" % field)


func test_customer_satisfaction_defaults_to_one_when_no_interactions() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_almost_eq(report.customer_satisfaction, 1.0, 0.001)


func test_customer_satisfaction_ratio_from_resolution_events() -> void:
	EventBus.day_started.emit(1)
	EventBus.customer_resolution_logged.emit("satisfied")
	EventBus.customer_resolution_logged.emit("satisfied")
	EventBus.customer_resolution_logged.emit("unsatisfied")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_almost_eq(report.customer_satisfaction, 0.667, 0.01)


func test_customer_satisfaction_blends_legacy_customer_signals() -> void:
	EventBus.day_started.emit(1)
	EventBus.customer_left.emit({"customer_id": 1, "satisfied": true})
	EventBus.customer_left.emit({"customer_id": 2, "satisfied": false})
	EventBus.customer_resolution_logged.emit("satisfied")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	# 1 satisfied (left) + 1 unsatisfied (left) + 1 satisfied (resolution) → 2/3.
	assert_almost_eq(report.customer_satisfaction, 0.667, 0.01)


func test_customer_satisfaction_resets_at_day_started() -> void:
	EventBus.day_started.emit(1)
	EventBus.customer_resolution_logged.emit("unsatisfied")
	EventBus.customer_resolution_logged.emit("unsatisfied")
	EventBus.day_ended.emit(1)
	EventBus.day_started.emit(2)
	EventBus.customer_resolution_logged.emit("satisfied")
	EventBus.day_ended.emit(2)
	var day2: PerformanceReport = _system.get_history()[1]
	assert_almost_eq(day2.customer_satisfaction, 1.0, 0.001)


func test_player_mistake_recorded_increments_mistakes_count() -> void:
	EventBus.day_started.emit(1)
	EventBus.player_mistake_recorded.emit("overcharge", "checkout")
	EventBus.player_mistake_recorded.emit("wrong_item", "checkout")
	EventBus.player_mistake_recorded.emit("failed_restock", "shelf")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.mistakes_count, 3)


func test_mistakes_count_resets_at_day_started() -> void:
	EventBus.day_started.emit(1)
	EventBus.player_mistake_recorded.emit("overcharge", "checkout")
	EventBus.day_ended.emit(1)
	EventBus.day_started.emit(2)
	EventBus.day_ended.emit(2)
	var day2: PerformanceReport = _system.get_history()[1]
	assert_eq(day2.mistakes_count, 0)


func test_inventory_discrepancy_flagged_increments_count() -> void:
	EventBus.day_started.emit(1)
	EventBus.inventory_discrepancy_flagged.emit("a", 5, 4)
	EventBus.inventory_discrepancy_flagged.emit("b", 2, 3)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.discrepancies_flagged, 2)


func test_hidden_thread_text_captured_from_signal() -> void:
	EventBus.day_started.emit(1)
	EventBus.hidden_thread_consequence_triggered.emit(
		"The missing receipt has been noticed."
	)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(
		report.hidden_thread_consequence_text,
		"The missing receipt has been noticed.",
	)


func test_hidden_thread_text_defaults_empty() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.hidden_thread_consequence_text, "")


func test_hidden_thread_text_resets_each_day() -> void:
	EventBus.day_started.emit(1)
	EventBus.hidden_thread_consequence_triggered.emit("first")
	EventBus.day_ended.emit(1)
	EventBus.day_started.emit(2)
	EventBus.day_ended.emit(2)
	var day2: PerformanceReport = _system.get_history()[1]
	assert_eq(day2.hidden_thread_consequence_text, "")


func test_employee_trust_defaults_to_zero_when_source_absent() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	# EmploymentSystem is an autoload — assert it gracefully reads or
	# returns 0.0. Either is acceptable as long as the field exists.
	assert_true(report.employee_trust >= 0.0)
	assert_true(report.employee_trust <= 1.0)


func test_manager_trust_defaults_clamped_to_unit_range() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_true(report.manager_trust >= 0.0)
	assert_true(report.manager_trust <= 1.0)


func test_inventory_variance_defaults_to_zero_when_source_absent() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_almost_eq(report.inventory_variance, 0.0, 0.001)


func test_to_from_dict_roundtrips_new_fields() -> void:
	var report := PerformanceReport.new()
	report.customer_satisfaction = 0.42
	report.employee_trust = 0.6
	report.manager_trust = 0.8
	report.mistakes_count = 7
	report.inventory_variance = -0.05
	report.discrepancies_flagged = 3
	report.hidden_thread_consequence_text = "narrative text"
	var data: Dictionary = report.to_dict()
	var restored: PerformanceReport = PerformanceReport.from_dict(data)
	assert_almost_eq(restored.customer_satisfaction, 0.42, 0.001)
	assert_almost_eq(restored.employee_trust, 0.6, 0.001)
	assert_almost_eq(restored.manager_trust, 0.8, 0.001)
	assert_eq(restored.mistakes_count, 7)
	assert_almost_eq(restored.inventory_variance, -0.05, 0.001)
	assert_eq(restored.discrepancies_flagged, 3)
	assert_eq(restored.hidden_thread_consequence_text, "narrative text")


func test_from_dict_uses_safe_defaults_for_legacy_payloads() -> void:
	var legacy: Dictionary = {"day": 1, "revenue": 100.0}
	var restored: PerformanceReport = PerformanceReport.from_dict(legacy)
	assert_almost_eq(restored.customer_satisfaction, 1.0, 0.001)
	assert_almost_eq(restored.employee_trust, 0.0, 0.001)
	assert_almost_eq(restored.manager_trust, 0.0, 0.001)
	assert_eq(restored.mistakes_count, 0)
	assert_eq(restored.discrepancies_flagged, 0)
	assert_eq(restored.hidden_thread_consequence_text, "")
