# gdlint:disable=max-returns
## Handles booster pack opening logic for the PocketCreatures card shop.
class_name PackOpeningSystem
extends RefCounted

const PACK_CATEGORY: String = "booster_packs"
const PACK_SUBCATEGORY: String = "sealed"
const CARD_CATEGORY: String = "singles"

const _VALID_RARITIES: Array[String] = [
	"common", "uncommon", "rare", "rare_holo",
	"holo_rare", "secret_rare", "ultra_rare", "energy",
]

var _data_loader: DataLoader = null
var _inventory_system: InventorySystem = null
var _economy_system: EconomySystem = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rng_manually_seeded: bool = false

var _commons_per_pack: int = 6
var _uncommons_per_pack: int = 3
var _energy_per_pack: int = 1
var _rare_slot_rare_chance: float = 0.90
var _rare_slot_holo_chance: float = 0.09
var _pack_conditions: Array[String] = ["good", "near_mint", "mint"]
var _set_tags: Array[String] = [
	"base_set", "canopy", "deep_dig",
	"shadow_set", "neo_spark", "crystal_storm",
]
## Per-set-tag pack type configs loaded from packs.json; keyed by set_tag.
var _pack_type_configs: Dictionary = {}
var _opening_ids: Dictionary = {}
var _pending_pack_id: String = ""
var _pending_pack_cards: Array[ItemInstance] = []
var _pending_preview_ids: Array[String] = []


## Initializes with required system references and loads pack type configs.
func initialize(
	data_loader: DataLoader,
	inventory_system: InventorySystem,
	economy_system: EconomySystem = null,
) -> void:
	_data_loader = data_loader
	_inventory_system = inventory_system
	_economy_system = economy_system
	_load_pack_types(data_loader.get_pocket_creatures_packs())


## Seeds the internal RNG for deterministic pack opening.
## Sets _rng_manually_seeded so _prepare_pack_cards skips pack-id reseeding.
func seed_rng(rng_seed: int) -> void:
	_rng.seed = rng_seed
	_rng_manually_seeded = true


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
		# Pack was already removed and money already charged inside
		# _prepare_pack_cards. _register_cards failure (e.g. backroom full
		# during pack open) currently leaves the player with no pack and no
		# cards. Surface it loud so it shows up in CI / telemetry instead of
		# being a silent loss. Rollback would require a refund + re-register
		# of the pack ItemInstance — see error-handling-report.md
		# Escalations §E1.
		push_error(
			(
				"PackOpeningSystem: register failed for pack '%s' after pack was "
				+ "consumed — cards lost. Backroom likely at capacity."
			)
			% pack_instance_id
		)
		return []
	EventBus.pack_opened.emit(pack_instance_id, _collect_card_ids(cards))
	EventBus.items_revealed.emit(pack_instance_id, cards)
	_emit_rare_pull_if_needed(cards, pack_instance_id)
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
		push_warning(
			"PackOpeningSystem: revealed card payload does not match pending pack '%s'"
			% _pending_pack_id
		)
		return false
	if not _register_cards(_pending_pack_cards):
		# Same loss mode as open_pack: pack was removed during preview, money
		# was charged, register failure here (backroom full) leaves the
		# player with no cards. Tightened from a silent return false to a
		# loud push_error so the loss is observable. Rollback gap tracked in
		# error-handling-report.md Escalations §E1.
		push_error(
			(
				"PackOpeningSystem: register failed at commit for pack '%s' — "
				+ "cards lost. Backroom likely at capacity."
			)
			% _pending_pack_id
		)
		return false
	EventBus.pack_opened.emit(
		_pending_pack_id,
		_collect_card_ids(_pending_pack_cards),
	)
	_emit_rare_pull_if_needed(_pending_pack_cards, _pending_pack_id)
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

	var day: int = 0
	if Engine.has_singleton("GameManager"):
		day = (Engine.get_singleton("GameManager") as GameManager).get_current_day()
	if not _rng_manually_seeded:
		_rng.seed = hash(pack_instance_id + str(day))

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


## Generates cards using per-pack-type config when available, else global defaults.
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

	var pack_cfg: Dictionary = _pack_type_configs.get(set_tag, {})
	var commons_count: int = int(pack_cfg.get("commons_count", _commons_per_pack))
	var uncommons_count: int = int(pack_cfg.get("uncommons_count", _uncommons_per_pack))
	var rare_chance: float = float(pack_cfg.get("rare_chance", _rare_slot_rare_chance))
	var holo_chance: float = float(pack_cfg.get("holo_chance", _rare_slot_holo_chance))

	var cards: Array[ItemInstance] = []

	var commons: Array[ItemDefinition] = pool["common"]
	for i: int in range(commons_count):
		var def: ItemDefinition = commons[_rng.randi() % commons.size()]
		cards.append(_create_card(def))

	var uncommons: Array[ItemDefinition] = pool["uncommon"]
	for i: int in range(uncommons_count):
		var def: ItemDefinition = uncommons[_rng.randi() % uncommons.size()]
		cards.append(_create_card(def))

	var rare_card: ItemInstance = _roll_rare_slot(pool, rare_chance, holo_chance)
	if rare_card:
		cards.append(rare_card)
	else:
		push_warning("PackOpeningSystem: rare slot roll produced no card — substituting common")
		var fallback: ItemDefinition = commons[_rng.randi() % commons.size()]
		cards.append(_create_card(fallback))

	var energy_card: ItemInstance = _pick_energy(pool)
	if energy_card:
		cards.append(energy_card)
	else:
		push_warning("PackOpeningSystem: energy slot produced no card — substituting common")
		var fallback: ItemDefinition = commons[_rng.randi() % commons.size()]
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
			push_warning(
				"PackOpeningSystem: unrecognized subcategory '%s' for item '%s'"
				% [item.subcategory, item.id]
			)


## Rolls the rare slot using weighted RNG.
func _roll_rare_slot(
	pool: Dictionary, rare_chance: float, holo_chance: float,
) -> ItemInstance:
	var roll: float = _rng.randf()
	var rares: Array[ItemDefinition] = pool["rare"]
	var holos: Array[ItemDefinition] = pool["holo_rare"]
	var secrets: Array[ItemDefinition] = pool["secret_rare"]

	if roll < rare_chance and not rares.is_empty():
		return _create_card(rares[_rng.randi() % rares.size()])
	if roll < rare_chance + holo_chance:
		if not holos.is_empty():
			return _create_card(holos[_rng.randi() % holos.size()])
		if not rares.is_empty():
			return _create_card(rares[_rng.randi() % rares.size()])
		return null
	if not secrets.is_empty():
		return _create_card(
			secrets[_rng.randi() % secrets.size()]
		)
	if not holos.is_empty():
		return _create_card(holos[_rng.randi() % holos.size()])
	if not rares.is_empty():
		return _create_card(rares[_rng.randi() % rares.size()])
	return null


## Picks a random energy card from the pool.
func _pick_energy(pool: Dictionary) -> ItemInstance:
	var energies: Array[ItemDefinition] = pool["energy"]
	if energies.is_empty():
		return null
	return _create_card(energies[_rng.randi() % energies.size()])


## Creates a card ItemInstance with random condition.
func _create_card(def: ItemDefinition) -> ItemInstance:
	var condition: String = _pack_conditions[
		_rng.randi() % _pack_conditions.size()
	]
	var inst: ItemInstance = ItemInstance.create(
		def, condition, 0, 0.0
	)
	inst.current_location = "backroom"
	return inst


## Parses pack type config entries from DataLoader and indexes by set_tag.
func _load_pack_types(packs: Array) -> void:
	_pack_type_configs.clear()
	for entry: Variant in packs:
		if entry is not Dictionary:
			continue
		var set_tag: String = str(entry.get("set_tag", ""))
		if set_tag.is_empty():
			continue
		var rw: Variant = entry.get("rarity_weights", {})
		var weights: Dictionary = rw as Dictionary if rw is Dictionary else {}
		var slots: Variant = entry.get("slots", [])
		var cfg: Dictionary = {
			"slot_count": int(entry.get("slot_count", 11)),
			"commons_count": _count_slot_type(slots, "common"),
			"uncommons_count": _count_slot_type(slots, "uncommon"),
			"rare_chance": float(weights.get("rare", _rare_slot_rare_chance)),
			"holo_chance": float(weights.get("holo_rare", _rare_slot_holo_chance)),
			"cost": float(entry.get("cost", 3.99)),
		}
		_pack_type_configs[set_tag] = cfg
		if set_tag not in _set_tags:
			_set_tags.append(set_tag)


func _count_slot_type(slots: Variant, slot_type: String) -> int:
	if slots is not Array:
		return 0
	for slot: Variant in slots:
		if slot is Dictionary and str(slot.get("type", "")) == slot_type:
			return int(slot.get("count", 0))
	return 0


func _register_cards(cards: Array[ItemInstance]) -> bool:
	# Roll back partial registrations: if the third card fails, the first two
	# are already in InventorySystem._items but are about to be discarded by
	# the caller (no signal emitted, no UI update). Without this, a backroom
	# capacity boundary leaves orphaned ItemInstances stuck in inventory while
	# the UI thinks the pack open failed entirely. See
	# docs/audits/error-handling-report.md §F1.
	var registered: Array[ItemInstance] = []
	for card: ItemInstance in cards:
		if not _inventory_system.register_item(card):
			# Inventory already push_warnings the underlying reason (capacity,
			# unresolved store_type, etc.). Avoid a second push_error so CI's
			# error audit stays clean for recoverable register failures.
			push_warning(
				"PackOpeningSystem: failed to register card '%s'"
				% card.instance_id
			)
			for registered_card: ItemInstance in registered:
				_inventory_system.remove_item(registered_card.instance_id)
			return false
		registered.append(card)
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


## Emits rare_pull_occurred when any card is holo, secret, or ultra rare.
func _emit_rare_pull_if_needed(
	cards: Array[ItemInstance], pack_id: String
) -> void:
	for card: ItemInstance in cards:
		if not card or not card.definition:
			continue
		if card.definition.subcategory in [
			"rare_holo", "holo_rare", "secret_rare", "ultra_rare"
		]:
			EventBus.rare_pull_occurred.emit(pack_id)
			return
