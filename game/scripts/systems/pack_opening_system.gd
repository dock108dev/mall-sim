## Handles booster pack opening logic for the PocketCreatures card shop.
class_name PackOpeningSystem
extends RefCounted

const PACK_CATEGORY: String = "booster_packs"
const PACK_SUBCATEGORY: String = "sealed"
const CARD_CATEGORY: String = "singles"
const CARDS_CONFIG_PATH: String = (
	"res://game/content/pocket_creatures_cards.json"
)

var _data_loader: DataLoader = null
var _inventory_system: InventorySystem = null
var _economy_system: EconomySystem = null

var _commons_per_pack: int = 6
var _uncommons_per_pack: int = 3
var _energy_per_pack: int = 1
var _rare_slot_rare_chance: float = 0.64
var _rare_slot_holo_chance: float = 0.33
var _rarity_price_table: Dictionary = {}
var _pack_conditions: Array[String] = ["good", "near_mint", "mint"]
var _set_tags: Array[String] = [
	"base_set", "jungle", "fossil",
	"team_rocket", "neo_genesis", "crystal_storm",
]
var _opening_ids: Dictionary = {}
var _pending_pack_id: String = ""
var _pending_pack_cards: Array[ItemInstance] = []
var _pending_preview_ids: Array[String] = []


## Initializes with required system references.
func initialize(
	data_loader: DataLoader,
	inventory_system: InventorySystem,
	economy_system: EconomySystem = null,
) -> void:
	_data_loader = data_loader
	_inventory_system = inventory_system
	_economy_system = economy_system
	_load_cards_config()


## Returns true if the item is an openable booster pack.
func is_booster_pack(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	return (
		item.definition.category == PACK_CATEGORY
		and item.definition.subcategory == PACK_SUBCATEGORY
	)


## Returns the cost to open a pack (its base price).
func get_pack_cost(item: ItemInstance) -> float:
	if not item or not item.definition:
		return 0.0
	return item.definition.base_price


## Returns true if the player can afford to open the pack.
func can_afford_pack(item: ItemInstance) -> bool:
	if not _economy_system:
		return true
	return _economy_system.get_cash() >= get_pack_cost(item)


## Opens a booster pack, charging the player and creating card instances.
## Returns the generated card instances, or an empty array on failure.
func open_pack(
	pack_instance_id: String,
) -> Array[ItemInstance]:
	if has_pending_pack_results():
		push_warning(
			"PackOpeningSystem: pending pack '%s' must be committed first"
			% _pending_pack_id
		)
		return []
	var cards: Array[ItemInstance] = _prepare_pack_cards(pack_instance_id)
	if cards.is_empty():
		return []
	if not _register_cards(cards):
		return []
	EventBus.pack_opened.emit(pack_instance_id, _collect_card_ids(cards))
	return cards


## Generates card results for the reveal UI and defers inventory commit.
func open_pack_preview(
	pack_instance_id: String,
) -> Array[ItemInstance]:
	if has_pending_pack_results():
		push_warning(
			"PackOpeningSystem: pending pack '%s' must be committed first"
			% _pending_pack_id
		)
		return []
	var cards: Array[ItemInstance] = _prepare_pack_cards(pack_instance_id)
	if cards.is_empty():
		return []
	_pending_pack_id = pack_instance_id
	_pending_pack_cards = cards
	_pending_preview_ids = _collect_card_ids(cards)
	return cards


## Commits the currently revealed pack results into inventory and emits pack_opened.
func commit_pack_results(revealed_cards: Array[Dictionary]) -> bool:
	if not has_pending_pack_results():
		push_warning("PackOpeningSystem: no pending pack results to commit")
		return false
	if not _revealed_cards_match_pending(revealed_cards):
		push_error(
			"PackOpeningSystem: revealed card payload does not match pending pack '%s'"
			% _pending_pack_id
		)
		return false
	if not _register_cards(_pending_pack_cards):
		return false
	EventBus.pack_opened.emit(
		_pending_pack_id,
		_collect_card_ids(_pending_pack_cards),
	)
	_clear_pending_pack_results()
	return true


## Returns true when a pack preview is waiting for UI confirmation.
func has_pending_pack_results() -> bool:
	return not _pending_pack_id.is_empty() \
		and not _pending_pack_cards.is_empty()


## Returns a four-tier rarity label suited for preview UI cards.
func get_preview_rarity(card: ItemInstance) -> String:
	if not card or not card.definition:
		return "common"
	var rarity_key: String = card.definition.rarity
	if rarity_key == "common":
		rarity_key = card.definition.subcategory
	match rarity_key:
		"uncommon":
			return "uncommon"
		"rare":
			return "rare"
		"rare_holo", "secret_rare", "very_rare", "legendary", "ultra_rare":
			return "ultra_rare"
		_:
			return "common"


func _prepare_pack_cards(
	pack_instance_id: String,
) -> Array[ItemInstance]:
	if not _data_loader or not _inventory_system:
		push_warning("PackOpeningSystem: not initialized")
		return []

	if _opening_ids.has(pack_instance_id):
		push_warning(
			"PackOpeningSystem: pack '%s' already being opened"
			% pack_instance_id
		)
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

	if _economy_system:
		var cost: float = get_pack_cost(pack)
		if not _economy_system.charge(cost, "Pack opening"):
			push_warning(
				"PackOpeningSystem: insufficient funds for pack '%s'"
				% pack_instance_id
			)
			return []

	_opening_ids[pack_instance_id] = true

	var set_tag: String = _get_set_tag(pack)
	if set_tag.is_empty():
		push_warning(
			"PackOpeningSystem: no set tag found for pack '%s'"
			% pack_instance_id
		)
		_opening_ids.erase(pack_instance_id)
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
		_opening_ids.erase(pack_instance_id)
		return []

	_inventory_system.remove_item(pack_instance_id)
	_opening_ids.erase(pack_instance_id)
	return cards


## Extracts the set identifier tag from a pack's tags.
func _get_set_tag(pack: ItemInstance) -> String:
	for tag: String in pack.definition.tags:
		if tag in _set_tags:
			return tag
	return ""


## Checks if a pack is first edition via its tags.
func _is_first_edition(pack: ItemInstance) -> bool:
	return "first_edition" in pack.definition.tags


## Generates cards: commons, uncommons, 1 rare slot, 1 energy.
func _generate_cards(
	set_tag: String, is_first_edition: bool,
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
	for i: int in range(_commons_per_pack):
		var def: ItemDefinition = commons[randi() % commons.size()]
		cards.append(_create_card(def))

	var uncommons: Array[ItemDefinition] = pool["uncommon"]
	for i: int in range(_uncommons_per_pack):
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
	set_tag: String, is_first_edition: bool,
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
	pool: Dictionary, item: ItemDefinition,
) -> void:
	match item.subcategory:
		"common":
			pool["common"].append(item)
		"uncommon":
			pool["uncommon"].append(item)
		"rare":
			pool["rare"].append(item)
		"rare_holo":
			pool["holo_rare"].append(item)
		"secret_rare":
			pool["secret_rare"].append(item)
		"energy":
			pool["energy"].append(item)
		_:
			push_error(
				"PackOpeningSystem: unrecognized subcategory '%s' for item '%s'"
				% [item.subcategory, item.id]
			)


## Rolls the rare slot using weighted RNG from config.
func _roll_rare_slot(pool: Dictionary) -> ItemInstance:
	var roll: float = randf()
	var rares: Array[ItemDefinition] = pool["rare"]
	var holos: Array[ItemDefinition] = pool["holo_rare"]
	var secrets: Array[ItemDefinition] = pool["secret_rare"]

	if roll < _rare_slot_rare_chance and not rares.is_empty():
		return _create_card(rares[randi() % rares.size()])
	elif roll < _rare_slot_rare_chance + _rare_slot_holo_chance:
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


## Creates a card ItemInstance with random condition from config.
func _create_card(def: ItemDefinition) -> ItemInstance:
	var condition: String = _pack_conditions[
		randi() % _pack_conditions.size()
	]
	var inst: ItemInstance = ItemInstance.create(
		def, condition, 0, 0.0
	)
	inst.current_location = "backroom"
	return inst


## Loads rarity weights, price table, and pack formula from JSON.
func _load_cards_config() -> void:
	if not FileAccess.file_exists(CARDS_CONFIG_PATH):
		push_warning(
			"PackOpeningSystem: config not found at %s"
			% CARDS_CONFIG_PATH
		)
		return
	var file: FileAccess = FileAccess.open(
		CARDS_CONFIG_PATH, FileAccess.READ
	)
	if not file:
		push_warning(
			"PackOpeningSystem: failed to open %s"
			% CARDS_CONFIG_PATH
		)
		return
	var json := JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error(
			"PackOpeningSystem: JSON parse error in %s: %s"
			% [CARDS_CONFIG_PATH, json.get_error_message()]
		)
		return
	var data: Variant = json.data
	if not data is Dictionary:
		push_error("PackOpeningSystem: config root must be a Dictionary")
		return
	var config: Dictionary = data as Dictionary
	_apply_config(config)


## Applies parsed config values.
func _apply_config(config: Dictionary) -> void:
	var formula: Variant = config.get("pack_formula", {})
	if formula is Dictionary:
		_commons_per_pack = int(formula.get("commons", _commons_per_pack))
		_uncommons_per_pack = int(
			formula.get("uncommons", _uncommons_per_pack)
		)
		_energy_per_pack = int(
			formula.get("energy", _energy_per_pack)
		)

	var weights: Variant = config.get("rarity_weights", {})
	if weights is Dictionary:
		_rare_slot_rare_chance = float(
			weights.get("rare", _rare_slot_rare_chance)
		)
		_rare_slot_holo_chance = float(
			weights.get("holo_rare", _rare_slot_holo_chance)
		)

	var prices: Variant = config.get("rarity_price_table", {})
	if prices is Dictionary:
		_rarity_price_table = prices as Dictionary

	var conditions: Variant = config.get("pack_conditions", [])
	if conditions is Array and not conditions.is_empty():
		_pack_conditions.clear()
		for cond: Variant in conditions:
			if cond is String:
				_pack_conditions.append(cond as String)

	var tags: Variant = config.get("set_tags", [])
	if tags is Array and not tags.is_empty():
		_set_tags.clear()
		for tag: Variant in tags:
			if tag is String:
				_set_tags.append(tag as String)


func _register_cards(cards: Array[ItemInstance]) -> bool:
	for card: ItemInstance in cards:
		if not _inventory_system.register_item(card):
			push_error(
				"PackOpeningSystem: failed to register card '%s'"
				% card.instance_id
			)
			return false
	return true


func _collect_card_ids(cards: Array[ItemInstance]) -> Array[String]:
	var card_ids: Array[String] = []
	for card: ItemInstance in cards:
		card_ids.append(String(card.instance_id))
	return card_ids


func _revealed_cards_match_pending(
	revealed_cards: Array[Dictionary],
) -> bool:
	if revealed_cards.is_empty():
		return false
	for revealed_card: Dictionary in revealed_cards:
		var card_id: String = str(revealed_card.get("id", ""))
		if card_id.is_empty():
			return false
		if not _pending_preview_ids.has(card_id):
			return false
	return true


func _clear_pending_pack_results() -> void:
	_pending_pack_id = ""
	_pending_pack_cards.clear()
	_pending_preview_ids.clear()
