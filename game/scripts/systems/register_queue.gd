## Manages an ordered queue of customers waiting at the store register.
class_name RegisterQueue
extends RefCounted

const MAX_QUEUE_SIZE: int = 3
const QUEUE_SPACING: float = 1.0

var _queue: Array[Customer] = []
var _register_position: Vector3 = Vector3.ZERO
var _queue_direction: Vector3 = Vector3.ZERO


## Sets up the queue with register and entry positions for direction calculation.
func initialize(register_pos: Vector3, entry_pos: Vector3) -> void:
	_register_position = register_pos
	var dir: Vector3 = entry_pos - register_pos
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = Vector3.BACK
	_queue_direction = dir.normalized()


## Attempts to add a customer to the queue. Returns true if added.
func try_add(customer: Customer) -> bool:
	if _queue.size() >= MAX_QUEUE_SIZE:
		return false
	if _queue.has(customer):
		return false
	_queue.append(customer)
	var index: int = _queue.size() - 1
	if index > 0:
		customer.enter_queue(_get_position(index))
	return true


## Removes a customer from the queue and repositions remaining customers.
func remove(customer: Customer) -> void:
	if not _queue.has(customer):
		return
	_queue.erase(customer)
	_reposition_queue()


## Removes and returns the first customer, then advances the rest.
func advance() -> void:
	if _queue.is_empty():
		return
	_queue.remove_at(0)
	_reposition_queue()


## Returns the first customer in the queue, or null.
func get_first() -> Customer:
	if _queue.is_empty():
		return null
	if not is_instance_valid(_queue[0]):
		_queue.remove_at(0)
		_reposition_queue()
		return get_first()
	return _queue[0]


## Returns the number of customers currently in the queue.
func get_size() -> int:
	return _queue.size()


## Returns true if the queue has reached maximum capacity.
func is_full() -> bool:
	return _queue.size() >= MAX_QUEUE_SIZE


## Returns the customer at the given index, or null if out of range.
func get_at(index: int) -> Customer:
	if index < 0 or index >= _queue.size():
		return null
	return _queue[index]


## Returns true if the given customer is in the queue.
func has_customer(customer: Customer) -> bool:
	return _queue.has(customer)


## Returns the customer's instance ID if they are in the queue.
func has_customer_id(cust_id: int) -> bool:
	for customer: Customer in _queue:
		if is_instance_valid(customer):
			if customer.get_instance_id() == cust_id:
				return true
	return false


## Removes a customer by instance ID and repositions the queue.
func remove_by_id(cust_id: int) -> void:
	for i: int in range(_queue.size() - 1, -1, -1):
		var customer: Customer = _queue[i]
		if not is_instance_valid(customer):
			_queue.remove_at(i)
			continue
		if customer.get_instance_id() == cust_id:
			_queue.remove_at(i)
			break
	_reposition_queue()


## Clears all customers from the queue.
func clear() -> void:
	_queue.clear()


func _get_position(index: int) -> Vector3:
	return _register_position + _queue_direction * QUEUE_SPACING * index


func _reposition_queue() -> void:
	for i: int in range(_queue.size()):
		var customer: Customer = _queue[i]
		if not is_instance_valid(customer):
			continue
		if i == 0:
			customer.advance_to_register()
		else:
			customer.enter_queue(_get_position(i))
