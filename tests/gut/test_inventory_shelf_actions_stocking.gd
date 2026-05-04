## InventoryShelfActions.place_item — category guard, Stocked toast, and the
## downstream contract InventoryPanel relies on after a successful press-E
## bridge.
##
## These tests pin the runtime contract for shelf stocking:
##   - mismatched item.category vs slot.accepted_category is rejected with a
##     localized "wrong category" notification AND no inventory mutation
##   - successful placement emits a "Stocked <item>" notification so the
##     player gets toast confirmation in the HUD
##   - mismatched stocking does NOT consume the item from backroom (the slot
##     remains empty, the item stays in backroom, no item_stocked fires)
extends GutTest


const _ShelfSlotScript: GDScript = preload(
	"res://game/scripts/stores/shelf_slot.gd"
)


var _data_loader: DataLoader
var _inventory_system: InventorySystem
var _previous_data_loader: DataLoader

var _stocked_events: Array = []
var _notifications: Array[String] = []


func before_each() -> void:
	_stocked_events.clear()
	_notifications.clear()
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()
	_previous_data_loader = GameManager.data_loader
	GameManager.data_loader = _data_loader
	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(_data_loader)
	EventBus.item_stocked.connect(_on_item_stocked)
	EventBus.notification_requested.connect(_on_notification_requested)


func after_each() -> void:
	if EventBus.item_stocked.is_connected(_on_item_stocked):
		EventBus.item_stocked.disconnect(_on_item_stocked)
	if EventBus.notification_requested.is_connected(_on_notification_requested):
		EventBus.notification_requested.disconnect(_on_notification_requested)
	GameManager.data_loader = _previous_data_loader


func _create_backroom_item_for_category(category: String) -> ItemInstance:
	var defs: Array[ItemDefinition] = _data_loader.get_all_items()
	for def: ItemDefinition in defs:
		if def.category == category:
			var item: ItemInstance = ItemInstance.create(
				def, "good", 0, def.base_price
			)
			item.current_location = "backroom"
			_inventory_system.register_item(item)
			return item
	return null


func _make_slot(id: String, accepted_category: String = "") -> ShelfSlot:
	var slot: ShelfSlot = _ShelfSlotScript.new()
	slot.slot_id = id
	slot.accepted_category = accepted_category
	add_child_autofree(slot)
	return slot


func test_successful_place_emits_stocked_notification() -> void:
	var item: ItemInstance = _create_backroom_item_for_category("cartridges")
	if item == null:
		pass_test("No cartridge items in content — skip")
		return
	var slot: ShelfSlot = _make_slot("cib_test_1", "cartridges")
	var actions := InventoryShelfActions.new()
	actions.inventory_system = _inventory_system
	actions.enter_placement_mode(item)

	var placed: bool = actions.place_item(item, slot)
	assert_true(placed, "place_item should succeed for matching category")

	# Notification body must reference the item's display name.
	var stocked_msg_seen: bool = false
	for msg: String in _notifications:
		if msg.begins_with("Stocked ") and msg.find(item.definition.item_name) != -1:
			stocked_msg_seen = true
			break
	assert_true(
		stocked_msg_seen,
		"successful place_item must emit a 'Stocked <item>' notification"
	)


func test_wrong_category_is_rejected_without_consuming_inventory() -> void:
	var cartridge_item: ItemInstance = _create_backroom_item_for_category(
		"cartridges"
	)
	if cartridge_item == null:
		pass_test("No cartridge items in content — skip")
		return
	# Slot only accepts consoles — placing a cartridge there must fail.
	var slot: ShelfSlot = _make_slot("console_only_1", "consoles")
	var actions := InventoryShelfActions.new()
	actions.inventory_system = _inventory_system
	actions.enter_placement_mode(cartridge_item)

	var placed: bool = actions.place_item(cartridge_item, slot)
	assert_false(
		placed,
		"place_item must reject when slot.accepted_category does not match"
	)
	assert_false(
		slot.is_occupied(),
		"slot must remain empty when rejection fires"
	)
	assert_eq(
		cartridge_item.current_location, "backroom",
		"item must remain in backroom when rejection fires"
	)
	assert_eq(
		_stocked_events.size(), 0,
		"item_stocked must not fire on a wrong-category rejection"
	)
	# A user-facing notification must be emitted so the player gets feedback.
	var rejection_seen: bool = false
	for msg: String in _notifications:
		if msg.findn("only accepts") != -1 or msg.findn("solo acepta") != -1:
			rejection_seen = true
			break
	assert_true(
		rejection_seen,
		"wrong-category rejection must surface a user-facing notification"
	)


func test_placement_mode_stays_armed_on_wrong_category() -> void:
	# A wrong-category click is a misclick — the player should stay in
	# placement mode so they can aim at a valid slot without re-entering
	# placement from the inventory panel.
	var cartridge_item: ItemInstance = _create_backroom_item_for_category(
		"cartridges"
	)
	if cartridge_item == null:
		pass_test("No cartridge items in content — skip")
		return
	var slot: ShelfSlot = _make_slot("console_only_2", "consoles")
	var actions := InventoryShelfActions.new()
	actions.inventory_system = _inventory_system
	actions.enter_placement_mode(cartridge_item)
	actions.place_item(cartridge_item, slot)
	assert_true(
		actions.is_placement_mode,
		"placement mode must stay armed after a wrong-category misclick"
	)


func test_unfiltered_slot_accepts_any_category() -> void:
	# Empty accepted_category (e.g. checkout impulse slots) must accept any
	# category — the existing checkout/accessories layout depends on this.
	var item: ItemInstance = _create_backroom_item_for_category("cartridges")
	if item == null:
		pass_test("No cartridge items in content — skip")
		return
	var slot: ShelfSlot = _make_slot("impulse_unfiltered", "")
	var actions := InventoryShelfActions.new()
	actions.inventory_system = _inventory_system
	actions.enter_placement_mode(item)

	var placed: bool = actions.place_item(item, slot)
	assert_true(
		placed,
		"slots without an accepted_category should accept any category"
	)


func test_stock_one_places_into_first_compatible_empty_slot() -> void:
	var item: ItemInstance = _create_backroom_item_for_category("cartridges")
	if item == null:
		pass_test("No cartridge items in content — skip")
		return
	var occupied_slot: ShelfSlot = _make_slot("cib_occupied", "cartridges")
	# Pre-occupy the first slot so stock_one is forced past it.
	occupied_slot.place_item("placeholder_item", "cartridges")
	var wrong_category_slot: ShelfSlot = _make_slot(
		"cib_wrong_cat", "consoles"
	)
	var empty_slot: ShelfSlot = _make_slot("cib_empty", "cartridges")
	var actions := InventoryShelfActions.new()
	actions.inventory_system = _inventory_system

	var slots: Array = [occupied_slot, wrong_category_slot, empty_slot]
	var placed: bool = actions.stock_one(item, slots)
	assert_true(placed, "stock_one must place into first compatible empty slot")
	assert_true(empty_slot.is_occupied(), "empty slot must now be occupied")
	assert_false(
		wrong_category_slot.is_occupied(),
		"wrong-category slot must remain empty"
	)
	assert_eq(
		item.current_location, "shelf:cib_empty",
		"item must be moved to the matched slot"
	)


func test_stock_one_returns_false_when_no_compatible_slot() -> void:
	var item: ItemInstance = _create_backroom_item_for_category("cartridges")
	if item == null:
		pass_test("No cartridge items in content — skip")
		return
	var actions := InventoryShelfActions.new()
	actions.inventory_system = _inventory_system

	# Only wrong-category slots — stock_one cannot place anywhere.
	var slots: Array = [
		_make_slot("only_consoles_a", "consoles"),
		_make_slot("only_consoles_b", "consoles"),
	]
	var placed: bool = actions.stock_one(item, slots)
	assert_false(
		placed, "stock_one must return false when no compatible slot exists"
	)
	assert_eq(
		item.current_location, "backroom",
		"item must remain in backroom on failure"
	)


func test_stock_max_fills_compatible_capacity() -> void:
	var first: ItemInstance = _create_backroom_item_for_category("cartridges")
	if first == null:
		pass_test("No cartridge items in content — skip")
		return
	var second: ItemInstance = _create_backroom_item_for_category("cartridges")
	var third: ItemInstance = _create_backroom_item_for_category("cartridges")
	if second == null or third == null:
		pass_test("Could not seed multiple cartridge items — skip")
		return
	# Pin to the same definition as `first` so stock_max counts them.
	second.definition = first.definition
	third.definition = first.definition
	var slot_a: ShelfSlot = _make_slot("cib_max_a", "cartridges")
	var slot_b: ShelfSlot = _make_slot("cib_max_b", "cartridges")
	var slot_wrong: ShelfSlot = _make_slot("cib_max_wrong", "consoles")
	var actions := InventoryShelfActions.new()
	actions.inventory_system = _inventory_system

	var placed: int = actions.stock_max(
		first, [slot_a, slot_wrong, slot_b]
	)
	assert_eq(placed, 2, "stock_max must fill all compatible empty slots")
	assert_true(slot_a.is_occupied(), "slot A must be filled")
	assert_true(slot_b.is_occupied(), "slot B must be filled")
	assert_false(
		slot_wrong.is_occupied(),
		"wrong-category slot must remain empty"
	)


func _on_item_stocked(instance_id: String, slot_id: String) -> void:
	_stocked_events.append({
		"instance_id": instance_id,
		"slot_id": slot_id,
	})


func _on_notification_requested(message: String) -> void:
	_notifications.append(message)
