## Per-negotiation state container for haggling between player and customer.
class_name HaggleSession
extends RefCounted

enum HaggleState {
	IDLE,
	EVALUATE,
	PLAYER_TURN,
	CUSTOMER_TURN,
	SALE_COMPLETE,
	WALKAWAY,
}

enum HaggleOutcome {
	PENDING,
	SALE,
	WALKAWAY,
}

const INSULT_PLAYER_MOVE_THRESHOLD: float = 0.02
const CUSTOMER_CONCESSION_THRESHOLD: float = 0.15
const QUEUE_TIME_REDUCTION: float = 0.30
const TIME_PER_TURN_MIN: float = 4.5
const TIME_PER_TURN_MAX: float = 12.0

var customer_ref: Node = null
var item_id: StringName = &""
var sticker_price: float = 0.0
var perceived_value: float = 0.0
var current_offer: float = 0.0
var offer_history: Array[float] = []
var round_number: int = 0
var max_rounds: int = 3
var time_per_turn: float = TIME_PER_TURN_MAX
var state: HaggleState = HaggleState.IDLE
var outcome: HaggleOutcome = HaggleOutcome.PENDING

var _previous_customer_offer: float = 0.0
var _current_customer_offer: float = 0.0


## Records a player counter-offer and advances the round.
func record_player_offer(price: float) -> void:
	offer_history.append(price)
	current_offer = price
	round_number += 1


## Records the customer's counter-offer for insult detection.
func record_customer_offer(price: float) -> void:
	_previous_customer_offer = _current_customer_offer
	_current_customer_offer = price
	current_offer = price


## Returns the gap between current offer and perceived value as a ratio.
func get_gap_ratio() -> float:
	if perceived_value <= 0.0:
		return 0.0
	return (current_offer - perceived_value) / perceived_value


## Returns true when the player barely moved their price after a
## significant customer concession — considered disrespectful.
func is_insulting_counter() -> bool:
	if offer_history.size() < 2:
		return false
	if sticker_price <= 0.0:
		return false
	if _previous_customer_offer <= 0.0 or _current_customer_offer <= 0.0:
		return false
	var last_offer: float = offer_history[-1]
	var prev_offer: float = offer_history[-2]
	var player_move: float = absf(last_offer - prev_offer) / sticker_price
	var customer_concession: float = absf(
		_current_customer_offer - _previous_customer_offer
	) / sticker_price
	return (
		player_move < INSULT_PLAYER_MOVE_THRESHOLD
		and customer_concession >= CUSTOMER_CONCESSION_THRESHOLD
	)


## Creates a configured session from customer data and queue state.
static func create(
	customer: Node,
	p_item_id: StringName,
	p_sticker_price: float,
	p_perceived_value: float,
	patience: float,
	queue_count: int,
) -> HaggleSession:
	var session := HaggleSession.new()
	session.customer_ref = customer
	session.item_id = p_item_id
	session.sticker_price = p_sticker_price
	session.perceived_value = p_perceived_value
	session.max_rounds = calculate_max_rounds(patience)
	session.time_per_turn = calculate_time_per_turn(
		patience, queue_count
	)
	session.state = HaggleState.IDLE
	session.outcome = HaggleOutcome.PENDING
	return session


## Creates a configured session from a customer profile.
static func create_from_profile(
	customer: Node,
	profile: CustomerTypeDefinition,
	p_item_id: StringName,
	p_sticker_price: float,
	p_perceived_value: float,
	queue_count: int,
) -> HaggleSession:
	var patience: float = 0.5
	if profile != null:
		patience = profile.patience
	return create(
		customer,
		p_item_id,
		p_sticker_price,
		p_perceived_value,
		patience,
		queue_count,
	)


## Maps customer patience to the number of haggle rounds they will tolerate.
static func calculate_max_rounds(patience: float) -> int:
	var clamped_patience: float = clampf(patience, 0.0, 1.0)
	if clamped_patience >= 0.95:
		return 5
	if clamped_patience >= 0.7:
		return 4
	if clamped_patience >= 0.45:
		return 3
	if clamped_patience >= 0.2:
		return 2
	return 1


## Calculates the allowed turn time from customer patience and queue pressure.
static func calculate_time_per_turn(
	patience: float, queue_count: int
) -> float:
	var base_time: float = lerpf(
		TIME_PER_TURN_MIN, TIME_PER_TURN_MAX,
		clampf(patience, 0.0, 1.0)
	)
	if queue_count >= 2:
		base_time *= (1.0 - QUEUE_TIME_REDUCTION)
	return base_time
