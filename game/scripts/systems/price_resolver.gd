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
## grade follows base: formal card grade applied before market/seasonal factors.
## demo_unit sits between event and haggle: floor presence boost before player negotiation.
const CHAIN_ORDER: Array[String] = [
	"base", "grade", "seasonal", "reputation", "event", "demo_unit", "haggle",
]

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
			entry.get("label", entry.get("name", "?"))
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
## emitting price_resolved on EventBus when emit_signal is true.
##
## The caller supplies multipliers with "slot" (one of CHAIN_ORDER) or "label"
## that matches a canonical name; unrecognized slots are applied after the
## canonical ones, preserving caller order.
static func resolve_for_item(
	item_id: StringName,
	base_price: float,
	multipliers: Array,
	emit_signal: bool = true,
) -> Result:
	var ordered: Array = _resequence(multipliers)
	var with_base: Array = [{
		"slot": "base",
		"label": "Base",
		"factor": 1.0,
		"detail": "Base price $%.2f" % base_price,
	}]
	with_base.append_array(ordered)
	var result: Result = resolve(base_price, with_base)
	if emit_signal:
		EventBus.price_resolved.emit(item_id, result.final_price, result.steps)
	return result


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
	for name: String in CHAIN_ORDER:
		if slots.has(name):
			result.append(slots[name])
	for entry: Dictionary in tail:
		result.append(entry)
	return result
