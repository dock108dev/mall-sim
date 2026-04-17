## Validates items_electronics.json meets ISSUE-282 acceptance criteria.
extends GutTest

const VALID_CATEGORIES: Array[String] = [
	"portable_music", "gaming_handheld", "tv",
	"dvd_player", "home_console", "accessory",
]
const VALID_RARITIES: Array[String] = [
	"common", "uncommon", "rare", "legendary",
]
const MIN_ITEM_COUNT: int = 20
const MIN_DEMO_UNIT_COUNT: int = 5
const MIN_LAUNCH_SPIKE_COUNT: int = 4
const LAUNCH_SPIKE_MULTIPLIER_THRESHOLD: float = 1.5


func before_all() -> void:
	DataLoaderSingleton.load_all_content()


func _get_electronics_items() -> Array[ItemDefinition]:
	return DataLoaderSingleton.get_items_by_store("electronics")


func test_minimum_item_count() -> void:
	var items: Array[ItemDefinition] = _get_electronics_items()
	assert_gte(
		items.size(),
		MIN_ITEM_COUNT,
		"Electronics store should have >= %d items, got %d"
		% [MIN_ITEM_COUNT, items.size()]
	)


func test_all_required_fields_present() -> void:
	var items: Array[ItemDefinition] = _get_electronics_items()
	for item: ItemDefinition in items:
		assert_ne(item.id, "", "Item must have id")
		assert_ne(item.item_name, "", "Item '%s' must have display name" % item.id)
		assert_ne(
			item.category, "",
			"Item '%s' must have category" % item.id
		)
		assert_gt(
			item.base_price, 0.0,
			"Item '%s' must have positive base_price" % item.id
		)
		assert_true(
			item.rarity in VALID_RARITIES,
			"Item '%s' rarity '%s' invalid" % [item.id, item.rarity]
		)
		assert_true(
			item.can_be_demo_unit is bool,
			"Item '%s' missing can_be_demo_unit" % item.id
		)
		assert_true(
			item.monthly_depreciation_rate >= 0.0,
			"Item '%s' missing monthly_depreciation_rate" % item.id
		)
		assert_true(
			item.launch_spike_eligible is bool,
			"Item '%s' missing launch_spike_eligible" % item.id
		)
		assert_true(
			item.launch_spike_multiplier >= 1.0,
			"Item '%s' missing launch_spike_multiplier" % item.id
		)
		assert_true(
			item.supplier_tier > 0,
			"Item '%s' missing supplier_tier" % item.id
		)


func test_categories_are_valid() -> void:
	var items: Array[ItemDefinition] = _get_electronics_items()
	for item: ItemDefinition in items:
		if not item.category in VALID_CATEGORIES:
			continue
		assert_true(
			item.category in VALID_CATEGORIES,
			"Item '%s' category '%s' not in allowed list"
			% [item.id, item.category]
		)


func test_at_least_three_distinct_categories() -> void:
	var items: Array[ItemDefinition] = _get_electronics_items()
	var seen_categories: Dictionary = {}
	for item: ItemDefinition in items:
		seen_categories[item.category] = true
	assert_gte(
		seen_categories.size(),
		3,
		"Electronics catalog needs >= 3 distinct categories, got %d"
		% seen_categories.size()
	)


func test_demo_unit_minimum_count() -> void:
	var items: Array[ItemDefinition] = _get_electronics_items()
	var count: Array = [0]
	for item: ItemDefinition in items:
		if item.can_be_demo_unit:
			count[0] += 1
	assert_gte(
		count[0],
		MIN_DEMO_UNIT_COUNT,
		"Need >= %d demo-unit items, got %d" % [MIN_DEMO_UNIT_COUNT, count[0]]
	)


func test_launch_spike_minimum_count() -> void:
	var items: Array[ItemDefinition] = _get_electronics_items()
	var count: Array = [0]
	for item: ItemDefinition in items:
		var eligible: bool = item.launch_spike_eligible
		var multiplier: float = item.launch_spike_multiplier
		if eligible and multiplier > LAUNCH_SPIKE_MULTIPLIER_THRESHOLD:
			count[0] += 1
	assert_gte(
		count[0],
		MIN_LAUNCH_SPIKE_COUNT,
		"Need >= %d items with launch_spike_eligible and multiplier > %.1f, got %d"
		% [MIN_LAUNCH_SPIKE_COUNT, LAUNCH_SPIKE_MULTIPLIER_THRESHOLD, count[0]]
	)


func test_base_prices_in_valid_range() -> void:
	var items: Array[ItemDefinition] = _get_electronics_items()
	for item: ItemDefinition in items:
		assert_gte(
			item.base_price, 20.0,
			"Item '%s' base_price %.2f below minimum 20.0"
			% [item.id, item.base_price]
		)
		assert_lte(
			item.base_price, 800.0,
			"Item '%s' base_price %.2f above maximum 800.0"
			% [item.id, item.base_price]
		)


func test_depreciation_rates_in_valid_range() -> void:
	var items: Array[ItemDefinition] = _get_electronics_items()
	for item: ItemDefinition in items:
		var rate: float = item.monthly_depreciation_rate
		assert_gte(
			rate, 0.0,
			"Item '%s' monthly_depreciation_rate %.3f below 0.0" % [item.id, rate]
		)
		assert_lte(
			rate, 0.15,
			"Item '%s' monthly_depreciation_rate %.3f above 0.15" % [item.id, rate]
		)


func test_supplier_tiers_valid() -> void:
	var items: Array[ItemDefinition] = _get_electronics_items()
	for item: ItemDefinition in items:
		var tier: int = item.supplier_tier
		assert_gte(
			tier, 1,
			"Item '%s' supplier_tier %d below minimum 1" % [item.id, tier]
		)
		assert_lte(
			tier, 3,
			"Item '%s' supplier_tier %d above maximum 3" % [item.id, tier]
		)


func test_all_item_ids_unique() -> void:
	var items: Array[ItemDefinition] = DataLoaderSingleton.get_all_items()
	var seen: Dictionary = {}
	for item: ItemDefinition in items:
		assert_false(
			seen.has(item.id),
			"Duplicate item ID detected: %s" % item.id
		)
		seen[item.id] = true
