## Accumulates per-day metrics and generates end-of-day performance reports.
class_name PerformanceReportSystem
extends Node


const MAX_HISTORY_SIZE: int = 30

var _daily_items_sold: int = 0
var _daily_units_sold: int = 0
var _daily_customers_served: int = 0
var _daily_revenue: float = 0.0
var _daily_walkouts: int = 0
var _daily_reputation_start: float = 0.0
var _daily_reputation_end: float = 0.0
var _daily_item_revenues: Dictionary = {}
var _daily_item_counts: Dictionary = {}
var _daily_haggle_wins: int = 0
var _daily_haggle_losses: int = 0
var _daily_late_fee_income: float = 0.0
var _daily_warranty_revenue: float = 0.0
var _daily_warranty_claim_costs: float = 0.0
var _daily_milestones: Array[String] = []
var _daily_start_tier: int = -1
var _daily_end_tier: int = -1
var _history: Array[PerformanceReport] = []

## Cached values from the most recent daily_financials_snapshot.
var _snapshot_revenue: float = 0.0
var _snapshot_expenses: float = 0.0
var _snapshot_received: bool = false


func initialize() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.haggle_completed.connect(_on_haggle_completed)
	EventBus.haggle_failed.connect(_on_haggle_failed)
	EventBus.milestone_completed.connect(_on_milestone_completed)
	EventBus.rental_late_fee.connect(_on_rental_late_fee)
	EventBus.warranty_purchased.connect(_on_warranty_purchased)
	EventBus.warranty_claim_triggered.connect(
		_on_warranty_claim_triggered
	)
	EventBus.daily_financials_snapshot.connect(
		_on_daily_financials_snapshot
	)


func get_history() -> Array[PerformanceReport]:
	return _history


func get_daily_revenue() -> float:
	return _daily_revenue


func get_daily_units_sold() -> int:
	return _daily_units_sold


func get_daily_customers_served() -> int:
	return _daily_customers_served


func get_save_data() -> Dictionary:
	var serialized_history: Array[Dictionary] = []
	for report: PerformanceReport in _history:
		serialized_history.append(report.to_dict())
	return {
		"history": serialized_history,
		"daily_items_sold": _daily_items_sold,
		"daily_units_sold": _daily_units_sold,
		"daily_customers_served": _daily_customers_served,
		"daily_revenue": _daily_revenue,
		"daily_walkouts": _daily_walkouts,
		"daily_reputation_start": _daily_reputation_start,
		"daily_reputation_end": _daily_reputation_end,
		"daily_item_revenues": _daily_item_revenues.duplicate(),
		"daily_item_counts": _daily_item_counts.duplicate(),
		"daily_haggle_wins": _daily_haggle_wins,
		"daily_haggle_losses": _daily_haggle_losses,
		"daily_late_fee_income": _daily_late_fee_income,
		"daily_warranty_revenue": _daily_warranty_revenue,
		"daily_warranty_claim_costs": _daily_warranty_claim_costs,
		"daily_milestones": _daily_milestones.duplicate(),
		"daily_start_tier": _daily_start_tier,
		"daily_end_tier": _daily_end_tier,
	}


func load_save_data(data: Dictionary) -> void:
	_history.clear()
	var saved_history: Variant = data.get("history", [])
	if saved_history is Array:
		for entry: Variant in saved_history:
			if entry is Dictionary:
				_history.append(
					PerformanceReport.from_dict(entry as Dictionary)
				)
	_daily_items_sold = int(data.get("daily_items_sold", 0))
	_daily_units_sold = int(data.get("daily_units_sold", 0))
	_daily_customers_served = int(
		data.get("daily_customers_served", 0)
	)
	_daily_revenue = float(data.get("daily_revenue", 0.0))
	_daily_walkouts = int(data.get("daily_walkouts", 0))
	_daily_reputation_start = float(
		data.get("daily_reputation_start", 0.0)
	)
	_daily_reputation_end = float(
		data.get("daily_reputation_end", 0.0)
	)
	var item_revs: Variant = data.get("daily_item_revenues", {})
	if item_revs is Dictionary:
		_daily_item_revenues = (item_revs as Dictionary).duplicate()
	var item_counts: Variant = data.get("daily_item_counts", {})
	if item_counts is Dictionary:
		_daily_item_counts = (item_counts as Dictionary).duplicate()
	_daily_haggle_wins = int(data.get("daily_haggle_wins", 0))
	_daily_haggle_losses = int(data.get("daily_haggle_losses", 0))
	_daily_late_fee_income = float(
		data.get("daily_late_fee_income", 0.0)
	)
	_daily_warranty_revenue = float(
		data.get("daily_warranty_revenue", 0.0)
	)
	_daily_warranty_claim_costs = float(
		data.get("daily_warranty_claim_costs", 0.0)
	)
	_daily_start_tier = int(data.get("daily_start_tier", -1))
	_daily_end_tier = int(data.get("daily_end_tier", -1))
	_daily_milestones.clear()
	var saved_ms: Variant = data.get("daily_milestones", [])
	if saved_ms is Array:
		for entry: Variant in saved_ms:
			_daily_milestones.append(str(entry))


func _on_daily_financials_snapshot(
	revenue: float, expenses: float, _net: float
) -> void:
	_snapshot_revenue = revenue
	_snapshot_expenses = expenses
	_snapshot_received = true


func _on_day_started(_day: int) -> void:
	_daily_items_sold = 0
	_daily_units_sold = 0
	_daily_customers_served = 0
	_daily_revenue = 0.0
	_daily_walkouts = 0
	_daily_item_revenues.clear()
	_daily_item_counts.clear()
	_daily_haggle_wins = 0
	_daily_haggle_losses = 0
	_daily_late_fee_income = 0.0
	_daily_warranty_revenue = 0.0
	_daily_warranty_claim_costs = 0.0
	_daily_milestones.clear()
	_daily_start_tier = _daily_end_tier
	_daily_reputation_start = _daily_reputation_end


func _on_day_ended(day: int) -> void:
	var report: PerformanceReport = _build_report(day)
	_apply_record_flags(report)
	_history.append(report)
	if _history.size() > MAX_HISTORY_SIZE:
		_history.remove_at(0)
	EventBus.performance_report_ready.emit(report)


func _on_item_sold(
	item_id: String, price: float, _category: String
) -> void:
	_daily_items_sold += 1
	var current: float = float(
		_daily_item_revenues.get(item_id, 0.0)
	)
	_daily_item_revenues[item_id] = current + price
	var current_count: int = int(_daily_item_counts.get(item_id, 0))
	_daily_item_counts[item_id] = current_count + 1


func _on_customer_purchased(
	_store_id: StringName, _item_id: StringName,
	price: float, _customer_id: StringName
) -> void:
	if price <= 0.0:
		return
	_daily_revenue += price
	_daily_units_sold += 1
	_daily_customers_served += 1


func _on_customer_left(customer_data: Dictionary) -> void:
	var satisfied: Variant = customer_data.get("satisfied", true)
	if satisfied is bool and not satisfied:
		_daily_walkouts += 1


func _on_reputation_changed(
	_store_id: String, new_value: float
) -> void:
	if _daily_reputation_start == 0.0:
		_daily_reputation_start = new_value
	_daily_reputation_end = new_value
	_daily_end_tier = _score_to_tier(new_value)
	if _daily_start_tier < 0:
		_daily_start_tier = _daily_end_tier


func _build_report(day: int) -> PerformanceReport:
	var report := PerformanceReport.new()
	report.day = day
	if not _snapshot_received:
		push_warning(
			"PerformanceReportSystem: daily_financials_snapshot not"
			+ " received before generate_report(); defaulting to 0.0"
		)
		report.revenue = 0.0
		report.expenses = 0.0
	else:
		report.revenue = _snapshot_revenue
		report.expenses = _snapshot_expenses
	report.profit = report.revenue - report.expenses
	_snapshot_received = false
	_snapshot_revenue = 0.0
	_snapshot_expenses = 0.0
	report.items_sold = _daily_items_sold
	report.units_sold = _daily_units_sold
	report.customers_served = _daily_customers_served
	report.walkouts = _daily_walkouts
	var total_interactions: int = _daily_customers_served + _daily_walkouts
	report.satisfaction_rate = clampf(
		float(_daily_customers_served - _daily_walkouts)
		/ float(max(1, total_interactions)),
		0.0,
		1.0,
	)
	report.reputation_delta = (
		_daily_reputation_end - _daily_reputation_start
	)
	var top_result: Dictionary = _find_top_item()
	report.top_item_sold = top_result.get("id", "")
	report.top_item_quantity = top_result.get("count", 0)
	report.haggle_wins = _daily_haggle_wins
	report.haggle_losses = _daily_haggle_losses
	report.tier_changed = (
		_daily_start_tier >= 0
		and _daily_end_tier >= 0
		and _daily_start_tier != _daily_end_tier
	)
	if report.tier_changed:
		report.new_tier_name = _tier_name(_daily_end_tier)
	report.late_fee_income = _daily_late_fee_income
	report.warranty_revenue = _daily_warranty_revenue
	report.warranty_claim_costs = _daily_warranty_claim_costs
	report.milestones_unlocked = _daily_milestones.duplicate()
	return report


func _find_top_item() -> Dictionary:
	var best_id: String = ""
	var best_revenue: float = 0.0
	for item_id: String in _daily_item_revenues:
		var rev: float = float(_daily_item_revenues[item_id])
		if rev > best_revenue:
			best_revenue = rev
			best_id = item_id
	var count: int = int(_daily_item_counts.get(best_id, 0))
	return {"id": best_id, "count": count}


func _on_haggle_completed(
	_store_id: StringName, _item_id: StringName,
	_final_price: float, _asking_price: float,
	_accepted: bool, _offer_count: int
) -> void:
	_daily_haggle_wins += 1


func _on_haggle_failed(
	_item_id: String, _customer_id: int
) -> void:
	_daily_haggle_losses += 1


func _on_rental_late_fee(
	_item_id: String, late_fee: float, _days_late: int
) -> void:
	_daily_late_fee_income += late_fee


func _on_warranty_purchased(
	_item_id: String, warranty_fee: float
) -> void:
	_daily_warranty_revenue += warranty_fee


func _on_warranty_claim_triggered(
	_item_id: String, replacement_cost: float
) -> void:
	_daily_warranty_claim_costs += replacement_cost


func _on_milestone_completed(
	_milestone_id: String,
	milestone_name: String,
	_reward_description: String,
) -> void:
	_daily_milestones.append(milestone_name)


func _score_to_tier(score: float) -> int:
	if score >= 76.0:
		return 3
	if score >= 51.0:
		return 2
	if score >= 26.0:
		return 1
	return 0


func _tier_name(tier: int) -> String:
	match tier:
		0:
			return "Notorious"
		1:
			return "Unremarkable"
		2:
			return "Reputable"
		3:
			return "Legendary"
	return "Unremarkable"


func _apply_record_flags(report: PerformanceReport) -> void:
	var flags: Dictionary = {}
	if _history.is_empty():
		if report.revenue > 0.0:
			flags["best_day_revenue"] = true
		report.record_flags = flags
		return
	var best_rev: float = 0.0
	var worst_rev: float = INF
	for past: PerformanceReport in _history:
		if past.revenue > best_rev:
			best_rev = past.revenue
		if past.revenue < worst_rev:
			worst_rev = past.revenue
	if report.revenue > best_rev:
		flags["best_day_revenue"] = true
	if report.revenue < worst_rev:
		flags["worst_day_revenue"] = true
	report.record_flags = flags
