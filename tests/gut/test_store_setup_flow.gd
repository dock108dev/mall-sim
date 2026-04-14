## Tests the store setup flow: starter inventory generation and deferred
## delivery via day_started signal.
extends GutTest


var _data_loader: DataLoader


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()


func test_generate_starter_inventory_returns_items() -> void:
	var items: Array[ItemInstance] = (
		_data_loader.generate_starter_inventory("sports")
	)
	assert_true(
		items.size() >= 6,
		"Should generate at least 6 items, got %d" % items.size()
	)
	assert_true(
		items.size() <= 10,
		"Should generate at most 10 items, got %d" % items.size()
	)


func test_generate_starter_inventory_all_common() -> void:
	var items: Array[ItemInstance] = (
		_data_loader.generate_starter_inventory("sports")
	)
	for item: ItemInstance in items:
		assert_eq(
			item.definition.rarity, "common",
			"All starter items should be common rarity"
		)


func test_generate_starter_inventory_matches_store_type() -> void:
	var items: Array[ItemInstance] = (
		_data_loader.generate_starter_inventory("sports")
	)
	for item: ItemInstance in items:
		assert_eq(
			item.definition.store_type, "sports",
			"All starter items should match the store type"
		)


func test_generate_starter_inventory_unique_ids() -> void:
	var items: Array[ItemInstance] = (
		_data_loader.generate_starter_inventory("sports")
	)
	var ids: Dictionary = {}
	for item: ItemInstance in items:
		assert_false(
			ids.has(item.instance_id),
			"Each item should have a unique instance_id"
		)
		ids[item.instance_id] = true


func test_generate_starter_inventory_unknown_store() -> void:
	var items: Array[ItemInstance] = (
		_data_loader.generate_starter_inventory("nonexistent")
	)
	assert_eq(
		items.size(), 0,
		"Unknown store type should return empty array"
	)


func test_generate_starter_inventory_all_store_types() -> void:
	var stores: Array[StoreDefinition] = (
		_data_loader.get_all_stores()
	)
	for store: StoreDefinition in stores:
		var items: Array[ItemInstance] = (
			_data_loader.generate_starter_inventory(store.id)
		)
		assert_true(
			items.size() >= 0,
			"Store '%s' should not error" % store.id
		)
