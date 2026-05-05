## Data resource for a single day's performance summary.
class_name PerformanceReport
extends Resource


@export var day: int = 0
@export var revenue: float = 0.0
@export var expenses: float = 0.0
@export var profit: float = 0.0
@export var items_sold: int = 0
@export var customers_served: int = 0
@export var units_sold: int = 0
@export var walkouts: int = 0
@export var satisfaction_rate: float = 0.0
@export var reputation_delta: float = 0.0
@export var top_item_sold: String = ""
@export var top_item_price: float = 0.0
@export var top_item_quantity: int = 0
@export var story_beat: String = ""
@export var forward_hook: String = ""
@export var haggle_wins: int = 0
@export var haggle_losses: int = 0
@export var tier_changed: bool = false
@export var new_tier_name: String = ""
@export var milestones_unlocked: Array[String] = []
## Richer milestone data: [{name, reward}] populated alongside milestones_unlocked.
@export var milestones_data: Array[Dictionary] = []
@export var late_fee_income: float = 0.0
@export var overdue_items_count: int = 0
@export var warranty_revenue: float = 0.0
@export var warranty_claim_costs: float = 0.0
@export var warranty_attach_rate: float = 0.0
@export var electronics_demo_active: bool = false
@export var demo_contribution_revenue: float = 0.0
@export var record_flags: Dictionary = {}
## Per-store daily revenue breakdown; populated from day_closed signal.
@export var store_revenue: Dictionary = {}
## Customer-resolution satisfaction ratio for the day (0.0–1.0). Defaults to
## 1.0 when no customer interactions occurred.
@export var customer_satisfaction: float = 1.0
## Average employee trust at end of day (0.0–1.0). Snapshotted from
## EmploymentSystem; defaults to 0.0 when source absent.
@export var employee_trust: float = 0.0
## Manager trust at end of day (0.0–1.0). Snapshotted from
## ManagerRelationshipManager; defaults to 0.0 when source absent.
@export var manager_trust: float = 0.0
## Player mistakes accumulated for the day; reset at day_started.
@export var mistakes_count: int = 0
## Aggregate inventory variance ratio for the day. 0.0 when source absent.
@export var inventory_variance: float = 0.0
## Count of inventory discrepancies flagged during closing checklist.
@export var discrepancies_flagged: int = 0
## Single-line narrative consequence text for the day. Empty when none.
@export var hidden_thread_consequence_text: String = ""


func to_dict() -> Dictionary:
	return {
		"day": day,
		"revenue": revenue,
		"expenses": expenses,
		"profit": profit,
		"items_sold": items_sold,
		"customers_served": customers_served,
		"units_sold": units_sold,
		"walkouts": walkouts,
		"satisfaction_rate": satisfaction_rate,
		"reputation_delta": reputation_delta,
		"top_item_sold": top_item_sold,
		"top_item_price": top_item_price,
		"top_item_quantity": top_item_quantity,
		"story_beat": story_beat,
		"forward_hook": forward_hook,
		"haggle_wins": haggle_wins,
		"haggle_losses": haggle_losses,
		"tier_changed": tier_changed,
		"new_tier_name": new_tier_name,
		"milestones_unlocked": milestones_unlocked.duplicate(),
		"milestones_data": milestones_data.duplicate(),
		"late_fee_income": late_fee_income,
		"overdue_items_count": overdue_items_count,
		"warranty_revenue": warranty_revenue,
		"warranty_claim_costs": warranty_claim_costs,
		"warranty_attach_rate": warranty_attach_rate,
		"electronics_demo_active": electronics_demo_active,
		"demo_contribution_revenue": demo_contribution_revenue,
		"record_flags": record_flags.duplicate(),
		"store_revenue": store_revenue.duplicate(),
		"customer_satisfaction": customer_satisfaction,
		"employee_trust": employee_trust,
		"manager_trust": manager_trust,
		"mistakes_count": mistakes_count,
		"inventory_variance": inventory_variance,
		"discrepancies_flagged": discrepancies_flagged,
		"hidden_thread_consequence_text": hidden_thread_consequence_text,
	}


static func from_dict(data: Dictionary) -> PerformanceReport:
	var report := PerformanceReport.new()
	report.day = int(data.get("day", 0))
	report.revenue = float(data.get("revenue", 0.0))
	report.expenses = float(data.get("expenses", 0.0))
	report.profit = float(data.get("profit", 0.0))
	report.items_sold = int(data.get("items_sold", 0))
	report.customers_served = int(data.get("customers_served", 0))
	report.units_sold = int(data.get("units_sold", 0))
	report.walkouts = int(data.get("walkouts", 0))
	report.satisfaction_rate = float(
		data.get("satisfaction_rate", 0.0)
	)
	report.reputation_delta = float(
		data.get("reputation_delta", 0.0)
	)
	report.top_item_sold = str(data.get("top_item_sold", ""))
	report.top_item_price = float(data.get("top_item_price", 0.0))
	report.top_item_quantity = int(data.get("top_item_quantity", 0))
	report.story_beat = str(data.get("story_beat", ""))
	report.forward_hook = str(data.get("forward_hook", ""))
	report.haggle_wins = int(data.get("haggle_wins", 0))
	report.haggle_losses = int(data.get("haggle_losses", 0))
	report.tier_changed = bool(data.get("tier_changed", false))
	report.new_tier_name = str(data.get("new_tier_name", ""))
	var saved_milestones: Variant = data.get("milestones_unlocked", [])
	if saved_milestones is Array:
		for entry: Variant in saved_milestones:
			report.milestones_unlocked.append(str(entry))
	var saved_ms_data: Variant = data.get("milestones_data", [])
	if saved_ms_data is Array:
		for entry: Variant in saved_ms_data:
			if entry is Dictionary:
				report.milestones_data.append((entry as Dictionary).duplicate())
	report.late_fee_income = float(data.get("late_fee_income", 0.0))
	report.overdue_items_count = int(data.get("overdue_items_count", 0))
	report.warranty_revenue = float(
		data.get("warranty_revenue", 0.0)
	)
	report.warranty_claim_costs = float(
		data.get("warranty_claim_costs", 0.0)
	)
	report.warranty_attach_rate = float(
		data.get("warranty_attach_rate", 0.0)
	)
	report.electronics_demo_active = bool(
		data.get("electronics_demo_active", false)
	)
	report.demo_contribution_revenue = float(
		data.get("demo_contribution_revenue", 0.0)
	)
	var flags: Variant = data.get("record_flags", {})
	if flags is Dictionary:
		report.record_flags = (flags as Dictionary).duplicate()
	var store_rev: Variant = data.get("store_revenue", {})
	if store_rev is Dictionary:
		report.store_revenue = (store_rev as Dictionary).duplicate()
	report.customer_satisfaction = float(
		data.get("customer_satisfaction", 1.0)
	)
	report.employee_trust = float(data.get("employee_trust", 0.0))
	report.manager_trust = float(data.get("manager_trust", 0.0))
	report.mistakes_count = int(data.get("mistakes_count", 0))
	report.inventory_variance = float(data.get("inventory_variance", 0.0))
	report.discrepancies_flagged = int(data.get("discrepancies_flagged", 0))
	report.hidden_thread_consequence_text = str(
		data.get("hidden_thread_consequence_text", "")
	)
	return report
