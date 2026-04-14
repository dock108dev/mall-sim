## Validates item catalog JSON files meet schema and content requirements.
extends GutTest

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
	"common", "uncommon", "rare", "very_rare", "legendary"
]


func test_minimum_item_counts_per_store() -> void:
	for store_id: String in REQUIRED_STORES:
		var items: Array[ItemDefinition] = (
			DataLoader.get_items_by_store(store_id)
		)
		var minimum: int = MIN_COUNTS[store_id]
		assert_gte(
			items.size(), minimum,
			"Store '%s' should have >= %d items, got %d"
			% [store_id, minimum, items.size()]
		)


func test_all_items_have_required_fields() -> void:
	var items: Array[ItemDefinition] = DataLoader.get_all_items()
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


func test_all_item_ids_unique() -> void:
	var items: Array[ItemDefinition] = DataLoader.get_all_items()
	var seen: Dictionary = {}
	for item: ItemDefinition in items:
		assert_false(
			seen.has(item.id),
			"Duplicate item ID: %s" % item.id
		)
		seen[item.id] = true


func test_store_types_match_canonical_ids() -> void:
	var items: Array[ItemDefinition] = DataLoader.get_all_items()
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
		DataLoader.get_items_by_store("sports")
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
		DataLoader.get_all_stores()
	)
	for store: StoreDefinition in stores:
		for item_id: String in store.starting_inventory:
			var item: ItemDefinition = DataLoader.get_item(item_id)
			assert_not_null(
				item,
				"Store '%s' starter item '%s' should exist"
				% [store.id, item_id]
			)
