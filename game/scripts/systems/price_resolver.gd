## Ordered multiplier chain with per-step audit trace.
##
## Canonical multiplier order: base → seasonal → reputation → event → haggle.
## Each multiplier entry must be a Dictionary with at least "factor" (float).
## The label field accepts either "label" or "name"; the detail field accepts
## either "detail" or "source". Unrecognized slot labels are still applied in
## the order the caller supplied, after being resequenced into the canonical
## slot order when the label matches a known slot.
class_name PriceResolver
extends RefCounted


## Canonical multiplier slot names, applied in this order when resequencing.
## rarity: raw rarity tier × difficulty rarity_scale (applied once, before lifecycle).
## lifecycle: rental freshness (ultra_new 1.35 / new 1.15 / common 1.0).
## condition: item wear state (poor → reduced factor).
## grade follows condition: formal letter-grade (Retro Games / Sports Cards).
## numeric_grade: ACC 1–10 numeric grade (Sports Cards).
## auth: authentication status multiplier (authenticated items get a bonus).
## demand: category demand modifier from EconomySystem sales history.
## drift: per-item random-walk drift factor from EconomySystem.
## trend: category trend level from MarketTrendSystem.
## seasonal: spending season × calendar × sport_season × tournament demand.
## reputation: store reputation tier (auto-injected when absent).
## meta_shift: meta-shift system multiplier for Pocket Creatures.
## event: active market event multiplier.
## test: item test-result multiplier (tested_working / tested_not_working).
## depreciation: time-based electronics depreciation / appreciation.
## demo_unit: floor-presence boost before player negotiation.
## random: checkout offer variance (±15% market noise).
## sensitivity: customer price-sensitivity discount in checkout offers.
## haggle: negotiated price ratio (final agreed price / sticker price).
## warranty: extended warranty add-on factor injected after haggle.
const CHAIN_ORDER: Array[String] = [
	"base", "rarity", "lifecycle", "condition", "grade", "numeric_grade",
	"auth", "demand", "drift", "trend", "seasonal", "reputation",
	"meta_shift", "event", "test", "depreciation", "demo_unit",
	"random", "sensitivity", "haggle", "warranty",
]

## Lifecycle multipliers for rental items by rarity tier (ISSUE-009).
const LIFECYCLE_MULTIPLIERS: Dictionary = {
	"ultra_new": 1.35,
	"new": 1.15,
	"common": 1.0,
}

## Six-tier card grade multipliers for the Sports Cards authentication mechanic.
## Applied via the "grade" slot in the PriceResolver chain.
const GRADE_MULTIPLIERS: Dictionary = {
	"S": 5.0,
	"A": 3.0,
	"B": 2.0,
	"C": 1.2,
	"D": 0.8,
	"F": 0.4,
}

## Grade tiers in ascending order (F = worst, S = best).
const GRADE_ORDER: PackedStringArray = ["F", "D", "C", "B", "A", "S"]

## Apex Card Certification (ACC) 1–10 numeric grade multipliers for Sports Cards.
## Mirrors the multiplier table in game/content/sports_cards/grade_definitions.json.
## Applied via the "numeric_grade" slot in the PriceResolver chain.
const NUMERIC_GRADE_MULTIPLIERS: Dictionary = {
	1: 0.10,
	2: 0.20,
	3: 0.35,
	4: 0.55,
	5: 0.80,
	6: 1.00,
	7: 1.20,
	8: 1.60,
	9: 2.50,
	10: 5.00,
}

## ACC grade labels for audit-trace display.
const NUMERIC_GRADE_LABELS: Dictionary = {
	1: "Poor",
	2: "Fair",
	3: "Very Good",
	4: "VG-Excellent",
	5: "Excellent",
	6: "Excellent-Near Mint",
	7: "Near Mint",
	8: "Near Mint-Mint",
	9: "Mint",
	10: "Gem Mint",
}


## A single step in the audit chain.
class AuditStep:
	var label: String
	var factor: float
	var price_after: float
	var detail: String

	func _init(l: String, f: float, p: float, d: String = "") -> void:
		label = l
		factor = f
		price_after = p
		detail = d

	func format() -> String:
		return "%-18s ×%.3f → $%-8.2f  %s" % [label, factor, price_after, detail]

	func to_dict() -> Dictionary:
		return {
			"name": label,
			"factor": factor,
			"price_after": price_after,
			"source": detail,
		}


## Returned by resolve().
class Result:
	var final_price: float = 0.0
	var steps: Array  # Array of AuditStep
	var audit_trace: Array  # Array of Dictionary (serializable view of steps)

	func _init() -> void:
		steps = []
		audit_trace = []

	func format_audit() -> String:
		var lines: Array[String] = []
		for step: Variant in steps:
			if step is AuditStep:
				lines.append((step as AuditStep).format())
		lines.append("FINAL: $%.2f" % final_price)
		return "\n".join(lines)


## Applies multipliers to base_price in declaration order and returns a Result.
## Accepts entries with label/factor/detail OR name/factor/source.
static func resolve(base_price: float, multipliers: Array) -> Result:
	var result := Result.new()
	var price := base_price
	for m: Variant in multipliers:
		if m is not Dictionary:
			continue
		var entry: Dictionary = m as Dictionary
		var factor: float = float(entry.get("factor", 1.0))
		price *= factor
		var label: String = str(
			entry.get("label", entry.get("name", entry.get("slot", "?")))
		)
		var detail: String = str(
			entry.get("detail", entry.get("source", ""))
		)
		var step := AuditStep.new(label, factor, price, detail)
		result.steps.append(step)
		result.audit_trace.append(step.to_dict())
	result.final_price = price
	return result


## Resolves a price for an item by applying canonical-ordered multipliers and
## emitting price_resolved on EventBus when emit_price_signal is true.
##
## The caller supplies multipliers with "slot" (one of CHAIN_ORDER) or "label"
## that matches a canonical name; unrecognized slots are applied after the
## canonical ones, preserving caller order.
static func resolve_for_item(
	item_id: StringName,
	base_price: float,
	multipliers: Array,
	emit_price_signal: bool = true,
) -> Result:
	var ordered: Array = _resequence(_inject_reputation(multipliers))
	var with_base: Array = [{
		"slot": "base",
		"label": "Base",
		"factor": 1.0,
		"detail": "Base price $%.2f" % base_price,
	}]
	with_base.append_array(ordered)
	var result: Result = resolve(base_price, with_base)
	if emit_price_signal:
		EventBus.price_resolved.emit(item_id, result.final_price, result.steps)
	return result


## Inserts a reputation multiplier entry drawn from ReputationSystemSingleton
## when the caller did not supply one. Keeps every resolve call auditable
## against the active store's live reputation.
static func _inject_reputation(multipliers: Array) -> Array:
	for m: Variant in multipliers:
		if m is not Dictionary:
			continue
		var entry: Dictionary = m as Dictionary
		var slot: String = str(
			entry.get("slot", entry.get("label", entry.get("name", "")))
		).to_lower()
		if slot == "reputation":
			return multipliers
	var store_id: String = ""
	var active: StringName = GameManager.get_active_store_id()
	if not active.is_empty():
		store_id = String(active)
	var factor: float = ReputationSystemSingleton.get_reputation_multiplier(store_id)
	var score: float = ReputationSystemSingleton.get_reputation(store_id)
	var source: String = "ReputationManager[%s]=%.1f" % [
		store_id if not store_id.is_empty() else "active", score
	]
	var extended: Array = []
	extended.append_array(multipliers)
	extended.append({
		"slot": "reputation",
		"label": "Reputation",
		"name": "reputation",
		"factor": factor,
		"detail": source,
		"source": source,
	})
	return extended


static func _resequence(multipliers: Array) -> Array:
	var slots: Dictionary = {}
	var tail: Array = []
	for m: Variant in multipliers:
		if m is not Dictionary:
			continue
		var entry: Dictionary = m as Dictionary
		var slot: String = str(
			entry.get("slot", entry.get("label", entry.get("name", "")))
		).to_lower()
		if CHAIN_ORDER.has(slot):
			slots[slot] = entry
		else:
			tail.append(entry)
	var result: Array = []
	for slot_key: String in CHAIN_ORDER:
		if slots.has(slot_key):
			result.append(slots[slot_key])
	for entry: Dictionary in tail:
		result.append(entry)
	return result
