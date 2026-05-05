## Structured per-event debug timeline. Stripped to a no-op in release builds.
##
## Maintains a ring buffer of recent events and prints structured lines for
## inventory mutations and customer FSM transitions. AuditLog handles stable
## pass/fail checkpoints; this log is a noisier per-event timeline used by the
## debug overlay and headless validation.
extends Node

const RING_CAPACITY: int = 512
## §F-145 — FIFO cap on the per-customer state dedup map. The
## `customer_left` payload uses a different key shape than the
## state-change handler (string `customer_id` vs. raw `instance_id`), so
## a one-to-one cleanup is not always available; the cap bounds the map
## across long debug sessions where freed customers leave their
## instance-id keys behind. Same defense-in-depth posture as §F-87 on
## `AmbientMomentsSystem._last_spotted`.
const MAX_CUSTOMER_STATE_ENTRIES: int = 256

var _ring: Array[Dictionary] = []
var _last_customer_state: Dictionary = {}
## Tracks insertion order for `_last_customer_state` so the FIFO eviction in
## `_on_customer_state_changed` can drop the oldest key when the map hits its
## cap without iterating Dictionary keys (which Godot does not guarantee in
## insertion order across all builds).
var _last_customer_state_order: Array[int] = []


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_wire()


func recent(n: int) -> Array[Dictionary]:
	if n <= 0:
		return []
	var size: int = _ring.size()
	var start: int = max(0, size - n)
	var out: Array[Dictionary] = []
	for i in range(start, size):
		out.append(_ring[i])
	return out


func clear() -> void:
	_ring.clear()
	_last_customer_state.clear()
	_last_customer_state_order.clear()


func _wire() -> void:
	EventBus.item_stocked.connect(_on_item_stocked)
	EventBus.item_removed_from_shelf.connect(_on_item_removed_from_shelf)
	EventBus.customer_state_changed.connect(_on_customer_state_changed)
	EventBus.customer_left.connect(_on_customer_left)


func _on_item_stocked(item_id: String, shelf_id: String) -> void:
	var to_loc: String = "shelf:%s" % shelf_id
	# Shelf slots hold a single item; backroom→shelf transitions count 0 → 1.
	_record("[STOCK]", "system", to_loc, "stock", {
		"item_id": item_id,
		"from_location": "backroom",
		"to_location": to_loc,
		"count_before": 0,
		"count_after": 1,
	})


func _on_item_removed_from_shelf(item_id: String, shelf_slot_id: String) -> void:
	var from_loc: String = "shelf:%s" % shelf_slot_id
	_record("[STOCK]", "system", from_loc, "remove", {
		"item_id": item_id,
		"from_location": from_loc,
		"to_location": "sold",
		"count_before": 1,
		"count_after": 0,
	})


func _on_customer_state_changed(customer: Node, new_state: int) -> void:
	var cid: int = customer.get_instance_id() if customer != null else 0
	var prev_state: int = _last_customer_state.get(cid, -1)
	if prev_state < 0:
		_last_customer_state_order.append(cid)
		# §F-145 — FIFO eviction when the dedup map is full. Drops the oldest
		# tracked customer so a freed Customer that never received a
		# `customer_left` event with a matching string id cannot sit in the
		# map for the rest of the debug session.
		while _last_customer_state_order.size() > MAX_CUSTOMER_STATE_ENTRIES:
			var evict: int = _last_customer_state_order.pop_front()
			_last_customer_state.erase(evict)
	_last_customer_state[cid] = new_state
	var from_name: String = "INITIAL" if prev_state < 0 else _state_name(prev_state)
	var to_name: String = _state_name(new_state)
	var actor: String = "customer:%d" % cid
	var target: String = _resolve_customer_target(customer)
	_record("[CUSTOMER]", actor, target, "state_change", {
		"from_state": from_name,
		"to_state": to_name,
	})


func _on_customer_left(data: Dictionary) -> void:
	var cid_value: Variant = data.get("customer_id", data.get("id", "?"))
	var actor: String = "customer:%s" % str(cid_value)
	# §F-145 — Drop the matching dedup entry on exit when the payload
	# carries a numeric instance-id. Bounded cap above guards the path
	# where the payload shape lacks the int id (e.g., shopper_ai's
	# Dictionary form keyed by Node ref).
	if cid_value is int:
		_last_customer_state.erase(cid_value as int)
		_last_customer_state_order.erase(cid_value as int)
	var params: Dictionary = {
		"satisfied": data.get("satisfied", true),
	}
	if data.has("reason"):
		params["reason"] = data["reason"]
	_record("[CUSTOMER]", actor, "exit", "customer_exit", params)


func _state_name(state: int) -> String:
	var name: String = Customer.state_name(state)
	if name.is_empty():
		return str(state)
	return name


func _resolve_customer_target(customer: Node) -> String:
	if customer == null:
		return ""
	# Customer FSM exposes the active shelf via a private field; fall back to
	# an empty string when the field is absent (mock customers in tests).
	var slot: Variant = customer.get(&"_current_target_slot")
	if slot == null:
		return ""
	if slot is Node and (slot as Node).has_method("get"):
		var slot_id: Variant = (slot as Node).get(&"slot_id")
		if slot_id != null and str(slot_id) != "":
			return "shelf:%s" % str(slot_id)
	return ""


func _record(
	tag: String, actor: String, target: String, action: String, params: Dictionary
) -> void:
	var entry: Dictionary = {
		"tag": tag,
		"actor": actor,
		"target": target,
		"action": action,
		"params": params,
		"msec": Time.get_ticks_msec(),
	}
	_ring.append(entry)
	if _ring.size() > RING_CAPACITY:
		_ring.remove_at(0)
	_print_entry(entry)


func _print_entry(entry: Dictionary) -> void:
	var line: String = "%s actor=%s target=%s action=%s" % [
		entry["tag"], entry["actor"], entry["target"], entry["action"],
	]
	var params: Dictionary = entry["params"]
	for key: String in params:
		line += " %s=%s" % [key, str(params[key])]
	line += " msec=%d" % int(entry["msec"])
	print(line)
