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
	var category: String = ""
	var item_name: String = ""
	if item.definition:
		category = item.definition.category
		item_name = item.definition.item_name
	# Reject before any state mutation if the slot enforces a category that
	# does not match the item — keeps the inventory in `backroom` and the slot
	# empty so the caller's idempotency contract holds (see EH-04 and the
	# duplicate-press regression covered by test_press_e_emits_item_stocked_exactly_once).
	if not slot.accepts_category(category):
		EventBus.notification_requested.emit(
			tr("INVENTORY_WRONG_CATEGORY") % slot.accepted_category
		)
		return false
	inventory_system.move_item(
		item.instance_id, "shelf:%s" % slot.slot_id
	)
	slot.place_item(item.instance_id, category)
	EventBus.item_stocked.emit(item.instance_id, slot.slot_id)
	if not item_name.is_empty():
		EventBus.notification_requested.emit(
			tr("INVENTORY_STOCKED") % item_name
		)
	exit_placement_mode()
	return true


## Auto-stocks one unit by routing place_item to the first compatible empty
## slot in `slots`. Returns true on success, false when no compatible slot
## exists or the underlying place_item call rejected. Bypasses placement
## mode — caller is responsible for surfacing the failure to the player when
## false is returned.
func stock_one(item: ItemInstance, slots: Array) -> bool:
	# Null `item` is a legitimate caller no-op (button gating in InventoryPanel
	# guards this); silent return matches `place_item`. See §F-92.
	if item == null:
		return false
	# Same wiring contract as `place_item` / `remove_item_from_shelf` (§F-04 /
	# EH-04): reaching here without `inventory_system` means a caller skipped
	# the `InventoryPanel._prep_row_action` mirror. Warn rather than swallow.
	if inventory_system == null:
		push_warning(
			"InventoryShelfActions.stock_one: inventory_system not wired; "
			+ "rejecting one-click stock."
		)
		return false
	var slot: ShelfSlot = _find_compatible_empty_slot(item, slots)
	if slot == null:
		return false
	return place_item(item, slot)


## Iterates compatible empty `slots` and places `item` plus matching backroom
## copies (same definition_id) up to capacity. Returns the number of items
## placed. Zero indicates either no compatible slots or no matching backroom
## stock; caller decides how to surface that to the player.
func stock_max(item: ItemInstance, slots: Array) -> int:
	# Null `item` / null definition mirror the `stock_one` / `place_item`
	# silent no-ops (legitimate caller paths under button gating). §F-92.
	if item == null:
		return 0
	# §F-04 / EH-04 wiring contract — same as `stock_one` / `place_item`.
	if inventory_system == null:
		push_warning(
			"InventoryShelfActions.stock_max: inventory_system not wired; "
			+ "rejecting bulk stock."
		)
		return 0
	if item.definition == null:
		return 0
	var def_id: String = item.definition.id
	if def_id.is_empty():
		return 0
	var queue: Array[ItemInstance] = _collect_backroom_matches(def_id, item)
	if queue.is_empty():
		return 0
	var category: String = item.definition.category
	var placed: int = 0
	for node: Node in slots:
		if queue.is_empty():
			break
		if not (node is ShelfSlot):
			continue
		var slot := node as ShelfSlot
		if slot.is_occupied():
			continue
		if not slot.accepts_category(category):
			continue
		var next_item: ItemInstance = queue.pop_front()
		if place_item(next_item, slot):
			placed += 1
	return placed


func _collect_backroom_matches(
	def_id: String, primary: ItemInstance
) -> Array[ItemInstance]:
	var queue: Array[ItemInstance] = [primary]
	for inv_item: ItemInstance in inventory_system.get_backroom_items():
		if inv_item == null or inv_item.definition == null:
			continue
		if inv_item.instance_id == primary.instance_id:
			continue
		if inv_item.definition.id != def_id:
			continue
		queue.append(inv_item)
	return queue


static func _find_compatible_empty_slot(
	item: ItemInstance, slots: Array
) -> ShelfSlot:
	if item == null:
		return null
	var category: String = ""
	if item.definition:
		category = item.definition.category
	for node: Node in slots:
		if not (node is ShelfSlot):
			continue
		var slot := node as ShelfSlot
		if slot.is_occupied():
			continue
		if not slot.accepts_category(category):
			continue
		return slot
	return null


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
