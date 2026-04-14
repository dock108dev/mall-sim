## Tests QueueSystem wiring: enqueue on customer_reached_checkout, dispatch
## via checkout_queue_ready, flush on store_exited, checkout_completed cycle,
## dequeue_customer, get_queue_position, wait-time abandonment, and
## active_store_changed flush.
extends GutTest


var _queue_system: QueueSystem
var _customer_scene: PackedScene
var _checkout_ready_signals: Array[Node] = []
var _customer_left_signals: Array[Dictionary] = []
var _queue_advanced_signals: Array[int] = []
var _queue_changed_signals: Array[int] = []
var _abandoned_signals: Array[Node] = []


func before_each() -> void:
	_customer_scene = preload(
		"res://game/scenes/characters/customer.tscn"
	)
	_queue_system = QueueSystem.new()
	add_child_autofree(_queue_system)
	_queue_system.initialize()
	_queue_system.setup_queue_positions(
		Vector3.ZERO, Vector3(0.0, 0.0, 5.0)
	)

	_checkout_ready_signals = []
	_customer_left_signals = []
	_queue_advanced_signals = []
	_queue_changed_signals = []
	_abandoned_signals = []

	EventBus.checkout_queue_ready.connect(_on_checkout_queue_ready)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.queue_advanced.connect(_on_queue_advanced)
	EventBus.queue_changed.connect(_on_queue_changed)
	EventBus.customer_abandoned_queue.connect(_on_customer_abandoned)


func after_each() -> void:
	_safe_disconnect(
		EventBus.checkout_queue_ready, _on_checkout_queue_ready
	)
	_safe_disconnect(EventBus.customer_left, _on_customer_left)
	_safe_disconnect(EventBus.queue_advanced, _on_queue_advanced)
	_safe_disconnect(EventBus.queue_changed, _on_queue_changed)
	_safe_disconnect(
		EventBus.customer_abandoned_queue, _on_customer_abandoned
	)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _make_customer() -> Customer:
	var customer: Customer = _customer_scene.instantiate()
	add_child_autofree(customer)
	return customer


func _make_customer_with_patience(patience: float) -> Customer:
	var customer: Customer = _make_customer()
	var prof: CustomerTypeDefinition = CustomerTypeDefinition.new()
	prof.patience = patience
	customer.profile = prof
	return customer


func _on_checkout_queue_ready(customer: Node) -> void:
	_checkout_ready_signals.append(customer)


func _on_customer_left(customer_data: Dictionary) -> void:
	_customer_left_signals.append(customer_data)


func _on_queue_advanced(queue_size: int) -> void:
	_queue_advanced_signals.append(queue_size)


func _on_queue_changed(queue_size: int) -> void:
	_queue_changed_signals.append(queue_size)


func _on_customer_abandoned(customer: Node) -> void:
	_abandoned_signals.append(customer)


# --- enqueue_customer on customer_reached_checkout ---


func test_enqueue_called_on_customer_reached_checkout() -> void:
	var customer: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(customer)
	assert_eq(
		_queue_system.get_queue_size(), 1,
		"Queue should have 1 customer after reached_checkout"
	)


func test_checkout_queue_ready_emitted_for_first_customer() -> void:
	var customer: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(customer)
	assert_eq(
		_checkout_ready_signals.size(), 1,
		"checkout_queue_ready should fire for first customer"
	)
	assert_eq(
		_checkout_ready_signals[0], customer,
		"checkout_queue_ready should carry the enqueued customer"
	)


func test_second_customer_waits_while_first_processing() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(c1)
	EventBus.customer_reached_checkout.emit(c2)
	assert_eq(
		_checkout_ready_signals.size(), 1,
		"Only first customer should trigger checkout_queue_ready"
	)
	assert_eq(
		_queue_system.get_queue_size(), 2,
		"Both customers should be in the queue"
	)


# --- queue_changed signal ---


func test_enqueue_emits_queue_changed() -> void:
	var customer: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(customer)
	assert_true(
		_queue_changed_signals.size() > 0,
		"queue_changed should fire on enqueue"
	)
	assert_eq(
		_queue_changed_signals[0], 1,
		"queue_changed should report size 1"
	)


# --- dequeue_customer ---


func test_dequeue_customer_returns_front() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	_queue_system.enqueue_customer(c1)
	_queue_system.enqueue_customer(c2)
	var front: Node = _queue_system.dequeue_customer()
	assert_eq(front, c1, "dequeue_customer should return front customer")
	assert_eq(
		_queue_system.get_queue_size(), 1,
		"Queue size should be 1 after dequeue"
	)


func test_dequeue_customer_emits_queue_changed() -> void:
	var customer: Customer = _make_customer()
	_queue_system.enqueue_customer(customer)
	_queue_changed_signals.clear()
	_queue_system.dequeue_customer()
	assert_true(
		_queue_changed_signals.size() > 0,
		"queue_changed should fire on dequeue"
	)
	assert_eq(
		_queue_changed_signals[0], 0,
		"queue_changed should report 0 after dequeue"
	)


func test_dequeue_empty_queue_returns_null() -> void:
	var result: Node = _queue_system.dequeue_customer()
	assert_null(
		result,
		"dequeue_customer on empty queue should return null"
	)


# --- get_queue_position ---


func test_get_queue_position_returns_zero_with_no_markers() -> void:
	var pos: Vector3 = _queue_system.get_queue_position(0)
	assert_eq(
		pos, Vector3.ZERO,
		"get_queue_position should return ZERO when no markers"
	)


func test_get_queue_position_returns_zero_for_invalid_index() -> void:
	var pos: Vector3 = _queue_system.get_queue_position(-1)
	assert_eq(
		pos, Vector3.ZERO,
		"get_queue_position should return ZERO for negative index"
	)


func test_get_queue_position_with_markers() -> void:
	var marker: Marker3D = Marker3D.new()
	marker.position = Vector3(5.0, 0.0, 3.0)
	add_child_autofree(marker)
	_queue_system.bind_queue_markers([marker])
	var pos: Vector3 = _queue_system.get_queue_position(0)
	assert_eq(
		pos, marker.global_position,
		"get_queue_position should return marker global position"
	)


# --- checkout_completed advances queue ---


func test_checkout_completed_dispatches_next() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(c1)
	EventBus.customer_reached_checkout.emit(c2)
	assert_eq(_checkout_ready_signals.size(), 1)
	EventBus.checkout_completed.emit(c1)
	assert_eq(
		_checkout_ready_signals.size(), 2,
		"checkout_queue_ready should fire for second customer"
	)
	assert_eq(
		_checkout_ready_signals[1], c2,
		"Second dispatch should carry the second customer"
	)


func test_checkout_completed_emits_queue_changed() -> void:
	var customer: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(customer)
	_queue_changed_signals.clear()
	EventBus.checkout_completed.emit(customer)
	assert_true(
		_queue_changed_signals.size() > 0,
		"queue_changed should fire after checkout_completed"
	)
	assert_eq(
		_queue_changed_signals[0], 0,
		"Queue should be empty after last customer completes"
	)


func test_checkout_completed_emits_queue_advanced() -> void:
	var customer: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(customer)
	EventBus.checkout_completed.emit(customer)
	assert_true(
		_queue_advanced_signals.size() > 0,
		"queue_advanced should fire after checkout_completed"
	)
	assert_eq(
		_queue_advanced_signals.back(), 0,
		"Queue should be empty after last customer completes"
	)


# --- FIFO order ---


func test_customers_dispatched_in_fifo_order() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	var c3: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(c1)
	EventBus.customer_reached_checkout.emit(c2)
	EventBus.customer_reached_checkout.emit(c3)
	assert_eq(_checkout_ready_signals[0], c1)
	EventBus.checkout_completed.emit(c1)
	assert_eq(_checkout_ready_signals[1], c2)
	EventBus.checkout_completed.emit(c2)
	assert_eq(_checkout_ready_signals[2], c3)


# --- Store exit flush ---


func test_store_exited_flushes_queue() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(c1)
	EventBus.customer_reached_checkout.emit(c2)
	EventBus.store_exited.emit(&"test_store")
	assert_eq(
		_queue_system.get_queue_size(), 0,
		"Queue should be empty after store_exited"
	)


func test_store_exited_emits_customer_left_for_pending() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(c1)
	EventBus.customer_reached_checkout.emit(c2)
	EventBus.store_exited.emit(&"test_store")
	assert_eq(
		_customer_left_signals.size(), 2,
		"customer_left should fire for each pending customer"
	)


func test_store_exited_emits_queue_changed_zero() -> void:
	var customer: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(customer)
	_queue_changed_signals.clear()
	EventBus.store_exited.emit(&"test_store")
	assert_true(
		_queue_changed_signals.has(0),
		"queue_changed(0) should fire after flush"
	)


func test_store_exited_emits_queue_advanced_zero() -> void:
	var customer: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(customer)
	_queue_advanced_signals.clear()
	EventBus.store_exited.emit(&"test_store")
	assert_true(
		_queue_advanced_signals.has(0),
		"queue_advanced(0) should fire after flush"
	)


# --- active_store_changed flush ---


func test_active_store_changed_flushes_queue() -> void:
	var c1: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(c1)
	EventBus.active_store_changed.emit(&"new_store")
	assert_eq(
		_queue_system.get_queue_size(), 0,
		"Queue should be empty after active_store_changed"
	)


func test_active_store_changed_emits_customer_left() -> void:
	var c1: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(c1)
	EventBus.active_store_changed.emit(&"new_store")
	assert_eq(
		_customer_left_signals.size(), 1,
		"customer_left should fire for pending customer"
	)


# --- Queue capacity ---


func test_fourth_customer_rejected_at_capacity() -> void:
	var c1: Customer = _make_customer()
	var c2: Customer = _make_customer()
	var c3: Customer = _make_customer()
	var c4: Customer = _make_customer()
	EventBus.customer_reached_checkout.emit(c1)
	EventBus.customer_reached_checkout.emit(c2)
	EventBus.customer_reached_checkout.emit(c3)
	var added: bool = _queue_system.enqueue_customer(c4)
	assert_false(
		added,
		"Fourth customer should be rejected at capacity"
	)


# --- Wait time abandonment ---


func test_customer_abandoned_after_patience_exceeded() -> void:
	var customer: Customer = _make_customer_with_patience(0.001)
	_queue_system.enqueue_customer(customer)
	var limit: float = 0.001 * QueueSystem.MAX_PATIENCE_MINUTES
	_queue_system._process(limit + 0.1)
	assert_eq(
		_abandoned_signals.size(), 1,
		"customer_abandoned_queue should fire"
	)
	assert_eq(
		_abandoned_signals[0], customer,
		"Abandoned signal should carry the customer"
	)
	assert_eq(
		_queue_system.get_queue_size(), 0,
		"Customer should be removed from queue"
	)


func test_patient_customer_stays_in_queue() -> void:
	var customer: Customer = _make_customer_with_patience(1.0)
	_queue_system.enqueue_customer(customer)
	_queue_system._process(1.0)
	assert_eq(
		_abandoned_signals.size(), 0,
		"Patient customer should not be abandoned"
	)
	assert_eq(
		_queue_system.get_queue_size(), 1,
		"Patient customer should remain in queue"
	)
