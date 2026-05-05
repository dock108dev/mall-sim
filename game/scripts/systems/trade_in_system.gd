## State machine for the trade-in intake flow.
##
## Owns the per-interaction state (`current_state`, customer/item/condition/
## offer), the valuation formula (`compute_offer`), and the EventBus signal
## emissions. The TradeInPanel scene is a thin view layer that observes this
## system and dispatches user input back to it via the public methods.
##
## Gated by the `employee_tradein_certified` unlock (ISSUE-008). Until granted,
## the system stays in the LOCKED state and `begin_interaction` is a no-op.
class_name TradeInSystem
extends Node

const UNLOCK_ID: StringName = &"employee_tradein_certified"

## Per-condition multipliers applied to base_price. The standard 40–55% buy
## fraction for clean used goods, scaling down for visible damage.
const CONDITION_MULT: Dictionary = {
	"mint": 0.55,
	"good": 0.40,
	"fair": 0.25,
	"poor": 0.12,
	"damaged": 0.05,
}

## Trust-tier additive bonus. Boundary is `>=` (a customer at trust 40 gets the
## first tier bonus, not the floor) — keeps the unlock-day reward visible.
const TRUST_TIER_40_BONUS: float = 0.03
const TRUST_TIER_60_BONUS: float = 0.06
const TRUST_TIER_80_BONUS: float = 0.10

## Floor on the offered credit and the rounding step for display.
const OFFER_FLOOR: float = 0.25
const OFFER_STEP: float = 0.25

enum State {
	LOCKED,
	IDLE,
	CUSTOMER_APPROACHES,
	ITEM_INSPECT,
	PLATFORM_CONFIRM,
	CONDITION_CHECK,
	VALUE_OFFER,
	AWAITING_PLAYER_DECISION,
	ACCEPT_PATH,
	REJECT_PATH,
	RECEIPT_SHOWN,
}

signal state_changed(old_state: int, new_state: int)

var current_state: int = State.LOCKED
var current_customer_id: String = ""
var current_customer_archetype: StringName = &""
var current_item_def_id: String = ""
var current_item_definition: ItemDefinition = null
var current_condition: String = ""
var current_offer: float = 0.0
var current_store_id: StringName = &"retro_games"

var inventory_system: Node = null
var economy_system: Node = null
var unlock_system: Node = null
var reputation_system: Node = null
## Optional. When set, `appraise()` multiplies the offer by the item's current
## market factor (decay profile output) so e.g. annual_sports titles eaten by
## a new-edition release pay out the depreciated credit, not face value.
var market_value_system: Node = null


func _ready() -> void:
	_refresh_lock_state()
	if EventBus.has_signal(&"unlock_granted"):
		EventBus.unlock_granted.connect(_on_unlock_granted)


## Returns the trust-tier bonus for a reputation score. Boundary uses `>=` so
## a customer at trust 40 enters the first bonus tier (matches ISSUE-012 spec).
static func get_trust_bonus(trust: float) -> float:
	if trust >= 80.0:
		return TRUST_TIER_80_BONUS
	if trust >= 60.0:
		return TRUST_TIER_60_BONUS
	if trust >= 40.0:
		return TRUST_TIER_40_BONUS
	return 0.0


## offer = snappedf(max(base_price * (cond_mult + trust_bonus) * market, 0.25), 0.25).
static func compute_offer(
	base_price: float,
	condition: String,
	trust: float,
	market_factor: float = 1.0,
) -> float:
	var cond_mult: float = float(CONDITION_MULT.get(condition, 0.0))
	var trust_bonus: float = get_trust_bonus(trust)
	var raw: float = base_price * (cond_mult + trust_bonus) * market_factor
	return snappedf(maxf(raw, OFFER_FLOOR), OFFER_STEP)


## Begins a trade-in interaction. No-op while LOCKED. Walks the inspection-side
## states (CUSTOMER_APPROACHES → ITEM_INSPECT) in one synchronous step so the
## panel only needs to render the post-inspect view.
##
## `customer_archetype` is optional; when provided, archetype-specific dialogue
## hooks (see `get_customer_dialogue_line`) can surface during appraisal.
func begin_interaction(
	customer_id: String,
	item_def_id: String,
	definition: ItemDefinition,
	customer_archetype: StringName = &"",
) -> void:
	if current_state == State.LOCKED:
		push_warning(
			"TradeInSystem: begin_interaction blocked while LOCKED"
		)
		return
	if current_state != State.IDLE:
		push_warning(
			"TradeInSystem: begin_interaction called while busy in state %d"
			% current_state
		)
		return
	if definition == null:
		push_warning("TradeInSystem: begin_interaction received null definition")
		return
	current_customer_id = customer_id
	current_customer_archetype = customer_archetype
	current_item_def_id = item_def_id
	current_item_definition = definition
	current_condition = ""
	current_offer = 0.0
	EventBus.trade_in_initiated.emit(customer_id)
	_set_state(State.CUSTOMER_APPROACHES)
	_set_state(State.ITEM_INSPECT)


## Player advances past the platform inspection.
func confirm_platform() -> void:
	if current_state != State.ITEM_INSPECT:
		return
	_set_state(State.PLATFORM_CONFIRM)
	_set_state(State.CONDITION_CHECK)


## Player picks one of the condition radio buttons.
func select_condition(condition: String) -> void:
	if not CONDITION_MULT.has(condition):
		push_warning(
			"TradeInSystem: select_condition received unknown '%s'" % condition
		)
		return
	if current_state != State.CONDITION_CHECK \
			and current_state != State.VALUE_OFFER \
			and current_state != State.AWAITING_PLAYER_DECISION:
		return
	current_condition = condition


## Computes the offer and advances to VALUE_OFFER + AWAITING_PLAYER_DECISION.
func appraise() -> void:
	if current_condition.is_empty():
		return
	if current_item_definition == null:
		return
	if current_state != State.CONDITION_CHECK:
		return
	var trust: float = _read_trust()
	var market_factor: float = _read_market_factor(current_item_definition)
	current_offer = compute_offer(
		current_item_definition.base_price,
		current_condition,
		trust,
		market_factor,
	)
	_set_state(State.VALUE_OFFER)
	EventBus.trade_in_offer_made.emit(
		current_customer_id,
		current_item_def_id,
		current_condition,
		current_offer,
	)
	_set_state(State.AWAITING_PLAYER_DECISION)


## Player accepts the offer. Creates the ItemInstance, deducts cash, advances
## to RECEIPT_SHOWN. Returns the created instance id (empty string on failure).
func make_offer() -> String:
	if current_state != State.AWAITING_PLAYER_DECISION:
		return ""
	if inventory_system == null or economy_system == null:
		push_warning("TradeInSystem: make_offer missing system injection")
		return ""
	_set_state(State.ACCEPT_PATH)
	var item: ItemInstance = inventory_system.create_item(
		current_item_def_id, current_condition, current_offer
	)
	if item == null:
		# §F-130 — create_item returns null for two distinct upstream failures
		# (backroom full vs. unknown item_def_id). The panel surfaces the empty
		# string as a status label, but without a log line the operator cannot
		# tell which failure mode happened. Backroom-full is a legitimate
		# runtime state (player must clear space); definition-missing is a
		# content-authoring break — both warrant the warning to disambiguate
		# silent acceptance failures from real flow regressions.
		push_warning((
			"TradeInSystem: make_offer aborted — inventory_system.create_item "
			+ "returned null for item_def_id='%s' condition='%s' offer=$%.2f "
			+ "(backroom full or definition missing)"
		) % [current_item_def_id, current_condition, current_offer])
		# Return to AWAITING so the panel can surface the failure without
		# losing the in-flight offer.
		_set_state(State.AWAITING_PLAYER_DECISION)
		return ""
	economy_system.deduct_cash(
		current_offer, "Trade-in: %s" % current_item_def_id
	)
	var instance_id: String = String(item.instance_id)
	EventBus.trade_in_accepted.emit(
		current_customer_id, instance_id, current_offer
	)
	EventBus.trade_in_completed.emit(current_customer_id, instance_id)
	_set_state(State.RECEIPT_SHOWN)
	return instance_id


## Player declines the offer. Emits trade_in_rejected and returns to IDLE.
func decline() -> void:
	if current_state != State.AWAITING_PLAYER_DECISION \
			and current_state != State.VALUE_OFFER \
			and current_state != State.CONDITION_CHECK \
			and current_state != State.ITEM_INSPECT:
		return
	_set_state(State.REJECT_PATH)
	EventBus.trade_in_rejected.emit(current_customer_id)
	_reset_to_idle()


## Player pressed Escape or stepped out of interaction range. The panel closes
## immediately, the customer leaves with a neutral one-liner, no trust delta,
## no inventory change. Emits trade_in_rejected so listeners can release the
## customer cleanly.
func silent_cancel() -> void:
	if current_state == State.IDLE or current_state == State.LOCKED:
		return
	if current_state == State.RECEIPT_SHOWN:
		# Receipt is post-accept; treat cancel-during-receipt as completion.
		_reset_to_idle()
		return
	EventBus.trade_in_rejected.emit(current_customer_id)
	_reset_to_idle()


## Auto-dismiss receipt timer or E-key press.
func complete_receipt() -> void:
	if current_state != State.RECEIPT_SHOWN:
		return
	_reset_to_idle()


func is_locked() -> bool:
	return current_state == State.LOCKED


func _on_unlock_granted(unlock_id: StringName) -> void:
	if unlock_id == UNLOCK_ID:
		_refresh_lock_state()


func _refresh_lock_state() -> void:
	var unlocked: bool = false
	if unlock_system != null and unlock_system.has_method("is_unlocked"):
		unlocked = bool(unlock_system.is_unlocked(UNLOCK_ID))
	elif Engine.has_singleton("UnlockSystem"):
		var us: Node = Engine.get_singleton("UnlockSystem") as Node
		if us != null and us.has_method("is_unlocked"):
			unlocked = bool(us.is_unlocked(UNLOCK_ID))
	if unlocked and current_state == State.LOCKED:
		_set_state(State.IDLE)
	elif not unlocked and current_state != State.LOCKED:
		_set_state(State.LOCKED)


func _read_market_factor(def: ItemDefinition) -> float:
	if def == null or market_value_system == null:
		return 1.0
	if not market_value_system.has_method("get_trade_in_market_factor"):
		return 1.0
	return float(market_value_system.get_trade_in_market_factor(def))


func _read_trust() -> float:
	if reputation_system == null:
		return 0.0
	if not reputation_system.has_method("get_reputation"):
		return 0.0
	return float(reputation_system.get_reputation(String(current_store_id)))


const _NEW_EDITION_DIALOGUE: String = (
	"Yeah, I know — the new one's out. Whatever you can do."
)


## Returns a one-line customer remark for the current interaction, or "" when
## no archetype-specific line applies. The sports_regular hook surfaces a "new
## edition is out" acknowledgement when the trade-in item is annual_sports and
## the live market factor is below 1.0 (i.e. a newer edition is in catalog or
## the title has aged) — explains the depreciated offer to the player.
func get_customer_dialogue_line() -> String:
	if current_customer_archetype != &"sports_regular":
		return ""
	if current_item_definition == null:
		return ""
	if String(current_item_definition.decay_profile) != "annual_sports":
		return ""
	var factor: float = _read_market_factor(current_item_definition)
	if factor >= 1.0:
		return ""
	return _NEW_EDITION_DIALOGUE


func _reset_to_idle() -> void:
	current_customer_id = ""
	current_customer_archetype = &""
	current_item_def_id = ""
	current_item_definition = null
	current_condition = ""
	current_offer = 0.0
	_set_state(State.IDLE)


func _set_state(new_state: int) -> void:
	if new_state == current_state:
		return
	var old_state: int = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)
