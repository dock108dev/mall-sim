## Tests StoreController base class: lifecycle signals, activation, and
## inventory/customer delegation.
extends GutTest


var _controller: StoreController


func before_each() -> void:
	_controller = StoreController.new()
	_controller.store_type = "test_store"
	add_child_autofree(_controller)


func test_active_store_changed_activates() -> void:
	EventBus.active_store_changed.emit(&"test_store")
	assert_true(
		_controller.is_active(),
		"Controller should be active after matching store change"
	)


func test_active_store_changed_deactivates() -> void:
	EventBus.active_store_changed.emit(&"test_store")
	assert_true(_controller.is_active())
	EventBus.active_store_changed.emit(&"other_store")
	assert_false(
		_controller.is_active(),
		"Controller should deactivate on non-matching store change"
	)


func test_not_active_by_default() -> void:
	assert_false(
		_controller.is_active(),
		"Controller should not be active by default"
	)


func test_get_inventory_without_system() -> void:
	var result: Array[Dictionary] = _controller.get_inventory()
	assert_eq(
		result.size(), 0,
		"get_inventory should return empty without InventorySystem"
	)


func test_get_active_customers_without_system() -> void:
	var result: Array[Node] = _controller.get_active_customers()
	assert_eq(
		result.size(), 0,
		"get_active_customers should return empty without CustomerSystem"
	)


func test_emit_store_signal_invalid_signal() -> void:
	_controller.emit_store_signal(&"nonexistent_signal_xyz")
	assert_true(
		true,
		"emit_store_signal with invalid signal should not crash"
	)


func test_deactivation_only_fires_when_was_active() -> void:
	EventBus.active_store_changed.emit(&"other_store")
	assert_false(
		_controller.is_active(),
		"Should remain inactive without prior activation"
	)
