## Accumulates per-day metrics and generates end-of-day performance reports.
class_name PerformanceReportSystem
extends Node


const MAX_HISTORY_SIZE: int = 30
const DAY_BEATS_PATH: String = "res://game/content/day_beats.json"

var _current_day: int = 1
var _day_beats: Dictionary = {}  # loaded from day_beats.json at initialize
var _daily_gross_revenue: float = 0.0
var _daily_total_expenses: float = 0.0
var _daily_items_sold: int = 0
var _daily_units_sold: int = 0
var _daily_customers_served: int = 0
var _daily_satisfied_customers: int = 0
var _daily_revenue: float = 0.0
var _daily_walkouts: int = 0
var _daily_reputation_start: float = 0.0
var _daily_reputation_end: float = 0.0
var _daily_item_revenues: Dictionary = {}
var _daily_item_max_prices: Dictionary = {}
var _daily_item_counts: Dictionary = {}
var _daily_customer_satisfaction_by_id: Dictionary = {}
var _daily_haggle_wins: int = 0
var _daily_haggle_losses: int = 0
var _daily_late_fee_income: float = 0.0
var _daily_overdue_count: int = 0
var _daily_warranty_revenue: float = 0.0
var _daily_warranty_claim_costs: float = 0.0
var _daily_electronics_sold: int = 0
var _daily_warranty_sold: int = 0
var _demo_unit_was_active: bool = false
var _daily_demo_contribution: float = 0.0
var _daily_milestones: Array[String] = []
var _daily_milestone_data: Array[Dictionary] = []
var _daily_start_tier: int = -1
var _daily_end_tier: int = -1
var _history: Array[PerformanceReport] = []

## Cached values from the most recent daily_financials_snapshot.
var _snapshot_revenue: float = 0.0
var _snapshot_expenses: float = 0.0
var _snapshot_received: bool = false


func initialize() -> void:
	_current_day = max(GameManager.get_current_day(), 1)
	_load_day_beats()
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.transaction_completed.connect(_on_transaction_completed)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.haggle_completed.connect(_on_haggle_completed)
	EventBus.haggle_failed.connect(_on_haggle_failed)
	EventBus.milestone_completed.connect(_on_milestone_completed)
	EventBus.rental_late_fee.connect(_on_rental_late_fee)
	EventBus.late_fee_collected.connect(_on_late_fee_collected)
	EventBus.rental_overdue.connect(_on_rental_overdue)
	EventBus.warranty_purchased.connect(_on_warranty_purchased)
	EventBus.warranty_claim_triggered.connect(
		_on_warranty_claim_triggered
	)
	EventBus.demo_unit_activated.connect(_on_demo_unit_activated)
	EventBus.demo_contribution_recorded.connect(
		_on_demo_contribution_recorded
	)
	EventBus.daily_financials_snapshot.connect(
		_on_daily_financials_snapshot
	)


func get_history() -> Array[PerformanceReport]:
	var sorted_history: Array[PerformanceReport] = []
	for report: PerformanceReport in _history:
		sorted_history.append(report)
	sorted_history.sort_custom(
		func(a: PerformanceReport, b: PerformanceReport) -> bool:
			return a.day < b.day
	)
	return sorted_history


func get_daily_revenue() -> float:
	return _daily_revenue


func get_daily_units_sold() -> int:
	return _daily_units_sold


func get_daily_customers_served() -> int:
	return _daily_customers_served


## Returns the legacy live daily summary dictionary used by UI and tests.
func generate_report() -> Dictionary:
	var gross_revenue: float = _daily_gross_revenue
	var total_expenses: float = _daily_total_expenses
	if _snapshot_received:
		gross_revenue = _snapshot_revenue
		total_expenses = _snapshot_expenses
	return {
		"gross_revenue": gross_revenue,
		"total_expenses": total_expenses,
		"net_profit": gross_revenue - total_expenses,
		"units_sold": _daily_units_sold,
		"day": _current_day,
	}


func get_save_data() -> Dictionary:
	var serialized_history: Array[Dictionary] = []
	for report: PerformanceReport in _history:
		serialized_history.append(report.to_dict())
	return {
		"history": serialized_history,
		"current_day": _current_day,
		"daily_gross_revenue": _daily_gross_revenue,
		"daily_total_expenses": _daily_total_expenses,
		"daily_items_sold": _daily_items_sold,
		"daily_units_sold": _daily_units_sold,
		"daily_customers_served": _daily_customers_served,
		"daily_satisfied_customers": _daily_satisfied_customers,
		"daily_revenue": _daily_revenue,
		"daily_walkouts": _daily_walkouts,
		"daily_reputation_start": _daily_reputation_start,
		"daily_reputation_end": _daily_reputation_end,
		"daily_item_revenues": _daily_item_revenues.duplicate(),
		"daily_item_max_prices": _daily_item_max_prices.duplicate(),
		"daily_item_counts": _daily_item_counts.duplicate(),
		"daily_customer_satisfaction_by_id": (
			_daily_customer_satisfaction_by_id.duplicate()
		),
		"daily_haggle_wins": _daily_haggle_wins,
		"daily_haggle_losses": _daily_haggle_losses,
		"daily_late_fee_income": _daily_late_fee_income,
		"daily_warranty_revenue": _daily_warranty_revenue,
		"daily_warranty_claim_costs": _daily_warranty_claim_costs,
		"daily_milestones": _daily_milestones.duplicate(),
		"daily_milestone_data": _daily_milestone_data.duplicate(),
		"daily_start_tier": _daily_start_tier,
		"daily_end_tier": _daily_end_tier,
	}


func load_save_data(data: Dictionary) -> void:
	_history.clear()
	_current_day = int(data.get("current_day", max(GameManager.get_current_day(), 1)))
	var saved_history: Variant = data.get("history", [])
	if saved_history is Array:
		for entry: Variant in saved_history:
			if entry is Dictionary:
				_history.append(
					PerformanceReport.from_dict(entry as Dictionary)
				)
	_daily_gross_revenue = float(
		data.get("daily_gross_revenue", data.get("daily_revenue", 0.0))
	)
	_daily_total_expenses = float(data.get("daily_total_expenses", 0.0))
	_daily_items_sold = int(data.get("daily_items_sold", 0))
	_daily_units_sold = int(data.get("daily_units_sold", 0))
	_daily_customers_served = int(
		data.get("daily_customers_served", 0)
	)
	_daily_satisfied_customers = int(
		data.get("daily_satisfied_customers", _daily_customers_served)
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
	var item_prices: Variant = data.get("daily_item_max_prices", {})
	if item_prices is Dictionary:
		_daily_item_max_prices = (item_prices as Dictionary).duplicate()
	var item_counts: Variant = data.get("daily_item_counts", {})
	if item_counts is Dictionary:
		_daily_item_counts = (item_counts as Dictionary).duplicate()
	var customer_satisfaction: Variant = data.get(
		"daily_customer_satisfaction_by_id", {}
	)
	if customer_satisfaction is Dictionary:
		_daily_customer_satisfaction_by_id = (
			customer_satisfaction as Dictionary
		).duplicate()
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
	_daily_milestone_data.clear()
	var saved_ms: Variant = data.get("daily_milestones", [])
	if saved_ms is Array:
		for entry: Variant in saved_ms:
			_daily_milestones.append(str(entry))
	var saved_ms_data: Variant = data.get("daily_milestone_data", [])
	if saved_ms_data is Array:
		for entry: Variant in saved_ms_data:
			if entry is Dictionary:
				_daily_milestone_data.append(
					(entry as Dictionary).duplicate()
				)


func _on_daily_financials_snapshot(
	revenue: float, expenses: float, _net: float
) -> void:
	_daily_gross_revenue = revenue
	_daily_total_expenses = expenses
	_snapshot_revenue = revenue
	_snapshot_expenses = expenses
	_snapshot_received = true


func _on_day_started(day: int) -> void:
	_current_day = max(day, 1)
	_daily_gross_revenue = 0.0
	_daily_total_expenses = 0.0
	_daily_items_sold = 0
	_daily_units_sold = 0
	_daily_customers_served = 0
	_daily_satisfied_customers = 0
	_daily_revenue = 0.0
	_daily_walkouts = 0
	_daily_item_revenues.clear()
	_daily_item_max_prices.clear()
	_daily_item_counts.clear()
	_daily_customer_satisfaction_by_id.clear()
	_daily_haggle_wins = 0
	_daily_haggle_losses = 0
	_daily_late_fee_income = 0.0
	_daily_overdue_count = 0
	_daily_warranty_revenue = 0.0
	_daily_warranty_claim_costs = 0.0
	_daily_electronics_sold = 0
	_daily_warranty_sold = 0
	_demo_unit_was_active = false
	_daily_demo_contribution = 0.0
	_daily_milestones.clear()
	_daily_milestone_data.clear()
	_daily_start_tier = _daily_end_tier
	_daily_reputation_start = _daily_reputation_end
	_snapshot_received = false
	_snapshot_revenue = 0.0
	_snapshot_expenses = 0.0


func _on_transaction_completed(
	amount: float, success: bool, message: String
) -> void:
	if not success or amount <= 0.0:
		return
	if _is_expense_transaction(message):
		_daily_total_expenses += amount
		return
	_daily_gross_revenue += amount


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
	if price > 0.0:
		_daily_revenue += price
	var current: float = float(
		_daily_item_revenues.get(item_id, 0.0)
	)
	_daily_item_revenues[item_id] = current + price
	var best_price: float = float(
		_daily_item_max_prices.get(item_id, 0.0)
	)
	if price > best_price:
		_daily_item_max_prices[item_id] = price
	var current_count: int = int(_daily_item_counts.get(item_id, 0))
	_daily_item_counts[item_id] = current_count + 1


func _on_customer_purchased(
	store_id: StringName, _item_id: StringName,
	price: float, _customer_id: StringName
) -> void:
	if price <= 0.0:
		return
	if not _daily_item_counts.has(String(_item_id)):
		_daily_revenue += price
	_daily_units_sold += 1
	_mark_customer_served(String(_customer_id), true)
	if store_id == &"electronics":
		_daily_electronics_sold += 1


func _on_customer_left(customer_data: Dictionary) -> void:
	var satisfied: bool = bool(customer_data.get("satisfied", true))
	_mark_customer_served(
		str(customer_data.get("customer_id", "")),
		satisfied,
	)


func _on_reputation_changed(
	_store_id: String, _old_score: float, new_value: float
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
			+ " received before generate_report(); using observed revenue"
		)
		report.revenue = _daily_revenue
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
	if _daily_customers_served > 0:
		report.satisfaction_rate = (
			float(_daily_satisfied_customers)
			/ float(_daily_customers_served)
		)
	else:
		report.satisfaction_rate = 0.0
	report.reputation_delta = (
		_daily_reputation_end - _daily_reputation_start
	)
	var top_result: Dictionary = _find_top_item()
	report.top_item_sold = top_result.get("id", "")
	report.top_item_price = float(top_result.get("price", 0.0))
	report.top_item_quantity = top_result.get("count", 0)
	report.story_beat = _get_story_beat(day)
	report.forward_hook = _get_forward_hook(day)
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
	report.overdue_items_count = _daily_overdue_count
	report.warranty_revenue = _daily_warranty_revenue
	report.warranty_claim_costs = _daily_warranty_claim_costs
	if _daily_electronics_sold > 0:
		report.warranty_attach_rate = (
			float(_daily_warranty_sold) / float(_daily_electronics_sold)
		)
	report.electronics_demo_active = _demo_unit_was_active
	report.demo_contribution_revenue = _daily_demo_contribution
	report.milestones_unlocked = _daily_milestones.duplicate()
	report.milestones_data = _daily_milestone_data.duplicate()
	return report


func _find_top_item() -> Dictionary:
	var best_id: String = ""
	var best_price: float = 0.0
	for item_id: String in _daily_item_max_prices:
		var price: float = float(_daily_item_max_prices[item_id])
		if price > best_price:
			best_price = price
			best_id = item_id
	var count: int = int(_daily_item_counts.get(best_id, 0))
	return {"id": best_id, "count": count, "price": best_price}


func _load_day_beats() -> void:
	if not FileAccess.file_exists(DAY_BEATS_PATH):
		push_warning("PerformanceReportSystem: day_beats.json not found")
		return
	var file := FileAccess.open(DAY_BEATS_PATH, FileAccess.READ)
	if not file:
		push_warning("PerformanceReportSystem: cannot open day_beats.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PerformanceReportSystem: day_beats.json parse error")
		return
	file.close()
	var data: Variant = json.get_data()
	if data is not Dictionary:
		return
	_day_beats = data as Dictionary


func _get_beat_for_day(day: int) -> Dictionary:
	var beats: Variant = _day_beats.get("day_beats", [])
	if beats is Array:
		for entry: Variant in beats as Array:
			if entry is Dictionary and int((entry as Dictionary).get("day", -1)) == day:
				return entry as Dictionary
	return {}


func _get_story_beat(day: int) -> String:
	var beat: Dictionary = _get_beat_for_day(day)
	if not beat.is_empty():
		var text: String = str(beat.get("story_beat", ""))
		if not text.is_empty():
			return text
	var fallback: String = str(_day_beats.get("fallback_beat", ""))
	if not fallback.is_empty():
		return fallback
	return "Another day at Cormorant Ridge Mall."


func _get_forward_hook(day: int) -> String:
	var beat: Dictionary = _get_beat_for_day(day)
	if not beat.is_empty():
		var text: String = str(beat.get("forward_hook", ""))
		if not text.is_empty():
			return text
	var fallback: String = str(_day_beats.get("fallback_hook", ""))
	if not fallback.is_empty():
		return fallback
	return "Tomorrow brings fresh opportunities."


func _is_expense_transaction(message: String) -> bool:
	var normalized: String = message.strip_edges().to_lower()
	return (
		normalized.begins_with("rent:")
		or normalized.contains("wage")
		or normalized.contains("order cost")
		or normalized.contains("cost")
		or normalized.contains("expense")
	)


func _mark_customer_served(customer_id: String, satisfied: bool) -> void:
	if customer_id.is_empty():
		_daily_customers_served += 1
		if satisfied:
			_daily_satisfied_customers += 1
		else:
			_daily_walkouts += 1
		return

	if _daily_customer_satisfaction_by_id.has(customer_id):
		var previous: bool = bool(
			_daily_customer_satisfaction_by_id[customer_id]
		)
		if previous == satisfied:
			return
		_daily_customer_satisfaction_by_id[customer_id] = satisfied
		if previous:
			_daily_satisfied_customers -= 1
		else:
			_daily_walkouts -= 1
		if satisfied:
			_daily_satisfied_customers += 1
		else:
			_daily_walkouts += 1
		return

	_daily_customer_satisfaction_by_id[customer_id] = satisfied
	_daily_customers_served += 1
	if satisfied:
		_daily_satisfied_customers += 1
	else:
		_daily_walkouts += 1


func _on_haggle_completed(
	_store_id: StringName, _item_id: StringName,
	_final_price: float, _asking_price: float,
	accepted: bool, _offer_count: int
) -> void:
	if accepted:
		_daily_haggle_wins += 1


func _on_haggle_failed(
	_item_id: String, _customer_id: int
) -> void:
	_daily_haggle_losses += 1


## rental_late_fee now fires on accrual (pending, not yet collected); we only
## count actual collected revenue via late_fee_collected below.
func _on_rental_late_fee(
	_item_id: String, _late_fee: float, _days_late: int
) -> void:
	pass


func _on_late_fee_collected(
	_item_id: String, amount: float, _days_late: int
) -> void:
	_daily_late_fee_income += amount


func _on_rental_overdue(
	_customer_id: String, _item_id: String
) -> void:
	_daily_overdue_count += 1


func _on_warranty_purchased(
	_item_id: String, warranty_fee: float
) -> void:
	_daily_warranty_revenue += warranty_fee
	_daily_warranty_sold += 1


func _on_warranty_claim_triggered(
	_item_id: String, replacement_cost: float
) -> void:
	_daily_warranty_claim_costs += replacement_cost


func _on_demo_unit_activated(_item_id: String, _category: String) -> void:
	_demo_unit_was_active = true


func _on_demo_contribution_recorded(amount: float) -> void:
	if amount <= 0.0:
		return
	_demo_unit_was_active = true
	_daily_demo_contribution += amount


func _on_milestone_completed(
	milestone_id: String,
	milestone_name: String,
	reward_description: String,
) -> void:
	_daily_milestones.append(milestone_name)
	var description: String = _lookup_milestone_description(milestone_id)
	_daily_milestone_data.append({
		"name": milestone_name,
		"description": description,
		"reward": reward_description,
	})


func _lookup_milestone_description(milestone_id: String) -> String:
	if milestone_id.is_empty():
		return ""
	if GameManager == null or GameManager.data_loader == null:
		return ""
	var definition: MilestoneDefinition = (
		GameManager.data_loader.get_milestone(milestone_id)
	)
	if definition == null:
		return ""
	return definition.description


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
	var flags: Dictionary = {
		"best_day_revenue": false,
		"worst_day_revenue": false,
	}
	if _history.is_empty():
		flags["best_day_revenue"] = true
		flags["worst_day_revenue"] = true
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
