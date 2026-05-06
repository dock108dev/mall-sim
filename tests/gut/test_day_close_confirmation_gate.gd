## Phase-3 close-day confirmation gate (ISSUE-010).
##
## When the player presses Close Day before completing one stock→sell loop on
## the active day, `DayCycleController._on_day_close_requested` must emit
## `EventBus.day_close_confirmation_requested(reason)` with copy that
## distinguishes "shelves empty" from "no sale yet" — and must NOT close the
## day until the player answers with `EventBus.day_close_confirmed`.
##
## The clock-driven `day_ended` path bypasses this gate so an end-of-day
## timeout always closes regardless of loop state.
extends GutTest


const _CONFIRMATION_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/close_day_confirmation_panel.tscn"
)


var _time: TimeSystem
var _economy: EconomySystem
var _staff: StaffSystem
var _progression: ProgressionSystem
var _ending_eval: EndingEvaluatorSystem
var _perf_report: PerformanceReportSystem
var _controller: DayCycleController

var _saved_state: GameManager.State
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]
var _saved_first_sale_flag: bool

var _confirmation_reasons: Array[String] = []
var _confirmed_count: int = 0
var _day_closed_count: int = 0


func before_each() -> void:
	_saved_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_first_sale_flag = GameState.get_flag(&"first_sale_complete")
	GameManager.current_state = GameManager.State.GAMEPLAY
	GameManager.current_store_id = &"retro_games"
	GameManager.owned_stores = []
	GameState.set_flag(&"first_sale_complete", false)

	# Reset autoload-scoped objective state so the gate sees a fresh Day 1.
	ObjectiveDirector._current_day = 1
	ObjectiveDirector._stocked = false
	ObjectiveDirector._sold = false
	ObjectiveDirector._loop_completed_today = false

	_time = TimeSystem.new()
	add_child_autofree(_time)
	_time.initialize()
	_time.current_day = 1

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(500.0)

	_staff = StaffSystem.new()
	add_child_autofree(_staff)

	_progression = ProgressionSystem.new()
	add_child_autofree(_progression)

	_ending_eval = EndingEvaluatorSystem.new()
	add_child_autofree(_ending_eval)
	_ending_eval.initialize()

	_perf_report = PerformanceReportSystem.new()
	add_child_autofree(_perf_report)
	_perf_report.initialize()

	_controller = DayCycleController.new()
	add_child_autofree(_controller)
	_controller.initialize(
		_time, _economy, _staff, _progression,
		_ending_eval, _perf_report,
	)

	_confirmation_reasons = []
	_confirmed_count = 0
	_day_closed_count = 0
	EventBus.day_close_confirmation_requested.connect(_on_confirmation_requested)
	EventBus.day_close_confirmed.connect(_on_confirmed)
	EventBus.day_closed.connect(_on_day_closed)


func after_each() -> void:
	GameManager.current_state = _saved_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	GameState.set_flag(&"first_sale_complete", _saved_first_sale_flag)
	ObjectiveDirector._current_day = 0
	ObjectiveDirector._stocked = false
	ObjectiveDirector._sold = false
	ObjectiveDirector._loop_completed_today = false
	_safe_disconnect(
		EventBus.day_close_confirmation_requested, _on_confirmation_requested
	)
	_safe_disconnect(EventBus.day_close_confirmed, _on_confirmed)
	_safe_disconnect(EventBus.day_closed, _on_day_closed)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_confirmation_requested(reason: String) -> void:
	_confirmation_reasons.append(reason)


func _on_confirmed() -> void:
	_confirmed_count += 1


func _on_day_closed(_day: int, _summary: Dictionary) -> void:
	_day_closed_count += 1


# ── ObjectiveDirector.can_close_day() ─────────────────────────────────────────


func test_can_close_day_true_when_loop_completed_today() -> void:
	ObjectiveDirector._loop_completed_today = true
	assert_true(
		ObjectiveDirector.can_close_day(),
		"can_close_day() must return true once the loop is complete"
	)


func test_can_close_day_false_when_loop_incomplete_in_gameplay() -> void:
	GameManager.current_state = GameManager.State.GAMEPLAY
	ObjectiveDirector._current_day = 1
	ObjectiveDirector._loop_completed_today = false
	assert_false(
		ObjectiveDirector.can_close_day(),
		"can_close_day() must return false when the loop is incomplete in GAMEPLAY"
	)


func test_can_close_day_true_when_no_day_started() -> void:
	# Headless / fixture context: no day_started has fired in the autoload.
	ObjectiveDirector._current_day = 0
	ObjectiveDirector._loop_completed_today = false
	assert_true(
		ObjectiveDirector.can_close_day(),
		"can_close_day() must fail open before any day has started"
	)


func test_can_close_day_true_outside_gameplay_states() -> void:
	# DAY_SUMMARY / BUILD / PAUSED / GAME_OVER are all non-active gameplay
	# states; the gate must fail open so they never trap a player.
	ObjectiveDirector._current_day = 1
	ObjectiveDirector._loop_completed_today = false
	GameManager.current_state = GameManager.State.PAUSED
	assert_true(
		ObjectiveDirector.can_close_day(),
		"can_close_day() must fail open outside of active-gameplay states"
	)


# ── ObjectiveDirector.get_close_blocked_reason() ─────────────────────────────


func test_blocked_reason_says_shelves_empty_when_not_stocked() -> void:
	ObjectiveDirector._stocked = false
	ObjectiveDirector._sold = false
	ObjectiveDirector._loop_completed_today = false
	var reason: String = ObjectiveDirector.get_close_blocked_reason()
	assert_string_contains(
		reason, "shelves",
		"Reason copy must mention shelves when the player has not stocked yet"
	)


func test_blocked_reason_says_no_sale_when_stocked_but_unsold() -> void:
	ObjectiveDirector._stocked = true
	ObjectiveDirector._sold = false
	ObjectiveDirector._loop_completed_today = false
	var reason: String = ObjectiveDirector.get_close_blocked_reason()
	assert_string_contains(
		reason, "sale",
		"Reason copy must mention 'sale' when shelves are stocked without a sale"
	)


# ── DayCycleController gate behavior ─────────────────────────────────────────


func test_close_request_blocked_when_loop_incomplete() -> void:
	ObjectiveDirector._loop_completed_today = false

	EventBus.day_close_requested.emit()

	assert_eq(
		_confirmation_reasons.size(), 1,
		"Gate must emit day_close_confirmation_requested when loop is incomplete"
	)
	assert_eq(
		_day_closed_count, 0,
		"Gate must NOT close the day before the player confirms"
	)
	assert_eq(
		GameManager.current_state, GameManager.State.GAMEPLAY,
		"Gate must hold the FSM in GAMEPLAY until the player confirms"
	)


func test_close_request_emits_shelves_empty_reason_when_unstocked() -> void:
	ObjectiveDirector._stocked = false
	ObjectiveDirector._sold = false
	ObjectiveDirector._loop_completed_today = false

	EventBus.day_close_requested.emit()

	assert_eq(_confirmation_reasons.size(), 1, "Gate must fire one reason")
	assert_string_contains(
		_confirmation_reasons[0], "shelves",
		"Empty-shelves close attempt must surface the shelves copy"
	)


func test_close_request_emits_no_sale_reason_when_stocked() -> void:
	ObjectiveDirector._stocked = true
	ObjectiveDirector._sold = false
	ObjectiveDirector._loop_completed_today = false

	EventBus.day_close_requested.emit()

	assert_eq(_confirmation_reasons.size(), 1, "Gate must fire one reason")
	assert_string_contains(
		_confirmation_reasons[0], "sale",
		"Stocked-but-unsold close attempt must mention 'sale' in the copy"
	)


func test_close_request_proceeds_when_loop_complete() -> void:
	ObjectiveDirector._stocked = true
	ObjectiveDirector._sold = true
	ObjectiveDirector._loop_completed_today = true

	EventBus.day_close_requested.emit()

	assert_eq(
		_confirmation_reasons.size(), 0,
		"Completed loop must not surface the confirmation modal"
	)
	assert_eq(
		_day_closed_count, 1,
		"Completed loop must close the day immediately"
	)


func test_day_close_confirmed_runs_close_path() -> void:
	ObjectiveDirector._loop_completed_today = false

	EventBus.day_close_requested.emit()
	assert_eq(_day_closed_count, 0, "Precondition: gate held the close")

	EventBus.day_close_confirmed.emit()

	assert_eq(
		_day_closed_count, 1,
		"day_close_confirmed must drive the day-closed close path"
	)
	assert_eq(
		GameManager.current_state, GameManager.State.DAY_SUMMARY,
		"Confirmed close must transition the FSM to DAY_SUMMARY"
	)


func test_day_ended_clock_path_bypasses_gate() -> void:
	# The day clock reaching end-of-day must close regardless of loop state —
	# the gate exists only on the player-initiated `day_close_requested` path.
	ObjectiveDirector._loop_completed_today = false

	EventBus.day_ended.emit(1)

	assert_eq(
		_confirmation_reasons.size(), 0,
		"Clock-driven day_ended must NOT pass through the confirmation gate"
	)
	assert_eq(
		_day_closed_count, 1,
		"Clock-driven day_ended must close the day directly"
	)


# ── Loop-completion flag wiring ──────────────────────────────────────────────


func test_loop_completed_today_set_after_stock_then_sell() -> void:
	ObjectiveDirector._stocked = false
	ObjectiveDirector._sold = false
	ObjectiveDirector._loop_completed_today = false

	EventBus.item_stocked.emit("test_item", "shelf_1")
	assert_false(
		ObjectiveDirector._loop_completed_today,
		"Stock alone must not flip the loop-complete flag"
	)

	EventBus.item_sold.emit("test_item", 25.0, "test")

	assert_true(
		ObjectiveDirector._loop_completed_today,
		"Stock followed by sell must set the loop-complete flag"
	)


func test_loop_completed_today_resets_on_day_started() -> void:
	ObjectiveDirector._loop_completed_today = true

	EventBus.day_started.emit(2)

	assert_false(
		ObjectiveDirector._loop_completed_today,
		"day_started must reset the per-day loop flag"
	)


# ── Confirmation panel UI behavior ───────────────────────────────────────────


func test_panel_shows_reason_on_confirmation_requested() -> void:
	var panel: CloseDayConfirmationPanel = (
		_CONFIRMATION_PANEL_SCENE.instantiate() as CloseDayConfirmationPanel
	)
	add_child_autofree(panel)
	# Drain layout so @onready references resolve before assertions.
	await get_tree().process_frame

	EventBus.day_close_confirmation_requested.emit("Stock the shelves first.")
	await get_tree().process_frame

	assert_true(
		panel.visible,
		"Panel must become visible when the gate fires"
	)
	assert_string_contains(
		panel._reason_label.text, "Stock the shelves",
		"Panel must render the supplied reason copy"
	)
	panel.close()


func test_panel_cancel_closes_without_emitting_confirmed() -> void:
	var panel: CloseDayConfirmationPanel = (
		_CONFIRMATION_PANEL_SCENE.instantiate() as CloseDayConfirmationPanel
	)
	add_child_autofree(panel)
	await get_tree().process_frame
	panel.show_with_reason("Stock the shelves first.")

	panel._on_cancel_pressed()

	assert_false(panel.visible, "Cancel must hide the panel")
	assert_eq(
		_confirmed_count, 0,
		"Cancel must NOT emit day_close_confirmed"
	)


func test_panel_confirm_emits_day_close_confirmed() -> void:
	var panel: CloseDayConfirmationPanel = (
		_CONFIRMATION_PANEL_SCENE.instantiate() as CloseDayConfirmationPanel
	)
	add_child_autofree(panel)
	await get_tree().process_frame
	panel.show_with_reason("Stock the shelves first.")

	panel._on_confirm_pressed()

	assert_false(panel.visible, "Confirm must hide the panel")
	assert_eq(
		_confirmed_count, 1,
		"Confirm must emit day_close_confirmed exactly once"
	)
