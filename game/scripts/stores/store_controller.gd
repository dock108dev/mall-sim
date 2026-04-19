## Base controller for all store types. Provides shared lifecycle, signal
## wiring, inventory interface, and slot/fixture management.
class_name StoreController
extends Node

var store_type: String = ""

var _slots: Array[Node] = []
var _fixtures: Array[Node] = []
var _register_area: Area3D = null
var _entry_area: Area3D = null
var _is_active: bool = false
var _inventory_system: InventorySystem = null
var _customer_system: CustomerSystem = null


## Initializes shared store identity before ready-time lifecycle wiring.
func initialize_store(
	store_id: StringName, store_kind: StringName = &""
) -> void:
	var resolved_type: StringName = store_kind
	if resolved_type.is_empty():
		resolved_type = store_id
	store_type = String(resolved_type)


func _ready() -> void:
	_collect_fixtures()
	_collect_slots()
	_collect_areas()
	_build_decorations()
	_connect_lifecycle_signals()


## Sets the InventorySystem reference for inventory queries.
func set_inventory_system(inv: InventorySystem) -> void:
	_inventory_system = inv


## Sets the CustomerSystem reference for active customer queries.
func set_customer_system(sys: CustomerSystem) -> void:
	_customer_system = sys


## Returns all items belonging to this store from InventorySystem.
func get_inventory() -> Array[Dictionary]:
	if not _inventory_system:
		return []
	var items: Array[ItemInstance] = (
		_inventory_system.get_items_for_store(store_type)
	)
	var result: Array[Dictionary] = []
	for item: ItemInstance in items:
		result.append({
			"instance_id": item.instance_id,
			"definition": item.definition,
			"condition": item.condition,
			"location": item.current_location,
		})
	return result


## Returns all active customers from CustomerSystem.
func get_active_customers() -> Array[Node]:
	if not _customer_system:
		return []
	var customers: Array[Customer] = (
		_customer_system.get_active_customers()
	)
	var result: Array[Node] = []
	for customer: Customer in customers:
		result.append(customer as Node)
	return result


## Validates store identity before emitting a signal on EventBus.
func emit_store_signal(
	signal_name: StringName, args: Array = []
) -> void:
	if store_type.is_empty():
		push_error(
			"StoreController: cannot emit signal without store_type"
		)
		return
	if not EventBus.has_signal(signal_name):
		push_error(
			"StoreController: EventBus has no signal '%s'" % signal_name
		)
		return
	var sig: Signal = Signal(EventBus, signal_name)
	sig.emit(args)


## Returns all ShelfSlot children across all fixtures.
func get_all_slots() -> Array[Node]:
	return _slots


## Returns slots that currently hold an item.
func get_occupied_slots() -> Array[Node]:
	var occupied: Array[Node] = []
	for slot: Node in _slots:
		if slot.has_method("is_occupied") and slot.is_occupied():
			occupied.append(slot)
	return occupied


## Returns slots that are currently empty.
func get_empty_slots() -> Array[Node]:
	var empty: Array[Node] = []
	for slot: Node in _slots:
		if not slot.has_method("is_occupied") or not slot.is_occupied():
			empty.append(slot)
	return empty


## Finds a slot by its slot_id property, or null if not found.
func get_slot_by_id(slot_id: String) -> Node:
	for slot: Node in _slots:
		if slot.get("slot_id") == slot_id:
			return slot
	return null


## Returns the register interaction zone, or null if none found.
func get_register_area() -> Area3D:
	return _register_area


## Returns the store entrance zone, or null if none found.
func get_entry_area() -> Area3D:
	return _entry_area


## Returns null by default; subclasses override to provide management UI.
func get_management_ui() -> Control:
	return null


## Returns the number of fixture parent nodes in this store.
func get_fixture_count() -> int:
	return _fixtures.size()


## Returns true if this controller's store is currently active.
func is_active() -> bool:
	return _is_active


## Virtual method called when this store becomes the active store.
func _on_store_activated() -> void:
	pass


## Virtual method called when this store is no longer the active store.
func _on_store_deactivated() -> void:
	pass


## Virtual method called after GameWorld has wired dependencies for store entry.
func _on_store_entered(_store_id: StringName) -> void:
	pass


## Returns the descriptors the ActionDrawer should render for this store.
## Each entry is {id: StringName, label: String, icon: String}. Subclasses
## override to append store-specific actions — call `super()` to keep the
## shared stock/price/inspect set.
func get_store_actions() -> Array:
	return [
		{"id": &"stock", "label": "Stock", "icon": ""},
		{"id": &"price", "label": "Price", "icon": ""},
		{"id": &"inspect", "label": "Inspect", "icon": ""},
		{"id": &"haggle", "label": "Haggle", "icon": ""},
	]


## Emits EventBus.actions_registered so the ActionDrawer can render this
## store's buttons. Called from the deferred store-entered handler.
func emit_actions_registered() -> void:
	if store_type.is_empty():
		return
	EventBus.actions_registered.emit(
		StringName(store_type), get_store_actions()
	)


## Virtual method called when the player exits this store.
func _on_store_exited(_store_id: StringName) -> void:
	pass


## Virtual method called at the start of each day.
func _on_day_started(_day: int) -> void:
	pass


## Virtual method called when the day ends; override to add store-specific cleanup.
func _on_day_ended(_day: int) -> void:
	pass


## Virtual method called when a customer enters a store.
func _on_customer_entered(_customer_data: Dictionary) -> void:
	pass


func _on_active_store_changed(store_id: StringName) -> void:
	var my_id: StringName = StringName(store_type)
	if store_id == my_id:
		_is_active = true
		_on_store_activated()
	else:
		if _is_active:
			_is_active = false
			_on_store_deactivated()


func _collect_fixtures() -> void:
	_fixtures.clear()
	for child: Node in get_children():
		if child.is_in_group("fixture"):
			_fixtures.append(child)


func _collect_slots() -> void:
	_slots.clear()
	for fixture: Node in _fixtures:
		for child: Node in fixture.get_children():
			if child.is_in_group("shelf_slot") or child.get("slot_id") != null:
				_slots.append(child)


func _collect_areas() -> void:
	for child: Node in get_children():
		if child is Area3D:
			if child.is_in_group("register_area"):
				_register_area = child as Area3D
			elif child.is_in_group("entry_area"):
				_entry_area = child as Area3D


func _build_decorations() -> void:
	if store_type.is_empty():
		return
	var node_ref: Variant = self
	if node_ref is Node3D:
		StoreDecorationBuilder.build(node_ref as Node3D, store_type)


func _connect_lifecycle_signals() -> void:
	_connect_signal(EventBus.store_entered, _defer_store_entered)
	_connect_signal(EventBus.store_exited, _on_store_exited)
	_connect_signal(EventBus.active_store_changed, _on_active_store_changed)
	_connect_signal(EventBus.day_started, _on_day_started)
	_connect_signal(EventBus.day_ended, _on_day_ended_notify)
	_connect_signal(EventBus.customer_entered, _on_customer_entered)


func _on_day_ended_notify(day: int) -> void:
	if store_type.is_empty():
		return
	_on_day_ended(day)
	_run_customer_simulation()
	EventBus.store_day_closed.emit(StringName(store_type), {"day": day})


## Runs the batch customer simulation for this store at end of day.
## Subclasses may override _get_event_traffic_multiplier() to provide
## store-specific event boosts.
func _run_customer_simulation() -> void:
	if not _inventory_system:
		return
	var rep_mult: float = ReputationSystemSingleton.get_customer_multiplier(store_type)
	var event_mult: float = _get_event_traffic_multiplier()
	var traffic: int = CustomerSimulator.calculate_traffic(
		CustomerSimulator.DEFAULT_BASE_TRAFFIC, rep_mult, event_mult
	)
	var snapshot: Array[ItemInstance] = _inventory_system.get_items_for_store(store_type)
	CustomerSimulator.simulate_day(StringName(store_type), traffic, snapshot)


## Override to return a store-specific event traffic multiplier.
func _get_event_traffic_multiplier() -> float:
	return 1.0


func _connect_signal(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


func _defer_store_entered(store_id: StringName) -> void:
	call_deferred("_handle_store_entered", store_id)


func _handle_store_entered(store_id: StringName) -> void:
	_on_store_entered(store_id)
	if StringName(store_type) == store_id:
		emit_actions_registered()
