## GUT tests for deferred store entry handling in StoreController.
extends GutTest


class TestStoreController:
	extends StoreController

	var enter_calls: Array[StringName] = []
	var inventory_was_wired_on_enter: bool = false

	func _ready() -> void:
		store_type = "test_store"
		super._ready()

	func _on_store_entered(store_id: StringName) -> void:
		inventory_was_wired_on_enter = _inventory_system != null
		enter_calls.append(store_id)


var _controller: TestStoreController
var _immediate_calls: Array[StringName] = []
var _inventory_system: InventorySystem


func before_each() -> void:
	_controller = TestStoreController.new()
	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	add_child_autofree(_controller)
	_immediate_calls.clear()
	EventBus.store_entered.connect(_on_store_entered_immediately)


func after_each() -> void:
	if EventBus.store_entered.is_connected(_on_store_entered_immediately):
		EventBus.store_entered.disconnect(_on_store_entered_immediately)


func test_store_entered_is_deferred_until_next_frame() -> void:
	EventBus.store_entered.emit(&"test_store")

	assert_eq(
		_immediate_calls, [&"test_store"],
		"Immediate listeners should run in the emitting frame"
	)
	assert_eq(
		_controller.enter_calls.size(), 0,
		"StoreController entry handlers should wait for deferred wiring"
	)

	await get_tree().process_frame

	assert_eq(
		_controller.enter_calls, [&"test_store"],
		"Deferred store entry should run on the next frame"
	)
	assert_true(
		_controller.inventory_was_wired_on_enter,
		"Deferred store entry should run after GameWorld-style dependency wiring"
	)


func _on_store_entered_immediately(store_id: StringName) -> void:
	_immediate_calls.append(store_id)
	_controller.set_inventory_system(_inventory_system)
