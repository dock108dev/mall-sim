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


## ISSUE-020: running subtotal per step must equal the exact cumulative product
## of factors applied so far, with no premature rounding between steps.
func test_running_subtotal_preserves_precision() -> void:
	var multipliers: Array = [
		{"slot": "seasonal", "factor": 1.07},
		{"slot": "reputation", "factor": 1.03},
		{"slot": "event", "factor": 0.97},
		{"slot": "haggle", "factor": 1.11},
	]
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"precision_item", 19.99, multipliers, false
	)
	# Expected: slots resolve in canonical order (seasonal, reputation, event,
	# haggle) on top of the base step, so the running subtotal at each step is
	# the ordered cumulative product, not the caller's declaration order.
	var cumulative: float = 19.99
	# Base step
	var base_step: PriceResolver.AuditStep = result.steps[0]
	assert_eq(base_step.label.to_lower(), "base", "First step must be base")
	assert_almost_eq(
		base_step.price_after, cumulative, TOLERANCE,
		"Base price_after should equal starting base_price"
	)
	var expected_factors: Array[float] = [1.07, 1.03, 0.97, 1.11]
	for i: int in range(expected_factors.size()):
		cumulative *= expected_factors[i]
		var step: PriceResolver.AuditStep = result.steps[i + 1]
		assert_almost_eq(
			step.price_after, cumulative, TOLERANCE,
			"Step %d running subtotal must equal cumulative product" % i
		)
	assert_almost_eq(
		result.final_price, cumulative, TOLERANCE,
		"final_price must equal final cumulative subtotal"
	)


## Identity factors (1.0) must leave the price unchanged end-to-end — guards
## against drift from floating-point rounding in the chain.
func test_identity_factor_chain_is_stable() -> void:
	var multipliers: Array = [
		{"slot": "seasonal", "factor": 1.0},
		{"slot": "event", "factor": 1.0},
		{"slot": "haggle", "factor": 1.0},
		{"slot": "reputation", "factor": 1.0},
	]
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"identity_item", BASE_PRICE, multipliers, false
	)
	assert_almost_eq(
		result.final_price, BASE_PRICE, TOLERANCE,
		"Chain of identity factors must preserve base price"
	)
	for step: Variant in result.steps:
		if step is PriceResolver.AuditStep:
			assert_almost_eq(
				(step as PriceResolver.AuditStep).price_after, BASE_PRICE, TOLERANCE,
				"Every step in an identity chain must equal the base price"
			)


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
