## Verifies RegisterQueue ordering, capacity, and position calculation.
extends Node3D

var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	_test_initialize()
	_test_add_first_customer_stays_purchasing()
	_test_add_beyond_capacity_rejected()
	_test_remove_repositions_queue()
	_test_queue_positions_are_spaced()
	_test_has_customer_id()
	_test_remove_by_id()
	_test_duplicate_add_rejected()
	_print_summary()


func _test_initialize() -> void:
	var queue: RegisterQueue = RegisterQueue.new()
	queue.initialize(Vector3(2.5, 0, 2.0), Vector3(0, 0, 2.5))
	_assert_equal(queue.get_size(), 0, "Queue starts empty")
	_assert_true(not queue.is_full(), "Queue is not full when empty")


func _test_add_first_customer_stays_purchasing() -> void:
	var queue: RegisterQueue = RegisterQueue.new()
	queue.initialize(Vector3(2.5, 0, 2.0), Vector3(0, 0, 2.5))
	var customer: Customer = _create_mock_customer()
	var added: bool = queue.try_add(customer)
	_assert_true(added, "First customer added successfully")
	_assert_equal(queue.get_size(), 1, "Queue has one customer")
	_assert_true(
		customer.current_state != Customer.State.WAITING_IN_QUEUE,
		"First customer is not in WAITING_IN_QUEUE"
	)
	customer.queue_free()


func _test_add_beyond_capacity_rejected() -> void:
	var queue: RegisterQueue = RegisterQueue.new()
	queue.initialize(Vector3.ZERO, Vector3(0, 0, 3))
	var customers: Array[Customer] = []
	for i: int in range(RegisterQueue.MAX_QUEUE_SIZE):
		var c: Customer = _create_mock_customer()
		customers.append(c)
		queue.try_add(c)
	_assert_true(queue.is_full(), "Queue is full at max size")
	var extra: Customer = _create_mock_customer()
	var added: bool = queue.try_add(extra)
	_assert_true(not added, "Fourth customer rejected")
	extra.queue_free()
	for c: Customer in customers:
		c.queue_free()


func _test_remove_repositions_queue() -> void:
	var queue: RegisterQueue = RegisterQueue.new()
	queue.initialize(Vector3.ZERO, Vector3(0, 0, 3))
	var c1: Customer = _create_mock_customer()
	var c2: Customer = _create_mock_customer()
	var c3: Customer = _create_mock_customer()
	queue.try_add(c1)
	queue.try_add(c2)
	queue.try_add(c3)
	queue.remove(c1)
	_assert_equal(queue.get_size(), 2, "Queue size after remove")
	var first: Customer = queue.get_first()
	_assert_true(
		first == c2, "c2 is now first after c1 removed"
	)
	c1.queue_free()
	c2.queue_free()
	c3.queue_free()


func _test_queue_positions_are_spaced() -> void:
	var reg_pos: Vector3 = Vector3(2.5, 0, 2.0)
	var entry_pos: Vector3 = Vector3(0, 0, 2.0)
	var queue: RegisterQueue = RegisterQueue.new()
	queue.initialize(reg_pos, entry_pos)
	var c1: Customer = _create_mock_customer()
	var c2: Customer = _create_mock_customer()
	queue.try_add(c1)
	queue.try_add(c2)
	_assert_true(
		c2.current_state == Customer.State.WAITING_IN_QUEUE,
		"Second customer enters WAITING_IN_QUEUE"
	)
	c1.queue_free()
	c2.queue_free()


func _test_has_customer_id() -> void:
	var queue: RegisterQueue = RegisterQueue.new()
	queue.initialize(Vector3.ZERO, Vector3(0, 0, 3))
	var c: Customer = _create_mock_customer()
	queue.try_add(c)
	var cid: int = c.get_instance_id()
	_assert_true(
		queue.has_customer_id(cid),
		"has_customer_id finds added customer"
	)
	_assert_true(
		not queue.has_customer_id(99999),
		"has_customer_id false for unknown id"
	)
	c.queue_free()


func _test_remove_by_id() -> void:
	var queue: RegisterQueue = RegisterQueue.new()
	queue.initialize(Vector3.ZERO, Vector3(0, 0, 3))
	var c: Customer = _create_mock_customer()
	queue.try_add(c)
	var cid: int = c.get_instance_id()
	queue.remove_by_id(cid)
	_assert_equal(queue.get_size(), 0, "Queue empty after remove_by_id")
	c.queue_free()


func _test_duplicate_add_rejected() -> void:
	var queue: RegisterQueue = RegisterQueue.new()
	queue.initialize(Vector3.ZERO, Vector3(0, 0, 3))
	var c: Customer = _create_mock_customer()
	queue.try_add(c)
	var added: bool = queue.try_add(c)
	_assert_true(not added, "Duplicate add rejected")
	_assert_equal(queue.get_size(), 1, "Queue size unchanged")
	c.queue_free()


func _create_mock_customer() -> Customer:
	var scene: PackedScene = load(
		"res://game/scenes/characters/customer.tscn"
	) as PackedScene
	var customer: Customer = scene.instantiate() as Customer
	add_child(customer)
	return customer


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error("FAIL: %s" % label)


func _assert_equal(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		_tests_passed += 1
	else:
		_tests_failed += 1
		push_error(
			"FAIL: %s (expected %d, got %d)"
			% [label, expected, actual]
		)


func _print_summary() -> void:
	var total: int = _tests_passed + _tests_failed
	if _tests_failed == 0:
		push_warning(
			"QUEUE TEST: All %d tests passed" % total
		)
	else:
		push_error(
			"QUEUE TEST: %d/%d tests failed"
			% [_tests_failed, total]
		)
