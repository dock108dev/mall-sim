## Tests RegisterQueue enqueue, dequeue, capacity, advancement, and reset.
extends GutTest


var _queue: RegisterQueue
var _customer_scene: PackedScene


func before_each() -> void:
	_customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)
	_queue = RegisterQueue.new()
	_queue.initialize(Vector3.ZERO, Vector3(0.0, 0.0, 5.0))


func _make_customer() -> Customer:
	var customer: Customer = _customer_scene.instantiate()
	add_child_autofree(customer)
	return customer


# --- Enqueue ---


func test_enqueue_returns_true_on_success() -> void:
	var customer: Customer = _make_customer()
	var result: bool = _queue.try_add(customer)
	assert_true(result, "try_add should return true for first customer")


func test_enqueue_places_customer_at_back() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	_queue.try_add(c1)
	_queue.try_add(c2)
	assert_eq(
		_queue.get_first(), c1,
		"First enqueued customer should be at front"
	)
	assert_eq(
		_queue.get_size(), 2,
		"Queue should contain both customers"
	)


# --- Dequeue / FIFO ---


func test_dequeue_returns_front_customer_fifo() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	var c3: Customer = _make_customer()
	_queue.try_add(c1)
	_queue.try_add(c2)
	_queue.try_add(c3)
	assert_eq(
		_queue.get_first(), c1,
		"First dequeue should return first enqueued customer"
	)
	_queue.advance()
	assert_eq(
		_queue.get_first(), c2,
		"After advance, second customer should be at front"
	)
	_queue.advance()
	assert_eq(
		_queue.get_first(), c3,
		"After two advances, third customer should be at front"
	)


# --- Capacity ---


func test_enqueue_refuses_when_at_max_capacity() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	var c3: Customer = _make_customer()
	var c4: Customer = _make_customer()
	_queue.try_add(c1)
	_queue.try_add(c2)
	_queue.try_add(c3)
	var result: bool = _queue.try_add(c4)
	assert_false(
		result,
		"try_add should return false when queue is at max capacity"
	)
	assert_eq(
		_queue.get_size(), RegisterQueue.MAX_QUEUE_SIZE,
		"Queue size should remain at MAX_QUEUE_SIZE"
	)


func test_is_full_at_capacity() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	var c3: Customer = _make_customer()
	_queue.try_add(c1)
	_queue.try_add(c2)
	assert_false(_queue.is_full(), "Queue should not be full with 2")
	_queue.try_add(c3)
	assert_true(
		_queue.is_full(),
		"Queue should be full at MAX_QUEUE_SIZE"
	)


func test_duplicate_customer_rejected() -> void:
	var customer: Customer = _make_customer()
	_queue.try_add(customer)
	var result: bool = _queue.try_add(customer)
	assert_false(
		result,
		"try_add should reject duplicate customer"
	)
	assert_eq(
		_queue.get_size(), 1,
		"Queue should still have 1 after duplicate attempt"
	)


# --- Advance ---


func test_advance_removes_front_and_promotes_next() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	var c3: Customer = _make_customer()
	_queue.try_add(c1)
	_queue.try_add(c2)
	_queue.try_add(c3)
	_queue.advance()
	assert_eq(
		_queue.get_size(), 2,
		"Queue should have 2 after one advance"
	)
	assert_eq(
		_queue.get_first(), c2,
		"Second customer should now be at front"
	)
	assert_false(
		_queue.has_customer(c1),
		"Removed customer should no longer be in queue"
	)


func test_advance_on_empty_queue_is_safe() -> void:
	_queue.advance()
	assert_eq(
		_queue.get_size(), 0,
		"Advancing empty queue should leave size at 0"
	)


# --- Empty dequeue ---


func test_get_first_on_empty_queue_returns_null() -> void:
	var result: Customer = _queue.get_first()
	assert_null(
		result,
		"get_first on empty queue should return null"
	)


# --- Queue length tracking ---


func test_size_after_enqueue_dequeue_series() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	var c3: Customer = _make_customer()
	assert_eq(_queue.get_size(), 0, "Initial size should be 0")
	_queue.try_add(c1)
	assert_eq(_queue.get_size(), 1, "Size after 1 enqueue")
	_queue.try_add(c2)
	assert_eq(_queue.get_size(), 2, "Size after 2 enqueues")
	_queue.try_add(c3)
	assert_eq(_queue.get_size(), 3, "Size after 3 enqueues")
	_queue.advance()
	assert_eq(_queue.get_size(), 2, "Size after 1 advance")
	_queue.advance()
	assert_eq(_queue.get_size(), 1, "Size after 2 advances")
	_queue.advance()
	assert_eq(_queue.get_size(), 0, "Size after all advanced")


# --- Reset / Clear ---


func test_clear_removes_all_customers() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	var c3: Customer = _make_customer()
	_queue.try_add(c1)
	_queue.try_add(c2)
	_queue.try_add(c3)
	_queue.clear()
	assert_eq(
		_queue.get_size(), 0,
		"Queue should be empty after clear"
	)
	assert_null(
		_queue.get_first(),
		"get_first should return null after clear"
	)
	assert_false(
		_queue.is_full(),
		"Queue should not be full after clear"
	)


# --- Remove by reference ---


func test_remove_specific_customer() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	var c3: Customer = _make_customer()
	_queue.try_add(c1)
	_queue.try_add(c2)
	_queue.try_add(c3)
	_queue.remove(c2)
	assert_eq(_queue.get_size(), 2, "Size after removing middle")
	assert_false(
		_queue.has_customer(c2),
		"Removed customer should not be in queue"
	)
	assert_eq(
		_queue.get_first(), c1,
		"Front should still be first customer"
	)


func test_remove_nonexistent_customer_is_safe() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	_queue.try_add(c1)
	_queue.remove(c2)
	assert_eq(
		_queue.get_size(), 1,
		"Size should not change when removing nonexistent customer"
	)


# --- Re-enqueue after capacity frees ---


func test_enqueue_succeeds_after_advance_frees_capacity() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	var c3: Customer = _make_customer()
	var c4: Customer = _make_customer()
	_queue.try_add(c1)
	_queue.try_add(c2)
	_queue.try_add(c3)
	assert_true(_queue.is_full(), "Queue should be full")
	_queue.advance()
	var result: bool = _queue.try_add(c4)
	assert_true(
		result,
		"try_add should succeed after advancing frees a slot"
	)
	assert_eq(_queue.get_size(), 3, "Queue should be full again")
