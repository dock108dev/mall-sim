## Shelf placement and removal actions used by the InventoryPanel.
class_name InventoryShelfActions
extends RefCounted

var inventory_system: InventorySystem
var is_placement_mode: bool = false


## `item` is optional so legacy/test callers can drive placement mode without a
## specific ItemInstance (see tests/gut/test_press_e_interaction_routing.gd).
## When omitted, the empty `item_name` triggers PlacementHintUI's fallback
## prompt — an intentional UX path, not a silent failure. See
## docs/audits/error-handling-report.md EH-02.
func enter_placement_mode(item: ItemInstance = null) -> void:
	if is_placement_mode:
		return
	is_placement_mode = true
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	EventBus.placement_mode_entered.emit()
	var item_name: String = ""
	if item != null:
		if item.definition != null:
			item_name = item.definition.item_name
		else:
			# A non-null ItemInstance without a definition is malformed inventory
			# state — surface it loudly so it shows up in CI / telemetry rather
			# than degrading silently to the fallback hint. See EH-03.
			push_warning(
				"InventoryShelfActions: ItemInstance %s has no definition; "
				% item.instance_id
				+ "placement hint will fall back to the generic prompt."
			)
	EventBus.placement_hint_requested.emit(item_name)


func exit_placement_mode() -> void:
	if not is_placement_mode:
		return
	is_placement_mode = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	EventBus.placement_mode_exited.emit()


func place_item(
	item: ItemInstance, slot: ShelfSlot
) -> bool:
	# Caller passed nothing to place — silently no-op (e.g. press-E with no
	# selected item). The button gating in inventory_panel guards this path,
	# so a null `item` here is legitimate and not worth logging.
	if item == null:
		return false
	# `inventory_system` is wired by InventoryPanel.open(); reaching here
	# without it means a caller skipped the panel boot path. See EH-04.
	if inventory_system == null:
		push_warning(
			"InventoryShelfActions.place_item: inventory_system not wired; "
			+ "rejecting placement."
		)
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
	# Same wiring contract as `place_item` (EH-04): if we reach this path
	# without `inventory_system`, surface it rather than swallow.
	if inventory_system == null:
		push_warning(
			"InventoryShelfActions.remove_item_from_shelf: inventory_system "
			+ "not wired; cannot return slot %s contents to backroom."
			% slot.slot_id
		)
		return
	var item_id: String = slot.get_item_instance_id()
	if item_id.is_empty():
		return
	slot.remove_item()
	inventory_system.move_item(item_id, "backroom")
	EventBus.item_removed_from_shelf.emit(item_id, slot.slot_id)
	EventBus.notification_requested.emit(tr("INVENTORY_RETURNED"))


func move_to_backroom(item: ItemInstance) -> void:
	# Null `item` is a legitimate caller no-op (context menu invoked with no
	# selection); silent return is intentional. EH-04 covers the
	# `inventory_system` case below.
	if item == null:
		return
	if inventory_system == null:
		push_warning(
			"InventoryShelfActions.move_to_backroom: inventory_system not "
			+ "wired; cannot move %s." % item.instance_id
		)
		return
	if not item.current_location.begins_with("shelf:"):
		return
	var shelf_id: String = item.current_location.substr(6)
	inventory_system.move_item(item.instance_id, "backroom")
	EventBus.item_removed_from_shelf.emit(
		item.instance_id, shelf_id
	)
