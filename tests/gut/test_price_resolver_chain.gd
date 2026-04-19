## Parameterized coverage for the canonical PriceResolver multiplier chain.
## Verifies: base → seasonal → reputation → event → haggle ordering is
## preserved for every store type, the final price matches the product of
## factors, and the price_resolved signal carries the audit trace.
extends GutTest


const TOLERANCE: float = 0.001
const BASE_PRICE: float = 100.0

var _store_params: Array = [
	{"store": "sports"},
	{"store": "retro_games"},
	{"store": "pocket_creatures"},
	{"store": "video_rental"},
	{"store": "electronics"},
]


func _canonical_multipliers(store: String) -> Array:
	return [
		{"slot": "event", "factor": 1.10, "detail": "%s event" % store},
		{"slot": "haggle", "factor": 0.90, "detail": "%s haggle" % store},
		{"slot": "reputation", "factor": 1.05, "detail": "%s reputation" % store},
		{"slot": "seasonal", "factor": 1.20, "detail": "%s seasonal" % store},
	]


func test_chain_order_preserved_for_all_stores(p = use_parameters(_store_params)) -> void:
	var store: String = p["store"]
	var multipliers: Array = _canonical_multipliers(store)
	var item_id: StringName = StringName("%s_item" % store)
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		item_id, BASE_PRICE, multipliers, false
	)
	var labels: Array[String] = []
	for step: Variant in result.steps:
		if step is PriceResolver.AuditStep:
			labels.append((step as PriceResolver.AuditStep).label.to_lower())
	var expected_order: Array[String] = ["base", "seasonal", "reputation", "event", "haggle"]
	assert_eq(
		labels, expected_order,
		"Canonical slots must resolve in base → seasonal → reputation → event → haggle order for %s" % store
	)
	var expected: float = BASE_PRICE * 1.20 * 1.05 * 1.10 * 0.90
	assert_almost_eq(
		result.final_price, expected, TOLERANCE,
		"Final price should equal ordered product of factors for %s" % store
	)


func test_haggle_applied_last_in_audit_trace() -> void:
	var multipliers: Array = _canonical_multipliers("sports")
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"item", BASE_PRICE, multipliers, false
	)
	assert_gt(result.steps.size(), 0, "Chain must produce at least one step")
	var last: PriceResolver.AuditStep = result.steps[result.steps.size() - 1]
	assert_eq(
		last.label.to_lower(), "haggle",
		"Haggle must be the final multiplier applied"
	)


func test_audit_trace_dicts_expose_breakdown() -> void:
	var multipliers: Array = _canonical_multipliers("retro_games")
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"cart", BASE_PRICE, multipliers, false
	)
	assert_eq(
		result.audit_trace.size(), result.steps.size(),
		"audit_trace must have one dict per step"
	)
	for entry: Dictionary in result.audit_trace:
		assert_true(entry.has("name"), "audit dict must have name")
		assert_true(entry.has("factor"), "audit dict must have factor")
		assert_true(entry.has("source"), "audit dict must have source")
		assert_true(entry.has("price_after"), "audit dict must have price_after")


func test_price_resolved_signal_carries_audit() -> void:
	var captured: Array = []
	var capture: Callable = func(iid: StringName, price: float, steps: Array) -> void:
		captured.append({"id": iid, "price": price, "steps": steps})
	EventBus.price_resolved.connect(capture)
	var multipliers: Array = _canonical_multipliers("electronics")
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"elec_001", BASE_PRICE, multipliers, true
	)
	EventBus.price_resolved.disconnect(capture)
	assert_eq(captured.size(), 1, "price_resolved must fire exactly once")
	assert_eq(captured[0]["id"], &"elec_001", "signal must carry item_id")
	assert_almost_eq(
		float(captured[0]["price"]), result.final_price, TOLERANCE,
		"signal price must match resolver final_price"
	)
	assert_eq(
		(captured[0]["steps"] as Array).size(), result.steps.size(),
		"signal must carry full audit step array"
	)
