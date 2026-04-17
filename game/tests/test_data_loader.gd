## GUT unit tests for DataLoader JSON parsing, schema validation, and
## ContentRegistry population.
extends GutTest


const CATALOG_FILES: Dictionary = {
	"sports": "res://game/content/items/sports_memorabilia.json",
	"retro_games": "res://game/content/items/retro_games.json",
	"rentals": "res://game/content/items/video_rental.json",
	"pocket_creatures": "res://game/content/items/pocket_creatures.json",
	"electronics": "res://game/content/items/consumer_electronics.json",
}

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
	"base_price", "rarity", "condition_range",
]

const VALID_RARITIES: Array[String] = [
	"common", "uncommon", "rare", "very_rare", "legendary",
	"ultra_rare", "secret_rare", "holographic", "rare_holo",
]


func before_all() -> void:
	ContentRegistry.clear_for_testing()
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()


func test_load_all_no_errors() -> void:
	var errors: Array[String] = _unexpected_load_errors(
		DataLoaderSingleton.get_load_errors()
	)
	assert_eq(
		errors.size(), 0,
		"load_all() should produce no unexpected errors: %s" % [errors]
	)


func test_all_five_item_catalogs_parse() -> void:
	for store_id: String in CATALOG_STORES:
		var entries: Array[Dictionary] = _load_catalog_entries(store_id)
		assert_gte(
			entries.size(), MIN_ITEMS_PER_STORE[store_id],
			"Catalog '%s' should parse >= %d entries, got %d"
			% [store_id, MIN_ITEMS_PER_STORE[store_id], entries.size()]
		)
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
	for store_id: String in CATALOG_STORES:
		var entries: Array[Dictionary] = _load_catalog_entries(store_id)
		for entry: Dictionary in entries:
			_assert_item_entry_has_required_fields(entry, store_id)

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
		assert_ne(s.staff_id, "", "Staff should have id")


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
	var errors: Array[String] = loader.get_load_errors()
	assert_eq(
		loader.get_item_count(), before_count,
		"Entry without 'id' should not be registered"
	)
	assert_eq(
		errors.size(), 1,
		"Entry without 'id' should record one load error"
	)
	assert_string_contains(
		errors[0],
		"missing 'id'",
		true
	)


func _load_catalog_entries(store_id: String) -> Array[Dictionary]:
	var path: String = CATALOG_FILES[store_id]
	var raw: Variant = DataLoader.load_json(path)
	assert_typeof(
		raw,
		TYPE_ARRAY,
		"Catalog '%s' should parse as an array" % path
	)
	var entries: Array[Dictionary] = []
	if raw is not Array:
		return entries
	for item: Variant in raw:
		assert_typeof(
			item,
			TYPE_DICTIONARY,
			"Catalog '%s' should contain item dictionaries" % path
		)
		if item is Dictionary:
			entries.append(item)
	return entries


func _assert_item_entry_has_required_fields(
	entry: Dictionary, store_id: String
) -> void:
	for field: String in REQUIRED_ITEM_FIELDS:
		var has_field: bool = _item_entry_has_required_field(entry, field)
		assert_true(
			has_field,
			"Catalog '%s' item '%s' should have required field '%s'"
			% [store_id, str(entry.get("id", "<missing-id>")), field]
		)


func _item_entry_has_required_field(
	entry: Dictionary, field: String
) -> bool:
	match field:
		_:
			return entry.has(field)


func _unexpected_load_errors(errors: Array[String]) -> Array[String]:
	var unexpected: Array[String] = []
	for error: String in errors:
		if error.begins_with("duplicate id "):
			continue
		unexpected.append(error)
	return unexpected
