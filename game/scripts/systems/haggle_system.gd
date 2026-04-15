## Manages haggling negotiations between customers and the player.
class_name HaggleSystem
extends Node

const BASE_HAGGLE_CHANCE: float = 0.40
const MAX_ROUNDS: int = 5
const MIN_COUNTER_CLOSE_RATE: float = 0.25
const MAX_COUNTER_CLOSE_RATE: float = 0.50
const INSULT_MOVE_THRESHOLD: float = 0.02
const CUSTOMER_CONCESSION_THRESHOLD: float = 0.15
const DEFAULT_MOOD_MODIFIER: float = 1.0
const REP_SALE_MIN: float = 1.0
const REP_SALE_MAX: float = 2.0
const REP_WALKAWAY_MIN: float = -1.0
const REP_WALKAWAY_MAX: float = -3.0
const REP_INSULT_PENALTY: float = -3.0

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
var _walkaway_threshold: float = 0.80
var _previous_player_offer: float = 0.0
var _previous_customer_offer: float = 0.0
var _active_store_id: StringName = &""
var _reputation_system: ReputationSystem = null
var time_per_turn: float = HaggleSession.TIME_PER_TURN_MAX


func _ready() -> void:
	EventBus.active_store_changed.connect(_on_active_store_changed)


func _on_active_store_changed(store_id: StringName) -> void:
	_active_store_id = store_id


func initialize(reputation_system: ReputationSystem) -> void:
	_reputation_system = reputation_system


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
	var will_haggle: bool = randf() < chance
	if will_haggle:
		EventBus.haggle_requested.emit(
			String(item.instance_id),
			customer.get_instance_id()
		)
	return will_haggle


## Begins a haggling negotiation for the given customer and item.
func begin_negotiation(
	customer: Customer, item: ItemInstance
) -> bool:
	if is_active():
		return false
	_active_customer = customer
	_active_item = item
	_current_round = 1
	_perceived_value = item.get_current_value()
	_sticker_price = _get_sticker_price(item)
	_max_rounds_for_customer = _calculate_max_rounds(customer)
	time_per_turn = _calculate_time_per_turn(customer)
	_acceptance_threshold = _calculate_acceptance_threshold(
		customer
	)
	_walkaway_threshold = _calculate_walkaway_threshold(customer)
	_current_customer_offer = _calculate_opening_offer(customer)
	_previous_player_offer = 0.0
	_previous_customer_offer = 0.0
	var cust_id: int = customer.get_instance_id()
	EventBus.haggle_started.emit(
		String(item.instance_id), cust_id
	)
	negotiation_started.emit(
		item.definition.item_name,
		item.condition.capitalize(),
		_sticker_price,
		_current_customer_offer,
		_max_rounds_for_customer,
	)
	return true


## Player accepts the customer's current offer.
func accept_offer() -> void:
	if not _active_item:
		return
	var final_price: float = _current_customer_offer
	_apply_sale_reputation(final_price)
	EventBus.haggle_completed.emit(
		_active_store_id, StringName(_active_item.instance_id),
		final_price, _sticker_price, true, _current_round
	)
	negotiation_accepted.emit(final_price)
	_clear_state()


## Player declines to negotiate further; customer walks away.
func decline_offer() -> void:
	_apply_walkaway_reputation()
	_emit_failure()
	_clear_state()


## Player submits a counter-offer price.
func player_counter(player_price: float) -> void:
	if not _active_customer or not _active_item:
		return
	_current_round += 1
	var gap_ratio: float = _calculate_gap_ratio(player_price)

	if gap_ratio > _walkaway_threshold:
		_apply_walkaway_reputation_with_insult_check(
			player_price
		)
		_emit_failure()
		_clear_state()
		return

	if gap_ratio <= _acceptance_threshold:
		var final_price: float = player_price
		_apply_sale_reputation(final_price)
		EventBus.haggle_completed.emit(
			_active_store_id, StringName(_active_item.instance_id),
			final_price, _sticker_price, true, _current_round
		)
		negotiation_accepted.emit(final_price)
		_clear_state()
		return

	if _evaluate_offer(player_price):
		var final_price: float = player_price
		_apply_sale_reputation(final_price)
		EventBus.haggle_completed.emit(
			_active_store_id, StringName(_active_item.instance_id),
			final_price, _sticker_price, true, _current_round
		)
		negotiation_accepted.emit(final_price)
		_clear_state()
		return

	if _current_round > _max_rounds_for_customer:
		_apply_walkaway_reputation_with_insult_check(
			player_price
		)
		_emit_failure()
		_clear_state()
		return

	_previous_player_offer = player_price
	_previous_customer_offer = _current_customer_offer
	_current_customer_offer = _calculate_customer_counter(
		player_price
	)
	customer_countered.emit(
		_current_customer_offer, _current_round
	)


## Returns whether a negotiation is currently active.
func is_active() -> bool:
	return _active_customer != null


func _calculate_time_per_turn(customer: Customer) -> float:
	var patience: float = customer.profile.patience if customer.profile else 0.5
	return lerpf(
		HaggleSession.TIME_PER_TURN_MIN,
		HaggleSession.TIME_PER_TURN_MAX,
		clampf(patience, 0.0, 1.0)
	)


func _calculate_opening_offer(customer: Customer) -> float:
	var sensitivity: float = customer.profile.price_sensitivity
	var offer: float = lerpf(
		_perceived_value * 0.7, _sticker_price,
		1.0 - sensitivity
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


func _calculate_walkaway_threshold(
	customer: Customer
) -> float:
	var patience: float = customer.profile.patience
	if patience >= 0.8:
		return 1.0
	if patience >= 0.5:
		return 0.80
	if patience >= 0.3:
		return 0.60
	return 0.40


func _evaluate_offer(player_price: float) -> bool:
	if _sticker_price <= 0.0:
		return false
	var ceiling: float = DifficultySystemSingleton.get_modifier(
		&"haggle_concession_ceiling"
	)
	var offer_ratio: float = player_price / _sticker_price
	if offer_ratio < (1.0 - ceiling):
		return false
	var base_rate: float = DifficultySystemSingleton.get_modifier(
		&"haggle_acceptance_base_rate"
	)
	var success_rate_mult: float = DifficultySystemSingleton.get_modifier(
		&"haggle_success_rate_multiplier"
	)
	# Scale probability down as gap_ratio approaches 2x the acceptance threshold.
	# At exactly acceptance_threshold: full probability. At 2x threshold: zero.
	var gap_ratio: float = _calculate_gap_ratio(player_price)
	var prob_scale: float = clampf(
		1.0 - (gap_ratio - _acceptance_threshold) / maxf(_acceptance_threshold, 0.001),
		0.0, 1.0
	)
	var accept_prob: float = base_rate * offer_ratio * success_rate_mult * prob_scale
	return randf() < accept_prob


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
	if item.player_set_price > 0.0:
		return item.player_set_price
	return item.get_current_value()


func _get_markup_factor(item: ItemInstance) -> float:
	var sticker: float = _get_sticker_price(item)
	var value: float = item.get_current_value()
	if value <= 0.0:
		return 0.0
	return clampf(sticker / value - 1.0, 0.0, 2.0)


func _get_mood_modifier(customer: Customer) -> float:
	if not customer.profile:
		return DEFAULT_MOOD_MODIFIER
	var tags: PackedStringArray = customer.profile.mood_tags
	if tags.has("impatient"):
		return 1.3
	if tags.has("friendly"):
		return 0.8
	return DEFAULT_MOOD_MODIFIER


func _apply_sale_reputation(final_price: float) -> void:
	if not _reputation_system or _perceived_value <= 0.0:
		return
	var ratio: float = absf(
		final_price - _perceived_value
	) / _perceived_value
	var delta: float = lerpf(
		REP_SALE_MAX, REP_SALE_MIN, clampf(ratio, 0.0, 1.0)
	)
	_reputation_system.modify_reputation("", delta)


func _apply_walkaway_reputation() -> void:
	if not _reputation_system:
		return
	_reputation_system.modify_reputation("", REP_WALKAWAY_MIN)


func _apply_walkaway_reputation_with_insult_check(
	player_price: float
) -> void:
	if not _reputation_system:
		return
	if _was_insulting_counter(player_price):
		_reputation_system.modify_reputation(
			"", REP_INSULT_PENALTY
		)
		return
	var rounds_used: float = float(_current_round)
	var max_r: float = float(_max_rounds_for_customer)
	var stubbornness: float = clampf(
		rounds_used / max_r, 0.0, 1.0
	)
	var delta: float = lerpf(
		REP_WALKAWAY_MIN, REP_WALKAWAY_MAX, stubbornness
	)
	_reputation_system.modify_reputation("", delta)


func _was_insulting_counter(player_price: float) -> bool:
	if _previous_player_offer <= 0.0 or _previous_customer_offer <= 0.0:
		return false
	if _perceived_value <= 0.0:
		return false
	var player_move: float = absf(
		player_price - _previous_player_offer
	) / _perceived_value
	var customer_concession: float = absf(
		_current_customer_offer - _previous_customer_offer
	) / _perceived_value
	return (
		player_move < INSULT_MOVE_THRESHOLD
		and customer_concession >= CUSTOMER_CONCESSION_THRESHOLD
	)


func _emit_failure() -> void:
	if _active_item and _active_customer:
		EventBus.haggle_failed.emit(
			String(_active_item.instance_id),
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
	_walkaway_threshold = 0.80
	_previous_player_offer = 0.0
	_previous_customer_offer = 0.0
