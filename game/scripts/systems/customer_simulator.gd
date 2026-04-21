## Stateless batch simulation of daily customer traffic and purchase decisions.
##
## Called once per store at end-of-day. Traffic = base × reputation × event.
## For each customer: picks a random archetype, finds a shelf candidate, resolves
## market price via PriceResolver, applies WTP check, and emits item_sold /
## customer_purchased for accepted purchases.
class_name CustomerSimulator
extends RefCounted

const ARCHETYPES_PATH: String = "res://game/content/customers/archetypes.json"
const DEFAULT_BASE_TRAFFIC: int = 10
## Fraction of ask price a hagglers's counter-offer represents.
const HAGGLE_COUNTER_FACTOR: float = 0.90

## Non-shelf locations — items here are not available for purchase.
const UNAVAILABLE_LOCATIONS: PackedStringArray = [
	"backroom", "rented", "returns_bin", "testing_station",
]

static var _archetypes: Array[Dictionary] = []
static var _archetypes_loaded: bool = false


## Returns floor(base × reputation_multiplier × event_multiplier).
static func calculate_traffic(
	base: int,
	reputation_multiplier: float,
	event_multiplier: float,
) -> int:
	return roundi(float(base) * reputation_multiplier * event_multiplier)


## Simulates traffic_count customer visits against inventory_snapshot.
## Returns Array[Dictionary] with keys: item_id, accepted, price — one entry per
## customer who found a candidate item.
## Emits EventBus.item_sold and EventBus.customer_purchased for each accepted sale.
static func simulate_day(
	store_id: StringName,
	traffic_count: int,
	inventory_snapshot: Array,
) -> Array[Dictionary]:
	_ensure_archetypes_loaded()
	if _archetypes.is_empty():
		push_error("CustomerSimulator: no archetypes — check %s" % ARCHETYPES_PATH)
		return []
	if traffic_count <= 0:
		return []

	var results: Array[Dictionary] = []
	var sold_ids: Dictionary = {}
	var shelf_items: Array = _shelf_items(inventory_snapshot)
	if shelf_items.is_empty():
		return results

	for _i: int in range(traffic_count):
		var archetype: Dictionary = _archetypes[randi() % _archetypes.size()]
		var candidate: ItemInstance = _find_candidate(shelf_items, sold_ids)
		if not candidate:
			continue

		var market_price: float = _market_price(candidate)
		if market_price <= 0.0:
			continue
		var ask: float = (
			candidate.player_set_price if candidate.player_set_price > 0.0
			else market_price
		)
		var wtp: float = archetype.get("wtp_multiplier", 1.0) * market_price
		var accepted: bool = ask <= wtp

		if not accepted:
			var haggle_prob: float = archetype.get("haggle_probability", 0.0)
			if randf() < haggle_prob:
				var counter: float = ask * HAGGLE_COUNTER_FACTOR
				if counter <= wtp:
					ask = counter
					accepted = true

		var item_name: String = (
			candidate.definition.item_name if candidate.definition else ""
		)
		if accepted:
			sold_ids[candidate.instance_id] = true
			var category: String = (
				String(candidate.definition.category) if candidate.definition else ""
			)
			EventBus.item_sold.emit(
				String(candidate.instance_id), ask, category
			)
			EventBus.customer_purchased.emit(
				store_id, candidate.instance_id, ask, &"simulated"
			)
		else:
			var reason: String = _classify_walk(ask, wtp, market_price)
			EventBus.customer_walked.emit(store_id, candidate.instance_id, reason)

		results.append({
			"item_id": candidate.instance_id,
			"item_name": item_name,
			"accepted": accepted,
			"price": ask,
			"walk_reason": "" if accepted else _classify_walk(ask, wtp, market_price),
		})

	return results


## Overrides the loaded archetypes array — intended for GUT tests only.
static func inject_archetypes_for_testing(archetypes: Array) -> void:
	_archetypes.clear()
	for entry: Variant in archetypes:
		if entry is Dictionary:
			_archetypes.append(entry as Dictionary)
	_archetypes_loaded = true


## Clears the archetype cache so the next simulate_day reloads from disk.
static func reset_archetype_cache() -> void:
	_archetypes.clear()
	_archetypes_loaded = false


## Simulates one customer visit for a single item. Emits EventBus signals on acceptance.
## Returns {item_id, item_name, accepted, price, walk_reason, market_price}.
static func simulate_single(
	store_id: StringName,
	item: ItemInstance,
) -> Dictionary:
	if not item or not item.definition:
		return {
			"item_id": &"",
			"item_name": "",
			"accepted": false,
			"price": 0.0,
			"walk_reason": "no_item",
			"market_price": 0.0,
		}
	_ensure_archetypes_loaded()
	if _archetypes.is_empty():
		return {
			"item_id": item.instance_id,
			"item_name": item.definition.item_name,
			"accepted": false,
			"price": 0.0,
			"walk_reason": "no_archetype",
			"market_price": 0.0,
		}
	var archetype: Dictionary = _archetypes[randi() % _archetypes.size()]
	var market_price: float = _market_price(item)
	if market_price <= 0.0:
		return {
			"item_id": item.instance_id,
			"item_name": item.definition.item_name,
			"accepted": false,
			"price": 0.0,
			"walk_reason": "no_price",
			"market_price": 0.0,
		}
	var ask: float = (
		item.player_set_price if item.player_set_price > 0.0 else market_price
	)
	var wtp: float = archetype.get("wtp_multiplier", 1.0) * market_price
	var accepted: bool = ask <= wtp
	if not accepted:
		var haggle_prob: float = archetype.get("haggle_probability", 0.0)
		if randf() < haggle_prob:
			var counter: float = ask * HAGGLE_COUNTER_FACTOR
			if counter <= wtp:
				ask = counter
				accepted = true
	var walk_reason: String = "" if accepted else _classify_walk(ask, wtp, market_price)
	var item_name: String = item.definition.item_name if item.definition else ""
	if accepted:
		var category: String = String(item.definition.category) if item.definition else ""
		EventBus.item_sold.emit(String(item.instance_id), ask, category)
		EventBus.customer_purchased.emit(store_id, item.instance_id, ask, &"simulated")
	else:
		EventBus.customer_walked.emit(store_id, item.instance_id, walk_reason)
	return {
		"item_id": item.instance_id,
		"item_name": item_name,
		"accepted": accepted,
		"price": ask,
		"walk_reason": walk_reason,
		"market_price": market_price,
	}


## Like simulate_day but emits no EventBus signals — for preview/dry-run use only.
## Returns Array[Dictionary] with keys: item_id, item_name, accepted, price, walk_reason.
static func simulate_day_dry_run(
	traffic_count: int,
	inventory_snapshot: Array,
) -> Array[Dictionary]:
	_ensure_archetypes_loaded()
	if _archetypes.is_empty() or traffic_count <= 0:
		return []
	var results: Array[Dictionary] = []
	var sold_ids: Dictionary = {}
	var shelf_items: Array = _shelf_items(inventory_snapshot)
	if shelf_items.is_empty():
		return results
	for _i: int in range(traffic_count):
		var archetype: Dictionary = _archetypes[randi() % _archetypes.size()]
		var candidate: ItemInstance = _find_candidate(shelf_items, sold_ids)
		if not candidate:
			continue
		var market_price: float = _market_price(candidate)
		if market_price <= 0.0:
			continue
		var ask: float = (
			candidate.player_set_price if candidate.player_set_price > 0.0
			else market_price
		)
		var wtp: float = archetype.get("wtp_multiplier", 1.0) * market_price
		var accepted: bool = ask <= wtp
		if not accepted:
			var haggle_prob: float = archetype.get("haggle_probability", 0.0)
			if randf() < haggle_prob:
				var counter: float = ask * HAGGLE_COUNTER_FACTOR
				if counter <= wtp:
					ask = counter
					accepted = true
		if accepted:
			sold_ids[candidate.instance_id] = true
		var item_name: String = (
			candidate.definition.item_name if candidate.definition else ""
		)
		results.append({
			"item_id": candidate.instance_id,
			"item_name": item_name,
			"accepted": accepted,
			"price": ask,
			"walk_reason": "" if accepted else _classify_walk(ask, wtp, market_price),
		})
	return results


# ── Private helpers ───────────────────────────────────────────────────────────

static func _shelf_items(snapshot: Array) -> Array:
	var result: Array = []
	for item: Variant in snapshot:
		if item is ItemInstance:
			var inst: ItemInstance = item as ItemInstance
			if not (inst.current_location in UNAVAILABLE_LOCATIONS):
				result.append(inst)
	return result


static func _find_candidate(
	shelf_items: Array,
	sold_ids: Dictionary,
) -> ItemInstance:
	var available: Array = []
	for item: Variant in shelf_items:
		var inst: ItemInstance = item as ItemInstance
		if not sold_ids.has(inst.instance_id):
			available.append(inst)
	if available.is_empty():
		return null
	return available[randi() % available.size()]


static func _market_price(item: ItemInstance) -> float:
	if not item.definition:
		return 0.0
	var cond_factor: float = ItemInstance.CONDITION_MULTIPLIERS.get(item.condition, 1.0)
	var multipliers: Array = [{
		"label": "Condition",
		"factor": cond_factor,
		"detail": item.condition,
	}]
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		item.instance_id, item.definition.base_price, multipliers, false
	)
	return result.final_price


static func _classify_walk(ask: float, wtp: float, market_price: float) -> String:
	if market_price > 0.0 and ask / market_price > 1.5:
		return "price_too_high"
	if ask > wtp:
		return "over_budget"
	return "not_interested"


static func _ensure_archetypes_loaded() -> void:
	if _archetypes_loaded:
		return
	_archetypes_loaded = true
	if not FileAccess.file_exists(ARCHETYPES_PATH):
		push_error("CustomerSimulator: archetypes file missing: %s" % ARCHETYPES_PATH)
		return
	var raw: String = FileAccess.get_file_as_string(ARCHETYPES_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is not Array:
		push_error("CustomerSimulator: archetypes.json root must be an Array")
		return
	for entry: Variant in parsed as Array:
		if entry is Dictionary:
			_archetypes.append(entry as Dictionary)
