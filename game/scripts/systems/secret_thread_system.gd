## Manages hidden narrative threads through 5 phases based on player behavior.
class_name SecretThreadSystem
extends Node


enum ThreadPhase { DORMANT, WATCHING, ACTIVE, REVEALED, RESOLVED }

var _thread_defs: Array[Dictionary] = []
var _thread_states: Dictionary = {}
var _signal_counts: Dictionary = {}
var _signal_values: Dictionary = {}
var _current_day: int = 0
var _player_cash: float = 0.0
var _reputation: float = 0.0
var _owned_store_count: int = 0
var _ambient_system: AmbientMomentsSystem
var _economy_system: EconomySystem


func initialize(ambient: AmbientMomentsSystem) -> void:
	_ambient_system = ambient
	_load_thread_definitions()
	_init_thread_states()
	_connect_signals()


func _ready() -> void:
	if _thread_defs.is_empty():
		_load_thread_definitions()
		_init_thread_states()
	_connect_signals()


func _load_thread_definitions() -> void:
	var loaded: Array[Dictionary] = []
	if ContentRegistry.is_ready():
		for thread_id: StringName in ContentRegistry.get_all_ids("secret_thread"):
			var entry: Dictionary = ContentRegistry.get_entry(thread_id)
			if not entry.is_empty():
				loaded.append(entry)
	if loaded.is_empty() and GameManager.data_loader:
		loaded = GameManager.data_loader.get_all_secret_threads()
	_thread_defs = loaded


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
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.money_changed.is_connected(_on_money_changed):
		EventBus.money_changed.connect(_on_money_changed)
	if not EventBus.reputation_changed.is_connected(_on_reputation_changed):
		EventBus.reputation_changed.connect(_on_reputation_changed)
	if not EventBus.customer_purchased.is_connected(_on_customer_purchased):
		EventBus.customer_purchased.connect(_on_customer_purchased)
	if not EventBus.item_sold.is_connected(_on_item_sold):
		EventBus.item_sold.connect(_on_item_sold)
	if not EventBus.price_set.is_connected(_on_price_set):
		EventBus.price_set.connect(_on_price_set)
	if not EventBus.order_delivered.is_connected(_on_order_delivered):
		EventBus.order_delivered.connect(_on_order_delivered)
	if not EventBus.item_stocked.is_connected(_on_item_stocked):
		EventBus.item_stocked.connect(_on_item_stocked)
	if not EventBus.haggle_completed.is_connected(_on_haggle_completed):
		EventBus.haggle_completed.connect(_on_haggle_completed)
	if not EventBus.lease_completed.is_connected(_on_lease_completed):
		EventBus.lease_completed.connect(_on_lease_completed)


func _on_day_started(day: int) -> void:
	_current_day = day
	_record_signal("day_started", [day])
	_evaluate_all_threads()
	_advance_active_threads(day)


func _on_money_changed(_old: float, new_amount: float) -> void:
	_player_cash = new_amount
	_record_signal("money_changed", [_old, new_amount])
	_evaluate_all_threads()


func _on_reputation_changed(_store_id: String, new_value: float) -> void:
	_reputation = new_value
	_record_signal("reputation_changed", [_store_id, new_value])
	_evaluate_all_threads()


func _on_customer_purchased(
	store_id: StringName, item_id: StringName,
	price: float, customer_id: StringName
) -> void:
	_record_signal("customer_purchased", [
		store_id, item_id, price, customer_id,
	])
	_evaluate_all_threads()


func _on_item_sold(
	item_id: String, price: float, cat: String
) -> void:
	_record_signal("item_sold", [item_id, price, cat])
	_evaluate_all_threads()


func _on_price_set(item_id: String, price: float) -> void:
	_record_signal("price_set", [item_id, price])
	_evaluate_all_threads()


func _on_order_delivered(
	store_id: StringName, items: Array
) -> void:
	_record_signal("order_delivered", [store_id, items])
	_evaluate_all_threads()


func _on_item_stocked(
	item_id: String, shelf_id: String
) -> void:
	_record_signal("item_stocked", [item_id, shelf_id])
	_evaluate_all_threads()


func _on_haggle_completed(
	store_id: StringName, item_id: StringName,
	final_price: float, asking_price: float,
	accepted: bool, offer_count: int
) -> void:
	_record_signal("haggle_completed", [
		store_id, item_id, final_price, asking_price,
		accepted, offer_count,
	])
	_evaluate_all_threads()


func _on_lease_completed(
	_store_id: StringName, success: bool, _message: String
) -> void:
	if success:
		_owned_store_count += 1
		_record_signal("lease_completed", [_store_id, success, _message])
		_evaluate_all_threads()


func _record_signal(signal_name: String, args: Array = []) -> void:
	_signal_counts[signal_name] = (
		_signal_counts.get(signal_name, 0) + 1
	)
	_signal_values[signal_name] = args.duplicate()
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
	var type: String = _condition_type(pre)
	match type:
		"signal_count", "signal_value":
			var sig: String = _condition_signal(pre)
			return _signal_counts.has(sig)
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
	var type: String = _condition_type(pre)
	match type:
		"signal_count":
			return _check_signal_count(pre, state)
		"signal_value":
			return _check_signal_value(pre)
		"day_reached":
			var value: int = int(pre.get("value", pre.get("threshold", 0)))
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
	var sig: String = _condition_signal(pre)
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


func _check_signal_value(pre: Dictionary) -> bool:
	var sig: String = _condition_signal(pre)
	if not _signal_values.has(sig):
		return false
	var args: Array = _signal_values.get(sig, []) as Array
	var index: int = int(pre.get("signal_param_index", 0))
	if index < 0 or index >= args.size():
		return false
	var expected: Variant = pre.get("value", pre.get("signal_param_value"))
	return expected == null or args[index] == expected


func _check_stat_threshold(pre: Dictionary) -> bool:
	var stat: String = str(pre.get("stat", pre.get("stat_key", "")))
	var threshold: float = float(pre.get("threshold", 0.0))
	match stat:
		"player_cash":
			return _player_cash >= threshold
		"reputation":
			return _reputation >= threshold
	return false


func _condition_type(pre: Dictionary) -> String:
	return str(pre.get("type", pre.get("condition_type", "")))


func _condition_signal(pre: Dictionary) -> String:
	return str(pre.get("signal", pre.get("signal_name", "")))


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
			_advance_active_step(thread_id, def, state, day)
		elif phase == ThreadPhase.REVEALED:
			if _is_final_step_complete(def, state, day):
				_do_resolve(thread_id, def, state)


func _advance_active_step(
	thread_id: String, def: Dictionary, state: Dictionary, day: int
) -> void:
	var steps: Array = def.get("steps", [])
	if steps.is_empty():
		if day > int(state.get("activated_day", 0)):
			_do_reveal(thread_id, def, state, day)
		return
	var step_index: int = int(state.get("step_index", 0))
	if step_index >= steps.size():
		return
	var step: Variant = steps[step_index]
	if step is not Dictionary:
		state["step_index"] = step_index + 1
		return
	var step_dict: Dictionary = step as Dictionary
	if not _is_step_complete(step_dict, state, day):
		return
	if bool(step_dict.get("is_reveal_step", false)):
		_do_reveal(thread_id, def, state, day)
	else:
		_apply_step_effect(step_dict)
		state["step_index"] = step_index + 1


func _is_step_complete(
	step: Dictionary, state: Dictionary, day: int
) -> bool:
	var trigger_type: String = str(step.get("trigger_type", ""))
	match trigger_type:
		"day_after_active":
			var days: int = int(step.get("trigger_value", 1))
			return day - int(state.get("activated_day", 0)) >= days
		"signal":
			var sig: String = str(step.get("signal_name", ""))
			var threshold: int = int(step.get("trigger_value", 1))
			var wc: Dictionary = state.get("watch_counters", {})
			return int(wc.get(sig, 0)) >= threshold
		"stat_threshold":
			return _check_stat_threshold({
				"stat": step.get("stat_key", "reputation"),
				"threshold": step.get("trigger_value", 0.0),
			})
		_:
			return day > int(state.get("activated_day", 0))


func _apply_step_effect(step: Dictionary) -> void:
	if str(step.get("effect_type", "")) != "emit_ambient":
		return
	var payload: Dictionary = step.get("effect_payload", {})
	var moment: StringName = StringName(str(payload.get("moment_id", "")))
	if not moment.is_empty() and _ambient_system:
		_ambient_system.enqueue_by_id(moment)


func _is_final_step_complete(
	def: Dictionary, state: Dictionary, day: int
) -> bool:
	var steps: Array = def.get("steps", [])
	if steps.is_empty():
		return day > int(state.get("revealed_day", 0))
	var step_index: int = int(state.get("step_index", 0))
	if step_index >= steps.size():
		return day > int(state.get("revealed_day", 0))
	var step: Variant = steps[step_index]
	if step is Dictionary and bool((step as Dictionary).get("is_reveal_step", false)):
		var trigger: int = int((step as Dictionary).get("trigger_value", 1))
		return day - int(state.get("activated_day", 0)) > trigger
	return day > int(state.get("revealed_day", 0))


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
	var steps: Array = def.get("steps", [])
	if not steps.is_empty():
		var step_index: int = int(state.get("step_index", 0))
		if step_index < steps.size() and steps[step_index] is Dictionary:
			_apply_step_effect(steps[step_index] as Dictionary)
	_transition(thread_id, state, ThreadPhase.REVEALED)
	state["revealed_day"] = day
	EventBus.secret_thread_revealed.emit(StringName(thread_id))
	var moment: String = _reveal_moment_id(def)
	if not moment.is_empty() and _ambient_system:
		_ambient_system.enqueue_by_id(StringName(moment))


func _do_resolve(
	thread_id: String, def: Dictionary, state: Dictionary
) -> void:
	var reward_data: Dictionary = _reward_data(def)
	_apply_completion_reward(thread_id, reward_data)
	var reward_unlock_id: StringName = StringName(
		str(reward_data.get("unlock_id", ""))
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
		StringName(thread_id), reward_data
	)
	if bool(def.get("resettable", false)):
		_reset_thread(thread_id, state)
	else:
		_transition(thread_id, state, ThreadPhase.RESOLVED)


func _apply_completion_reward(
	thread_id: String, reward_data: Dictionary
) -> void:
	match str(reward_data.get("type", "")):
		"cash":
			var amount: float = float(reward_data.get("value", 0.0))
			if amount > 0.0 and _economy_system:
				_economy_system.add_cash(
					amount, "secret_thread_reward: " + thread_id
				)
		"reputation":
			EventBus.reputation_changed.emit(
				str(reward_data.get("store_id", "")),
				float(reward_data.get("value", 0.0)),
			)


func _reward_data(def: Dictionary) -> Dictionary:
	var reward: Dictionary = {}
	var raw: Variant = def.get("completion_reward", def.get("reward", {}))
	if raw is Dictionary:
		reward = (raw as Dictionary).duplicate(true)
	if reward.has("amount") and not reward.has("value"):
		reward["value"] = reward.get("amount")
	if def.has("reward_unlock_id"):
		reward["unlock_id"] = str(def.get("reward_unlock_id", ""))
	return reward


func _reveal_moment_id(def: Dictionary) -> String:
	var moment: String = str(def.get("reveal_moment", ""))
	if not moment.is_empty():
		return moment
	var steps: Array = def.get("steps", [])
	for step: Variant in steps:
		if step is not Dictionary:
			continue
		var step_dict: Dictionary = step as Dictionary
		if not bool(step_dict.get("is_reveal_step", false)):
			continue
		var payload: Dictionary = step_dict.get("effect_payload", {})
		return str(payload.get("moment_id", ""))
	return ""


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
	var save_data: Dictionary = data.duplicate(true)
	save_data["thread_states"] = data
	save_data["signal_counts"] = _signal_counts.duplicate()
	save_data["signal_values"] = _signal_values.duplicate(true)
	save_data["owned_store_count"] = _owned_store_count
	return save_data


## Restores thread state from saved data without re-emitting signals.
func load_state(data: Dictionary) -> void:
	var thread_data: Variant = data.get("thread_states", data)
	if thread_data is Dictionary:
		for thread_id: String in (thread_data as Dictionary):
			if thread_id in ["signal_counts", "signal_values", "owned_store_count", "thread_states"]:
				continue
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
	var sv: Variant = data.get("signal_values", {})
	if sv is Dictionary:
		_signal_values = (sv as Dictionary).duplicate(true)
	_owned_store_count = int(data.get("owned_store_count", 0))
