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


## Regression: all twelve multiplier-source slots can be expressed in PriceResolver
## and the final price equals the product of all factors in canonical order.
func test_all_twelve_source_slots_representable() -> void:
	var base: float = 10.0
	var multipliers: Array = [
		{"slot": "rarity",      "label": "Rarity",        "factor": 1.5,  "detail": "rare"},
		{"slot": "lifecycle",   "label": "Lifecycle",     "factor": 1.35, "detail": "ultra_new"},
		{"slot": "condition",   "label": "Condition",     "factor": 1.0,  "detail": "good"},
		{"slot": "grade",       "label": "Grade",         "factor": 2.0,  "detail": "B"},
		{"slot": "auth",        "label": "Authentication","factor": 2.0,  "detail": "authenticated"},
		{"slot": "trend",       "label": "Trend",         "factor": 1.2,  "detail": "hot"},
		{"slot": "seasonal",    "label": "Seasonal",      "factor": 1.1,  "detail": "holiday"},
		{"slot": "reputation",  "label": "Reputation",    "factor": 1.05, "detail": "tier-2"},
		{"slot": "meta_shift",  "label": "Meta Shift",    "factor": 0.8,  "detail": "meta down"},
		{"slot": "event",       "label": "Market Event",  "factor": 1.15, "detail": "weekend"},
		{"slot": "depreciation","label": "Depreciation",  "factor": 0.9,  "detail": "day-7"},
		{"slot": "warranty",    "label": "Warranty",      "factor": 1.2,  "detail": "1-year"},
	]
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"twelve_source_item", base, multipliers, false
	)
	# step count = 12 supplied + 1 base step
	assert_eq(result.steps.size(), 13,
		"All twelve source slots plus base must appear in the trace")
	# All twelve unique slot labels must appear in the output
	var labels: Array[String] = []
	for s: Variant in result.steps:
		if s is PriceResolver.AuditStep:
			labels.append((s as PriceResolver.AuditStep).label.to_lower())
	assert_true(labels.has("base"),          "trace must have base step")
	assert_true(labels.has("rarity"),        "trace must have rarity")
	assert_true(labels.has("lifecycle"),     "trace must have lifecycle")
	assert_true(labels.has("condition"),     "trace must have condition")
	assert_true(labels.has("grade"),         "trace must have grade")
	assert_true(labels.has("authentication"),"trace must have authentication")
	assert_true(labels.has("trend"),         "trace must have trend")
	assert_true(labels.has("seasonal"),      "trace must have seasonal")
	assert_true(labels.has("reputation"),    "trace must have reputation")
	assert_true(labels.has("meta shift"),    "trace must have meta_shift")
	assert_true(labels.has("market event"),  "trace must have market event")
	assert_true(labels.has("depreciation"),  "trace must have depreciation")
	assert_true(labels.has("warranty"),      "trace must have warranty")
	# Final price must equal exact product
	var expected: float = base
	for m: Dictionary in multipliers:
		expected *= float(m["factor"])
	assert_almost_eq(result.final_price, expected, TOLERANCE,
		"Final price must equal the exact product of all twelve source multipliers")


## Regression: checkout offer formula (market value × random × sensitivity)
## produces the same result when routed through PriceResolver as it did when
## computed directly. This guards against the migration changing prices.
func test_checkout_offer_matches_direct_formula() -> void:
	var base: float = 20.0
	var rarity_mult: float = 1.0   # common
	var cond_mult: float = 1.0     # good
	var random_mult: float = 1.05  # fixed variance (no RNG — deterministic test)
	var sensitivity: float = 0.5
	var sensitivity_mult: float = 1.0 - sensitivity * 0.3  # = 0.85
	# Direct formula: same as pre-refactor checkout calculation
	var direct: float = base * rarity_mult * cond_mult * random_mult * sensitivity_mult
	# PriceResolver path with reputation suppressed (matches pre-refactor behaviour)
	var multipliers: Array = [
		{"slot": "rarity",      "label": "Rarity",            "factor": rarity_mult,      "detail": "common"},
		{"slot": "condition",   "label": "Condition",         "factor": cond_mult,        "detail": "good"},
		{"slot": "random",      "label": "Offer Variance",    "factor": random_mult,      "detail": "fixed"},
		{"slot": "sensitivity", "label": "Price Sensitivity", "factor": sensitivity_mult, "detail": "0.5"},
		{"slot": "reputation",  "label": "Reputation",        "factor": 1.0,              "detail": "suppressed"},
	]
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"checkout_reg_item", base, multipliers, false
	)
	assert_almost_eq(result.final_price, direct, TOLERANCE,
		"PriceResolver checkout path must equal direct formula product")
	# Verify canonical ordering: random and sensitivity are applied after rarity/condition
	var labels: Array[String] = []
	for s: Variant in result.steps:
		if s is PriceResolver.AuditStep:
			labels.append((s as PriceResolver.AuditStep).label.to_lower())
	var rarity_idx: int  = labels.find("rarity")
	var cond_idx: int    = labels.find("condition")
	var random_idx: int  = labels.find("offer variance")
	var sens_idx: int    = labels.find("price sensitivity")
	assert_gt(random_idx, cond_idx,   "random must come after condition in trace")
	assert_gt(sens_idx,   random_idx, "sensitivity must come after random in trace")
	assert_gt(random_idx, rarity_idx, "random must come after rarity in trace")


## Regression: CHAIN_ORDER change must preserve relative ordering of the five
## canonical slots used by the existing store-coverage test.
func test_legacy_canonical_slot_order_unchanged() -> void:
	var multipliers: Array = _canonical_multipliers("electronics")
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		&"legacy_order_item", BASE_PRICE, multipliers, false
	)
	var labels: Array[String] = []
	for step: Variant in result.steps:
		if step is PriceResolver.AuditStep:
			labels.append((step as PriceResolver.AuditStep).label.to_lower())
	var expected: Array[String] = ["base", "seasonal", "reputation", "event", "haggle"]
	assert_eq(labels, expected,
		"Existing canonical slot order must be preserved after CHAIN_ORDER expansion")


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
