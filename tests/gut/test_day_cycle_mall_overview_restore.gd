## DayCycleController hides MallOverview while the summary modal is open and
## restores its visibility based on the post-acknowledgement FSM state. This
## guards the Day N → Day N+1 hand-off so the "Continue" button (state →
## GAMEPLAY, player still inside the store) does not bleed MallOverview's
## full-screen Control over the in-store viewport.
extends GutTest


var _time: TimeSystem
var _economy: EconomySystem
var _ending_evaluator: EndingEvaluatorSystem
var _perf_report: PerformanceReportSystem
var _controller: DayCycleController
var _mall_overview: Control
var _day_summary: DaySummary

var _saved_state: GameManager.State
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	GameManager.current_state = GameManager.State.GAMEPLAY
	GameManager.current_store_id = &"retro_games"
	GameManager.owned_stores = [&"retro_games"]

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.initialize()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(500.0)

	_ending_evaluator = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_evaluator)
	_ending_evaluator.initialize()

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()

	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)

	_mall_overview = Control.new()
	add_child_autofree(_mall_overview)

	_controller = DayCycleController.new()
	add_child_autofree(_controller)
	_controller.initialize(
		_time, _economy, null, null, _ending_evaluator, _perf_report
	)
	_controller.set_day_summary(_day_summary)
	_controller.set_mall_overview(_mall_overview)


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	# DaySummary._reset_for_tests pairs with InputFocus.pop hygiene so the
	# next test starts from a clean modal-focus stack.
	if is_instance_valid(_day_summary):
		_day_summary._reset_for_tests()


## Continue path: state ends in GAMEPLAY, player back in store. MallOverview
## must stay hidden so its full-screen Control does not render over the store.
func test_dismiss_keeps_mall_overview_hidden_when_state_is_gameplay() -> void:
	_mall_overview.visible = false
	EventBus.day_close_requested.emit()
	assert_false(
		_mall_overview.visible,
		"MallOverview must be hidden while the summary modal is open"
	)
	# Simulate the Continue button: ack day → DayCycleController._on_day_acknowledged
	# transitions FSM to GAMEPLAY.
	EventBus.next_day_confirmed.emit()
	assert_eq(
		GameManager.current_state, GameManager.State.GAMEPLAY,
		"Continue path must leave the FSM in GAMEPLAY"
	)
	# Direct dismiss callback simulates the post-tween emit.
	_controller._on_day_summary_dismissed()
	assert_false(
		_mall_overview.visible,
		"MallOverview must stay hidden after dismiss when the player returned "
		+ "to GAMEPLAY (Day N → Day N+1 Continue path)"
	)


## Mall Overview path: state ends in MALL_OVERVIEW, player wants the hub.
## MallOverview must be visible after the summary dismisses.
func test_dismiss_shows_mall_overview_when_state_is_mall_overview() -> void:
	_mall_overview.visible = false
	EventBus.day_close_requested.emit()
	# Simulate the Mall Overview button: ack first, then state → MALL_OVERVIEW.
	EventBus.next_day_confirmed.emit()
	GameManager.change_state(GameManager.State.MALL_OVERVIEW)
	_controller._on_day_summary_dismissed()
	assert_true(
		_mall_overview.visible,
		"MallOverview must be re-shown after dismiss when the FSM is in "
		+ "MALL_OVERVIEW (player chose Return to Mall)"
	)


## Day 1 → Day 2: TimeSystem must advance and active_store_id must persist.
func test_day_advances_and_active_store_persists_across_continue() -> void:
	var manager: StoreStateManager = StoreStateManager.new()
	add_child_autofree(manager)
	manager.lease_store(0, &"retro_games", &"retro_games", false)
	manager.set_active_store(&"retro_games", false)
	assert_eq(
		manager.active_store_id, &"retro_games",
		"Precondition: active_store_id must be set before Day 1 close"
	)
	EventBus.day_close_requested.emit()
	EventBus.next_day_confirmed.emit()
	assert_eq(
		_time.current_day, 2,
		"Day must advance to 2 after Continue ack"
	)
	assert_eq(
		manager.active_store_id, &"retro_games",
		"active_store_id must persist across the day boundary so readers "
		+ "(InventoryPanel, tutorial gates) keep observing the store"
	)


## Day-boundary tutorial guard: a completed tutorial must remain completed
## across the day_started signal so Day 2 does not re-show Day 1 milestones.
func test_completed_tutorial_remains_finished_on_day_started() -> void:
	var tutorial: TutorialSystem = TutorialSystem.new()
	add_child_autofree(tutorial)
	tutorial.tutorial_completed = true
	tutorial.tutorial_active = false
	tutorial.current_step = TutorialSystem.TutorialStep.FINISHED
	EventBus.day_started.emit(2)
	assert_true(
		tutorial.tutorial_completed,
		"tutorial_completed must persist across day_started emission"
	)
	assert_eq(
		tutorial.current_step, TutorialSystem.TutorialStep.FINISHED,
		"current_step must remain FINISHED on Day 2 — no milestone replay"
	)
