## Integration test: DataLoader validates required fields, types, and value ranges for all content types.
extends GutTest

const REQUIRED_STORE_IDS: Array[String] = [
	"sports", "retro_games", "rentals",
	"pocket_creatures", "electronics"
]

const _GHOST_STORE_ID: StringName = &"schema_test_ghost_store"


func after_each() -> void:
	_cleanup_ghost_store()


# --- Scenario A: valid content files pass validation ---

func test_real_content_loads_without_errors() -> void:
	var errors: Array[String] = DataLoader.get_load_errors()
	assert_eq(
		errors.size(), 0,
		"DataLoader should report zero load errors on real content"
	)


func test_content_registry_is_ready_after_load() -> void:
	assert_true(
		ContentRegistry.is_ready(),
		"ContentRegistry should be ready after DataLoader loads content"
	)


func test_all_five_store_ids_resolve_via_content_registry() -> void:
	for store_id: String in REQUIRED_STORE_IDS:
		var resolved: StringName = ContentRegistry.resolve(store_id)
		assert_ne(
			resolved, &"",
			"Store ID '%s' should resolve via ContentRegistry" % store_id
		)


func test_all_item_ids_accessible_in_data_loader() -> void:
	var items: Array[ItemDefinition] = DataLoader.get_all_items()
	assert_gt(items.size(), 0, "DataLoader should have items loaded")
	for item: ItemDefinition in items:
		var found: ItemDefinition = DataLoader.get_item(item.id)
		assert_not_null(
			found,
			"Item '%s' should be retrievable via DataLoader.get_item()" % item.id
		)


# --- Scenario B: item missing required field is rejected ---

func test_item_missing_base_price_returns_null() -> void:
	var data: Dictionary = {
		"id": "schema_test_no_price",
		"display_name": "Missing Price Item",
		"category": "test",
	}
	var result: ItemDefinition = ContentParser.parse_item(data)
	assert_null(result, "parse_item should return null when base_price is absent")


func test_item_missing_id_returns_null() -> void:
	var data: Dictionary = {
		"base_price": 10.0,
		"display_name": "No ID Item",
	}
	var result: ItemDefinition = ContentParser.parse_item(data)
	assert_null(result, "parse_item should return null when id is absent")


func test_item_missing_base_price_not_registered_in_content_registry() -> void:
	var data: Dictionary = {
		"id": "schema_test_b_unreg",
		"display_name": "Missing Price Unreg",
	}
	ContentParser.parse_item(data)
	assert_false(
		ContentRegistry.exists("schema_test_b_unreg"),
		"Item with missing base_price should not appear in ContentRegistry"
	)


# --- Scenario C: item with out-of-range value is rejected ---

func test_item_with_negative_base_price_returns_null() -> void:
	var data: Dictionary = {
		"id": "schema_test_neg_price",
		"display_name": "Negative Price Item",
		"category": "test",
		"base_price": -1.0,
	}
	var result: ItemDefinition = ContentParser.parse_item(data)
	assert_null(result, "parse_item should return null when base_price is negative")


func test_item_with_negative_base_price_not_registered() -> void:
	var data: Dictionary = {
		"id": "schema_test_c_neg_reg",
		"display_name": "Neg Price Reg Test",
		"category": "test",
		"base_price": -99.0,
	}
	ContentParser.parse_item(data)
	assert_false(
		ContentRegistry.exists("schema_test_c_neg_reg"),
		"Item with negative base_price should not be registered in ContentRegistry"
	)


# --- Scenario D: store definition with unknown scene_path is flagged as warning ---

func test_store_with_nonexistent_scene_path_still_parses() -> void:
	var data: Dictionary = _ghost_store_data()
	var store: StoreDefinition = ContentParser.parse_store(data)
	assert_not_null(
		store,
		"parse_store should succeed even when scene_path does not exist on disk"
	)


func test_store_with_nonexistent_scene_path_is_registered() -> void:
	var data: Dictionary = _ghost_store_data()
	var store: StoreDefinition = ContentParser.parse_store(data)
	ContentRegistry.register(_GHOST_STORE_ID, store, "store")
	ContentRegistry.register_entry(data, "store")
	assert_true(
		ContentRegistry.exists(String(_GHOST_STORE_ID)),
		"Store with nonexistent scene_path should still appear in ContentRegistry"
	)


func test_nonexistent_scene_path_is_not_in_validate_errors() -> void:
	var data: Dictionary = _ghost_store_data()
	var store: StoreDefinition = ContentParser.parse_store(data)
	ContentRegistry.register(_GHOST_STORE_ID, store, "store")
	ContentRegistry.register_entry(data, "store")
	var errors: Array[String] = ContentRegistry.validate_all_references()
	for err: String in errors:
		assert_false(
			err.contains("nonexistent_ghost_scene"),
			"Missing scene_path should emit push_warning, not appear in error list"
		)


# --- Required field contracts: items ---

func test_item_contract_requires_id() -> void:
	assert_null(
		ContentParser.parse_item({"base_price": 5.0}),
		"item contract: id is required"
	)


func test_item_contract_requires_base_price() -> void:
	assert_null(
		ContentParser.parse_item({"id": "contract_item_no_price"}),
		"item contract: base_price is required"
	)


func test_item_contract_rejects_negative_base_price() -> void:
	assert_null(
		ContentParser.parse_item({"id": "contract_item_neg", "base_price": -0.01}),
		"item contract: base_price must be >= 0"
	)


# --- Required field contracts: stores ---

func test_store_contract_requires_id() -> void:
	assert_null(
		ContentParser.parse_store({"name": "No ID Store"}),
		"store contract: id is required"
	)


func test_store_contract_requires_name() -> void:
	assert_null(
		ContentParser.parse_store({"id": "contract_store_no_name"}),
		"store contract: name is required"
	)


# --- Required field contracts: customers ---

func test_customer_contract_requires_id() -> void:
	assert_null(
		ContentParser.parse_customer({"name": "No ID Customer"}),
		"customer contract: id is required"
	)


func test_customer_contract_requires_name() -> void:
	assert_null(
		ContentParser.parse_customer({"id": "contract_customer_no_name"}),
		"customer contract: name is required"
	)


# --- Required field contracts: events ---

func test_market_event_contract_requires_id() -> void:
	assert_null(
		ContentParser.parse_market_event({"event_type": "price_spike"}),
		"market_event contract: id is required"
	)


func test_market_event_contract_requires_event_type() -> void:
	assert_null(
		ContentParser.parse_market_event({"id": "contract_evt_no_type"}),
		"market_event contract: event_type is required"
	)


# --- Required field contracts: fixtures ---

func test_fixture_contract_requires_id() -> void:
	assert_null(
		ContentParser.parse_fixture({"name": "No ID Fixture", "cost": 50.0}),
		"fixture contract: id is required"
	)


func test_fixture_contract_requires_name() -> void:
	assert_null(
		ContentParser.parse_fixture({"id": "contract_fix_no_name", "cost": 50.0}),
		"fixture contract: name is required"
	)


func test_fixture_contract_requires_cost() -> void:
	assert_null(
		ContentParser.parse_fixture({"id": "contract_fix_no_cost", "name": "Fixture"}),
		"fixture contract: cost/price is required"
	)


# --- Helpers ---

func _ghost_store_data() -> Dictionary:
	return {
		"id": "schema_test_ghost_store",
		"name": "Ghost Store",
		"scene_path": "res://game/scenes/stores/nonexistent_ghost_scene.tscn",
	}


func _cleanup_ghost_store() -> void:
	if not ContentRegistry.exists(String(_GHOST_STORE_ID)):
		return
	ContentRegistry._entries.erase(_GHOST_STORE_ID)
	ContentRegistry._resources.erase(_GHOST_STORE_ID)
	ContentRegistry._types.erase(_GHOST_STORE_ID)
	ContentRegistry._display_names.erase(_GHOST_STORE_ID)
	ContentRegistry._scene_map.erase(_GHOST_STORE_ID)
	for key: StringName in ContentRegistry._aliases.keys():
		if ContentRegistry._aliases[key] == _GHOST_STORE_ID:
			ContentRegistry._aliases.erase(key)
