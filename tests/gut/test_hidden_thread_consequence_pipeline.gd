## Integration test: verifies that `hidden_thread_consequence_triggered` is
## emitted before `performance_report_ready` fires on day_ended, so the
## end-of-day report contains the tiered consequence text.
extends GutTest


var _hidden: HiddenThreadSystem
var _perf_report: PerformanceReportSystem
var _saved_state: GameManager.State
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	GameManager.current_state = GameManager.State.GAMEPLAY
	GameManager.owned_stores = []

	_hidden = (
		Engine.get_main_loop().root.get_node("HiddenThreadSystemSingleton")
		as HiddenThreadSystem
	)
	_hidden.reset()

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	_hidden.reset()


func test_zero_inspections_yields_empty_consequence_text_on_report() -> void:
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _perf_report.get_history().back()
	assert_eq(report.hidden_thread_consequence_text, "")


func test_one_inspection_yields_minor_irregularity_text_on_report() -> void:
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _perf_report.get_history().back()
	assert_eq(
		report.hidden_thread_consequence_text,
		HiddenThreadSystem.CONSEQUENCE_TEXT_ONE,
	)


func test_multiple_inspections_yield_escalating_text_on_report() -> void:
	EventBus.hold_shelf_inspected.emit(&"retro_games", 0)
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	EventBus.register_note_examined.emit(&"retro_games", 1)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _perf_report.get_history().back()
	assert_eq(
		report.hidden_thread_consequence_text,
		HiddenThreadSystem.CONSEQUENCE_TEXT_MULTIPLE,
	)


func test_consequence_emission_precedes_performance_report_ready() -> void:
	# Tracks ordering by recording the hidden text observed when
	# performance_report_ready fires; if the text is non-empty at that point,
	# the consequence emission must have already updated the report builder's
	# cached _daily_hidden_thread_text.
	EventBus.warranty_binder_examined.emit(&"retro_games", 1)
	var captured: Dictionary = {"text": "<unset>"}
	var listener: Callable = func(report: PerformanceReport) -> void:
		captured["text"] = report.hidden_thread_consequence_text
	EventBus.performance_report_ready.connect(listener)
	EventBus.day_ended.emit(2)
	EventBus.performance_report_ready.disconnect(listener)
	assert_eq(
		String(captured["text"]),
		HiddenThreadSystem.CONSEQUENCE_TEXT_ONE,
		"performance_report_ready listener received non-empty hidden text",
	)
