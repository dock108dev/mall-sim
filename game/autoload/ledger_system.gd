## Per-transaction event log with day-close anchor records.
##
## Hybrid log: subscribes to canonical EventBus mutation signals to build a
## ring-buffered intra-day timeline of sales / stock / receive / defective
## events, and snapshots the `day_closed` payload as a committed anchor.
##
## Intra-day `_entries` clear at `day_started` so the new day's queries do not
## bleed prior-day rows. `_day_records` persist across days for reconciliation.
extends Node

const MAX_ENTRIES: int = 4096
## §F-146 — Cap on `_day_records` to bound a long-session run. The
## campaign + tournament loop tops out at ~60 days; 256 leaves a wide
## safety margin while still preventing Dictionary-of-summaries growth
## across an `EventBus.day_closed` flood (e.g., a stuck day-cycle
## controller emitting day_closed in a tight loop). Older anchor records
## drop in FIFO order so the most recent reconciliation window stays
## available for `validate_against_anchor`.
const MAX_DAY_RECORDS: int = 256

var _entries: Array[Dictionary] = []
var _day_records: Array[Dictionary] = []
var _seq: int = 0
var _time_system: TimeSystem = null


## §F-146 — Variant→float coercion that rejects NaN / Inf to a default
## then floors at zero. Mirrors `EconomySystem._safe_finite_float`
## (§F-09.1) and `HiddenThreadSystem._safe_finite_float` (§F-128) — the
## ledger is the SSOT for daily revenue reconciliation, so a NaN price
## emitted by an upstream regression must not silently corrupt
## `validate_against_anchor` (where `delta = abs(NaN - x)` always
## produces NaN, which compares false against every threshold).
static func _safe_finite_price(value: Variant, default_value: float) -> float:
	var coerced: float = float(value)
	if is_nan(coerced) or is_inf(coerced):
		return default_value
	return maxf(coerced, 0.0)


func initialize(time_system: TimeSystem) -> void:
	_time_system = time_system


func _ready() -> void:
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.item_stocked.connect(_on_item_stocked)
	EventBus.order_delivered.connect(_on_order_delivered)
	EventBus.defective_item_received.connect(_on_defective_item_received)
	EventBus.day_closed.connect(_on_day_closed)
	EventBus.day_started.connect(_on_day_started)


func clear() -> void:
	_entries.clear()
	_day_records.clear()
	_seq = 0


func get_entries_for_day(day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _entries:
		if int(e.get("day", -1)) == day:
			out.append(e)
	return out


func get_sales_for_day(day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _entries:
		if int(e.get("day", -1)) == day and e.get("kind", &"") == &"sale":
			out.append(e)
	return out


func get_day_record(day: int) -> Dictionary:
	for r: Dictionary in _day_records:
		if int(r.get("day", -1)) == day:
			return r
	return {}


func get_debug_dump(day: int) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== LEDGER DAY %d ===" % day)
	for e: Dictionary in get_entries_for_day(day):
		lines.append(
			"[%04d] t=%d %s item=%s store=%s $%.2f cust=%s detail=%s"
			% [
				int(e.get("seq", 0)),
				int(e.get("time_msec", 0)),
				String(e.get("kind", &"")),
				String(e.get("item_id", "")),
				String(e.get("store_id", "")),
				float(e.get("price", 0.0)),
				String(e.get("customer_id", "")),
				String(e.get("detail", "")),
			]
		)
	var rec: Dictionary = get_day_record(day)
	if not rec.is_empty():
		lines.append("--- DAY CLOSE ANCHOR ---")
		lines.append(
			"revenue=%.2f profit=%.2f items_sold=%d customers_served=%d"
			% [
				float(rec.get("total_revenue", 0.0)),
				float(rec.get("net_profit", 0.0)),
				int(rec.get("items_sold", 0)),
				int(rec.get("customers_served", 0)),
			]
		)
	return "\n".join(lines)


## Reconciles the sum of `kind=sale` ledger entries for the day against the
## anchor `total_revenue` captured from the `day_closed` payload. Returns a
## Dictionary so callers can branch on `match` or report `delta` directly.
func validate_against_anchor(day: int) -> Dictionary:
	var ledger_revenue: float = 0.0
	for s: Dictionary in get_sales_for_day(day):
		# §F-146 — finite-clamp on the read side so a stale entry from
		# before the §F-146 _append clamp shipped cannot poison the
		# accumulator with NaN. New writes are already guarded.
		ledger_revenue += _safe_finite_price(s.get("price", 0.0), 0.0)
	var rec: Dictionary = get_day_record(day)
	var has_anchor: bool = not rec.is_empty()
	# §F-146 — Reject NaN/Inf on the anchor side too. The anchor flows
	# from `day_closed.summary["total_revenue"]`; EconomySystem already
	# finite-clamps the source, but a future regression that writes NaN
	# into the day-summary payload must not silently propagate NaN
	# through `delta = abs(NaN - x)` (which yields NaN that compares
	# false against the 0.01 threshold — `match` already returns false
	# via the `has_anchor` short-circuit, but consumers of `delta` for
	# telemetry would otherwise see NaN). The `-1.0` sentinel for "no
	# anchor exists" is preserved by routing the missing-record path
	# around the clamp (the `maxf(...,0.0)` floor would otherwise
	# clobber the sentinel to 0.0).
	var anchor_revenue: float = -1.0
	if has_anchor:
		anchor_revenue = _safe_finite_price(rec.get("total_revenue", 0.0), 0.0)
	var delta: float = abs(ledger_revenue - anchor_revenue)
	return {
		"ledger_revenue": ledger_revenue,
		"anchor_revenue": anchor_revenue,
		"delta": delta,
		"match": has_anchor and delta < 0.01,
	}


func _append(
	kind: StringName,
	item_id: String,
	store_id: String,
	price: float,
	customer_id: String,
	detail: String,
) -> void:
	# §F-142 — Refuse to append when the ledger has no TimeSystem reference.
	# `_time_system` is wired in `GameWorld.initialize_tier_5_meta`; the
	# autoload subscribes to mutation signals at `_ready` (well before tier
	# 5), so there is a real boot window where an early `customer_purchased`
	# emit would land here unstamped. Stamping `day=0` would silently
	# mis-attribute the entry — `validate_against_anchor` would never
	# reconcile because no day-0 anchor exists, and the per-day query helpers
	# (`get_entries_for_day` / `get_sales_for_day`) would silently exclude
	# the row from the day it actually belongs to. Loud-and-skip is the
	# correct posture: the integrity check is the system's whole reason for
	# existing.
	if _time_system == null:
		push_warning(
			(
				"LedgerSystem: dropping %s entry (item='%s', store='%s', $%.2f) — "
				+ "TimeSystem not yet initialized. Tier-5 init dependency."
			)
			% [String(kind), item_id, store_id, price]
		)
		return
	var day: int = _time_system.current_day
	_entries.append({
		"seq": _seq,
		"day": day,
		"time_msec": Time.get_ticks_msec(),
		"kind": kind,
		"item_id": item_id,
		"store_id": store_id,
		# §F-146 — finite-clamp the price field at the SSOT boundary so an
		# upstream NaN/Inf regression cannot poison `validate_against_anchor`.
		"price": _safe_finite_price(price, 0.0),
		"customer_id": customer_id,
		"detail": detail,
	})
	_seq += 1
	if _entries.size() > MAX_ENTRIES:
		_entries.remove_at(0)


func _on_customer_purchased(
	store_id: StringName,
	item_id: StringName,
	price: float,
	customer_id: StringName,
) -> void:
	_append(
		&"sale", String(item_id), String(store_id), price, String(customer_id), ""
	)


func _on_item_stocked(item_id: String, shelf_id: String) -> void:
	_append(&"stock", item_id, "", 0.0, "", shelf_id)


func _on_order_delivered(store_id: StringName, items: Array) -> void:
	for item: Variant in items:
		var iid: String = ""
		if item is Dictionary:
			iid = str((item as Dictionary).get("item_id", ""))
		else:
			iid = str(item)
		_append(&"receive", iid, String(store_id), 0.0, "", "order_delivered")


func _on_defective_item_received(item_id: String) -> void:
	_append(&"defective", item_id, "", 0.0, "", "damaged_bin")


func _on_day_closed(_day: int, summary: Dictionary) -> void:
	_day_records.append(summary.duplicate(true))
	# §F-146 — FIFO-evict oldest anchor records so a stuck day-cycle
	# emitter cannot grow the day-records array unbounded across a
	# long-session run. The cap is well above the campaign + tournament
	# day count.
	while _day_records.size() > MAX_DAY_RECORDS:
		_day_records.remove_at(0)


func _on_day_started(_day: int) -> void:
	_entries.clear()
