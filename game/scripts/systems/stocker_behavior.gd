## Auto-restocks shelves when a Stocker staff member is assigned to a store.
class_name StockerBehavior
extends Node


const SKILL_BASE_INTERVALS: Dictionary = {
	1: 90.0,
	2: 60.0,
	3: 45.0,
}

var _inventory_system: InventorySystem = null
var _staff_system: StaffSystem = null
var _data_loader: DataLoader = null
var _timers: Dictionary = {}
var _active_stockers: Dictionary = {}


func initialize(
	inventory: InventorySystem,
	staff: StaffSystem,
	data_loader: DataLoader,
) -> void:
	_inventory_system = inventory
	_staff_system = staff
	_data_loader = data_loader
	EventBus.staff_hired.connect(_on_staff_hired)
	EventBus.staff_fired.connect(_on_staff_fired)
	EventBus.staff_quit.connect(_on_staff_quit)
	refresh_all_stores()


func refresh_all_stores() -> void:
	if not _staff_system:
		return
	var active_ids: Array[String] = _staff_system.get_staffed_store_ids()
	var stale_ids: Array[String] = []
	for store_id: String in _active_stockers:
		if store_id not in active_ids:
			stale_ids.append(store_id)
	for store_id: String in stale_ids:
		_stop_timer(store_id)
		_active_stockers.erase(store_id)
	for store_id: String in active_ids:
		_refresh_store(store_id)


func _on_staff_hired(_staff_id: String, store_id: String) -> void:
	_refresh_store(store_id)


func _on_staff_fired(_staff_id: String, store_id: String) -> void:
	_refresh_store(store_id)


func _on_staff_quit(staff_id: String) -> void:
	for store_id: String in _active_stockers:
		var info: Dictionary = _active_stockers[store_id]
		if info.get("instance_id", "") == staff_id:
			_refresh_store(store_id)
			return


func _refresh_store(store_id: String) -> void:
	var stocker: Dictionary = _find_stocker_for_store(store_id)
	if stocker.is_empty():
		_stop_timer(store_id)
		_active_stockers.erase(store_id)
		return
	_active_stockers[store_id] = stocker
	var def: StaffDefinition = _get_staff_definition(
		stocker.get("definition_id", "")
	)
	if not def:
		_stop_timer(store_id)
		_active_stockers.erase(store_id)
		return
	var interval: float = _calc_interval(def)
	_start_timer(store_id, interval)


func _find_stocker_for_store(store_id: String) -> Dictionary:
	if not _staff_system:
		return {}
	var staff_list: Array[Dictionary] = (
		_staff_system.get_staff_for_store(store_id)
	)
	for entry: Dictionary in staff_list:
		var def: StaffDefinition = _get_staff_definition(
			entry.get("definition_id", "")
		)
		if def and def.role == StaffDefinition.StaffRole.STOCKER:
			return entry
	return {}


func _calc_interval(def: StaffDefinition) -> float:
	var base: float = float(
		SKILL_BASE_INTERVALS.get(def.skill_level, 90.0)
	)
	var perf: float = def.performance_multiplier()
	if perf <= 0.0:
		return base
	return base / perf


func _start_timer(store_id: String, interval: float) -> void:
	if _timers.has(store_id):
		var existing: Timer = _timers[store_id]
		existing.wait_time = interval
		if existing.is_stopped():
			existing.start()
		return
	var timer := Timer.new()
	timer.wait_time = interval
	timer.one_shot = false
	timer.timeout.connect(_on_timer_fire.bind(store_id))
	add_child(timer)
	_timers[store_id] = timer
	timer.start()


func _stop_timer(store_id: String) -> void:
	if not _timers.has(store_id):
		return
	var timer: Timer = _timers[store_id]
	timer.stop()
	timer.queue_free()
	_timers.erase(store_id)


func _on_timer_fire(store_id: String) -> void:
	if not _active_stockers.has(store_id):
		_stop_timer(store_id)
		return
	var stocker_info: Dictionary = _active_stockers[store_id]
	var staff_id: String = stocker_info.get("instance_id", "")
	var def: StaffDefinition = _get_staff_definition(
		stocker_info.get("definition_id", "")
	)
	if def:
		var new_interval: float = _calc_interval(def)
		var timer: Timer = _timers.get(store_id) as Timer
		if timer and absf(timer.wait_time - new_interval) > 0.1:
			timer.wait_time = new_interval
	_restock_one_item(store_id, staff_id)


func _restock_one_item(store_id: String, staff_id: String) -> void:
	if not _inventory_system or not _data_loader:
		return
	var store_def: StoreDefinition = _data_loader.get_store(store_id)
	if not store_def:
		return
	var store_type: String = store_def.store_type
	var shelf_items: Array[ItemInstance] = (
		_inventory_system.get_shelf_items_for_store(store_type)
	)
	var capacity: int = store_def.shelf_capacity
	if capacity <= 0:
		capacity = 50
	if shelf_items.size() >= capacity:
		return
	var backroom: Array[ItemInstance] = (
		_inventory_system.get_backroom_items_for_store(store_type)
	)
	if backroom.is_empty():
		return
	var item: ItemInstance = backroom[0]
	var slot_id: String = "stocker_slot_%d" % shelf_items.size()
	_inventory_system.move_item(
		item.instance_id, "shelf:%s" % slot_id
	)
	var item_def_id: String = (
		item.definition.id if item.definition else ""
	)
	EventBus.staff_restocked_shelf.emit(staff_id, item_def_id)


func _get_staff_definition(
	definition_id: String
) -> StaffDefinition:
	if _data_loader:
		return _data_loader.get_staff_definition(definition_id)
	return null
