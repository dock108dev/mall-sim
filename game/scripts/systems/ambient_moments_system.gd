## Flavor event scheduler with hidden state model and 5 trigger categories.
class_name AmbientMomentsSystem
extends Node


enum State { IDLE, MONITORING, SUSPENDED }

const MAX_QUEUE_SIZE: int = 3

var _state: int = State.IDLE
var _moment_definitions: Array[AmbientMomentDefinition] = []
var _cooldowns: Dictionary = {}
var _delivery_queue: Array[StringName] = []
var _suspend_count: int = 0
var _secret_moments: AmbientSecretThreadMoments


## Sets up the system with required references and loads definitions.
func initialize(
	secret_thread: SecretThreadManager,
	inventory: InventorySystem,
	time: TimeSystem,
) -> void:
	_secret_moments = AmbientSecretThreadMoments.new()
	_secret_moments.secret_thread_manager = secret_thread
	_secret_moments.inventory_system = inventory
	_secret_moments.time_system = time
	_secret_moments.pick_trigger_days()
	_load_definitions()
	_apply_state({})
	_connect_signals()


func _load_definitions() -> void:
	if not GameManager.data_loader:
		return
	_moment_definitions = (
		GameManager.data_loader.get_all_ambient_moments()
	)


func _connect_signals() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.haggle_started.connect(_on_haggle_started)
	EventBus.haggle_completed.connect(_on_haggle_completed)
	EventBus.build_mode_entered.connect(_on_build_mode_entered)
	EventBus.build_mode_exited.connect(_on_build_mode_exited)
	if _secret_moments:
		EventBus.mystery_item_inspected.connect(
			_secret_moments.on_mystery_item_inspected
		)
		EventBus.odd_notification_read.connect(
			_secret_moments.on_odd_notification_read
		)
		EventBus.discrepancy_noticed.connect(
			_secret_moments.on_discrepancy_noticed
		)
		EventBus.wrong_name_customer_interacted.connect(
			_secret_moments.on_wrong_name_customer_interacted
		)
		EventBus.renovation_sounds_heard.connect(
			_secret_moments.on_renovation_sounds_heard
		)


func _process(delta: float) -> void:
	if _secret_moments:
		_secret_moments.process_tick(delta)


## Returns the current scheduler state.
func get_state() -> int:
	return _state


## Returns the discrepancy amount if active, else 0.0.
func get_active_discrepancy() -> float:
	if _secret_moments:
		return _secret_moments.get_active_discrepancy()
	return 0.0


## Returns true if the discrepancy is currently visible.
func is_discrepancy_active() -> bool:
	if _secret_moments:
		return _secret_moments.is_discrepancy_active()
	return false


## Bypasses scheduler and adds moment directly to delivery queue.
func enqueue_by_id(moment_id: StringName) -> void:
	if moment_id.is_empty():
		push_error("AmbientMomentsSystem: empty moment_id")
		return
	if _cooldowns.has(String(moment_id)):
		EventBus.ambient_moment_cancelled.emit(moment_id, &"cooldown")
		return
	if _delivery_queue.size() >= MAX_QUEUE_SIZE:
		EventBus.ambient_moment_cancelled.emit(
			moment_id, &"queue_full"
		)
		return
	_delivery_queue.append(moment_id)
	EventBus.ambient_moment_queued.emit(moment_id)
	_dispatch_next()


func _on_day_started(day: int) -> void:
	if _state == State.IDLE:
		_state = State.MONITORING
	_tick_cooldowns()
	if _secret_moments:
		_secret_moments.on_day_started(day)


func _on_day_ended(day: int) -> void:
	if _secret_moments:
		_secret_moments.on_day_ended(day)


func _on_hour_changed(hour: int) -> void:
	if _state != State.MONITORING:
		return
	_evaluate_moments(hour)


func _on_haggle_started(
	_item_id: String, _customer_id: int
) -> void:
	_suspend()


func _on_haggle_completed(
	_store_id: StringName, _item_id: StringName,
	_final_price: float, _asking_price: float,
	_accepted: bool, _offer_count: int,
) -> void:
	_resume()


func _on_build_mode_entered() -> void:
	_suspend()


func _on_build_mode_exited() -> void:
	_resume()


func _suspend() -> void:
	_suspend_count += 1
	if _state == State.MONITORING:
		_state = State.SUSPENDED
		_cancel_queued_moments(&"suspended")


func _resume() -> void:
	_suspend_count = maxi(_suspend_count - 1, 0)
	if _suspend_count == 0 and _state == State.SUSPENDED:
		_state = State.MONITORING


func _cancel_queued_moments(reason: StringName) -> void:
	for moment_id: StringName in _delivery_queue:
		EventBus.ambient_moment_cancelled.emit(
			moment_id, reason
		)
	_delivery_queue.clear()


func _evaluate_moments(hour: int) -> void:
	if _delivery_queue.size() >= MAX_QUEUE_SIZE:
		return
	var eligible: Array[AmbientMomentDefinition] = (
		_get_eligible_moments(hour)
	)
	if eligible.is_empty():
		return
	var chosen: AmbientMomentDefinition = _weighted_pick(eligible)
	if not chosen:
		return
	var moment_sn: StringName = StringName(chosen.id)
	_delivery_queue.append(moment_sn)
	_cooldowns[chosen.id] = chosen.cooldown_days
	EventBus.ambient_moment_queued.emit(moment_sn)
	_dispatch_next()


func _get_eligible_moments(
	hour: int,
) -> Array[AmbientMomentDefinition]:
	var eligible: Array[AmbientMomentDefinition] = []
	for def: AmbientMomentDefinition in _moment_definitions:
		if _cooldowns.has(def.id):
			continue
		if _delivery_queue.size() >= MAX_QUEUE_SIZE:
			break
		if _check_trigger(def, hour):
			eligible.append(def)
	return eligible


func _check_trigger(
	def: AmbientMomentDefinition, hour: int
) -> bool:
	match def.trigger_category:
		"time_of_day":
			return _check_time_trigger(def, hour)
		"reputation_tier":
			return _check_reputation_trigger(def)
		"item_type":
			return _check_item_type_trigger(def)
		"store_type":
			return _check_store_type_trigger(def)
		"random_chance":
			return _check_random_trigger(def)
	return false


func _check_time_trigger(
	def: AmbientMomentDefinition, hour: int
) -> bool:
	return hour == int(def.trigger_value)


func _check_reputation_trigger(
	def: AmbientMomentDefinition,
) -> bool:
	var required_tier: int = int(def.trigger_value)
	var current_score: float = _get_current_reputation()
	return int(current_score / 25.0) >= required_tier


func _check_item_type_trigger(
	def: AmbientMomentDefinition,
) -> bool:
	var store_id: String = GameManager.current_store_id
	if store_id.is_empty():
		return false
	return not def.trigger_value.is_empty()


func _check_store_type_trigger(
	def: AmbientMomentDefinition,
) -> bool:
	return GameManager.current_store_id == def.trigger_value


func _check_random_trigger(
	def: AmbientMomentDefinition,
) -> bool:
	return randf() < float(def.trigger_value)


func _get_current_reputation() -> float:
	var store_id: String = GameManager.current_store_id
	if store_id.is_empty():
		return 0.0
	var rep_sys: Node = get_node_or_null(
		"/root/ReputationSystemSingleton"
	)
	if rep_sys and rep_sys.has_method("get_reputation"):
		var score: Variant = rep_sys.get_reputation(store_id)
		return float(score) if score != null else 0.0
	return 0.0


func _weighted_pick(
	candidates: Array[AmbientMomentDefinition],
) -> AmbientMomentDefinition:
	var total: float = 0.0
	for def: AmbientMomentDefinition in candidates:
		total += def.scheduling_weight
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for def: AmbientMomentDefinition in candidates:
		cumulative += def.scheduling_weight
		if roll <= cumulative:
			return def
	return candidates[candidates.size() - 1]


func _dispatch_next() -> void:
	if _state == State.SUSPENDED:
		return
	if _delivery_queue.is_empty():
		return
	var moment_id: StringName = _delivery_queue.pop_front()
	var def: AmbientMomentDefinition = _find_definition(
		String(moment_id)
	)
	if def:
		EventBus.ambient_moment_delivered.emit(
			moment_id, def.display_type,
			def.flavor_text, def.audio_cue_id
		)
	else:
		EventBus.ambient_moment_delivered.emit(
			moment_id, &"toast", str(moment_id), &""
		)


func _find_definition(
	id: String,
) -> AmbientMomentDefinition:
	for def: AmbientMomentDefinition in _moment_definitions:
		if def.id == id:
			return def
	return null


func _tick_cooldowns() -> void:
	var to_remove: PackedStringArray = []
	for moment_id: String in _cooldowns:
		_cooldowns[moment_id] = int(_cooldowns[moment_id]) - 1
		if int(_cooldowns[moment_id]) <= 0:
			to_remove.append(moment_id)
	for moment_id: String in to_remove:
		_cooldowns.erase(moment_id)


# ── Save / Load ──────────────────────────────────────────────────────────────


## Serializes moment state for saving.
func get_save_data() -> Dictionary:
	var cooldown_save: Dictionary = {}
	for key: String in _cooldowns:
		cooldown_save[key] = _cooldowns[key]
	var data: Dictionary = {
		"state": _state,
		"cooldowns": cooldown_save,
		"delivery_queue": _delivery_queue.duplicate(),
	}
	if _secret_moments:
		data.merge(_secret_moments.get_save_data())
	return data


## Restores moment state from saved data.
func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_state = int(data.get("state", State.IDLE))
	_suspend_count = 0
	_delivery_queue = []
	var queue_data: Variant = data.get("delivery_queue", [])
	if queue_data is Array:
		for entry: Variant in queue_data:
			_delivery_queue.append(StringName(str(entry)))
	_cooldowns = {}
	var cooldown_data: Variant = data.get("cooldowns", {})
	if cooldown_data is Dictionary:
		for key: String in (cooldown_data as Dictionary):
			_cooldowns[key] = int(
				(cooldown_data as Dictionary)[key]
			)
	if _secret_moments:
		_secret_moments.apply_state(data)
