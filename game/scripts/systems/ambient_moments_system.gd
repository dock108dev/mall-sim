## Flavor event scheduler with hidden state model and 5 trigger categories.
class_name AmbientMomentsSystem
extends Node


enum State { IDLE, MONITORING, SUSPENDED }

const MAX_QUEUE_SIZE: int = 3
## Maximum number of moment cards shown simultaneously in the tray.
const MAX_ACTIVE_SLOTS: int = 3

var _state: int = State.IDLE
var _moment_definitions: Array[AmbientMomentDefinition] = []
var _definition_cache: Dictionary = {}
var _cooldowns: Dictionary = {}
var _delivery_queue: Array[StringName] = []
## Moment IDs currently displayed; value is remaining display time in seconds.
var _active_moments: Dictionary = {}
var _delivery_history: Dictionary = {}
var _recent_item_categories: Dictionary = {}
var _recent_store_entries: Dictionary = {}
var _active_store_id: StringName = &""
var _current_season_id: String = ""
var _current_hour_context: int = 0
var _suspend_count: int = 0
var _secret_moments: AmbientSecretThreadMoments


func _ready() -> void:
	_load_definitions()
	_active_store_id = GameManager.get_active_store_id()


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
	var loaded: Array[AmbientMomentDefinition] = []
	if ContentRegistry.is_ready():
		for moment_id: StringName in ContentRegistry.get_all_ids(
			"ambient_moment"
		):
			var entry: Dictionary = ContentRegistry.get_entry(moment_id)
			if entry.is_empty():
				continue
			var def: AmbientMomentDefinition = (
				ContentParser.parse_ambient_moment(entry)
			)
			if def:
				loaded.append(def)
	if loaded.is_empty() and GameManager.data_loader:
		loaded = GameManager.data_loader.get_all_ambient_moments()
	_moment_definitions = loaded
	_rebuild_definition_cache()


func _connect_signals() -> void:
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.day_ended.is_connected(_on_day_ended):
		EventBus.day_ended.connect(_on_day_ended)
	if not EventBus.hour_changed.is_connected(_on_hour_changed):
		EventBus.hour_changed.connect(_on_hour_changed)
	if not EventBus.season_changed.is_connected(_on_season_changed):
		EventBus.season_changed.connect(_on_season_changed)
	if not EventBus.haggle_started.is_connected(_on_haggle_started):
		EventBus.haggle_started.connect(_on_haggle_started)
	if not EventBus.haggle_completed.is_connected(_on_haggle_completed):
		EventBus.haggle_completed.connect(_on_haggle_completed)
	if not EventBus.build_mode_entered.is_connected(
		_on_build_mode_entered
	):
		EventBus.build_mode_entered.connect(_on_build_mode_entered)
	if not EventBus.build_mode_exited.is_connected(_on_build_mode_exited):
		EventBus.build_mode_exited.connect(_on_build_mode_exited)
	if not EventBus.item_sold.is_connected(_on_item_sold):
		EventBus.item_sold.connect(_on_item_sold)
	if not EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.connect(_on_store_entered)
	if not EventBus.active_store_changed.is_connected(
		_on_active_store_changed
	):
		EventBus.active_store_changed.connect(_on_active_store_changed)
	if _secret_moments:
		if not EventBus.mystery_item_inspected.is_connected(
			_secret_moments.on_mystery_item_inspected
		):
			EventBus.mystery_item_inspected.connect(
				_secret_moments.on_mystery_item_inspected
			)
		if not EventBus.odd_notification_read.is_connected(
			_secret_moments.on_odd_notification_read
		):
			EventBus.odd_notification_read.connect(
				_secret_moments.on_odd_notification_read
			)
		if not EventBus.discrepancy_noticed.is_connected(
			_secret_moments.on_discrepancy_noticed
		):
			EventBus.discrepancy_noticed.connect(
				_secret_moments.on_discrepancy_noticed
			)
		if not EventBus.wrong_name_customer_interacted.is_connected(
			_secret_moments.on_wrong_name_customer_interacted
		):
			EventBus.wrong_name_customer_interacted.connect(
				_secret_moments.on_wrong_name_customer_interacted
			)
		if not EventBus.renovation_sounds_heard.is_connected(
			_secret_moments.on_renovation_sounds_heard
		):
			EventBus.renovation_sounds_heard.connect(
				_secret_moments.on_renovation_sounds_heard
			)


func _process(delta: float) -> void:
	if _secret_moments:
		_secret_moments.process_tick(delta)
	_tick_active_moments(delta)


## Returns the current scheduler state.
func get_state() -> int:
	return _state


## Returns the current queued moment count.
func get_queue_size() -> int:
	return _delivery_queue.size()


## Returns the number of moment cards currently displayed in the tray.
func get_active_moment_count() -> int:
	return _active_moments.size()


## Overrides the current season ID for filter evaluation (also used in tests).
func set_current_season_id(season_id: String) -> void:
	_current_season_id = season_id


## Returns the queued moment IDs in delivery order.
func get_queued_moment_ids() -> Array[StringName]:
	return _delivery_queue.duplicate()


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
	if is_moment_on_cooldown(moment_id):
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
	_current_hour_context = hour
	if _state != State.MONITORING:
		_clear_transient_triggers()
		return
	_evaluate_moments(hour)
	_clear_transient_triggers()


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


func _on_item_sold(
	_item_id: String, _price: float, category: String
) -> void:
	if category.is_empty():
		return
	_recent_item_categories[category] = true


func _on_store_entered(store_id: StringName) -> void:
	if store_id.is_empty():
		return
	_active_store_id = store_id
	_recent_store_entries[String(store_id)] = true


func _on_active_store_changed(store_id: StringName) -> void:
	_active_store_id = store_id


func _suspend() -> void:
	_suspend_count += 1
	if _state == State.MONITORING:
		_state = State.SUSPENDED
		_cancel_queued_moments(&"suspended")


func _resume() -> void:
	_suspend_count = maxi(_suspend_count - 1, 0)
	if _suspend_count == 0 and _state == State.SUSPENDED:
		_state = State.MONITORING
		_dispatch_next()


func _cancel_queued_moments(reason: StringName) -> void:
	for moment_id: StringName in _delivery_queue:
		EventBus.ambient_moment_cancelled.emit(
			moment_id, reason
		)
	_delivery_queue.clear()


func _evaluate_moments(hour: int) -> void:
	trigger_moment(hour)


## Selects and dispatches one eligible ambient moment for the given hour.
func trigger_moment(hour: int = -1) -> StringName:
	if _delivery_queue.size() >= MAX_QUEUE_SIZE:
		return &""
	var target_hour: int = hour
	if target_hour < 0:
		target_hour = _get_current_hour()
	var eligible: Array[AmbientMomentDefinition] = (
		_get_eligible_moments(target_hour)
	)
	if eligible.is_empty():
		return &""
	var chosen: AmbientMomentDefinition = _weighted_pick(eligible)
	if not chosen:
		return &""
	var moment_sn: StringName = StringName(chosen.id)
	_delivery_queue.append(moment_sn)
	EventBus.ambient_moment_queued.emit(moment_sn)
	_dispatch_next()
	return moment_sn


## Advances ambient moment cooldown counters by scheduler ticks.
func advance_time(seconds: float) -> void:
	var ticks: int = maxi(int(seconds), 0)
	for i: int in range(ticks):
		_tick_cooldowns()


## Returns eligible moment definitions for the given or current hour.
func get_eligible_moments(
	hour: int = -1,
) -> Array[AmbientMomentDefinition]:
	var target_hour: int = hour
	if target_hour < 0:
		target_hour = _get_current_hour()
	return _get_eligible_moments(target_hour)


## Replaces the active ambient moment definitions.
func set_moment_pool(pool: Array[AmbientMomentDefinition]) -> void:
	_moment_definitions = pool.duplicate()
	_rebuild_definition_cache()


func _get_eligible_moments(
	hour: int,
) -> Array[AmbientMomentDefinition]:
	var eligible: Array[AmbientMomentDefinition] = []
	for def: AmbientMomentDefinition in _moment_definitions:
		if _is_definition_auto_scheduler_blocked(def):
			continue
		if _delivery_queue.size() >= MAX_QUEUE_SIZE:
			break
		if not _matches_extended_filter(def):
			continue
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
	if not _matches_location_category(def):
		return false
	return hour == int(def.trigger_value)


func _check_reputation_trigger(
	def: AmbientMomentDefinition,
) -> bool:
	if not _matches_location_category(def):
		return false
	var required_tier: int = int(def.trigger_value)
	var current_score: float = _get_current_reputation()
	return int(current_score / 25.0) >= required_tier


func _check_item_type_trigger(
	def: AmbientMomentDefinition,
) -> bool:
	if not _matches_location_category(def):
		return false
	if def.trigger_value.is_empty():
		return false
	return _recent_item_categories.has(def.trigger_value)


func _check_store_type_trigger(
	def: AmbientMomentDefinition,
) -> bool:
	if not _matches_location_category(def):
		return false
	var store_id: StringName = StringName(def.trigger_value)
	if _recent_store_entries.has(String(store_id)):
		return true
	return (
		_active_store_id == store_id
		and not _has_been_delivered(StringName(def.id))
	)


func _check_random_trigger(
	def: AmbientMomentDefinition,
) -> bool:
	if not _matches_location_category(def):
		return false
	return randf() < float(def.trigger_value)


func _get_current_reputation() -> float:
	var store_id: String = String(GameManager.get_active_store_id())
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
	if _active_moments.size() >= MAX_ACTIVE_SLOTS:
		return
	var moment_id: StringName = _delivery_queue.pop_front()
	var def: AmbientMomentDefinition = _find_definition(String(moment_id))
	var duration: float = 8.0
	var flavor: String = str(moment_id)
	var display_type: StringName = &"toast"
	var audio_cue: StringName = &""
	if def:
		_apply_delivery_tracking(def)
		duration = def.duration_seconds if def.duration_seconds > 0.0 else 8.0
		flavor = def.flavor_text
		display_type = def.display_type
		audio_cue = def.audio_cue_id
	_active_moments[moment_id] = duration
	EventBus.ambient_moment_delivered.emit(
		moment_id, display_type, flavor, audio_cue
	)
	EventBus.moment_displayed.emit(moment_id, flavor, duration)


func _tick_active_moments(delta: float) -> void:
	if _active_moments.is_empty():
		return
	var expired: Array[StringName] = []
	for moment_id: StringName in _active_moments:
		_active_moments[moment_id] = float(_active_moments[moment_id]) - delta
		if float(_active_moments[moment_id]) <= 0.0:
			expired.append(moment_id)
	for moment_id: StringName in expired:
		_expire_moment(moment_id)


func _expire_moment(moment_id: StringName) -> void:
	_active_moments.erase(moment_id)
	EventBus.moment_expired.emit(moment_id)
	if _active_moments.is_empty() and _delivery_queue.is_empty():
		EventBus.moment_queue_empty.emit()
	else:
		_dispatch_next()


## Returns false when the moment's store_id, season_id, or day range doesn't
## match the current game context. Empty fields mean "no constraint".
func _matches_extended_filter(def: AmbientMomentDefinition) -> bool:
	if not def.store_id.is_empty():
		if String(_active_store_id) != def.store_id:
			return false
	if not def.season_id.is_empty():
		if _current_season_id != def.season_id:
			return false
	var current_day: int = _get_current_day()
	if def.min_day > 0 and current_day < def.min_day:
		return false
	if def.max_day > 0 and current_day > def.max_day:
		return false
	return true


func _on_season_changed(new_season: int, _old_season: int) -> void:
	_current_season_id = _season_int_to_id(new_season)


func _season_int_to_id(season: int) -> String:
	match season:
		0:
			return "spring"
		1:
			return "summer"
		2:
			return "fall"
		3:
			return "winter"
	return ""


func _find_definition(
	id: String,
) -> AmbientMomentDefinition:
	if _definition_cache.has(id):
		return _definition_cache[id] as AmbientMomentDefinition
	for def: AmbientMomentDefinition in _moment_definitions:
		if def.id == id:
			_definition_cache[id] = def
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
	var history_save: Dictionary = {}
	for moment_id: String in _delivery_history:
		var raw_history: Variant = _delivery_history[moment_id]
		if raw_history is Dictionary:
			history_save[moment_id] = (raw_history as Dictionary).duplicate()
	var data: Dictionary = {
		"state": _state,
		"cooldowns": cooldown_save,
		"delivery_queue": _delivery_queue.duplicate(),
		"delivery_history": history_save,
	}
	if _secret_moments:
		data.merge(_secret_moments.get_save_data())
	return data


## Restores moment state from saved data.
func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


## Restores moment state from saved data.
func load_state(data: Dictionary) -> void:
	load_save_data(data)


func _apply_state(data: Dictionary) -> void:
	_state = int(data.get("state", State.IDLE))
	_active_store_id = GameManager.get_active_store_id()
	_suspend_count = 0
	_delivery_queue = []
	_active_moments.clear()
	_recent_item_categories.clear()
	_recent_store_entries.clear()
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
	_delivery_history = {}
	var history_data: Variant = data.get("delivery_history", {})
	if history_data is Dictionary:
		for key: String in (history_data as Dictionary):
			var raw_history: Variant = (
				history_data as Dictionary
			)[key]
			if raw_history is not Dictionary:
				continue
			var history_entry: Dictionary = raw_history as Dictionary
			_delivery_history[key] = {
				"last_delivered_day": int(
					history_entry.get("last_delivered_day", 0)
				),
				"last_delivered_hour": int(
					history_entry.get("last_delivered_hour", -1)
				),
				"total_deliveries": int(
					history_entry.get("total_deliveries", 0)
				),
			}
	if _secret_moments:
		_secret_moments.apply_state(data)


## Returns true when the moment is blocked by an active cooldown or one-shot history.
func is_moment_on_cooldown(moment_id: StringName) -> bool:
	var def: AmbientMomentDefinition = _find_definition(String(moment_id))
	if def == null:
		return _cooldowns.has(String(moment_id))
	return _is_definition_on_cooldown(def)


## Returns the last day on which the moment was delivered.
func get_last_delivered_day(moment_id: StringName) -> int:
	var history: Dictionary = _delivery_history.get(
		String(moment_id), {}
	) as Dictionary
	return int(history.get("last_delivered_day", 0))


## Returns the total number of times the moment has been delivered.
func get_total_deliveries(moment_id: StringName) -> int:
	var history: Dictionary = _delivery_history.get(
		String(moment_id), {}
	) as Dictionary
	return int(history.get("total_deliveries", 0))


## Returns the eligible moment count for the current in-game hour.
func get_eligible_moment_count() -> int:
	return _get_eligible_moments(_get_current_hour()).size()


func _rebuild_definition_cache() -> void:
	_definition_cache.clear()
	for def: AmbientMomentDefinition in _moment_definitions:
		_definition_cache[def.id] = def


func _clear_transient_triggers() -> void:
	_recent_item_categories.clear()
	_recent_store_entries.clear()


func _matches_location_category(
	def: AmbientMomentDefinition
) -> bool:
	match def.category:
		"", "any":
			return true
		"hallway":
			return _active_store_id.is_empty()
		"store":
			return not _active_store_id.is_empty()
		"secret_thread":
			return false
	return false


func _apply_delivery_tracking(
	def: AmbientMomentDefinition
) -> void:
	_mark_delivered(def.id)
	if def.cooldown_days > 0:
		_cooldowns[def.id] = def.cooldown_days
	else:
		_cooldowns.erase(def.id)


func _mark_delivered(moment_id: String) -> void:
	var history: Dictionary = _delivery_history.get(
		moment_id, {}
	) as Dictionary
	history["last_delivered_day"] = _get_current_day()
	history["last_delivered_hour"] = _get_current_hour()
	history["total_deliveries"] = int(
		history.get("total_deliveries", 0)
	) + 1
	_delivery_history[moment_id] = history


func _is_definition_auto_scheduler_blocked(
	def: AmbientMomentDefinition
) -> bool:
	if def.category == "secret_thread":
		return true
	return _is_definition_on_cooldown(def)


func _is_definition_on_cooldown(
	def: AmbientMomentDefinition
) -> bool:
	if def.cooldown_days <= 0:
		return _has_been_delivered(StringName(def.id))
	return _cooldowns.has(def.id)


func _has_been_delivered(moment_id: StringName) -> bool:
	return _delivery_history.has(String(moment_id))


func _get_current_day() -> int:
	return GameManager.current_day


func _get_current_hour() -> int:
	return _current_hour_context
