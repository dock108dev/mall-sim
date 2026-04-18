## Mall-level customer spawner that distributes customers across owned stores.
class_name MallCustomerSpawner
extends Node

const MAX_MALL_CUSTOMERS: int = 15
const BASE_SPAWN_INTERVAL: float = 45.0
const SECOND_STORE_CHANCE: float = 0.2
const SECOND_VISIT_DELAY: float = 30.0

const TIME_MULTIPLIERS: Dictionary = {
	"morning": 0.5,
	"midday": 1.5,
	"afternoon": 1.0,
	"evening": 0.3,
}

var _customer_system: CustomerSystem = null
var _reputation_system: ReputationSystem = null
var _seasonal_event_system: SeasonalEventSystem = null
var _store_selector: StoreSelector = null
var _spawn_accumulator: float = 0.0
var _current_time_multiplier: float = 1.0
var _time_scale: float = 1.0
var _all_profiles: Dictionary = {}
var _store_customer_counts: Dictionary = {}
var _total_customer_count: int = 0
var _pending_second_visits: Array[Dictionary] = []
var _second_visit_timer: float = 0.0


func initialize(
	customer_system: CustomerSystem,
	reputation_system: ReputationSystem,
	trend_system: TrendSystem = null
) -> void:
	_customer_system = customer_system
	_reputation_system = reputation_system
	_store_selector = StoreSelector.new()
	_store_selector.initialize(reputation_system, trend_system)
	_current_time_multiplier = _get_time_multiplier(
		Constants.STORE_OPEN_HOUR
	)
	_load_all_profiles()
	_init_store_counts()

	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.store_leased.connect(_on_store_leased)


func _process(delta: float) -> void:
	if _time_scale <= 0.0:
		return
	var scaled_delta: float = delta * _time_scale
	_spawn_accumulator += scaled_delta
	var interval: float = _get_spawn_interval()
	if _spawn_accumulator >= interval:
		_spawn_accumulator -= interval
		_try_spawn_customer()
	_process_second_visits(scaled_delta)


## Returns the total number of customers across all stores.
func get_total_customer_count() -> int:
	return _total_customer_count


## Returns the customer count for a specific store.
func get_store_customer_count(store_id: String) -> int:
	return _store_customer_counts.get(store_id, 0) as int


func _load_all_profiles() -> void:
	_all_profiles.clear()
	if not GameManager.data_loader:
		push_warning(
			"MallCustomerSpawner: DataLoader not available"
		)
		return
	for store_id: StringName in GameManager.get_owned_store_ids():
		var profiles: Array[CustomerTypeDefinition] = (
			GameManager.data_loader.get_customer_types_for_store(
				String(store_id)
			)
		)
		if not profiles.is_empty():
			_all_profiles[String(store_id)] = profiles


func _init_store_counts() -> void:
	_store_customer_counts.clear()
	for store_id: StringName in GameManager.get_owned_store_ids():
		_store_customer_counts[String(store_id)] = 0
	_total_customer_count = 0
	if _store_selector:
		_store_selector.set_store_counts(_store_customer_counts)


## Sets the SeasonalEventSystem reference for traffic multipliers.
func set_seasonal_event_system(
	system: SeasonalEventSystem
) -> void:
	_seasonal_event_system = system


func _get_spawn_interval() -> float:
	var time_mult: float = _current_time_multiplier
	time_mult *= _get_reputation_spawn_multiplier()
	if _seasonal_event_system:
		time_mult *= _seasonal_event_system.get_traffic_multiplier()
	if time_mult <= 0.0:
		return BASE_SPAWN_INTERVAL * 10.0
	return BASE_SPAWN_INTERVAL / time_mult


func _get_phase_for_hour(hour: int) -> String:
	if hour < 12:
		return "morning"
	if hour < 14:
		return "midday"
	if hour < 18:
		return "afternoon"
	return "evening"


func _get_time_multiplier(hour: int) -> float:
	var phase: String = _get_phase_for_hour(hour)
	return TIME_MULTIPLIERS.get(phase, 1.0) as float


func _get_reputation_spawn_multiplier() -> float:
	if not _reputation_system or GameManager.get_owned_store_ids().is_empty():
		return 1.0
	return _reputation_system.get_global_customer_multiplier()


func _try_spawn_customer() -> void:
	if _total_customer_count >= MAX_MALL_CUSTOMERS:
		return
	var target_store: String = _store_selector.select_store()
	if target_store.is_empty():
		return
	if not _all_profiles.has(target_store):
		return
	_spawn_for_store(target_store)


func _spawn_for_store(store_id: String) -> void:
	var profiles: Array = _all_profiles.get(store_id, []) as Array
	if profiles.is_empty():
		return

	var profile: CustomerTypeDefinition = profiles.pick_random()
	var is_active: bool = (
		store_id == String(GameManager.get_active_store_id())
	)

	if is_active and _customer_system:
		_customer_system.spawn_customer(profile, store_id)
	else:
		_spawn_background_customer(store_id, profile)

	_store_customer_counts[store_id] = (
		(_store_customer_counts.get(store_id, 0) as int) + 1
	)
	_total_customer_count += 1


func _spawn_background_customer(
	store_id: String, profile: CustomerTypeDefinition
) -> void:
	var customer_data: Dictionary = {
		"customer_id": randi(),
		"profile_id": profile.id,
		"profile_name": profile.customer_name,
		"store_id": store_id,
		"is_background": true,
	}
	EventBus.customer_entered.emit(customer_data)

	var visit_duration: float = randf_range(
		profile.browse_time_range[0],
		profile.browse_time_range[1]
	)
	_schedule_background_departure(
		store_id, customer_data, visit_duration
	)


func _schedule_background_departure(
	store_id: String,
	customer_data: Dictionary,
	delay: float
) -> void:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(
		delay / maxf(_time_scale, 0.1), 1.0
	)
	add_child(timer)
	timer.timeout.connect(
		_on_background_customer_done.bind(
			store_id, customer_data, timer
		)
	)
	timer.start()


func _on_background_customer_done(
	store_id: String,
	customer_data: Dictionary,
	timer: Timer
) -> void:
	timer.queue_free()
	_decrement_store_count(store_id)
	EventBus.customer_left.emit(customer_data)

	if randf() < SECOND_STORE_CHANCE:
		_queue_second_visit(customer_data)


func _process_second_visits(delta: float) -> void:
	if _pending_second_visits.is_empty():
		return
	_second_visit_timer += delta
	if _second_visit_timer < SECOND_VISIT_DELAY:
		return
	_second_visit_timer = 0.0

	var visit: Dictionary = _pending_second_visits.pop_front()
	var excluded: String = visit.get("from_store", "") as String
	_try_second_store_visit(excluded)


func _queue_second_visit(customer_data: Dictionary) -> void:
	_pending_second_visits.append({
		"from_store": customer_data.get("store_id", ""),
	})


func _try_second_store_visit(excluded_store: String) -> void:
	if _total_customer_count >= MAX_MALL_CUSTOMERS:
		return
	var target: String = _store_selector.select_store(
		excluded_store
	)
	if target.is_empty():
		return
	if not _all_profiles.has(target):
		return
	_spawn_for_store(target)


func _decrement_store_count(store_id: String) -> void:
	var current: int = (
		_store_customer_counts.get(store_id, 0) as int
	)
	_store_customer_counts[store_id] = maxi(current - 1, 0)
	_total_customer_count = maxi(_total_customer_count - 1, 0)


func _on_customer_left(customer_data: Dictionary) -> void:
	var is_bg: bool = (
		customer_data.get("is_background", false) as bool
	)
	if is_bg:
		return
	var store_id: String = (
		customer_data.get("store_id", "") as String
	)
	if store_id.is_empty():
		return
	_decrement_store_count(store_id)

	if randf() < SECOND_STORE_CHANCE:
		_queue_second_visit(customer_data)


func _on_hour_changed(hour: int) -> void:
	_current_time_multiplier = _get_time_multiplier(hour)


func _on_speed_changed(new_speed: float) -> void:
	_time_scale = new_speed


func _on_day_ended(_day: int) -> void:
	_init_store_counts()
	_pending_second_visits.clear()
	_second_visit_timer = 0.0
	_spawn_accumulator = 0.0


func _on_store_leased(
	_slot_index: int, _store_type: String
) -> void:
	_load_all_profiles()
	_init_store_counts()


## Spawns a customer in the current store for debug purposes.
func debug_spawn_customer() -> void:
	var store_id: String = String(GameManager.get_active_store_id())
	if store_id.is_empty():
		push_warning(
			"MallCustomerSpawner: No current store for debug spawn"
		)
		return
	if not _all_profiles.has(store_id):
		push_warning(
			"MallCustomerSpawner: No profiles for store %s"
			% store_id
		)
		return
	_spawn_for_store(store_id)
