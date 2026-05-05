## Tests the closing-checklist gating in DayCycleController. When the
## `employee_closing_certified` unlock is granted, day-end opens the checklist
## panel before the day-summary; without the unlock, the day flows straight
## to the summary.
extends GutTest


var _controller: DayCycleController
var _time: TimeSystem
var _economy: EconomySystem
var _staff: StaffSystem
var _progression: ProgressionSystem
var _ending_eval: EndingEvaluatorSystem
var _perf_report: PerformanceReportSystem

var _summary_calls: int = 0


func before_each() -> void:
	_summary_calls = 0
	UnlockSystemSingleton.initialize()

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.initialize()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(1000.0)

	_staff = StaffSystem.new()
	add_child_autofree(_staff)

	_progression = ProgressionSystem.new()
	add_child_autofree(_progression)

	_ending_eval = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_eval)

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()

	_controller = DayCycleController.new()
	add_child_autofree(_controller)
	_controller.initialize(
		_time, _economy, _staff, _progression, _ending_eval, _perf_report,
	)


func after_each() -> void:
	UnlockSystemSingleton.initialize()


func test_should_run_closing_checklist_false_without_panel() -> void:
	# No checklist panel mounted → gate is false even if the unlock is
	# granted (no-op rather than error).
	UnlockSystemSingleton._granted[
		DayCycleController.CLOSING_CERT_UNLOCK_ID
	] = true
	assert_false(_controller._should_run_closing_checklist())


func test_should_run_closing_checklist_false_without_unlock() -> void:
	var checklist: ClosingChecklist = preload(
		"res://game/scenes/ui/closing_checklist.tscn"
	).instantiate() as ClosingChecklist
	add_child_autofree(checklist)
	_controller.set_closing_checklist(checklist)
	assert_false(_controller._should_run_closing_checklist())


func test_should_run_closing_checklist_true_with_unlock_and_panel() -> void:
	var checklist: ClosingChecklist = preload(
		"res://game/scenes/ui/closing_checklist.tscn"
	).instantiate() as ClosingChecklist
	add_child_autofree(checklist)
	_controller.set_closing_checklist(checklist)
	UnlockSystemSingleton._granted[
		DayCycleController.CLOSING_CERT_UNLOCK_ID
	] = true
	assert_true(_controller._should_run_closing_checklist())
