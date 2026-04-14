## Manages hidden narrative threads through 5 phases based on player behavior.
class_name SecretThreadSystem
extends Node


enum ThreadPhase { DORMANT, WATCHING, ACTIVE, REVEALED, RESOLVED }

var _thread_defs: Array[Dictionary] = []
var _thread_states: Dictionary = {}
var _signal_counts: Dictionary = {}
var _current_day: int = 0
var _player_cash: float = 0.0
var _reputation: float = 0.0
var _owned_store_count: int = 0
var _ambient_system: AmbientMomentsSystem
var _economy_system: EconomySystem


func initialize(ambient: AmbientMomentsSystem) -> void:
	_ambient_system = ambient
	if GameManager.data_loader:
		_thread_defs = GameManager.data_loader.get_all_secret_threads()
	_init_thread_states()
	_connect_signals()


## Injects the economy system used to apply cash completion rewards.
func set_economy_system(economy: EconomySystem) -> void:
	_economy_system = economy


func _init_thread_states() -> void:
	for def: Dictionary in _thread_defs:
		var thread_id: String = str(def.get("id", ""))
		if thread_id.is_empty():
			continue
		if _thread_states.has(thread_id):
			continue
		_thread_states[thread_id] = _default_state()


func _default_state() -> Dictionary:
	return {
		"phase": ThreadPhase.DORMANT,
		"step_index": 0,
		"activated_day": 0,
		"revealed_day": 0,
		"watch_counters": {},
	}


func _connect_signals() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.price_set.connect(_on_price_set)
	EventBus.order_delivered.connect(_on_order_delivered)
	EventBus.item_stocked.connect(_on_item_stocked)
	EventBus.haggle_completed.connect(_on_haggle_completed)
	EventBus.lease_completed.connect(_on_lease_completed)


func _on_day_started(day: int) -> void:
	_current_day = day
	_increment_signal("day_started")
	_evaluate_all_threads()
	_advance_active_threads(day)


func _on_money_changed(_old: float, new_amount: float) -> void:
	_player_cash = new_amount


func _on_reputation_changed(_store_id: String, new_value: float) -> void:
	_reputation = new_value


func _on_customer_purchased(
	_store_id: StringName, _item_id: StringName,
	_price: float, _customer_id: StringName
) -> void:
	_increment_signal("customer_purchased")
	_evaluate_all_threads()


func _on_item_sold(
	_item_id: String, _price: float, _cat: String
) -> void:
	_increment_signal("item_sold")
	_evaluate_all_threads()


func _on_price_set(_item_id: String, _price: float) -> void:
	_increment_signal("price_set")
	_evaluate_all_threads()


func _on_order_delivered(
	_store_id: StringName, _items: Array
) -> void:
	_increment_signal("order_delivered")
	_evaluate_all_threads()


func _on_item_stocked(
	_item_id: String, _shelf_id: String
) -> void:
	_increment_signal("item_stocked")
	_evaluate_all_threads()


func _on_haggle_completed(
	_store_id: StringName, _item_id: StringName,
	_final_price: float, _asking_price: float,
	_accepted: bool, _offer_count: int
) -> void:
	_increment_signal("haggle_completed")
	_evaluate_all_threads()


func _on_lease_completed(
	_store_id: StringName, success: bool, _message: String
) -> void:
	if success:
		_owned_store_count += 1
		_increment_signal("lease_completed")
		_evaluate_all_threads()


func _increment_signal(signal_name: String) -> void:
	_signal_counts[signal_name] = (
		_signal_counts.get(signal_name, 0) + 1
	)
	for thread_id: String in _thread_states:
		var state: Dictionary = _thread_states[thread_id]
		var phase: int = int(state.get("phase", 0))
		if phase == ThreadPhase.DORMANT or phase == ThreadPhase.WATCHING:
			var wc: Dictionary = state.get("watch_counters", {})
			wc[signal_name] = wc.get(signal_name, 0) + 1
			state["watch_counters"] = wc


func _evaluate_all_threads() -> void:
	for def: Dictionary in _thread_defs:
		var thread_id: String = str(def.get("id", ""))
		if not _thread_states.has(thread_id):
			continue
		var state: Dictionary = _thread_states[thread_id]
		var phase: int = int(state.get("phase", ThreadPhase.DORMANT))
		match phase:
			ThreadPhase.DORMANT:
				_try_start_watching(thread_id, def, state)
			ThreadPhase.WATCHING:
				_try_activate(thread_id, def, state)


func _try_start_watching(
	thread_id: String, def: Dictionary, state: Dictionary
) -> void:
	var preconditions: Array = def.get("preconditions", [])
	for pre: Variant in preconditions:
		if pre is not Dictionary:
			continue
		if _is_precondition_relevant(pre as Dictionary):
			_transition(thread_id, state, ThreadPhase.WATCHING)
			return


func _is_precondition_relevant(pre: Dictionary) -> bool:
	var type: String = str(pre.get("type", ""))
	match type:
		"signal_count":
			var sig: String = str(pre.get("signal", ""))
			return _signal_counts.has(sig) or _current_day > 0
		"day_reached":
			return _current_day > 0
		"stat_threshold", "store_owned":
			return true
	return false


func _try_activate(
	thread_id: String, def: Dictionary, state: Dictionary
) -> void:
	var preconditions: Array = def.get("preconditions", [])
	if preconditions.is_empty():
		return
	for pre: Variant in preconditions:
		if pre is not Dictionary:
			continue
		if not _check_precondition(pre as Dictionary, state):
			return
	_transition(thread_id, state, ThreadPhase.ACTIVE)
	state["activated_day"] = _current_day


func _check_precondition(
	pre: Dictionary, state: Dictionary
) -> bool:
	var type: String = str(pre.get("type", ""))
	match type:
		"signal_count":
			return _check_signal_count(pre, state)
		"signal_value":
			return _check_signal_count(pre, state)
		"day_reached":
			var value: int = int(pre.get("value", 0))
			return _current_day >= value
		"stat_threshold":
			return _check_stat_threshold(pre)
		"store_owned":
			var threshold: int = int(pre.get("threshold", 0))
			return _owned_store_count >= threshold
	return false


func _check_signal_count(
	pre: Dictionary, state: Dictionary
) -> bool:
	var sig: String = str(pre.get("signal", ""))
	var threshold: int = int(pre.get("threshold", 1))
	var comparison: String = str(pre.get("comparison", "gte"))
	var count: int
	if comparison == "equal":
		count = _signal_counts.get(sig, 0)
	else:
		var wc: Dictionary = state.get("watch_counters", {})
		count = wc.get(sig, 0)
	match comparison:
		"equal":
			return count == threshold
		"lte":
			return count <= threshold
		_:
			return count >= threshold


func _check_stat_threshold(pre: Dictionary) -> bool:
	var stat: String = str(pre.get("stat", ""))
	var threshold: float = float(pre.get("threshold", 0.0))
	match stat:
		"player_cash":
			return _player_cash >= threshold
		"reputation":
			return _reputation >= threshold
	return false


func _advance_active_threads(day: int) -> void:
	for def: Dictionary in _thread_defs:
		var thread_id: String = str(def.get("id", ""))
		if not _thread_states.has(thread_id):
			continue
		var state: Dictionary = _thread_states[thread_id]
		var phase: int = int(state.get("phase", ThreadPhase.DORMANT))
		if phase == ThreadPhase.ACTIVE:
			if _check_timeout(thread_id, def, state, day):
				continue
			if day > int(state.get("activated_day", 0)):
				_do_reveal(thread_id, def, state, day)
		elif phase == ThreadPhase.REVEALED:
			if day > int(state.get("revealed_day", 0)):
				_do_resolve(thread_id, def, state)


func _check_timeout(
	thread_id: String, def: Dictionary,
	state: Dictionary, day: int
) -> bool:
	var timeout: int = int(def.get("timeout_days", 0))
	if timeout <= 0:
		return false
	var activated: int = int(state.get("activated_day", 0))
	if day - activated < timeout:
		return false
	EventBus.secret_thread_failed.emit(StringName(thread_id))
	if bool(def.get("resettable", false)):
		_reset_thread(thread_id, state)
	else:
		_transition(thread_id, state, ThreadPhase.RESOLVED)
	return true


func _do_reveal(
	thread_id: String, def: Dictionary,
	state: Dictionary, day: int
) -> void:
	_transition(thread_id, state, ThreadPhase.REVEALED)
	state["revealed_day"] = day
	EventBus.secret_thread_revealed.emit(StringName(thread_id))
	var moment: String = str(def.get("reveal_moment", ""))
	if not moment.is_empty() and _ambient_system:
		_ambient_system.enqueue_by_id(StringName(moment))


func _do_resolve(
	thread_id: String, def: Dictionary, state: Dictionary
) -> void:
	_apply_completion_cash_reward(thread_id, def)
	var reward_unlock_id: StringName = StringName(
		str(def.get("reward_unlock_id", ""))
	)
	if not reward_unlock_id.is_empty():
		var unlock_sys: Node = get_node_or_null(
			"/root/UnlockSystemSingleton"
		)
		if unlock_sys and unlock_sys.has_method("is_unlocked"):
			if not unlock_sys.is_unlocked(reward_unlock_id):
				unlock_sys.grant_unlock(reward_unlock_id)
		else:
			push_error(
				"SecretThreadSystem: UnlockSystem not found"
			)
	EventBus.secret_thread_completed.emit(
		StringName(thread_id), reward_unlock_id
	)
	if bool(def.get("resettable", false)):
		_reset_thread(thread_id, state)
	else:
		_transition(thread_id, state, ThreadPhase.RESOLVED)


func _apply_completion_cash_reward(
	thread_id: String, def: Dictionary
) -> void:
	var reward: Variant = def.get("completion_reward", {})
	if reward is not Dictionary:
		return
	var reward_dict: Dictionary = reward as Dictionary
	var reward_type: String = str(reward_dict.get("type", ""))
	if reward_type != "cash":
		return
	var amount: float = float(reward_dict.get("value", 0.0))
	if amount <= 0.0:
		return
	if not _economy_system:
		return
	_economy_system.add_cash(amount, "secret_thread_reward: " + thread_id)


func _reset_thread(thread_id: String, state: Dictionary) -> void:
	_transition(thread_id, state, ThreadPhase.DORMANT)
	state["activated_day"] = 0
	state["revealed_day"] = 0
	state["step_index"] = 0
	state["watch_counters"] = {}


func _transition(
	thread_id: String, state: Dictionary, new_phase: int
) -> void:
	var old_phase: int = int(
		state.get("phase", ThreadPhase.DORMANT)
	)
	if old_phase == new_phase:
		return
	state["phase"] = new_phase
	EventBus.secret_thread_state_changed.emit(
		StringName(thread_id),
		StringName(_phase_name(old_phase)),
		StringName(_phase_name(new_phase)),
	)


func _phase_name(phase: int) -> String:
	match phase:
		ThreadPhase.DORMANT:
			return "DORMANT"
		ThreadPhase.WATCHING:
			return "WATCHING"
		ThreadPhase.ACTIVE:
			return "ACTIVE"
		ThreadPhase.REVEALED:
			return "REVEALED"
		ThreadPhase.RESOLVED:
			return "RESOLVED"
	return "UNKNOWN"


## Forces the named thread one phase forward from ACTIVE or REVEALED.
## Used by tests and forced narrative progressions; no-ops on other phases.
func advance_thread(thread_id: String) -> void:
	if not _thread_states.has(thread_id):
		push_error("SecretThreadSystem: unknown thread_id '%s'" % thread_id)
		return
	var state: Dictionary = _thread_states[thread_id]
	var phase: int = int(state.get("phase", ThreadPhase.DORMANT))
	var def: Dictionary = _find_def(thread_id)
	match phase:
		ThreadPhase.ACTIVE:
			_do_reveal(thread_id, def, state, _current_day)
		ThreadPhase.REVEALED:
			_do_resolve(thread_id, def, state)
		_:
			push_warning(
				"SecretThreadSystem: advance_thread called on non-advanceable phase"
			)


func _find_def(thread_id: String) -> Dictionary:
	for def: Dictionary in _thread_defs:
		if str(def.get("id", "")) == thread_id:
			return def
	return {}


## Returns the phase of a specific thread.
func get_thread_phase(thread_id: String) -> int:
	if not _thread_states.has(thread_id):
		return ThreadPhase.DORMANT
	return int(
		_thread_states[thread_id].get("phase", ThreadPhase.DORMANT)
	)


## Serializes all thread state for saving.
func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	for thread_id: String in _thread_states:
		var state: Dictionary = _thread_states[thread_id]
		data[thread_id] = {
			"phase": int(state.get("phase", 0)),
			"step_index": int(state.get("step_index", 0)),
			"activated_day": int(state.get("activated_day", 0)),
			"revealed_day": int(state.get("revealed_day", 0)),
			"watch_counters": (
				state.get("watch_counters", {}) as Dictionary
			).duplicate(),
		}
	return {
		"thread_states": data,
		"signal_counts": _signal_counts.duplicate(),
		"owned_store_count": _owned_store_count,
	}


## Restores thread state from saved data without re-emitting signals.
func load_state(data: Dictionary) -> void:
	var thread_data: Variant = data.get("thread_states", {})
	if thread_data is Dictionary:
		for thread_id: String in (thread_data as Dictionary):
			var saved: Variant = (thread_data as Dictionary)[thread_id]
			if saved is not Dictionary:
				continue
			var saved_dict: Dictionary = saved as Dictionary
			if not _thread_states.has(thread_id):
				_thread_states[thread_id] = _default_state()
			var state: Dictionary = _thread_states[thread_id]
			state["phase"] = int(saved_dict.get("phase", 0))
			state["step_index"] = int(
				saved_dict.get("step_index", 0)
			)
			state["activated_day"] = int(
				saved_dict.get("activated_day", 0)
			)
			state["revealed_day"] = int(
				saved_dict.get("revealed_day", 0)
			)
			var wc: Variant = saved_dict.get("watch_counters", {})
			if wc is Dictionary:
				state["watch_counters"] = (
					wc as Dictionary
				).duplicate()
	var sc: Variant = data.get("signal_counts", {})
	if sc is Dictionary:
		_signal_counts = (sc as Dictionary).duplicate()
	_owned_store_count = int(data.get("owned_store_count", 0))
