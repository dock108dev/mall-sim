## Guards diminishing-rarity pricing against store customer budget ceilings.
extends GutTest


const STORE_ITEM_PATHS: Dictionary = {
	"sports_memorabilia": "res://game/content/items/sports_memorabilia.json",
	"retro_games": "res://game/content/items/retro_games.json",
	"video_rental": "res://game/content/items/video_rental.json",
	"pocket_creatures": "res://game/content/items/pocket_creatures.json",
	"electronics": "res://game/content/items/consumer_electronics.json",
}
const STORE_CUSTOMER_PATHS: Dictionary = {
	"sports_memorabilia": "res://game/content/customers/sports_store_customers.json",
	"retro_games": "res://game/content/customers/retro_games_customers.json",
	"video_rental": "res://game/content/customers/video_rental_customers.json",
	"pocket_creatures": "res://game/content/customers/pocket_creatures_customers.json",
	"electronics": "res://game/content/customers/electronics_customers.json",
}
const MAX_REPUTATION_BUDGET_MULTIPLIER: float = 2.0

var _economy: EconomySystem


func before_all() -> void:
	DifficultySystemSingleton._current_tier_id = &"normal"
	DifficultySystemSingleton._tiers = {
		&"normal": {
			"modifiers": {
				"starting_cash_multiplier": 1.0,
			},
		},
	}


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()


func test_store_catalog_market_values_fit_customer_budget_caps() -> void:
	for store_id: String in STORE_ITEM_PATHS:
		var max_budget: float = _get_store_max_budget(store_id)
		var items: Array[ItemDefinition] = _load_item_definitions(
			STORE_ITEM_PATHS[store_id]
		)
		assert_gt(
			max_budget, 0.0,
			"Store '%s' must have a positive budget ceiling" % store_id
		)
		assert_gt(
			items.size(), 0,
			"Store '%s' must define at least one item" % store_id
		)
		for item_def: ItemDefinition in items:
			var item: ItemInstance = ItemInstance.create_from_definition(
				item_def, "good"
			)
			var value: float = _economy.calculate_market_value(item)
			assert_lte(
				value, max_budget,
				"%s market value %.2f exceeds %s max budget %.2f"
				% [item_def.id, value, store_id, max_budget]
			)


func _get_store_max_budget(store_id: String) -> float:
	var max_budget: float = 0.0
	for entry: Dictionary in _load_array_entries(STORE_CUSTOMER_PATHS[store_id]):
		var budget_range: Variant = entry.get("budget_range", [])
		if budget_range is not Array or budget_range.size() < 2:
			continue
		var budget_values: Array = budget_range as Array
		max_budget = maxf(
			max_budget,
			float(budget_values[1]) * MAX_REPUTATION_BUDGET_MULTIPLIER
		)
	return max_budget


func _load_item_definitions(path: String) -> Array[ItemDefinition]:
	var defs: Array[ItemDefinition] = []
	for entry: Dictionary in _load_array_entries(path):
		defs.append(_build_item_definition(entry))
	return defs


func _load_array_entries(path: String) -> Array[Dictionary]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var data: Variant = JSON.parse_string(file.get_as_text())
	var entries: Array[Dictionary] = []
	if data is not Array:
		return entries
	for entry: Variant in data:
		if entry is Dictionary:
			entries.append(entry as Dictionary)
	return entries


func _build_item_definition(entry: Dictionary) -> ItemDefinition:
	var item_def := ItemDefinition.new()
	item_def.id = str(entry.get("id", ""))
	item_def.base_price = float(entry.get("base_price", 0.0))
	item_def.rarity = str(entry.get("rarity", "common"))
	item_def.category = str(entry.get("category", ""))
	item_def.tags = _string_name_array(entry.get("tags", []))
	return item_def


func _string_name_array(values: Variant) -> Array[StringName]:
	var names: Array[StringName] = []
	if values is Array:
		for value: Variant in values:
			names.append(StringName(str(value)))
	return names
