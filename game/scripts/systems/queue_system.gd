## Manages the checkout queue, bridging NPC arrivals to transaction processing.
class_name QueueSystem
extends Node

const MAX_PATIENCE_MINUTES: float = 120.0

var _register_queue: RegisterQueue = null
var _processing: bool = false
var _queue_markers: Array[Marker3D] = []
var _wait_times: Dictionary = {}
var _patience_limits: Dictionary = {}


func initialize() -> void:
	_register_queue = RegisterQueue.new()
	EventBus.customer_reached_checkout.connect(_on_customer_reached_checkout)
	EventBus.checkout_completed.connect(_on_checkout_completed)
	EventBus.store_exited.connect(_on_store_exited)
	EventBus.active_store_changed.connect(_on_active_store_changed)


func setup_queue_positions(
	register_pos: Vector3, entry_pos: Vector3
) -> void:
	_register_queue.initialize(register_pos, entry_pos)


func get_queue_size() -> int:
	return _register_queue.get_size()


func enqueue_customer(customer: Node) -> bool:
	if not customer is Customer:
		push_error("QueueSystem: enqueue_customer called with non-Customer node")
		return false
	var typed: Customer = customer as Customer
	if not _register_queue.try_add(typed):
		typed.reject_from_queue()
		return false
	var cust_id: int = typed.get_instance_id()
	_wait_times[cust_id] = 0.0
	var patience: float = typed.profile.patience if typed.profile else 0.5
	_patience_limits[cust_id] = patience * MAX_PATIENCE_MINUTES
	EventBus.queue_changed.emit(_register_queue.get_size())
	_try_dispatch_next()
	return true


func enqueue(customer: Node) -> bool:
	return enqueue_customer(customer)


func dequeue_customer() -> Node:
	var front: Customer = _register_queue.get_first()
	if not front:
		return null
	_register_queue.advance()
	_processing = false
	_clear_wait_data(front)
	EventBus.queue_changed.emit(_register_queue.get_size())
	EventBus.queue_advanced.emit(_register_queue.get_size())
	_try_dispatch_next()
	return front


func get_queue_position(index: int) -> Vector3:
	if _queue_markers.size() > index and index >= 0:
		return _queue_markers[index].global_position
	return Vector3.ZERO


func bind_queue_markers(markers: Array[Marker3D]) -> void:
	_queue_markers = markers


func _process(delta: float) -> void:
	if not _register_queue or _register_queue.get_size() == 0:
		return
	var abandoned: Array[Customer] = []
	for i: int in range(_register_queue.get_size()):
		var customer: Customer = _register_queue.get_at(i)
		if not customer or not is_instance_valid(customer):
			continue
		var cust_id: int = customer.get_instance_id()
		if not _wait_times.has(cust_id):
			continue
		_wait_times[cust_id] += delta
		var limit: float = _patience_limits.get(cust_id, 60.0)
		if _wait_times[cust_id] >= limit:
			abandoned.append(customer)
	for customer: Customer in abandoned:
		_remove_abandoned(customer)


func _remove_abandoned(customer: Customer) -> void:
	_register_queue.remove(customer)
	var was_processing: bool = _processing
	_clear_wait_data(customer)
	EventBus.customer_abandoned_queue.emit(customer)
	EventBus.queue_changed.emit(_register_queue.get_size())
	EventBus.queue_advanced.emit(_register_queue.get_size())
	if was_processing:
		_processing = false
		_try_dispatch_next()


func _on_customer_reached_checkout(customer: Node) -> void:
	enqueue_customer(customer)


func _on_checkout_completed(customer: Node) -> void:
	_processing = false
	if customer is Customer and is_instance_valid(customer):
		_register_queue.remove(customer as Customer)
		_clear_wait_data(customer as Customer)
	EventBus.queue_changed.emit(_register_queue.get_size())
	EventBus.queue_advanced.emit(_register_queue.get_size())
	_try_dispatch_next()


func _on_store_exited(_store_id: StringName) -> void:
	_flush_queue()


func _on_active_store_changed(_store_id: StringName) -> void:
	_flush_queue()
	_queue_markers.clear()
	_bind_markers_from_group()


func _bind_markers_from_group() -> void:
	var markers: Array[Marker3D] = []
	var nodes: Array[Node] = get_tree().get_nodes_in_group("queue_markers")
	for node: Node in nodes:
		if node is Marker3D:
			markers.append(node as Marker3D)
	_queue_markers = markers


func _try_dispatch_next() -> void:
	if _processing:
		return
	var next: Customer = _register_queue.get_first()
	if not next:
		return
	if not is_instance_valid(next):
		_register_queue.advance()
		_try_dispatch_next()
		return
	_processing = true
	EventBus.checkout_queue_ready.emit(next)


func _flush_queue() -> void:
	_processing = false
	var queue_size: int = _register_queue.get_size()
	for i: int in range(queue_size):
		var customer: Customer = _register_queue.get_first()
		if customer and is_instance_valid(customer):
			var data: Dictionary = {
				"customer_id": customer.get_instance_id(),
			}
			EventBus.customer_left.emit(data)
		_register_queue.advance()
	_wait_times.clear()
	_patience_limits.clear()
	EventBus.queue_changed.emit(0)
	EventBus.queue_advanced.emit(0)


func _clear_wait_data(customer: Customer) -> void:
	if not is_instance_valid(customer):
		return
	var cust_id: int = customer.get_instance_id()
	_wait_times.erase(cust_id)
	_patience_limits.erase(cust_id)
