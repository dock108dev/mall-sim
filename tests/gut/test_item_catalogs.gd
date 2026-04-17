## Validates item catalog JSON files meet schema and content requirements.
extends GutTest

func before_all() -> void:
	DataLoaderSingleton.load_all_content()
	DifficultySystemSingleton._load_config()

const REQUIRED_STORES: Array[String] = [
	"sports", "retro_games", "rentals",
	"pocket_creatures", "electronics"
]

const MIN_COUNTS: Dictionary = {
	"sports": 20,
	"retro_games": 25,
	"rentals": 20,
	"pocket_creatures": 30,
	"electronics": 20
}

const VALID_RARITIES: Array[String] = [
	"common", "uncommon", "rare", "very_rare", "legendary",
	"ultra_rare", "secret_rare", "holographic", "rare_holo",
]
const ISSUE_139_RARITIES: Array[String] = [
	"common", "uncommon", "rare", "ultra_rare",
]


func test_minimum_item_counts_per_store() -> void:
	for store_id: String in REQUIRED_STORES:
		var items: Array[ItemDefinition] = (
			DataLoaderSingleton.get_items_by_store(store_id)
		)
		var minimum: int = MIN_COUNTS[store_id]
		assert_gte(
			items.size(), minimum,
			"Store '%s' should have >= %d items, got %d"
			% [store_id, minimum, items.size()]
		)


func test_all_items_have_required_fields() -> void:
	var items: Array[ItemDefinition] = DataLoaderSingleton.get_all_items()
	for item: ItemDefinition in items:
		assert_ne(item.id, "", "Item should have id")
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
			"Item '%s' rarity '%s' invalid" % [item.id, item.rarity]
		)
		assert_gt(
			item.condition_range.size(), 0,
			"Item '%s' should have condition_range" % item.id
		)


func test_catalog_json_entries_match_issue_139_schema() -> void:
	var catalog_paths: Array[String] = [
		"res://game/content/items/sports_memorabilia.json",
		"res://game/content/items/retro_games.json",
		"res://game/content/items/video_rental.json",
		"res://game/content/items/pocket_creatures.json",
		"res://game/content/items/consumer_electronics.json",
	]
	for path: String in catalog_paths:
		var data: Variant = DataLoaderSingleton.load_json(path)
		assert_true(data is Array, "Catalog should be an array: %s" % path)
		if data is not Array:
			continue
		for raw_entry: Variant in data:
			assert_true(raw_entry is Dictionary, "Entry should be object in %s" % path)
			if raw_entry is not Dictionary:
				continue
			var entry: Dictionary = raw_entry as Dictionary
			for key: String in [
				"id",
				"item_name",
				"store_type",
				"category",
				"base_price",
				"rarity",
				"condition_range",
				"description",
			]:
				assert_true(
					entry.has(key),
					"Entry '%s' in %s missing '%s'"
					% [entry.get("id", "?"), path, key]
				)
			assert_true(
				str(entry.get("rarity", "")) in ISSUE_139_RARITIES,
				"Entry '%s' in %s uses unsupported ISSUE-139 rarity '%s'"
				% [entry.get("id", "?"), path, entry.get("rarity", "")]
			)


func test_issue_139_catalog_ids_unique_across_target_files() -> void:
	var catalog_paths: Array[String] = [
		"res://game/content/items/sports_memorabilia.json",
		"res://game/content/items/retro_games.json",
		"res://game/content/items/video_rental.json",
		"res://game/content/items/pocket_creatures.json",
		"res://game/content/items/consumer_electronics.json",
	]
	var seen_ids: Dictionary = {}
	for path: String in catalog_paths:
		var data: Variant = DataLoaderSingleton.load_json(path)
		assert_true(data is Array, "Catalog should be an array: %s" % path)
		if data is not Array:
			continue
		for raw_entry: Variant in data:
			if raw_entry is not Dictionary:
				continue
			var entry: Dictionary = raw_entry as Dictionary
			var item_id: String = str(entry.get("id", ""))
			assert_false(
				seen_ids.has(item_id),
				"Duplicate ISSUE-139 item ID '%s' found in %s and %s"
				% [item_id, seen_ids.get(item_id, "?"), path]
			)
			seen_ids[item_id] = path


func test_all_item_ids_unique() -> void:
	var items: Array[ItemDefinition] = DataLoaderSingleton.get_all_items()
	var seen: Dictionary = {}
	for item: ItemDefinition in items:
		assert_false(
			seen.has(item.id),
			"Duplicate item ID: %s" % item.id
		)
		seen[item.id] = true


func test_store_types_match_canonical_ids() -> void:
	var items: Array[ItemDefinition] = DataLoaderSingleton.get_all_items()
	var store_ids: Array[StringName] = (
		ContentRegistry.get_all_ids("store")
	)
	for item: ItemDefinition in items:
		var resolved: StringName = ContentRegistry.resolve(
			item.store_type
		)
		assert_ne(
			resolved, &"",
			"Item '%s' store_type '%s' should resolve"
			% [item.id, item.store_type]
		)


func test_no_real_brand_names_in_sports() -> void:
	var items: Array[ItemDefinition] = (
		DataLoaderSingleton.get_items_by_store("sports")
	)
	var banned: Array[String] = [
		"Nike", "Adidas", "Topps", "Upper Deck", "Fleer",
		"Bowman", "Griffey", "Jordan", "Jeter", "Montana",
		"Mantle", "Ripken"
	]
	for item: ItemDefinition in items:
		for word: String in banned:
			assert_false(
				item.item_name.contains(word),
				"Item '%s' contains real name '%s'"
				% [item.id, word]
			)
			assert_false(
				item.description.contains(word),
				"Item '%s' description contains '%s'"
				% [item.id, word]
			)


func test_starting_inventory_references_valid() -> void:
	var stores: Array[StoreDefinition] = (
		DataLoaderSingleton.get_all_stores()
	)
	for store: StoreDefinition in stores:
		for item_id: String in store.starting_inventory:
			var item: ItemDefinition = DataLoaderSingleton.get_item(item_id)
			assert_not_null(
				item,
				"Store '%s' starter item '%s' should exist"
				% [store.id, item_id]
			)
