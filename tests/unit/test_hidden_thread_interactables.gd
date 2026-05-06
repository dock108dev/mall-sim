## Unit tests for the seven hidden-thread Interactable subclasses.
##
## Each thin script extends Interactable and emits its respective EventBus
## signal on `interact()`. Tests verify the signal fires with the expected
## payload shape and that the description toast is requested.
extends GutTest


func before_each() -> void:
	var hidden: HiddenThreadSystem = (
		Engine.get_main_loop().root.get_node("HiddenThreadSystemSingleton")
		as HiddenThreadSystem
	)
	hidden.reset()


func _add_to_tree(node: Interactable) -> void:
	node.store_id = &"retro_games"
	add_child_autofree(node)
	# Allow _ready to run.
	await get_tree().process_frame


func test_hold_shelf_interactable_emits_signal_on_interact() -> void:
	var node := HoldShelfInteractable.new()
	await _add_to_tree(node)
	watch_signals(EventBus)
	node.interact()
	assert_signal_emit_count(EventBus, "hold_shelf_inspected", 1)


func test_warranty_binder_interactable_emits_signal_on_interact() -> void:
	var node := WarrantyBinderInteractable.new()
	await _add_to_tree(node)
	watch_signals(EventBus)
	node.interact()
	assert_signal_emit_count(EventBus, "warranty_binder_examined", 1)


func test_backordered_console_interactable_emits_signal_on_interact() -> void:
	var node := BackorderedConsoleInteractable.new()
	node.item_id = &"sku_x"
	node.backorder_start_day = 1
	await _add_to_tree(node)
	watch_signals(EventBus)
	node.interact()
	assert_signal_emit_count(EventBus, "backordered_item_examined", 1)
	var params: Array = get_signal_parameters(
		EventBus, "backordered_item_examined", 0
	)
	assert_eq(StringName(params[1]), &"sku_x")


func test_register_note_interactable_emits_signal_on_interact() -> void:
	var node := RegisterNoteInteractable.new()
	await _add_to_tree(node)
	watch_signals(EventBus)
	node.interact()
	assert_signal_emit_count(EventBus, "register_note_examined", 1)


func test_security_flyer_interactable_emits_signal_on_interact() -> void:
	var node := SecurityFlyerInteractable.new()
	await _add_to_tree(node)
	watch_signals(EventBus)
	node.interact()
	assert_signal_emit_count(EventBus, "security_flyer_examined", 1)


func test_returned_item_interactable_emits_signal_on_interact() -> void:
	var node := ReturnedItemInteractable.new()
	node.item_id = &"sku_camera"
	await _add_to_tree(node)
	watch_signals(EventBus)
	node.interact()
	assert_signal_emit_count(EventBus, "returned_item_examined", 1)
	var params: Array = get_signal_parameters(
		EventBus, "returned_item_examined", 0
	)
	assert_eq(StringName(params[1]), &"sku_camera")


func test_employee_schedule_interactable_emits_signal_on_interact() -> void:
	var node := EmployeeScheduleInteractable.new()
	await _add_to_tree(node)
	watch_signals(EventBus)
	node.interact()
	assert_signal_emit_count(EventBus, "employee_schedule_examined", 1)


func test_each_interactable_requests_a_notification_toast() -> void:
	var node := WarrantyBinderInteractable.new()
	await _add_to_tree(node)
	watch_signals(EventBus)
	node.interact()
	assert_signal_emit_count(EventBus, "notification_requested", 1)


func test_disabled_interactable_does_not_emit() -> void:
	var node := WarrantyBinderInteractable.new()
	node.enabled = false
	await _add_to_tree(node)
	watch_signals(EventBus)
	node.interact()
	assert_signal_emit_count(EventBus, "warranty_binder_examined", 0)
