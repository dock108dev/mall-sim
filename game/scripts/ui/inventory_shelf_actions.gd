## Shelf placement and removal actions used by the InventoryPanel.
class_name InventoryShelfActions
extends RefCounted

var inventory_system: InventorySystem
var is_placement_mode: bool = false


func enter_placement_mode() -> void:
	if is_placement_mode:
		return
	is_placement_mode = true
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	EventBus.placement_mode_entered.emit()


func exit_placement_mode() -> void:
	if not is_placement_mode:
		return
	is_placement_mode = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	EventBus.placement_mode_exited.emit()


func place_item(
	item: ItemInstance, slot: ShelfSlot
) -> bool:
	if not item or not inventory_system:
		return false
	if slot.is_occupied():
		EventBus.notification_requested.emit(
			tr("INVENTORY_SLOT_OCCUPIED")
		)
		return false
	if item.current_location != "backroom":
		EventBus.notification_requested.emit(
			tr("INVENTORY_NOT_IN_LOCATION") % "backroom"
		)
		return false
	inventory_system.move_item(
		item.instance_id, "shelf:%s" % slot.slot_id
	)
	var category: String = ""
	if item.definition:
		category = item.definition.category
	slot.place_item(item.instance_id, category)
	EventBus.item_stocked.emit(item.instance_id, slot.slot_id)
	exit_placement_mode()
	return true


func remove_item_from_shelf(slot: ShelfSlot) -> void:
	if not inventory_system:
		return
	var item_id: String = slot.get_item_instance_id()
	if item_id.is_empty():
		return
	slot.remove_item()
	inventory_system.move_item(item_id, "backroom")
	EventBus.item_removed_from_shelf.emit(item_id, slot.slot_id)
	EventBus.notification_requested.emit(tr("INVENTORY_RETURNED"))


func move_to_backroom(item: ItemInstance) -> void:
	if not item or not inventory_system:
		return
	if not item.current_location.begins_with("shelf:"):
		return
	var shelf_id: String = item.current_location.substr(6)
	inventory_system.move_item(item.instance_id, "backroom")
	EventBus.item_removed_from_shelf.emit(
		item.instance_id, shelf_id
	)
