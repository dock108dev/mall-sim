## Starter inventory seeding helpers for RetroGames. Pulled out of
## retro_games.gd so the store controller stays focused on lifecycle wiring;
## this file owns the ContentRegistry lookups and ItemDefinition construction
## used at first-store-entry to populate the shelves.
class_name RetroGamesStarterSeed
extends RefCounted

## Upper bound on starter-inventory `quantity` per entry. Per-store shelf
## footprint tops out near 30 slots, so anything beyond this is a content
## authoring typo — clamp it before the loop so a stray three-digit value
## cannot stall the boot path.
const _MAX_STARTER_QUANTITY: int = 64


## Seeds the InventorySystem with the starter items declared in the store
## definition. No-op if the store already has inventory, the inventory system
## isn't wired up, or the entry is missing/malformed.
static func seed(
	store_id: StringName,
	store_definition: Dictionary,
	inventory_system: Node,
) -> void:
	if inventory_system == null:
		return
	var existing: Array[ItemInstance] = (
		inventory_system.get_items_for_store(String(store_id))
	)
	if not existing.is_empty():
		return
	var entry: Dictionary = store_definition
	if entry.is_empty():
		entry = ContentRegistry.get_entry(store_id)
	if entry.is_empty():
		push_error(
			"RetroGames: no ContentRegistry entry for %s" % store_id
		)
		return
	var starter_items: Variant = entry.get("starting_inventory", [])
	if starter_items is not Array:
		# §F-32 — non-Array `starting_inventory` is a content-authoring error;
		# warn so the typo surfaces in CI/dev logs rather than silently
		# shipping a store with no starter inventory.
		push_warning(
			"RetroGames: starting_inventory for %s is %s, expected Array"
			% [store_id, type_string(typeof(starter_items))]
		)
		return
	for item_data: Variant in starter_items as Array:
		_seed_entry(store_id, item_data, inventory_system)


static func _seed_entry(
	store_id: StringName, item_data: Variant, inventory_system: Node
) -> void:
	# `starting_inventory` accepts either bare item-id strings (the canonical
	# JSON form in store_definitions.json) or `{item_id, quantity, condition}`
	# dictionaries (legacy form retained for save-data compatibility).
	if item_data is String:
		_add_starter_item_by_id(
			store_id, item_data as String, 1, "", inventory_system
		)
		return
	if item_data is Dictionary:
		var dict := item_data as Dictionary
		var raw_id: Variant = dict.get("item_id", "")
		if not raw_id is String:
			push_warning(
				(
					"RetroGames: starting_inventory entry has non-String "
					+ "item_id %s for %s"
				)
				% [type_string(typeof(raw_id)), store_id]
			)
			return
		_add_starter_item_by_id(
			store_id,
			raw_id as String,
			int(dict.get("quantity", 1)),
			str(dict.get("condition", "")),
			inventory_system,
		)
		return
	push_warning(
		(
			"RetroGames: starting_inventory entry is %s, expected "
			+ "String or Dictionary (store=%s)"
		)
		% [type_string(typeof(item_data)), store_id]
	)


static func _add_starter_item_by_id(
	store_id: StringName,
	raw_id: String,
	quantity: int,
	condition: String,
	inventory_system: Node,
) -> void:
	if raw_id.is_empty() or quantity <= 0:
		return
	if quantity > _MAX_STARTER_QUANTITY:
		push_warning(
			(
				"RetroGames: starter quantity %d for '%s' exceeds cap %d; "
				+ "clamping (likely content authoring typo)"
			)
			% [quantity, raw_id, _MAX_STARTER_QUANTITY]
		)
		quantity = _MAX_STARTER_QUANTITY
	var canonical: StringName = ContentRegistry.resolve(raw_id)
	if canonical.is_empty():
		push_error("RetroGames: unknown item_id '%s'" % raw_id)
		return
	var entry: Dictionary = ContentRegistry.get_entry(canonical)
	if entry.is_empty():
		# §F-33 — `resolve()` succeeded so the alias map knows the id, but
		# the entry table doesn't. That's a registry inconsistency, not a
		# normal "unknown id" case; promote to push_error so CI catches it.
		push_error(
			"RetroGames: registry inconsistency — '%s' resolves to '%s' but has no entry"
			% [raw_id, canonical]
		)
		return
	var def: ItemDefinition = _build_definition_from_entry(canonical, entry)
	for i: int in range(quantity):
		var instance: ItemInstance = (
			ItemInstance.create_from_definition(def, condition)
		)
		inventory_system.add_item(store_id, instance)


static func _build_definition_from_entry(
	canonical_id: StringName, data: Dictionary
) -> ItemDefinition:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = String(canonical_id)
	if data.has("item_name"):
		def.item_name = str(data["item_name"])
	if data.has("base_price"):
		def.base_price = float(data["base_price"])
	if data.has("category"):
		def.category = str(data["category"])
	if data.has("rarity"):
		def.rarity = str(data["rarity"])
	if data.has("store_type"):
		def.store_type = str(data["store_type"])
	return def
