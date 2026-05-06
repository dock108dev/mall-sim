## Coordinates the end-of-day flow: report → summary panel → wages → evaluation → advance.
## Acts as DayManager: only this class emits EventBus.day_closed.
class_name DayCycleController
extends Node


const CLOSING_CERT_UNLOCK_ID: StringName = &"employee_closing_certified"

var _time_system: TimeSystem
var _economy_system: EconomySystem
var _staff_system: StaffSystem
var _progression_system: ProgressionSystem
var _ending_evaluator: EndingEvaluatorSystem
var _performance_report_system: PerformanceReportSystem
var _day_manager: DayManager
var _day_summary: DaySummary
var _closing_checklist: ClosingChecklist
var _mall_overview: Control
var _seasonal_event_system: SeasonalEventSystem
var _ambient_moments_system: AmbientMomentsSystem
var _pending_report: PerformanceReport
var _awaiting_acknowledgement: bool = false
var _last_closed_day: int = 0
var _pending_checklist_day: int = 0
var _ensure_panels_callback: Callable
var _save_manager: SaveManager = null


func initialize(
	time_system: TimeSystem,
	economy_system: EconomySystem,
	staff_system: StaffSystem,
	progression_system: ProgressionSystem,
	ending_evaluator: EndingEvaluatorSystem,
	performance_report_system: PerformanceReportSystem,
) -> void:
	_time_system = time_system
	_economy_system = economy_system
	_staff_system = staff_system
	_progression_system = progression_system
	_ending_evaluator = ending_evaluator
	_performance_report_system = performance_report_system
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.day_close_requested.connect(_on_day_close_requested)
	EventBus.day_close_confirmed.connect(_on_day_close_confirmed)
	EventBus.next_day_confirmed.connect(_on_day_acknowledged)
	EventBus.performance_report_ready.connect(_on_report_ready)


func set_day_summary(panel: DaySummary) -> void:
	_day_summary = panel
	if is_instance_valid(panel):
		panel.dismissed.connect(_on_day_summary_dismissed)


func set_closing_checklist(panel: ClosingChecklist) -> void:
	_closing_checklist = panel
	if is_instance_valid(panel):
		panel.completed.connect(_on_closing_checklist_completed)


## The hub's MallOverview Control is hidden while the Day Summary modal is
## open so it does not bleed through the overlay (P1.4).
func set_mall_overview(overview: Control) -> void:
	_mall_overview = overview


## Restores MallOverview visibility based on the post-acknowledgement FSM
## state, not the prior state. The "Mall Overview" button on the summary
## acks the day and lands the FSM in MALL_OVERVIEW — MallOverview must show.
## The "Continue" button leaves the FSM in GAMEPLAY (player still inside the
## store) — MallOverview must stay hidden so its full-screen Control does not
## render on top of the store viewport during the Day N → Day N+1 hand-off.
##
## §F-91 — Pass 13: silent return on `not is_instance_valid(_mall_overview)`
## is the Tier-5 init pattern. `DayCycleController` runs in Tier 5 (per
## docs/architecture.md); the `_mall_overview` ref is injected by `MallHub`
## via `set_mall_overview`. Headless tests and pre-hub-mount frames take the
## silent path symmetrically with `_show_day_summary`'s own
## `is_instance_valid(_mall_overview)` guard at line 220 — if the producer
## path took the no-op, the dismissal restore staying a no-op is the
## consistent contract. Production wiring guarantees both fire.
func _on_day_summary_dismissed() -> void:
	if not is_instance_valid(_mall_overview):
		return
	var should_show: bool = (
		GameManager.current_state == GameManager.State.MALL_OVERVIEW
	)
	_mall_overview.visible = should_show


func set_day_manager(manager: DayManager) -> void:
	_day_manager = manager


func set_seasonal_event_system(system: SeasonalEventSystem) -> void:
	_seasonal_event_system = system


func set_ambient_moments_system(system: AmbientMomentsSystem) -> void:
	_ambient_moments_system = system


func set_ensure_panels_callback(callback: Callable) -> void:
	_ensure_panels_callback = callback


func set_save_manager(manager: SaveManager) -> void:
	_save_manager = manager


func _on_day_close_requested() -> void:
	if not _time_system:
		push_warning("DayCycleController: day_close_requested before initialize")
		return
	# Gate the player-initiated close path on a completed stock→sell loop. The
	# clock-triggered `day_ended` signal does NOT route through here, so an
	# end-of-day timeout always closes regardless of loop state.
	if not _can_close_day():
		var reason: String = _resolve_close_blocked_reason()
		EventBus.day_close_confirmation_requested.emit(reason)
		return
	_on_day_ended(_time_system.current_day)


## Player chose "Close Day" inside the confirmation modal. Bypasses the gate
## and runs the same close path as the unguarded request.
func _on_day_close_confirmed() -> void:
	if not _time_system:
		push_warning(
			"DayCycleController: day_close_confirmed before initialize"
		)
		return
	_on_day_ended(_time_system.current_day)


## Queries `ObjectiveDirector.can_close_day()` when the autoload is reachable.
## Fails open when the autoload is missing so headless test harnesses that
## construct `DayCycleController` without a full autoload roster still close
## the day on demand.
func _can_close_day() -> bool:
	var od: Node = get_node_or_null("/root/ObjectiveDirector")
	if od == null or not od.has_method("can_close_day"):
		return true
	return bool(od.call("can_close_day"))


func _resolve_close_blocked_reason() -> String:
	var od: Node = get_node_or_null("/root/ObjectiveDirector")
	if od == null or not od.has_method("get_close_blocked_reason"):
		return "You haven't made a sale yet. Close the day anyway?"
	return str(od.call("get_close_blocked_reason"))


func _on_day_ended(day: int) -> void:
	if GameManager.current_state == GameManager.State.GAME_OVER:
		return
	# Prevent double-close if both day_ended and day_close_requested fire.
	if _awaiting_acknowledgement:
		return

	_last_closed_day = day

	# Finalize hidden-thread consequence text before any report build so the
	# `hidden_thread_consequence_triggered` signal lands on the bus before
	# PerformanceReportSystem emits `performance_report_ready`. The call is
	# idempotent per day, so the autoload's own day_ended handler running the
	# same path is a no-op the second time.
	var hidden_thread: Node = get_node_or_null("/root/HiddenThreadSystemSingleton")
	if hidden_thread != null and hidden_thread.has_method("finalize_day"):
		hidden_thread.call("finalize_day", day)

	if _ensure_panels_callback.is_valid():
		_ensure_panels_callback.call()

	GameManager.change_state(GameManager.State.DAY_SUMMARY)
	_awaiting_acknowledgement = true

	if _should_run_closing_checklist():
		_pending_checklist_day = day
		_closing_checklist.open_for_day(day)
		return
	_show_day_summary(day)


## Returns true when the player has earned the closing-certification unlock
## AND the runtime checklist panel is mounted. Without the unlock, the day
## flows straight to the summary as before.
func _should_run_closing_checklist() -> bool:
	if not is_instance_valid(_closing_checklist):
		return false
	var unlocks: Node = get_node_or_null("/root/UnlockSystemSingleton")
	if unlocks == null or not unlocks.has_method("is_unlocked"):
		return false
	return bool(unlocks.call("is_unlocked", CLOSING_CERT_UNLOCK_ID))


func _on_closing_checklist_completed(day: int) -> void:
	if day != _pending_checklist_day:
		return
	_pending_checklist_day = 0
	_show_day_summary(day)


func _on_report_ready(report: PerformanceReport) -> void:
	_pending_report = report


func _on_day_acknowledged() -> void:
	if not _awaiting_acknowledgement:
		return
	_awaiting_acknowledgement = false

	_process_wages()

	if GameManager.current_state == GameManager.State.GAME_OVER:
		return

	_evaluate_milestones()
	_evaluate_endings()
	_evaluate_arc()

	if GameManager.current_state == GameManager.State.GAME_OVER:
		return

	GameManager.change_state(GameManager.State.GAMEPLAY)
	if _save_manager:
		_save_manager.save_game(0)
	_time_system.advance_to_next_day()


func _show_day_summary(day: int) -> void:
	var summary: Dictionary = _economy_system.get_daily_summary()

	var warranty_rev: float = 0.0
	var warranty_claims: float = 0.0
	var store_ctrl: StoreController = _find_store_controller()
	if store_ctrl is ElectronicsStoreController:
		var elec: ElectronicsStoreController = (
			store_ctrl as ElectronicsStoreController
		)
		var wm: WarrantyManager = elec.get_warranty_manager()
		warranty_rev = wm.get_daily_warranty_revenue()
		warranty_claims = wm.get_daily_claim_costs()

	var seasonal_impact: String = ""
	if _seasonal_event_system:
		seasonal_impact = _seasonal_event_system.get_impact_summary()

	var discrepancy: float = 0.0
	if _ambient_moments_system:
		discrepancy = _ambient_moments_system.get_active_discrepancy()

	var wages: float = 0.0
	if _staff_system:
		wages = _staff_system.get_total_daily_wages()

	# Build the full payload emitted as day_closed so UI and tests can consume it.
	var store_revenue: Dictionary = (
		_economy_system.get_day_end_summary(day).get("store_daily_revenue", {})
	)
	# §F-60 — `inventory_remaining = 0` when InventorySystem is unresolved
	# matches the surrounding null-system fallbacks in this function (`wages`,
	# `warranty_rev`, `seasonal_impact` all default-to-zero on missing systems).
	# In production the system is always live by day-close (gameplay has been
	# running long enough to record sales); the null arm fires only in
	# unit-test fixtures that drive `_show_day_summary` without a full GameWorld.
	var backroom_remaining: int = 0
	var shelf_remaining: int = 0
	var inventory_system: InventorySystem = GameManager.get_inventory_system()
	if inventory_system != null:
		shelf_remaining = inventory_system.get_shelf_items().size()
		backroom_remaining = inventory_system.get_backroom_items().size()
	var inventory_remaining: int = shelf_remaining + backroom_remaining
	# §F-114 — Day-summary "Customers Served" pulls from the cumulative day
	# counter so the payload is self-contained — readers of `day_closed` no
	# longer need to also subscribe to `performance_report_ready` to fill the
	# label. The null-system arm is the Tier-3 init test-seam (matches the
	# surrounding `_inventory_system` / `_staff_system` guards in this
	# function): production day-close cannot reach this branch (the system is
	# always live by then), and the default-to-0 emit means `day_summary.gd`
	# either renders 0 (test fixture) or the real value (production), both of
	# which are valid render states gated by the §F-102 `has()` check on the
	# consumer side.
	var customers_served: int = 0
	if _performance_report_system != null:
		customers_served = (
			_performance_report_system.get_daily_customers_served()
		)
	var shift_summary: Dictionary = {}
	var shift: Node = get_node_or_null("/root/ShiftSystem")
	if shift != null and shift.has_method("get_shift_summary"):
		shift_summary = shift.call("get_shift_summary")
	var customer_system: CustomerSystem = GameManager.get_customer_system()
	if customer_system != null:
		var leave_counts: Dictionary = customer_system.get_leave_counts()
		shift_summary["customers_happy"] = int(leave_counts.get("happy", 0))
		shift_summary["customers_no_stock"] = int(leave_counts.get("no_stock", 0))
		shift_summary["customers_timeout"] = int(leave_counts.get("timeout", 0))
		shift_summary["customers_price"] = int(leave_counts.get("price", 0))

	var hidden_interactions: int = 0
	var hidden_thread_node: Node = get_node_or_null(
		"/root/HiddenThreadSystemSingleton"
	)
	if (
		hidden_thread_node != null
		and "hidden_thread_interactions" in hidden_thread_node
	):
		hidden_interactions = maxi(
			int(hidden_thread_node.hidden_thread_interactions), 0
		)

	var payload: Dictionary = {
		"day": day,
		"total_revenue": summary.get("total_revenue", 0.0),
		"total_expenses": summary.get("total_expenses", 0.0),
		"net_profit": summary.get("net_profit", 0.0),
		"items_sold": summary.get("items_sold", 0),
		"customers_served": customers_served,
		"rent": summary.get("rent", 0.0),
		"net_cash": _economy_system.get_cash(),
		"store_revenue": store_revenue,
		"warranty_revenue": warranty_rev,
		"warranty_claims": warranty_claims,
		"seasonal_impact": seasonal_impact,
		"discrepancy": discrepancy,
		"staff_wages": wages,
		"inventory_remaining": inventory_remaining,
		"backroom_inventory_remaining": backroom_remaining,
		"shelf_inventory_remaining": shelf_remaining,
		"shift_summary": shift_summary,
		"hidden_thread_interactions": hidden_interactions,
	}
	EventBus.day_closed.emit(day, payload)
	EventBus.publish_day_end_summary(payload)

	# §F-141 — LedgerSystem reconciliation runs in every build (the
	# anchor mismatch is a data-integrity check), but the verbose
	# per-entry dump is gated on `OS.is_debug_build()` so shipping
	# builds do not flood stdout with the per-day timeline. Direct
	# typed calls on the autoload (vs. the prior `get_node_or_null`
	# + `.call()`) so a signature regression on `get_debug_dump` /
	# `validate_against_anchor` fails at parse time instead of being
	# silently masked by a runtime "method not found".
	if OS.is_debug_build():
		print(LedgerSystem.get_debug_dump(day))
	var ledger_check: Dictionary = LedgerSystem.validate_against_anchor(day)
	if not bool(ledger_check.get("match", false)):
		push_warning(
			"LedgerSystem: revenue delta %.2f for day %d (ledger=%.2f anchor=%.2f)"
			% [
				float(ledger_check.get("delta", 0.0)),
				day,
				float(ledger_check.get("ledger_revenue", 0.0)),
				float(ledger_check.get("anchor_revenue", -1.0)),
			]
		)

	if not _day_summary:
		return

	# Hide the MallOverview while the summary modal is open so its store
	# cards do not bleed through the overlay (P1.4). Visibility on dismiss is
	# restored from the post-acknowledgement FSM state so the Continue button
	# (state → GAMEPLAY) does not bleed MallOverview over the store viewport.
	if is_instance_valid(_mall_overview):
		_mall_overview.visible = false

	var archetype_name: String = _compute_day_archetype(payload)
	var floor_stars: int = _compute_floor_awareness_stars(payload)
	var attention_notes: Array[String] = _build_attention_notes(payload)

	_day_summary.show_summary(
		day,
		payload["total_revenue"],
		payload["total_expenses"],
		payload["net_profit"],
		payload["items_sold"],
		payload["rent"],
		warranty_rev,
		warranty_claims,
		seasonal_impact,
		discrepancy,
		wages,
		archetype_name,
		floor_stars,
		attention_notes,
	)

	# Forward the deferred hidden-thread reveal so the timer is anchored to the
	# panel-show moment rather than the upstream `performance_report_ready`
	# signal time. Empty text leaves the label permanently hidden.
	if _pending_report != null:
		_day_summary.set_hidden_thread_text(
			_pending_report.hidden_thread_consequence_text
		)


## Returns the inspection-count-driven archetype name per BRAINDUMP §11.
## 0 inspections → "The Mark"; 1 → "The Warm Body"; 2 → "The Floor Walker";
## 3–4 → "The Paper Trail"; 5+ → "The Company Person".
static func _compute_day_archetype(payload: Dictionary) -> String:
	var count: int = _hidden_inspection_count(payload)
	if count <= 0:
		return "The Mark"
	if count == 1:
		return "The Warm Body"
	if count == 2:
		return "The Floor Walker"
	if count <= 4:
		return "The Paper Trail"
	return "The Company Person"


## Returns 1..5 stars per BRAINDUMP §5: 0 inspections=1, 1=2, 2=3,
## 3–4=4, 5+=5. Minimum is 1 — there is no 0-star result.
static func _compute_floor_awareness_stars(payload: Dictionary) -> int:
	var count: int = _hidden_inspection_count(payload)
	if count <= 0:
		return 1
	if count == 1:
		return 2
	if count == 2:
		return 3
	if count <= 4:
		return 4
	return 5


## Returns up to 4 short observations drawn from shift_summary fields
## and inventory split. Empty array is valid.
static func _build_attention_notes(payload: Dictionary) -> Array[String]:
	var notes: Array[String] = []
	var ss: Dictionary = payload.get("shift_summary", {})
	var no_stock: int = int(ss.get("customers_no_stock", 0))
	var timeout: int = int(ss.get("customers_timeout", 0))
	var price_l: int = int(ss.get("customers_price", 0))
	var happy: int = int(ss.get("customers_happy", 0))
	var total_leaves: int = no_stock + timeout + price_l + happy
	var happy_rate: float = float(happy) / float(maxi(total_leaves, 1))
	var discrepancy: float = float(payload.get("discrepancy", 0.0))
	var backroom: int = int(payload.get("backroom_inventory_remaining", 0))
	var total_inv: int = maxi(int(payload.get("inventory_remaining", 0)), 1)
	var backroom_frac: float = float(backroom) / float(total_inv)
	var shelf_rem: int = int(payload.get("shelf_inventory_remaining", 0))
	var sold: int = int(payload.get("items_sold", 0))

	if no_stock > 0:
		notes.append(
			"%d customer(s) left empty-handed — shelf ran dry." % no_stock
		)
	if timeout > 0:
		notes.append(
			"%d customer(s) gave up waiting — floor coverage too slow." % timeout
		)
	if price_l > 2:
		notes.append(
			"%d customer(s) balked at price — consider markdowns." % price_l
		)
	if discrepancy >= 0.05:
		notes.append(
			"Inventory variance at %.0f%% — check backroom counts."
			% (discrepancy * 100.0)
		)
	if backroom_frac > 0.6:
		notes.append("Over half your stock is still in the backroom.")
	if shelf_rem == 0 and sold == 0:
		notes.append("Nothing moved today — floor was empty all shift.")
	if happy_rate >= 0.9 and total_leaves >= 3:
		notes.append("Strong shift — most customers left satisfied.")

	return notes.slice(0, 4)


static func _hidden_inspection_count(payload: Dictionary) -> int:
	return maxi(int(payload.get("hidden_thread_interactions", 0)), 0)


func _process_wages() -> void:
	if not _staff_system:
		return
	_staff_system.process_daily_wages()


func _evaluate_milestones() -> void:
	if not _progression_system:
		return
	_progression_system.evaluate_day_end()


func _evaluate_endings() -> void:
	if not _ending_evaluator:
		return
	if _ending_evaluator.has_ending_been_shown():
		return
	var ending_id: StringName = _ending_evaluator.evaluate()
	if ending_id != EndingEvaluatorSystem.FALLBACK_ENDING_ID:
		_ending_evaluator.force_ending(ending_id)


func _evaluate_arc() -> void:
	if not _day_manager or not _economy_system:
		return
	_day_manager.evaluate_day_end(_last_closed_day, _economy_system.get_cash())


func _find_store_controller() -> StoreController:
	var store_container: Node = get_parent().get_node_or_null(
		"StoreContainer"
	)
	if not store_container:
		return null
	return _find_store_controller_recursive(store_container)


func _find_store_controller_recursive(node: Node) -> StoreController:
	if node is StoreController:
		return node as StoreController
	for child: Node in node.get_children():
		var found: StoreController = (
			_find_store_controller_recursive(child)
		)
		if found:
			return found
	return null
