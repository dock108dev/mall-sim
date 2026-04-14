## GUT unit tests for DataLoader JSON parsing, schema validation, and
## ContentRegistry population.
extends GutTest


const CATALOG_STORES: Array[String] = [
	"sports", "retro_games", "rentals",
	"pocket_creatures", "electronics",
]

const MIN_ITEMS_PER_STORE: Dictionary = {
	"sports": 20,
	"retro_games": 25,
	"rentals": 20,
	"pocket_creatures": 30,
	"electronics": 20,
}

const REQUIRED_ITEM_FIELDS: Array[String] = [
	"id", "item_name", "category", "store_type",
	"base_price", "rarity",
]

const VALID_RARITIES: Array[String] = [
	"common", "uncommon", "rare", "very_rare", "legendary",
	"ultra_rare", "secret_rare", "holographic", "rare_holo",
]


func before_all() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()


func test_load_all_no_errors() -> void:
	var errors: Array[String] = DataLoaderSingleton.get_load_errors()
	assert_eq(
		errors.size(), 0,
		"load_all() should produce no errors: %s" % [errors]
	)


func test_all_five_item_catalogs_parse() -> void:
	for store_id: String in CATALOG_STORES:
		var items: Array[ItemDefinition] = (
			DataLoaderSingleton.get_items_by_store(store_id)
		)
		var minimum: int = MIN_ITEMS_PER_STORE[store_id]
		assert_gte(
			items.size(), minimum,
			"Store '%s' should have >= %d items, got %d"
			% [store_id, minimum, items.size()]
		)


func test_all_items_have_required_fields() -> void:
	var items: Array[ItemDefinition] = DataLoaderSingleton.get_all_items()
	assert_gt(items.size(), 0, "Should have loaded items")
	for item: ItemDefinition in items:
		assert_ne(
			item.id, "",
			"Item should have id"
		)
		assert_ne(
			item.item_name, "",
			"Item '%s' should have name" % item.id
		)
		assert_ne(
			item.category, "",
			"Item '%s' should have category" % item.id
		)
		assert_ne(
			item.store_type, "",
			"Item '%s' should have store_type" % item.id
		)
		assert_gt(
			item.base_price, 0.0,
			"Item '%s' should have positive base_price" % item.id
		)
		assert_true(
			item.rarity in VALID_RARITIES,
			"Item '%s' rarity '%s' is not valid"
			% [item.id, item.rarity]
		)


func test_all_item_ids_unique_across_catalogs() -> void:
	var items: Array[ItemDefinition] = DataLoaderSingleton.get_all_items()
	var seen: Dictionary = {}
	for item: ItemDefinition in items:
		assert_false(
			seen.has(item.id),
			"Duplicate item ID found: '%s'" % item.id
		)
		seen[item.id] = true


func test_store_definitions_produce_five_canonical_ids() -> void:
	var ids: Array[StringName] = ContentRegistry.get_all_ids("store")
	assert_eq(
		ids.size(), 5,
		"Should have exactly 5 store IDs, got %d" % ids.size()
	)
	for store_id: String in CATALOG_STORES:
		assert_has(
			ids, StringName(store_id),
			"Missing store ID: '%s'" % store_id
		)


func test_staff_definitions_parse() -> void:
	var staff: Array[StaffDefinition] = (
		DataLoaderSingleton.get_all_staff_definitions()
	)
	assert_gt(
		staff.size(), 0,
		"Should load at least one staff definition"
	)
	for s: StaffDefinition in staff:
		assert_ne(s.id, "", "Staff should have id")


func test_economy_config_has_valid_starting_cash() -> void:
	var config: EconomyConfig = DataLoaderSingleton.get_economy_config()
	assert_not_null(config, "Should load economy config")
	assert_gt(
		config.starting_cash, 0.0,
		"Economy config should have positive starting_cash"
	)


func test_missing_id_field_rejects_entry() -> void:
	var loader: DataLoader = DataLoader.new()
	add_child_autofree(loader)
	var before_count: int = loader.get_item_count()
	loader._build_and_register("item", {"name": "No ID Item"})
	assert_eq(
		loader.get_item_count(), before_count,
		"Entry without 'id' should not be registered"
	)
