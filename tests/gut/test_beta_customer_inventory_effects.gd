extends GutTest

const BetaCustomerInventoryEffectsScript: GDScript = preload(
	"res://game/scripts/beta/beta_customer_inventory_effects.gd"
)
const STORE_ID: StringName = &"retro_games"
const GAME_ID: String = "neo_ignite_motorway_kings_loose"
const GAME_IN_ID: String = "neo_ignite_motorway_kings_westside_loose"
const CONTROLLER_ID: String = "neo_ignite_controller_standard"

var _data_loader: DataLoader
var _inventory: InventorySystem
var _shelf_root: Node
var _inventory_changed_count: int = 0


func before_each() -> void:
	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_seed_item_definitions()
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)
	_shelf_root = Node.new()
	add_child_autofree(_shelf_root)
	_inventory_changed_count = 0
	EventBus.inventory_changed.connect(_on_inventory_changed)


func after_each() -> void:
	if EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.disconnect(_on_inventory_changed)


func test_swap_removes_shelf_item_creates_backroom_return_and_clears_slot() -> void:
	var sold: ItemInstance = _add_item(GAME_ID, "good", "shelf:slot_a")
	var slot: ShelfSlot = _add_slot("slot_a", sold.instance_id)

	var result: Dictionary = _apply_effects(
		{
			"inventory":
			[
				_remove_effect(GAME_ID, 1),
				{
					"op": "create_item",
					"store_id": String(STORE_ID),
					"definition_id": GAME_IN_ID,
					"condition": "near_mint",
					"location": "backroom",
					"quantity": 1,
					"acquired_price": 0,
					"reason": "customer_exchange_in",
				},
			],
		}
	)

	assert_true(bool(result.get("ok", false)))
	assert_null(_inventory.get_item(sold.instance_id))
	assert_false(slot.is_occupied(), "Visible shelf slot should clear after sale")
	assert_eq(_inventory.get_backroom_items_for_store(String(STORE_ID)).size(), 1)
	assert_eq(int((result["inventory_counts"] as Dictionary).get("backroom", -1)), 1)


func test_bundle_sale_removes_two_stocked_items_atomically() -> void:
	var game: ItemInstance = _add_item(GAME_ID, "good", "shelf:slot_game")
	var controller: ItemInstance = _add_item(CONTROLLER_ID, "good", "shelf:slot_controller")
	_add_slot("slot_game", game.instance_id)
	_add_slot("slot_controller", controller.instance_id)

	var result: Dictionary = _apply_effects(
		{
			"inventory":
			[
				_remove_effect(GAME_ID, 1),
				_remove_effect(CONTROLLER_ID, 1),
			],
		}
	)

	assert_true(bool(result.get("ok", false)))
	assert_null(_inventory.get_item(game.instance_id))
	assert_null(_inventory.get_item(controller.instance_id))
	assert_eq((result.get("applied", []) as Array).size(), 2)


func test_decline_no_sale_does_not_emit_inventory_change() -> void:
	var result: Dictionary = _apply_effects(
		{
			"inventory":
			[
				{"op": "no_inventory_change", "reason": "return_refused"},
			],
		}
	)

	assert_true(bool(result.get("ok", false)))
	assert_eq(_inventory_changed_count, 0)
	assert_eq((result.get("applied", []) as Array).size(), 1)


func test_missing_item_fallback_reports_noop_without_inventory_signal() -> void:
	var result: Dictionary = _apply_effects(
		{
			"inventory": [_remove_effect(GAME_ID, 1)],
		}
	)

	assert_false(bool(result.get("ok", true)))
	assert_eq(_inventory_changed_count, 0)
	assert_eq((result.get("applied", []) as Array).size(), 0)
	var failed: Dictionary = (result.get("failed", []) as Array)[0] as Dictionary
	assert_eq(str(failed.get("reason", "")), "missing_matching_stock")


func test_insufficient_quantity_keeps_existing_stock_and_emits_no_signal() -> void:
	var item: ItemInstance = _add_item(GAME_ID, "good", "backroom")
	var result: Dictionary = _apply_effects(
		{
			"inventory": [_remove_effect(GAME_ID, 2)],
		}
	)

	assert_false(bool(result.get("ok", true)))
	assert_not_null(_inventory.get_item(item.instance_id))
	assert_eq(_inventory_changed_count, 1, "Only setup add_item should emit")
	var failed: Dictionary = (result.get("failed", []) as Array)[0] as Dictionary
	assert_eq(str(failed.get("reason", "")), "insufficient_quantity")


func _adapter() -> RefCounted:
	return BetaCustomerInventoryEffectsScript.new(_inventory, _shelf_root) as RefCounted


func _apply_effects(effects: Dictionary) -> Dictionary:
	return _adapter().call("apply", effects) as Dictionary


func _add_item(definition_id: String, condition: String, location: String) -> ItemInstance:
	var definition: ItemDefinition = _data_loader.get_item(definition_id)
	assert_not_null(definition)
	var item: ItemInstance = ItemInstance.create(definition, condition, 0, definition.base_price)
	item.current_location = location
	_inventory.add_item(STORE_ID, item)
	return item


func _seed_item_definitions() -> void:
	var items: Dictionary = {}
	items[GAME_ID] = _make_definition(GAME_ID, "Motorway Kings", &"cartridges", 22.0)
	items[GAME_IN_ID] = _make_definition(
		GAME_IN_ID, "Motorway Kings: Westside", &"cartridges", 32.0
	)
	items[CONTROLLER_ID] = _make_definition(
		CONTROLLER_ID, "Neo Ignite Controller", &"accessories", 24.0
	)
	_data_loader.set("_items", items)


func _make_definition(
	definition_id: String, display_name: String, category: StringName, base_price: float
) -> ItemDefinition:
	var definition: ItemDefinition = ItemDefinition.new()
	definition.id = definition_id
	definition.item_name = display_name
	definition.store_type = STORE_ID
	definition.category = category
	definition.base_price = base_price
	definition.rarity = "common"
	return definition


func _add_slot(slot_id: String, item_id: String) -> ShelfSlot:
	var slot: ShelfSlot = ShelfSlot.new()
	slot.slot_id = slot_id
	_shelf_root.add_child(slot)
	slot.set("_held_item_id", item_id)
	slot.set("_held_category", "cartridges")
	slot.set("_occupied", true)
	return slot


func _remove_effect(definition_id: String, quantity: int) -> Dictionary:
	return {
		"op": "remove_stock",
		"from": "shelf_first",
		"store_id": String(STORE_ID),
		"selector":
		{
			"definition_id": definition_id,
			"fallback_category": "cartridges",
			"prefer_location": "shelf",
		},
		"quantity": quantity,
		"reason": "customer_sale",
	}


func _on_inventory_changed() -> void:
	_inventory_changed_count += 1
