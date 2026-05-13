## Structured per-event timeline. The ring buffer + stdout print are
## debug-only; the `EventBus.event_logged(tag, message)` broadcast fires in
## every build so the player-facing bottom-left log surface can render the
## same stream without scanning the buffer.
##
## Maintains a ring buffer of recent events and prints structured lines for
## inventory mutations, customer FSM transitions, day lifecycle, money
## stat mutations, modal open/close beats, gameplay-ready (game started),
## and objective completions. AuditLog handles stable pass/fail
## checkpoints; this log is a noisier per-event timeline used by the
## debug overlay, headless validation, and the on-screen log panel.
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


## The ring buffer and stdout print are debug-only — release builds skip
## the storage path but keep the EventBus.event_logged broadcast active so
## the on-screen panel still receives entries.
var _buffer_enabled: bool = OS.is_debug_build()


func _ready() -> void:
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
	EventBus.day_started.connect(_on_day_started)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.gameplay_ready.connect(_on_gameplay_ready)
	EventBus.modal_opened.connect(_on_modal_opened)
	EventBus.modal_closed.connect(_on_modal_closed)
	EventBus.objective_completed.connect(_on_objective_completed)


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
	# Skip no-op transitions where the customer's `_set_state` was called
	# with `new_state == current_state` — those produce `X -> X` rows that
	# carry no signal for the on-screen log surface and burn the FSM hot
	# path with redundant `event_logged` emits + per-row tween work in
	# every BetaEventLogPanel listener.
	if prev_state == new_state:
		return
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


func _on_day_started(day: int) -> void:
	_record("[DAY]", "system", "day:%d" % day, "day_started", {"day": day})


func _on_money_changed(old_amount: float, new_amount: float) -> void:
	_record("[STAT]", "system", "player", "stat_changed", {
		"stat": "money",
		"old_value": old_amount,
		"new_value": new_amount,
		"delta": new_amount - old_amount,
	})


func _on_gameplay_ready() -> void:
	_record("[SYSTEM]", "system", "game", "game_started", {})


func _on_modal_opened(modal_id: StringName) -> void:
	_record("[MODAL]", "system", String(modal_id), "modal_opened", {
		"modal_id": String(modal_id),
	})


func _on_modal_closed(modal_id: StringName) -> void:
	_record("[MODAL]", "system", String(modal_id), "modal_closed", {
		"modal_id": String(modal_id),
	})


func _on_objective_completed(objective_id: StringName, label: String) -> void:
	_record("[OBJECTIVE]", "system", String(objective_id), "objective_completed", {
		"objective_id": String(objective_id),
		"label": label,
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
	# Player-facing broadcast must always fire — the on-screen bottom-left
	# log surface is a shipped UI affordance, not a debug overlay. The ring
	# buffer storage below stays debug-gated for perf and disk-noise reasons.
	EventBus.event_logged.emit(tag, _format_message(action, target, params))
	if not _buffer_enabled:
		return
	_ring.append(entry)
	if _ring.size() > RING_CAPACITY:
		_ring.remove_at(0)
	_print_entry(entry)


## Renders the structured record into a human-readable single line the
## on-screen panel can show without re-deriving copy at every call site.
## Keeps each per-tag shape tight — the surface caps width at ~260 px and
## relies on these strings staying short.
func _format_message(action: String, target: String, params: Dictionary) -> String:
	match action:
		"stock":
			return "Stocked %s." % str(params.get("item_id", ""))
		"remove":
			return "Sold %s." % str(params.get("item_id", ""))
		"state_change":
			return "%s -> %s" % [
				str(params.get("from_state", "?")),
				str(params.get("to_state", "?")),
			]
		"customer_exit":
			var satisfied: bool = bool(params.get("satisfied", true))
			return "Customer left (%s)." % ("satisfied" if satisfied else "unhappy")
		"day_started":
			return "Day %d started." % int(params.get("day", 0))
		"stat_changed":
			var stat: String = str(params.get("stat", ""))
			if stat == "money":
				var delta: float = float(params.get("delta", 0.0))
				var sign: String = "+" if delta >= 0.0 else "-"
				return "Money %s$%.2f." % [sign, abs(delta)]
			return "%s changed." % stat
		"game_started":
			return "Game started."
		"modal_opened":
			return "Modal opened: %s." % str(params.get("modal_id", ""))
		"modal_closed":
			return "Modal closed: %s." % str(params.get("modal_id", ""))
		"objective_completed":
			# Past-tense `label` is the player-facing completion copy supplied
			# by the chain controller (see
			# `BetaDayOneController._objective_completion_label`); the log row
			# is just that label verbatim.
			return str(params.get("label", ""))
		_:
			# §EH-39 — Drift surface: a new `action` token added to
			# `_record` callers without a matching case here will land on
			# the on-screen panel as a bare action string (e.g. "checkout"
			# instead of "Customer checked out"). Push a debug-build
			# warning so the QA log carries the unmapped token; release
			# builds skip the warning to keep the FSM hot path quiet but
			# still produce a coherent row.
			if OS.is_debug_build():
				push_warning(
					(
						"EventLog._format_message: unmapped action '%s' "
						+ "(target='%s') — falling back to raw token. Add a "
						+ "match arm in event_log.gd to give it a player-"
						+ "facing string."
					) % [action, target]
				)
			if target.is_empty():
				return action
			return "%s %s" % [action, target]


func _print_entry(entry: Dictionary) -> void:
	var line: String = "%s actor=%s target=%s action=%s" % [
		entry["tag"], entry["actor"], entry["target"], entry["action"],
	]
	var params: Dictionary = entry["params"]
	for key: String in params:
		line += " %s=%s" % [key, str(params[key])]
	line += " msec=%d" % int(entry["msec"])
	print(line)
