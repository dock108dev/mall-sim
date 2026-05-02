## Coordinates the end-of-day flow: report → summary panel → wages → evaluation → advance.
## Acts as DayManager: only this class emits EventBus.day_closed.
class_name DayCycleController
extends Node


var _time_system: TimeSystem
var _economy_system: EconomySystem
var _staff_system: StaffSystem
var _progression_system: ProgressionSystem
var _ending_evaluator: EndingEvaluatorSystem
var _performance_report_system: PerformanceReportSystem
var _day_manager: DayManager
var _day_summary: DaySummary
var _mall_overview: Control
var _seasonal_event_system: SeasonalEventSystem
var _ambient_moments_system: AmbientMomentsSystem
var _pending_report: PerformanceReport
var _awaiting_acknowledgement: bool = false
var _last_closed_day: int = 0
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
	EventBus.next_day_confirmed.connect(_on_day_acknowledged)
	EventBus.performance_report_ready.connect(_on_report_ready)


func set_day_summary(panel: DaySummary) -> void:
	_day_summary = panel
	if is_instance_valid(panel):
		panel.dismissed.connect(_on_day_summary_dismissed)


## The hub's MallOverview Control is hidden while the Day Summary modal is
## open so it does not bleed through the overlay (P1.4).
func set_mall_overview(overview: Control) -> void:
	_mall_overview = overview


func _on_day_summary_dismissed() -> void:
	if is_instance_valid(_mall_overview):
		_mall_overview.visible = true


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
	_on_day_ended(_time_system.current_day)


func _on_day_ended(day: int) -> void:
	if GameManager.current_state == GameManager.State.GAME_OVER:
		return
	# Prevent double-close if both day_ended and day_close_requested fire.
	if _awaiting_acknowledgement:
		return

	_last_closed_day = day

	if _ensure_panels_callback.is_valid():
		_ensure_panels_callback.call()

	GameManager.change_state(GameManager.State.DAY_SUMMARY)
	_awaiting_acknowledgement = true
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
	var inventory_remaining: int = 0
	var inventory_system: InventorySystem = GameManager.get_inventory_system()
	if inventory_system != null:
		inventory_remaining = (
			inventory_system.get_shelf_items().size()
			+ inventory_system.get_backroom_items().size()
		)
	var payload: Dictionary = {
		"day": day,
		"total_revenue": summary.get("total_revenue", 0.0),
		"total_expenses": summary.get("total_expenses", 0.0),
		"net_profit": summary.get("net_profit", 0.0),
		"items_sold": summary.get("items_sold", 0),
		"rent": summary.get("rent", 0.0),
		"net_cash": _economy_system.get_cash(),
		"store_revenue": store_revenue,
		"warranty_revenue": warranty_rev,
		"warranty_claims": warranty_claims,
		"seasonal_impact": seasonal_impact,
		"discrepancy": discrepancy,
		"staff_wages": wages,
		"inventory_remaining": inventory_remaining,
	}
	EventBus.day_closed.emit(day, payload)
	EventBus.publish_day_end_summary(payload)

	if not _day_summary:
		return

	# Hide the MallOverview while the summary modal is open so its store
	# cards do not bleed through the overlay (P1.4).
	if is_instance_valid(_mall_overview):
		_mall_overview.visible = false

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
	)


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
