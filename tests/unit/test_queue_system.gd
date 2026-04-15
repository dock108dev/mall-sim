## Unit tests for QueueSystem — enqueue/dequeue FIFO, overflow guard, empty guard, and signals.
extends GutTest

const MAX_QUEUE_SIZE: int = 3

var _queue_system: QueueSystem
var _profile: CustomerTypeDefinition

var _queue_changed_sizes: Array[int] = []


func before_each() -> void:
	_queue_changed_sizes = []
	EventBus.queue_changed.connect(_on_queue_changed)

	_queue_system = QueueSystem.new()
	add_child_autofree(_queue_system)
	_queue_system.initialize()

	_profile = CustomerTypeDefinition.new()
	_profile.id = "test_customer"
	_profile.customer_name = "Test Customer"
	_profile.budget_range = [10.0, 200.0]
	_profile.patience = 0.8
	_profile.price_sensitivity = 0.5
	_profile.preferred_categories = PackedStringArray([])
	_profile.preferred_tags = PackedStringArray([])
	_profile.condition_preference = "good"
	_profile.browse_time_range = [30.0, 60.0]
	_profile.purchase_probability_base = 0.9
	_profile.impulse_buy_chance = 0.1
	_profile.mood_tags = PackedStringArray([])


func after_each() -> void:
	if EventBus.queue_changed.is_connected(_on_queue_changed):
		EventBus.queue_changed.disconnect(_on_queue_changed)


func _on_queue_changed(queue_size: int) -> void:
	_queue_changed_sizes.append(queue_size)


func _make_customer() -> Customer:
	var customer: Customer = Customer.new()
	add_child_autofree(customer)
	customer.profile = _profile
	return customer


# --- Initial state ---


func test_initial_queue_size_is_zero() -> void:
	assert_eq(
		_queue_system.get_queue_size(), 0,
		"Queue should be empty on initialization"
	)


# --- Enqueue ---


func test_enqueue_increments_size() -> void:
	var customer: Customer = _make_customer()
	_queue_system.enqueue_customer(customer)
	assert_eq(
		_queue_system.get_queue_size(), 1,
		"Size should be 1 after enqueueing one customer"
	)


func test_enqueue_returns_true_on_success() -> void:
	var customer: Customer = _make_customer()
	var result: bool = _queue_system.enqueue_customer(customer)
	assert_true(result, "enqueue_customer should return true on success")


func test_peek_returns_enqueued_customer() -> void:
	var customer: Customer = _make_customer()
	_queue_system.enqueue_customer(customer)
	assert_eq(
		_queue_system._register_queue.get_first(), customer,
		"get_first() should return the enqueued customer"
	)


# --- FIFO ordering ---


func test_fifo_ordering_two_customers() -> void:
	var customer_a: Customer = _make_customer()
	var customer_b: Customer = _make_customer()
	_queue_system.enqueue_customer(customer_a)
	_queue_system.enqueue_customer(customer_b)
	var first: Node = _queue_system.dequeue_customer()
	var second: Node = _queue_system.dequeue_customer()
	assert_eq(first, customer_a, "First dequeue should return customer A")
	assert_eq(second, customer_b, "Second dequeue should return customer B")


func test_fifo_size_decrements_after_dequeue() -> void:
	var customer_a: Customer = _make_customer()
	var customer_b: Customer = _make_customer()
	_queue_system.enqueue_customer(customer_a)
	_queue_system.enqueue_customer(customer_b)
	_queue_system.dequeue_customer()
	assert_eq(
		_queue_system.get_queue_size(), 1,
		"Size should be 1 after dequeueing one of two customers"
	)


# --- Empty dequeue guard ---


func test_dequeue_empty_queue_returns_null() -> void:
	var result: Node = _queue_system.dequeue_customer()
	assert_null(result, "dequeue_customer on empty queue should return null")


func test_dequeue_empty_queue_does_not_crash() -> void:
	# Calling dequeue on empty queue must complete without raising an error.
	_queue_system.dequeue_customer()
	assert_true(true, "dequeue_customer on empty queue should not crash")


# --- Overflow guard ---


func test_overflow_rejected_at_max_capacity() -> void:
	for _i: int in range(MAX_QUEUE_SIZE):
		_queue_system.enqueue_customer(_make_customer())
	var extra: Customer = _make_customer()
	var result: bool = _queue_system.enqueue_customer(extra)
	assert_false(result, "enqueue_customer should return false when queue is full")
	assert_eq(
		_queue_system.get_queue_size(), MAX_QUEUE_SIZE,
		"Size should remain at MAX_QUEUE_SIZE after overflow attempt"
	)


# --- EventBus signal integration ---


func test_customer_reached_checkout_triggers_enqueue() -> void:
	var customer: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(customer)
	assert_eq(
		_queue_system.get_queue_size(), 1,
		"customer_reached_checkout should cause QueueSystem to enqueue the customer"
	)


func test_customer_reached_checkout_emits_queue_changed() -> void:
	var customer: Customer = _make_customer()
	_queue_changed_sizes.clear()
	EventBus.customer_reached_checkout.emit(customer)
	assert_true(
		_queue_changed_sizes.size() > 0,
		"queue_changed should be emitted after customer_reached_checkout"
	)
	assert_eq(
		_queue_changed_sizes[-1], 1,
		"queue_changed should carry size of 1 after first enqueue"
	)


func test_dequeue_emits_queue_changed() -> void:
	var customer: Customer = _make_customer()
	_queue_system.enqueue_customer(customer)
	_queue_changed_sizes.clear()
	_queue_system.dequeue_customer()
	assert_true(
		_queue_changed_sizes.size() > 0,
		"queue_changed should be emitted after dequeue"
	)
	assert_eq(
		_queue_changed_sizes[-1], 0,
		"queue_changed should carry updated size of 0 after dequeue"
	)


# --- Clear via store exit ---


func test_store_exited_clears_queue() -> void:
	for _i: int in range(2):
		_queue_system.enqueue_customer(_make_customer())
	assert_eq(
		_queue_system.get_queue_size(), 2,
		"Queue should have 2 customers before store exit"
	)
	EventBus.store_exited.emit(&"test_store")
	assert_eq(
		_queue_system.get_queue_size(), 0,
		"Queue should be empty after store_exited signal"
	)


func test_store_exited_emits_queue_changed_with_zero() -> void:
	_queue_system.enqueue_customer(_make_customer())
	_queue_changed_sizes.clear()
	EventBus.store_exited.emit(&"test_store")
	assert_true(
		_queue_changed_sizes.size() > 0,
		"queue_changed should be emitted after store_exited"
	)
	assert_eq(
		_queue_changed_sizes[-1], 0,
		"queue_changed should carry 0 after store_exited clears the queue"
	)


func test_peek_returns_null_after_clear() -> void:
	_queue_system.enqueue_customer(_make_customer())
	EventBus.store_exited.emit(&"test_store")
	assert_null(
		_queue_system._register_queue.get_first(),
		"get_first() should return null after queue is cleared"
	)
