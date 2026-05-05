## ReturnsSystem — owner of the post-sale returns and exchanges flow.
##
## Listens for EventBus.defective_sale_occurred and tracks a pending
## ReturnRecord per defective sale so the angry_return_customer that arrives
## later can be paired with the original transaction. Exposes a decision API
## consumed by the returns decision card (refund / exchange / deny / escalate)
## and applies the trust, manager_approval, reputation, and cash side effects
## documented in the issue spec.
##
## The damaged-bin reconciliation runs on demand via check_bin_variance(): any
## item sitting in the InventorySystem damaged-bin location whose instance_id
## is not in the resolved-refund ledger emits inventory_variance_noted, which
## HiddenThreadSystem consumes to advance scapegoat_risk.
extends Node


## Resolution labels carried on return_accepted / decision API.
const RESOLUTION_REFUND: String = "refund"
const RESOLUTION_EXCHANGE: String = "exchange"
const RESOLUTION_DENY: String = "deny"
const RESOLUTION_ESCALATE: String = "escalate"

## Trust deltas per the returns-flow spec. Funnel through EmploymentSystem.
const TRUST_DELTA_RETURN_ACCEPTED: float = 1.0
const TRUST_DELTA_RETURN_DENIED: float = -2.0
const TRUST_DELTA_RETURN_ESCALATED: float = 0.5

## Manager approval delta when the player escalates instead of deciding.
const MANAGER_APPROVAL_DELTA_ESCALATED: float = 0.02

## Reputation delta applied when the player denies a defective return.
const REPUTATION_DELTA_DENIED: float = -1.0

## Trust-change reasons surfaced on EventBus.trust_changed.
const REASON_RETURN_ACCEPTED: String = "return_accepted"
const REASON_RETURN_DENIED: String = "return_denied"
const REASON_RETURN_ESCALATED: String = "return_escalated"

## Unlock that gates the exchange-only branch (ISSUE-008).
const STOCKING_TRAINED_UNLOCK: StringName = &"employee_stocking_trained"

## Default human-readable defect labels surfaced on the decision card.
## Maps the raw condition reason to a UI string used as the context line.
const DEFECT_REASON_LABELS: Dictionary = {
	"poor": "Scratched disc",
	"damaged": "Open box, broken seal",
	"wrong_platform": "Wrong platform",
	"changed_mind": "Changed their mind",
	"defective": "Doesn't work",
}


var _pending_records: Array[ReturnRecord] = []
var _resolved_refund_instances: Dictionary = {}
var _inventory_system: InventorySystem = null


func _ready() -> void:
	EventBus.defective_sale_occurred.connect(_on_defective_sale_occurred)


## Optional dependency injection for tests and host scenes that want the
## system to perform damaged-bin moves directly. When absent the decision API
## still applies trust / approval / cash deltas; the bin move is a no-op so
## the spec's terminal location requirement is enforced only when an
## InventorySystem is available.
func set_inventory_system(system: InventorySystem) -> void:
	_inventory_system = system


## Builds and registers a ReturnRecord at the moment of the defective sale.
## Most production paths reach this through the EventBus listener; tests and
## the trade-in / warranty flows call directly to attach extra metadata
## (customer_id, sale_price, item_name) the bare signal does not carry.
func record_defective_sale(
	item_id: String,
	defect_reason: String,
	store_id: StringName = &"",
	customer_id: StringName = &"",
	item_name: String = "",
	sale_price: float = 0.0,
	day_sold: int = -1,
) -> ReturnRecord:
	if item_id.is_empty():
		push_warning("ReturnsSystem: record_defective_sale missing item_id")
		return null
	var record: ReturnRecord = ReturnRecord.new()
	record.item_id = item_id
	record.store_id = store_id
	record.customer_id = customer_id
	record.item_name = item_name
	record.item_condition = defect_reason
	record.sale_price = sale_price
	record.defect_reason = defect_reason
	if day_sold >= 0:
		record.day_sold = day_sold
	else:
		record.day_sold = GameManager.get_current_day()
	_pending_records.append(record)
	return record


## Returns a defensive copy of the unresolved return queue.
func get_pending_returns() -> Array[ReturnRecord]:
	var copy: Array[ReturnRecord] = []
	for record: ReturnRecord in _pending_records:
		copy.append(record)
	return copy


## Returns the oldest unresolved record (FIFO). Returns null when no defective
## sales are awaiting an angry-return resolution.
func peek_next_return() -> ReturnRecord:
	if _pending_records.is_empty():
		return null
	return _pending_records[0]


## Returns true when there is at least one unresolved return record. The
## angry_return_customer spawn path consumes this in concert with
## CustomerSystem._defective_sale_today.
func has_pending_returns() -> bool:
	return not _pending_records.is_empty()


## Builds the customer-data dictionary the returns decision card consumes.
##
## Keys mirror CheckoutPanel.populate_customer_card with two additions:
##   - condition           : String — used to grey out "Deny"
##   - exchange_unlocked   : bool   — used to hide the exchange choice
func build_card_data(record: ReturnRecord) -> Dictionary:
	if record == null:
		return {}
	var item_label: String = record.item_name
	if item_label.is_empty():
		item_label = record.item_id
	var defect_label: String = String(
		DEFECT_REASON_LABELS.get(record.defect_reason, record.defect_reason)
	)
	var condition_disallows_deny: bool = is_condition_defective(
		record.item_condition
	)
	var deny_label: String
	if condition_disallows_deny:
		deny_label = "Cannot deny — defective copy"
	else:
		deny_label = "−2 trust, −1 rep"
	return {
		"archetype_id": &"angry_return_customer",
		"archetype_label": "Angry Return — %s" % item_label,
		"want": "Wants a refund or exchange.",
		"context": defect_label,
		"reasoning": "",
		"offer_price": record.sale_price,
		"sticker_price": record.sale_price,
		"rep_delta": "+1 trust if accepted",
		"decline_label": deny_label,
		"condition": record.item_condition,
		"exchange_unlocked": is_exchange_choice_available(),
		"deny_available": not condition_disallows_deny,
		"refund_label": "+1 trust, refund $%.2f" % record.sale_price,
		"exchange_label": "+1 trust, swap copy",
		"escalate_label": "+0.5 trust, +0.02 mgr approval",
	}


## True when the resolved item condition makes the deny option unavailable.
## Per store policy, a customer cannot be turned away for a defective copy.
static func is_condition_defective(condition: String) -> bool:
	return condition == "poor" or condition == "damaged"


## True when the exchange-only branch should appear on the decision card.
## Gated by the employee_stocking_trained unlock per ISSUE-008.
static func is_exchange_choice_available() -> bool:
	return UnlockSystemSingleton.is_unlocked(STOCKING_TRAINED_UNLOCK)


## Returns the canonical list of choices the panel should render for this
## record. Each entry is a dict with keys {id, label, available, visible}.
func get_available_choices(record: ReturnRecord) -> Array[Dictionary]:
	if record == null:
		return []
	var choices: Array[Dictionary] = []
	choices.append({
		"id": RESOLUTION_REFUND,
		"label": "Accept — full refund",
		"available": true,
		"visible": true,
	})
	if is_exchange_choice_available():
		choices.append({
			"id": RESOLUTION_EXCHANGE,
			"label": "Accept — exchange",
			"available": true,
			"visible": true,
		})
	var deny_available: bool = not is_condition_defective(
		record.item_condition
	)
	choices.append({
		"id": RESOLUTION_DENY,
		"label": "Deny — policy",
		"available": deny_available,
		"visible": true,
	})
	choices.append({
		"id": RESOLUTION_ESCALATE,
		"label": "Escalate to manager",
		"available": true,
		"visible": true,
	})
	return choices


## Applies a return decision and emits the matching EventBus signal. Returns
## true on success; false when the choice is invalid, the record is unknown,
## or a policy gate (defective-deny, exchange-locked) blocks the choice.
func apply_decision(
	record: ReturnRecord, choice: String
) -> bool:
	if record == null:
		push_warning("ReturnsSystem: apply_decision called with null record")
		return false
	if record.resolved:
		push_warning(
			"ReturnsSystem: record %s already resolved as %s"
			% [record.item_id, record.resolution]
		)
		return false
	match choice:
		RESOLUTION_REFUND:
			return _accept_refund(record)
		RESOLUTION_EXCHANGE:
			if not is_exchange_choice_available():
				push_warning(
					"ReturnsSystem: exchange choice unavailable; "
					+ "employee_stocking_trained not granted"
				)
				return false
			return _accept_exchange(record)
		RESOLUTION_DENY:
			if is_condition_defective(record.item_condition):
				push_warning(
					"ReturnsSystem: cannot deny defective return for %s"
					% record.item_id
				)
				return false
			return _deny(record)
		RESOLUTION_ESCALATE:
			return _escalate(record)
		_:
			push_warning(
				"ReturnsSystem: unknown decision choice '%s'" % choice
			)
			return false


## Walks the InventorySystem damaged-bin and emits inventory_variance_noted
## for every item not in the resolved-refund ledger. Returns the number of
## variance events fired so callers / tests can assert reconciliation.
func check_bin_variance() -> int:
	if _inventory_system == null:
		return 0
	var variance_count: int = 0
	for item: ItemInstance in _inventory_system.get_damaged_bin_items():
		var instance_id: String = item.instance_id
		if _resolved_refund_instances.has(instance_id):
			continue
		var sid: StringName = &""
		if item.definition:
			sid = ContentRegistry.resolve(item.definition.store_type)
		var item_id: StringName = StringName(instance_id)
		EventBus.inventory_variance_noted.emit(sid, item_id, 0, 1)
		variance_count += 1
	return variance_count


## Emits return_initiated for the supplied record. Decoupled from
## record_defective_sale so callers (e.g. the angry-return spawn path) emit
## the signal at the moment the player begins the decision flow rather than
## at the moment the original sale fired.
func emit_return_initiated(record: ReturnRecord) -> void:
	if record == null:
		return
	EventBus.return_initiated.emit(
		record.customer_id,
		StringName(record.item_id),
		record.defect_reason,
	)


## Test seam — clears all pending and resolved state so tests can run
## without leaking records across cases.
func reset_for_tests() -> void:
	_pending_records.clear()
	_resolved_refund_instances.clear()


# ── Internals ────────────────────────────────────────────────────────────────


func _on_defective_sale_occurred(
	item_id: String, reason: String
) -> void:
	if item_id.is_empty():
		return
	# Production callers (CheckoutSystem) do not yet carry full context on the
	# signal; record the bare minimum so the angry-return spawn gate has a
	# corresponding pending record. Richer fields (price, name, customer) are
	# attached later by callers that have access to them.
	record_defective_sale(item_id, reason)


func _accept_refund(record: ReturnRecord) -> bool:
	EmploymentSystem.apply_trust_delta(
		TRUST_DELTA_RETURN_ACCEPTED, REASON_RETURN_ACCEPTED
	)
	_debit_store_account(record.sale_price)
	_move_to_damaged_bin(record.item_id)
	_resolved_refund_instances[record.item_id] = true
	_finalize(record, RESOLUTION_REFUND)
	EventBus.return_accepted.emit(
		record.customer_id, StringName(record.item_id), RESOLUTION_REFUND
	)
	EventBus.defective_item_received.emit(record.item_id)
	return true


func _accept_exchange(record: ReturnRecord) -> bool:
	EmploymentSystem.apply_trust_delta(
		TRUST_DELTA_RETURN_ACCEPTED, REASON_RETURN_ACCEPTED
	)
	_finalize(record, RESOLUTION_EXCHANGE)
	EventBus.return_accepted.emit(
		record.customer_id, StringName(record.item_id), RESOLUTION_EXCHANGE
	)
	return true


func _deny(record: ReturnRecord) -> bool:
	EmploymentSystem.apply_trust_delta(
		TRUST_DELTA_RETURN_DENIED, REASON_RETURN_DENIED
	)
	_apply_reputation_delta(record.store_id, REPUTATION_DELTA_DENIED)
	_finalize(record, RESOLUTION_DENY)
	EventBus.return_denied.emit(
		record.customer_id, StringName(record.item_id)
	)
	return true


func _escalate(record: ReturnRecord) -> bool:
	EmploymentSystem.apply_trust_delta(
		TRUST_DELTA_RETURN_ESCALATED, REASON_RETURN_ESCALATED
	)
	EmploymentSystem.apply_manager_approval_delta(
		MANAGER_APPROVAL_DELTA_ESCALATED, REASON_RETURN_ESCALATED
	)
	_finalize(record, RESOLUTION_ESCALATE)
	return true


func _finalize(record: ReturnRecord, resolution: String) -> void:
	record.resolved = true
	record.resolution = resolution
	_pending_records.erase(record)


func _apply_reputation_delta(
	store_id: StringName, delta: float
) -> void:
	if store_id.is_empty():
		ReputationSystemSingleton.add_reputation("", delta)
		return
	ReputationSystemSingleton.add_reputation(String(store_id), delta)


func _debit_store_account(amount: float) -> void:
	if amount <= 0.0:
		return
	var economy: EconomySystem = GameManager.get_economy_system()
	if economy == null:
		# §F-129 — refund cash debit is a data-integrity surface. Silently
		# dropping the charge would leave the player keeping the customer's
		# money on a refund-resolved record, which the Day Summary cash deltas
		# would never reconcile. EconomySystem is a Tier-1 init dependency
		# (GameWorld.initialize_tier_1_data); a null here means a real init
		# regression, not an optional injection — the test fixture for refund
		# trust deltas (test_returns_system.gd) intentionally does not seed
		# economy, but production paths always do.
		push_error((
			"ReturnsSystem: _debit_store_account skipped — "
			+ "EconomySystem unavailable (Tier-1 init regression); "
			+ "amount=$%.2f silently dropped"
		) % amount)
		return
	economy.charge(amount, "return_refund")


func _move_to_damaged_bin(instance_id: String) -> void:
	# §F-134 — empty instance_id is unreachable from the production refund
	# path: record_defective_sale rejects empty item_id at line 84. The guard
	# here is defensive against hand-constructed ReturnRecords in tests.
	# §F-135 — _inventory_system == null is the documented optional-injection
	# seam (see set_inventory_system docstring): apply_decision still applies
	# trust / approval / cash deltas; the bin move is a no-op so the spec's
	# terminal location requirement is enforced only when an InventorySystem
	# is available. Mirrors check_bin_variance line 263.
	if _inventory_system == null or instance_id.is_empty():
		return
	_inventory_system.move_to_damaged_bin(instance_id)
