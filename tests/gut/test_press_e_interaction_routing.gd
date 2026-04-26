## ISSUE-002: press-E routing through Interactable.interact() exercises both
## the placement-mode bridge in InventoryShelfActions (SHELF_SLOT) and the
## existing register handler in PlayerCheckout (REGISTER).
##
## These tests bypass the InteractionRay raycast layer and drive the same
## EventBus signals the ray emits, so they cover the contract the ray relies
## on without depending on viewport / collision-layer setup.
extends GutTest


const _InteractableScript: GDScript = preload(
	"res://game/scripts/components/interactable.gd"
)
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


# ── Placement-mode press-E on an empty ShelfSlot ─────────────────────────────


func test_press_e_on_empty_shelf_slot_in_placement_mode_places_item() -> void:
	var item: ItemInstance = _create_backroom_item()
	if item == null:
		pass_test("No item definitions loaded — skip")
		return
	var slot: ShelfSlot = _make_slot("slot_a")
	var actions := InventoryShelfActions.new()
	actions.inventory_system = _inventory_system

	actions.enter_placement_mode(item)
	# The interaction ray would call slot.interact(); we drive its observable
	# effect directly so the test does not depend on raycast geometry.
	EventBus.interactable_interacted.emit(
		slot, Interactable.InteractionType.SHELF_SLOT
	)

	assert_eq(
		_stocked_events.size(), 1,
		"press-E on empty ShelfSlot during placement should fire item_stocked once"
	)
	if _stocked_events.size() == 1:
		assert_eq(
			_stocked_events[0]["instance_id"],
			String(item.instance_id),
			"item_stocked must carry the placed item's instance_id"
		)
		assert_eq(
			_stocked_events[0]["slot_id"], slot.slot_id,
			"item_stocked must carry the target slot_id"
		)
	assert_false(
		actions.is_placement_mode,
		"Successful placement should exit placement mode"
	)
	assert_true(
		slot.is_occupied(), "ShelfSlot should be occupied after placement"
	)
	assert_eq(
		item.current_location, "shelf:%s" % slot.slot_id,
		"ItemInstance.current_location should reflect the new shelf path"
	)


func test_press_e_emits_item_stocked_exactly_once() -> void:
	var item: ItemInstance = _create_backroom_item()
	if item == null:
		pass_test("No item definitions loaded — skip")
		return
	var slot: ShelfSlot = _make_slot("slot_b")
	var actions := InventoryShelfActions.new()
	actions.inventory_system = _inventory_system
	actions.enter_placement_mode(item)

	# Two press-E in quick succession — first should place, second should be
	# a no-op because the actions object exited placement mode after the first.
	EventBus.interactable_interacted.emit(
		slot, Interactable.InteractionType.SHELF_SLOT
	)
	EventBus.interactable_interacted.emit(
		slot, Interactable.InteractionType.SHELF_SLOT
	)

	assert_eq(
		_stocked_events.size(), 1,
		"item_stocked must fire exactly once even with a duplicate press-E"
	)


func test_press_e_outside_placement_mode_is_noop_for_shelf_actions() -> void:
	var item: ItemInstance = _create_backroom_item()
	if item == null:
		pass_test("No item definitions loaded — skip")
		return
	var slot: ShelfSlot = _make_slot("slot_c")
	var actions := InventoryShelfActions.new()
	actions.inventory_system = _inventory_system
	# Note: never call enter_placement_mode — the disconnect is the contract.

	EventBus.interactable_interacted.emit(
		slot, Interactable.InteractionType.SHELF_SLOT
	)

	assert_eq(
		_stocked_events.size(), 0,
		"InventoryShelfActions must not place items unless placement mode is active"
	)
	assert_false(
		slot.is_occupied(),
		"ShelfSlot should remain empty when no placement is in flight"
	)


# ── Register press-E ─────────────────────────────────────────────────────────


func test_press_e_on_register_with_no_customer_emits_no_customer_notification() -> void:
	var economy: EconomySystem = EconomySystem.new()
	add_child_autofree(economy)
	economy.initialize(1000.0)
	var customers: CustomerSystem = CustomerSystem.new()
	add_child_autofree(customers)
	var reputation: ReputationSystem = ReputationSystem.new()
	reputation.auto_connect_bus = false
	add_child_autofree(reputation)
	var checkout := PlayerCheckout.new()
	add_child_autofree(checkout)
	checkout.initialize(economy, _inventory_system, customers, reputation)

	var register: Interactable = _make_register()
	EventBus.interactable_interacted.emit(
		register, Interactable.InteractionType.REGISTER
	)

	# Robust to localization: at least one notification must contain the phrase.
	var matched: bool = false
	for msg: String in _notifications:
		if msg.findn("no customer") != -1:
			matched = true
			break
	assert_true(
		matched,
		"Register press-E with no customer must emit the 'No customer waiting' notification"
	)


# ── Helpers ──────────────────────────────────────────────────────────────────


func _create_backroom_item() -> ItemInstance:
	var defs: Array[ItemDefinition] = _data_loader.get_all_items()
	if defs.is_empty():
		return null
	var def: ItemDefinition = defs[0]
	var item: ItemInstance = ItemInstance.create(
		def, "good", 0, def.base_price
	)
	item.current_location = "backroom"
	_inventory_system.register_item(item)
	return item


func _make_slot(id: String) -> ShelfSlot:
	var slot: ShelfSlot = _ShelfSlotScript.new()
	slot.slot_id = id
	add_child_autofree(slot)
	return slot


func _make_register() -> Interactable:
	var node: Interactable = _InteractableScript.new()
	node.interaction_type = Interactable.InteractionType.REGISTER
	node.display_name = "Cash Register"
	add_child_autofree(node)
	return node


func _on_item_stocked(instance_id: String, slot_id: String) -> void:
	_stocked_events.append({
		"instance_id": instance_id,
		"slot_id": slot_id,
	})


func _on_notification_requested(message: String) -> void:
	_notifications.append(message)
