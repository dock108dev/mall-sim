## GUT tests for store ID normalization across DataLoader and InventorySystem.
extends GutTest


const STORE_FIXTURES: Array[Dictionary] = [
	{
		"id": "sports",
		"aliases": ["sports_memorabilia"],
		"name": "Sports Memorabilia",
		"scene_path": "res://game/scenes/stores/sports_memorabilia.tscn",
		"starting_inventory": ["sports_item_common"],
	},
	{
		"id": "retro_games",
		"name": "Retro Game Store",
		"scene_path": "res://game/scenes/stores/retro_games.tscn",
		"starting_inventory": ["retro_games_item_common"],
	},
	{
		"id": "rentals",
		"aliases": ["video_rental"],
		"name": "Video Rental",
		"scene_path": "res://game/scenes/stores/video_rental.tscn",
		"starting_inventory": ["rentals_item_common"],
	},
	{
		"id": "pocket_creatures",
		"name": "PocketCreatures Card Shop",
		"scene_path": "res://game/scenes/stores/pocket_creatures.tscn",
		"starting_inventory": ["pocket_creatures_item_common"],
	},
	{
		"id": "electronics",
		"aliases": ["consumer_electronics"],
		"name": "Consumer Electronics",
		"scene_path": "res://game/scenes/stores/consumer_electronics.tscn",
		"starting_inventory": ["electronics_item_common"],
	},
]

var _data_loader: DataLoader
var _inventory_system: InventorySystem


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_register_fixture_catalog()
	_inventory_system = InventorySystem.new()
	add_child_autofree(_inventory_system)
	_inventory_system.initialize(_data_loader)


func test_create_starting_inventory_builds_all_five_store_types() -> void:
	for store_entry: Dictionary in STORE_FIXTURES:
		var store_id: String = str(store_entry["id"])
		var items: Array[ItemInstance] = (
			_data_loader.create_starting_inventory(store_id)
		)
		assert_eq(
			items.size(), 1,
			"Store '%s' should build its configured starting inventory"
			% store_id
		)
		var item: ItemInstance = items[0]
		assert_not_null(item.definition)
		if item.definition:
			assert_eq(item.definition.store_type, store_id)


func test_generate_starter_inventory_builds_all_five_store_types() -> void:
	for store_entry: Dictionary in STORE_FIXTURES:
		var store_id: String = str(store_entry["id"])
		var items: Array[ItemInstance] = (
			_data_loader.generate_starter_inventory(store_id)
		)
		assert_eq(
			items.size(), 1,
			"Store '%s' should generate starter inventory from common items"
			% store_id
		)
		var item: ItemInstance = items[0]
		assert_not_null(item.definition)
		if item.definition:
			assert_eq(item.definition.store_type, store_id)
			assert_eq(item.definition.rarity, "common")


func test_generate_starter_inventory_resolves_store_aliases() -> void:
	var items: Array[ItemInstance] = (
		_data_loader.generate_starter_inventory("sports_memorabilia")
	)
	assert_eq(
		items.size(), 1,
		"Alias store IDs should still generate canonical starter inventory"
	)
	var item: ItemInstance = items[0]
	assert_not_null(item.definition)
	if item.definition:
		assert_eq(item.definition.id, "sports_item_common")
		assert_eq(item.definition.store_type, "sports")


func test_inventory_load_save_resolves_legacy_shelf_and_queue_store_ids() -> void:
	_inventory_system.load_save_data(
		{
			"items": [
				{
					"instance_id": "item_legacy_1",
					"definition_id": "rentals_item_common",
					"condition": "good",
					"acquired_day": 1,
					"acquired_price": 5.0,
					"current_location": "shelf:slot_01",
					"player_set_price": 7.0,
					"tested": false,
					"test_result": "",
					"is_demo": false,
					"demo_placed_day": 0,
					"authentication_status": "none",
					"rental_due_day": -1,
				},
			],
			"shelf_assignments": {
				"video_rental": {
					"slot_01": "item_legacy_1",
				},
			},
			"restock_queue": [
				{
					"store_id": "consumer_electronics",
					"item_id": "electronics_item_common",
					"quantity": 1,
				},
			],
		}
	)

	var shelf_item: ItemInstance = _inventory_system.get_shelf_item(
		&"rentals",
		&"slot_01"
	)
	assert_not_null(
		shelf_item,
		"Legacy shelf assignment keys should resolve to canonical store IDs"
	)
	_inventory_system.process_restock_queue()
	var electronics_stock: Array[ItemInstance] = _inventory_system.get_stock(
		&"electronics"
	)
	assert_eq(
		electronics_stock.size(),
		1,
		"Legacy restock queue store IDs should resolve to canonical IDs"
	)


func _register_fixture_catalog() -> void:
	for store_entry: Dictionary in STORE_FIXTURES:
		_data_loader._build_and_register("store", store_entry)
		var store_id: String = str(store_entry["id"])
		_data_loader._build_and_register(
			"item",
			{
				"id": "%s_item_common" % store_id,
				"item_name": "%s Common Item" % store_id.capitalize(),
				"category": "test_items",
				"store_type": store_id,
				"base_price": 10.0,
				"rarity": "common",
			}
		)
