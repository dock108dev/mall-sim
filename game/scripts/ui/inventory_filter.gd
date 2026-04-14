## Filtering and item row building utilities for the InventoryPanel.
class_name InventoryFilter
extends RefCounted

const CONDITIONS: Array[String] = [
	"mint", "near_mint", "good", "fair", "poor",
]
const RARITIES: Array[String] = [
	"common", "uncommon", "rare", "very_rare", "legendary",
]


## Filters items by search text, condition, and rarity.
static func apply(
	items: Array[ItemInstance],
	search_text: String,
	condition: String,
	rarity: String,
) -> Array[ItemInstance]:
	var clean_search: String = search_text.strip_edges().to_lower()
	if clean_search.is_empty() and condition.is_empty() and rarity.is_empty():
		return items
	var result: Array[ItemInstance] = []
	for item: ItemInstance in items:
		if not item.definition:
			continue
		if not clean_search.is_empty():
			if item.definition.item_name.to_lower().find(clean_search) == -1:
				continue
		if not condition.is_empty() and item.condition != condition:
			continue
		if not rarity.is_empty() and item.definition.rarity != rarity:
			continue
		result.append(item)
	return result


## Calculates the total estimated value for a list of items.
static func total_value(items: Array[ItemInstance]) -> float:
	var total: float = 0.0
	for item: ItemInstance in items:
		total += item.get_current_value()
	return total


## Resolves condition filter index to string. Returns "" for "All".
static func condition_at_index(idx: int) -> String:
	if idx <= 0 or idx - 1 >= CONDITIONS.size():
		return ""
	return CONDITIONS[idx - 1]


## Resolves rarity filter index to string. Returns "" for "All".
static func rarity_at_index(idx: int) -> String:
	if idx <= 0 or idx - 1 >= RARITIES.size():
		return ""
	return RARITIES[idx - 1]


## Populates a condition OptionButton with "All" + each condition.
static func populate_condition_options(btn: OptionButton) -> void:
	btn.clear()
	btn.add_item("All Conditions", 0)
	for i: int in range(CONDITIONS.size()):
		btn.add_item(CONDITIONS[i].capitalize(), i + 1)
	btn.selected = 0


## Populates a rarity OptionButton with "All" + each rarity label.
static func populate_rarity_options(btn: OptionButton) -> void:
	btn.clear()
	btn.add_item("All Rarities", 0)
	for i: int in range(RARITIES.size()):
		var label: String = UIThemeConstants.get_rarity_label(
			RARITIES[i]
		)
		btn.add_item(label, i + 1)
	btn.selected = 0
