## Handles booster pack opening logic for the PocketCreatures card shop.
class_name PackOpeningSystem
extends RefCounted

const PACK_SUBCATEGORY: String = "booster_pack"
const PACK_CATEGORY: String = "sealed_product"
const CARD_CATEGORY: String = "card_singles"
const COMMONS_PER_PACK: int = 6
const UNCOMMONS_PER_PACK: int = 3
const ENERGY_PER_PACK: int = 1
const RARE_SLOT_RARE_CHANCE: float = 0.64
const RARE_SLOT_HOLO_CHANCE: float = 0.33
const PACK_CONDITIONS: Array[String] = ["good", "near_mint", "mint"]

const SET_TAGS: Array[String] = [
	"base_set", "jungle", "fossil",
	"neo_genesis", "gym_heroes", "crystal_storm",
]

var _data_loader: DataLoader = null
var _inventory_system: InventorySystem = null


## Initializes with required system references.
func initialize(
	data_loader: DataLoader,
	inventory_system: InventorySystem
) -> void:
	_data_loader = data_loader
	_inventory_system = inventory_system


## Returns true if the item is an openable booster pack.
func is_booster_pack(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	return (
		item.definition.category == PACK_CATEGORY
		and item.definition.subcategory == PACK_SUBCATEGORY
	)


## Opens a booster pack, removing it and creating 11 card instances.
## Returns the generated card instances, or an empty array on failure.
func open_pack(
	pack_instance_id: String
) -> Array[ItemInstance]:
	if not _data_loader or not _inventory_system:
		push_warning("PackOpeningSystem: not initialized")
		return []
	var pack: ItemInstance = _inventory_system.get_item(
		pack_instance_id
	)
	if not pack:
		push_warning(
			"PackOpeningSystem: pack '%s' not found"
			% pack_instance_id
		)
		return []
	if not is_booster_pack(pack):
		push_warning(
			"PackOpeningSystem: item '%s' is not a booster pack"
			% pack_instance_id
		)
		return []

	var set_tag: String = _get_set_tag(pack)
	if set_tag.is_empty():
		push_warning(
			"PackOpeningSystem: no set tag found for pack '%s'"
			% pack_instance_id
		)
		return []

	var is_first_edition: bool = _is_first_edition(pack)
	var cards: Array[ItemInstance] = _generate_cards(
		set_tag, is_first_edition
	)
	if cards.is_empty():
		push_warning(
			"PackOpeningSystem: failed to generate cards for '%s'"
			% pack_instance_id
		)
		return []

	_inventory_system.remove_item(pack_instance_id)

	var card_ids: Array[String] = []
	for card: ItemInstance in cards:
		_inventory_system.register_item(card)
		card_ids.append(card.instance_id)

	EventBus.pack_opened.emit(pack_instance_id, card_ids)
	return cards


## Extracts the set identifier tag from a pack's tags.
func _get_set_tag(pack: ItemInstance) -> String:
	for tag: String in pack.definition.tags:
		if tag in SET_TAGS:
			return tag
	return ""


## Checks if a pack is first edition via its tags.
func _is_first_edition(pack: ItemInstance) -> bool:
	return "first_edition" in pack.definition.tags


## Generates 11 cards: 6C, 3U, 1 rare slot, 1 energy.
func _generate_cards(
	set_tag: String, is_first_edition: bool
) -> Array[ItemInstance]:
	var pool: Dictionary = _build_card_pool(
		set_tag, is_first_edition
	)
	if pool.get("common", []).is_empty():
		push_warning(
			"PackOpeningSystem: no commons found for set '%s'"
			% set_tag
		)
		return []
	if pool.get("uncommon", []).is_empty():
		push_warning(
			"PackOpeningSystem: no uncommons found for set '%s'"
			% set_tag
		)
		return []

	var cards: Array[ItemInstance] = []

	var commons: Array[ItemDefinition] = pool["common"]
	for i: int in range(COMMONS_PER_PACK):
		var def: ItemDefinition = commons[randi() % commons.size()]
		cards.append(_create_card(def))

	var uncommons: Array[ItemDefinition] = pool["uncommon"]
	for i: int in range(UNCOMMONS_PER_PACK):
		var def: ItemDefinition = uncommons[
			randi() % uncommons.size()
		]
		cards.append(_create_card(def))

	var rare_card: ItemInstance = _roll_rare_slot(pool)
	if rare_card:
		cards.append(rare_card)
	else:
		var fallback: ItemDefinition = commons[
			randi() % commons.size()
		]
		cards.append(_create_card(fallback))

	var energy_card: ItemInstance = _pick_energy(pool)
	if energy_card:
		cards.append(energy_card)
	else:
		var fallback: ItemDefinition = commons[
			randi() % commons.size()
		]
		cards.append(_create_card(fallback))

	return cards


## Builds categorized pools of card definitions for a set.
func _build_card_pool(
	set_tag: String, is_first_edition: bool
) -> Dictionary:
	var pool: Dictionary = {
		"common": [] as Array[ItemDefinition],
		"uncommon": [] as Array[ItemDefinition],
		"rare": [] as Array[ItemDefinition],
		"holo_rare": [] as Array[ItemDefinition],
		"secret_rare": [] as Array[ItemDefinition],
		"energy": [] as Array[ItemDefinition],
	}
	var all_items: Array[ItemDefinition] = (
		_data_loader.get_items_by_store("pocket_creatures")
	)
	for item: ItemDefinition in all_items:
		if item.category != CARD_CATEGORY:
			continue
		if set_tag not in item.tags:
			if item.subcategory != "energy":
				continue
		var has_first_ed: bool = "first_edition" in item.tags
		if is_first_edition and has_first_ed:
			_add_to_pool(pool, item)
		elif not is_first_edition and not has_first_ed:
			_add_to_pool(pool, item)

	return pool


## Adds a card definition to the appropriate pool bucket.
func _add_to_pool(
	pool: Dictionary, item: ItemDefinition
) -> void:
	match item.subcategory:
		"common":
			pool["common"].append(item)
		"uncommon":
			pool["uncommon"].append(item)
		"rare":
			pool["rare"].append(item)
		"holo_rare":
			pool["holo_rare"].append(item)
		"secret_rare":
			pool["secret_rare"].append(item)
		"energy":
			pool["energy"].append(item)


## Rolls the rare slot: 64% rare, 33% holo rare, 3% secret rare.
func _roll_rare_slot(pool: Dictionary) -> ItemInstance:
	var roll: float = randf()
	var rares: Array[ItemDefinition] = pool["rare"]
	var holos: Array[ItemDefinition] = pool["holo_rare"]
	var secrets: Array[ItemDefinition] = pool["secret_rare"]

	if roll < RARE_SLOT_RARE_CHANCE and not rares.is_empty():
		return _create_card(rares[randi() % rares.size()])
	elif roll < RARE_SLOT_RARE_CHANCE + RARE_SLOT_HOLO_CHANCE:
		if not holos.is_empty():
			return _create_card(holos[randi() % holos.size()])
		if not rares.is_empty():
			return _create_card(rares[randi() % rares.size()])
	else:
		if not secrets.is_empty():
			return _create_card(
				secrets[randi() % secrets.size()]
			)
		if not holos.is_empty():
			return _create_card(holos[randi() % holos.size()])
		if not rares.is_empty():
			return _create_card(rares[randi() % rares.size()])
	return null


## Picks a random energy card from the pool.
func _pick_energy(pool: Dictionary) -> ItemInstance:
	var energies: Array[ItemDefinition] = pool["energy"]
	if energies.is_empty():
		return null
	return _create_card(energies[randi() % energies.size()])


## Creates a card ItemInstance with random condition (good-mint).
func _create_card(def: ItemDefinition) -> ItemInstance:
	var condition: String = PACK_CONDITIONS[
		randi() % PACK_CONDITIONS.size()
	]
	var inst: ItemInstance = ItemInstance.create(
		def, condition, 0, 0.0
	)
	inst.current_location = "backroom"
	return inst
