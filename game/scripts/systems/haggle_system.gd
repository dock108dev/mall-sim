## Manages haggling negotiations between customers and the player.
class_name HaggleSystem
extends Node

const BASE_HAGGLE_CHANCE: float = 0.40
const MAX_ROUNDS: int = 5
const MIN_COUNTER_CLOSE_RATE: float = 0.25
const MAX_COUNTER_CLOSE_RATE: float = 0.50
const INSULT_THRESHOLD: float = -0.05
const DEFAULT_MOOD_MODIFIER: float = 1.0

signal negotiation_started(
	item_name: String,
	item_condition: String,
	sticker_price: float,
	customer_offer: float,
	max_rounds: int
)
signal customer_countered(new_offer: float, round_number: int)
signal negotiation_accepted(final_price: float)
signal negotiation_failed()

var _active_customer: Customer = null
var _active_item: ItemInstance = null
var _sticker_price: float = 0.0
var _perceived_value: float = 0.0
var _current_customer_offer: float = 0.0
var _current_round: int = 0
var _max_rounds_for_customer: int = MAX_ROUNDS
var _acceptance_threshold: float = 0.30


## Returns true if this customer will attempt to haggle on the item.
func should_haggle(
	customer: Customer, item: ItemInstance
) -> bool:
	if not customer or not customer.profile:
		return false
	var sensitivity: float = customer.profile.price_sensitivity
	var mood_mod: float = _get_mood_modifier(customer)
	var markup: float = _get_markup_factor(item)
	var chance: float = (
		BASE_HAGGLE_CHANCE * sensitivity * mood_mod * markup
	)
	return randf() < chance


## Begins a haggling negotiation for the given customer and item.
func begin_negotiation(
	customer: Customer, item: ItemInstance
) -> void:
	_active_customer = customer
	_active_item = item
	_current_round = 1
	_perceived_value = item.get_current_value()
	_sticker_price = _get_sticker_price(item)
	_max_rounds_for_customer = _calculate_max_rounds(customer)
	_acceptance_threshold = _calculate_acceptance_threshold(
		customer
	)
	_current_customer_offer = _calculate_opening_offer(customer)
	var cust_id: int = customer.get_instance_id()
	EventBus.haggle_started.emit(
		item.instance_id, cust_id
	)
	negotiation_started.emit(
		item.definition.name,
		item.condition.capitalize(),
		_sticker_price,
		_current_customer_offer,
		_max_rounds_for_customer,
	)


## Player accepts the customer's current offer.
func accept_offer() -> void:
	var final_price: float = _current_customer_offer
	EventBus.haggle_completed.emit(
		_active_item.instance_id, final_price
	)
	negotiation_accepted.emit(final_price)
	_clear_state()


## Player declines to negotiate further; customer walks away.
func decline_offer() -> void:
	_emit_failure()
	_clear_state()


## Player submits a counter-offer price.
func player_counter(player_price: float) -> void:
	if not _active_customer or not _active_item:
		return
	_current_round += 1
	var gap_ratio: float = _calculate_gap_ratio(player_price)
	if gap_ratio < INSULT_THRESHOLD:
		_emit_failure()
		_clear_state()
		return
	if gap_ratio <= _acceptance_threshold:
		var final_price: float = player_price
		EventBus.haggle_completed.emit(
			_active_item.instance_id, final_price
		)
		negotiation_accepted.emit(final_price)
		_clear_state()
		return
	if _current_round > _max_rounds_for_customer:
		_emit_failure()
		_clear_state()
		return
	_current_customer_offer = _calculate_customer_counter(
		player_price
	)
	customer_countered.emit(
		_current_customer_offer, _current_round
	)


## Returns whether a negotiation is currently active.
func is_active() -> bool:
	return _active_customer != null


func _calculate_opening_offer(customer: Customer) -> float:
	var sensitivity: float = customer.profile.price_sensitivity
	var offer: float = lerpf(
		_perceived_value, _sticker_price, 1.0 - sensitivity
	)
	return maxf(offer, 0.01)


func _calculate_max_rounds(customer: Customer) -> int:
	var patience: float = customer.profile.patience
	if patience >= 0.8:
		return MAX_ROUNDS
	if patience >= 0.5:
		return 4
	if patience >= 0.3:
		return 3
	return 2


func _calculate_acceptance_threshold(
	customer: Customer
) -> float:
	var sensitivity: float = customer.profile.price_sensitivity
	if sensitivity >= 0.8:
		return 0.15
	if sensitivity >= 0.4:
		return 0.30
	return 0.50


func _calculate_gap_ratio(player_price: float) -> float:
	if _perceived_value <= 0.0:
		return 0.0
	return (player_price - _perceived_value) / _perceived_value


func _calculate_customer_counter(
	player_price: float
) -> float:
	var close_rate: float = randf_range(
		MIN_COUNTER_CLOSE_RATE, MAX_COUNTER_CLOSE_RATE
	)
	var new_offer: float = lerpf(
		_current_customer_offer, player_price, close_rate
	)
	return maxf(new_offer, 0.01)


func _get_sticker_price(item: ItemInstance) -> float:
	if item.set_price > 0.0:
		return item.set_price
	return item.get_current_value()


func _get_markup_factor(item: ItemInstance) -> float:
	var sticker: float = _get_sticker_price(item)
	var value: float = item.get_current_value()
	if value <= 0.0:
		return 1.0
	var ratio: float = sticker / value
	return clampf(ratio, 0.5, 2.0)


func _get_mood_modifier(customer: Customer) -> float:
	if not customer.profile:
		return DEFAULT_MOOD_MODIFIER
	var tags: PackedStringArray = customer.profile.mood_tags
	if tags.has("impatient"):
		return 1.3
	if tags.has("friendly"):
		return 0.8
	return DEFAULT_MOOD_MODIFIER


func _emit_failure() -> void:
	if _active_item and _active_customer:
		EventBus.haggle_failed.emit(
			_active_item.instance_id,
			_active_customer.get_instance_id(),
		)
	negotiation_failed.emit()


func _clear_state() -> void:
	_active_customer = null
	_active_item = null
	_sticker_price = 0.0
	_perceived_value = 0.0
	_current_customer_offer = 0.0
	_current_round = 0
	_max_rounds_for_customer = MAX_ROUNDS
	_acceptance_threshold = 0.30
