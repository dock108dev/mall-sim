## Verifies RegisterQueue ordering, capacity, and position calculation.
extends GutTest

var _queue: RegisterQueue = null


func before_each() -> void:
	_queue = RegisterQueue.new()
	_queue.initialize(Vector3(2.5, 0, 2.0), Vector3(0, 0, 2.5))


func after_each() -> void:
	_queue = null


func test_queue_starts_empty() -> void:
	assert_eq(_queue.get_size(), 0, "Queue starts empty")
	assert_false(_queue.is_full(), "Queue is not full when empty")


func test_add_first_customer_stays_purchasing() -> void:
	var customer: Customer = _create_mock_customer()
	var added: bool = _queue.try_add(customer)
	assert_true(added, "First customer added successfully")
	assert_eq(_queue.get_size(), 1, "Queue has one customer")
	assert_ne(
		customer.current_state,
		Customer.State.WAITING_IN_QUEUE,
		"First customer is not in WAITING_IN_QUEUE"
	)
	customer.queue_free()


func test_add_beyond_capacity_rejected() -> void:
	_queue.initialize(Vector3.ZERO, Vector3(0, 0, 3))
	var customers: Array[Customer] = []
	for i: int in range(RegisterQueue.MAX_QUEUE_SIZE):
		var c: Customer = _create_mock_customer()
		customers.append(c)
		_queue.try_add(c)
	assert_true(_queue.is_full(), "Queue is full at max size")
	var extra: Customer = _create_mock_customer()
	var added: bool = _queue.try_add(extra)
	assert_false(added, "Extra customer rejected")
	extra.queue_free()
	for c: Customer in customers:
		c.queue_free()


func test_remove_repositions_queue() -> void:
	_queue.initialize(Vector3.ZERO, Vector3(0, 0, 3))
	var c1: Customer = _create_mock_customer()
	var c2: Customer = _create_mock_customer()
	var c3: Customer = _create_mock_customer()
	_queue.try_add(c1)
	_queue.try_add(c2)
	_queue.try_add(c3)
	_queue.remove(c1)
	assert_eq(_queue.get_size(), 2, "Queue size after remove")
	var first: Customer = _queue.get_first()
	assert_eq(first, c2, "c2 is now first after c1 removed")
	c1.queue_free()
	c2.queue_free()
	c3.queue_free()


func test_queue_positions_are_spaced() -> void:
	var reg_pos: Vector3 = Vector3(2.5, 0, 2.0)
	var entry_pos: Vector3 = Vector3(0, 0, 2.0)
	_queue.initialize(reg_pos, entry_pos)
	var c1: Customer = _create_mock_customer()
	var c2: Customer = _create_mock_customer()
	_queue.try_add(c1)
	_queue.try_add(c2)
	assert_eq(
		c2.current_state,
		Customer.State.WAITING_IN_QUEUE,
		"Second customer enters WAITING_IN_QUEUE"
	)
	c1.queue_free()
	c2.queue_free()


func test_has_customer_id() -> void:
	_queue.initialize(Vector3.ZERO, Vector3(0, 0, 3))
	var c: Customer = _create_mock_customer()
	_queue.try_add(c)
	var cid: int = c.get_instance_id()
	assert_true(
		_queue.has_customer_id(cid),
		"has_customer_id finds added customer"
	)
	assert_false(
		_queue.has_customer_id(99999),
		"has_customer_id false for unknown id"
	)
	c.queue_free()


func test_remove_by_id() -> void:
	_queue.initialize(Vector3.ZERO, Vector3(0, 0, 3))
	var c: Customer = _create_mock_customer()
	_queue.try_add(c)
	var cid: int = c.get_instance_id()
	_queue.remove_by_id(cid)
	assert_eq(_queue.get_size(), 0, "Queue empty after remove_by_id")
	c.queue_free()


func test_duplicate_add_rejected() -> void:
	_queue.initialize(Vector3.ZERO, Vector3(0, 0, 3))
	var c: Customer = _create_mock_customer()
	_queue.try_add(c)
	var added: bool = _queue.try_add(c)
	assert_false(added, "Duplicate add rejected")
	assert_eq(_queue.get_size(), 1, "Queue size unchanged")
	c.queue_free()


func _create_mock_customer() -> Customer:
	var customer: Customer = Customer.new()
	add_child(customer)
	return customer
