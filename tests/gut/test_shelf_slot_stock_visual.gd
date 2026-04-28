## Tests for signal-driven ShelfSlot visual updates wired in StoreController.
## Verifies that item_stocked shows a 3D mesh on the slot and
## item_removed_from_shelf clears it — covering customer-purchase and
## move-to-backroom removal paths that bypass InventoryShelfActions.
extends GutTest


func _make_controller_with_slot(slot_id: String) -> Array:
	var controller := StoreController.new()
	var fixture := Node.new()
	fixture.add_to_group("fixture")
	controller.add_child(fixture)
	var slot := ShelfSlot.new()
	slot.slot_id = slot_id
	fixture.add_child(slot)
	add_child_autofree(controller)
	return [controller, slot]


func test_item_stocked_signal_occupies_slot() -> void:
	var pair: Array = _make_controller_with_slot("vis_slot_01")
	var slot := pair[1] as ShelfSlot

	EventBus.item_stocked.emit("inst_vis_01", "vis_slot_01")

	assert_true(
		slot.is_occupied(),
		"Slot must be occupied after item_stocked fires for its shelf_id"
	)


func test_item_stocked_adds_child_node_to_slot() -> void:
	var pair: Array = _make_controller_with_slot("vis_slot_02")
	var slot := pair[1] as ShelfSlot
	var count_before: int = slot.get_children().size()

	EventBus.item_stocked.emit("inst_vis_02", "vis_slot_02")

	assert_gt(
		slot.get_children().size(),
		count_before,
		"Stocking must add at least one child node (the item mesh) to the slot"
	)


func test_item_removed_from_shelf_clears_slot() -> void:
	var pair: Array = _make_controller_with_slot("vis_slot_03")
	var slot := pair[1] as ShelfSlot

	EventBus.item_stocked.emit("inst_vis_03", "vis_slot_03")
	assert_true(slot.is_occupied(), "Pre-condition: slot must be occupied after stocking")

	EventBus.item_removed_from_shelf.emit("inst_vis_03", "vis_slot_03")

	assert_false(
		slot.is_occupied(),
		"Slot must be empty after item_removed_from_shelf fires for its shelf_id"
	)


func test_item_stocked_unknown_shelf_id_no_effect() -> void:
	var pair: Array = _make_controller_with_slot("vis_slot_04")
	var slot := pair[1] as ShelfSlot

	EventBus.item_stocked.emit("inst_vis_04", "completely_different_shelf")

	assert_false(
		slot.is_occupied(),
		"Slot must not be occupied when shelf_id does not match"
	)


func test_item_stocked_occupied_slot_keeps_first_item() -> void:
	var pair: Array = _make_controller_with_slot("vis_slot_05")
	var slot := pair[1] as ShelfSlot

	EventBus.item_stocked.emit("inst_first", "vis_slot_05")
	EventBus.item_stocked.emit("inst_second", "vis_slot_05")

	assert_eq(
		slot.get_item_instance_id(),
		"inst_first",
		"First item must remain; second stock on an occupied slot is rejected"
	)
