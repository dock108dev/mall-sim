## Controller for the PocketCreatures card shop lifecycle and hooks.
class_name PocketCreaturesStoreController
extends StoreController

const STORE_ID: StringName = &"pocket_creatures"
const STORE_TYPE: StringName = &"pocket_creatures"

var pack_opening_system: PackOpeningSystem = null
var tournament_system: TournamentSystem = null
var meta_shift_system: MetaShiftSystem = null
var _seasonal_event_system: SeasonalEventSystem = null
var _economy_system: EconomySystem = null
var _pack_inventory_count: int = 0
var _initialized: bool = false


func _ready() -> void:
	initialize()
	super._ready()


## Initializes pack tracking and connects inventory signals.
func initialize() -> void:
	if _initialized:
		return
	initialize_store(STORE_ID, STORE_TYPE)
	_pack_inventory_count = 0
	_connect_signal(EventBus.active_store_changed, _on_active_store_changed)
	_connect_signal(EventBus.inventory_item_added, _on_inventory_item_added)
	_connect_signal(EventBus.seasonal_event_started, _on_seasonal_event_started)
	_connect_signal(EventBus.tournament_resolved, _on_tournament_resolved)
	_initialized = true


## Sets the economy system reference for pack cost deduction.
func set_economy_system(system: EconomySystem) -> void:
	_economy_system = system


## Initializes the pack opening system with required references.
func initialize_pack_system(
	data_loader: DataLoader,
	inventory_system: InventorySystem,
) -> void:
	pack_opening_system = PackOpeningSystem.new()
	pack_opening_system.initialize(
		data_loader, inventory_system, _economy_system
	)


## Sets the tournament system reference for hosting tournaments.
func set_tournament_system(system: TournamentSystem) -> void:
	tournament_system = system


## Sets the meta shift system reference for competitive meta tracking.
func set_meta_shift_system(system: MetaShiftSystem) -> void:
	meta_shift_system = system


## Sets the seasonal event system reference for tournament price resolution.
func set_seasonal_event_system(system: SeasonalEventSystem) -> void:
	_seasonal_event_system = system


## Resolves the tournament-adjusted price for a card via PriceResolver.
## Includes tournament price_spike_multiplier in the audit trace when active.
func resolve_card_price(item_id: StringName) -> PriceResolver.Result:
	if not _inventory_system:
		return PriceResolver.Result.new()
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item or not item.definition:
		return PriceResolver.Result.new()
	var multipliers: Array = []
	if _seasonal_event_system:
		var spike: float = (
			_seasonal_event_system.get_tournament_price_spike_multiplier(item)
		)
		if not is_equal_approx(spike, 1.0):
			multipliers.append({
				"slot": "event",
				"label": "Tournament",
				"factor": spike,
				"detail": "Active tournament price spike",
			})
	return PriceResolver.resolve_for_item(
		item_id, item.definition.base_price, multipliers
	)


## Opens a booster pack, emits items_revealed, and returns card IDs.
func open_pack(item_id: StringName) -> Array[StringName]:
	if not pack_opening_system:
		push_warning("PocketCreaturesStoreController: pack system not set")
		return []
	var pack_result: Array[ItemInstance] = (
		pack_opening_system.open_pack(String(item_id))
	)
	if not pack_result.is_empty():
		EventBus.items_revealed.emit(String(item_id), pack_result)
	var card_ids: Array[StringName] = []
	for item: ItemInstance in pack_result:
		card_ids.append(StringName(item.instance_id))
	return card_ids


## Opens a booster pack and returns the full card ItemInstances.
func open_pack_with_cards(
	item_id: StringName,
) -> Array[ItemInstance]:
	if not pack_opening_system:
		push_warning("PocketCreaturesStoreController: pack system not set")
		return []
	return pack_opening_system.open_pack_preview(String(item_id))


## Returns true if the player can afford to open the given pack.
func can_afford_pack(item: ItemInstance) -> bool:
	if not pack_opening_system:
		return false
	return pack_opening_system.can_afford_pack(item)


## Returns the count of sealed packs currently in stock.
func get_pack_count() -> int:
	return _pack_inventory_count


## Returns true if a meta shift is currently active.
func is_meta_shift_active() -> bool:
	if not meta_shift_system:
		return false
	return meta_shift_system.is_shift_active()


## Returns cards currently rising in the meta.
func get_meta_rising_cards() -> Array[Dictionary]:
	if not meta_shift_system:
		return []
	return meta_shift_system.get_rising_cards()


## Returns cards currently falling in the meta.
func get_meta_falling_cards() -> Array[Dictionary]:
	if not meta_shift_system:
		return []
	return meta_shift_system.get_falling_cards()


## Returns true if the player can host a tournament.
func can_host_tournament() -> bool:
	if not tournament_system:
		return false
	return tournament_system.can_host_tournament()


## Returns the reason a tournament cannot be hosted.
func get_tournament_block_reason() -> String:
	if not tournament_system:
		return "Tournament system not available"
	return tournament_system.get_block_reason()


## Starts a small tournament ($30). Returns true on success.
func host_small_tournament() -> bool:
	if not tournament_system:
		return false
	return tournament_system.start_tournament(
		TournamentSystem.TournamentSize.SMALL
	)


## Starts a large tournament ($50). Returns true on success.
func host_large_tournament() -> bool:
	if not tournament_system:
		return false
	return tournament_system.start_tournament(
		TournamentSystem.TournamentSize.LARGE
	)


## Returns true if the given item is an openable booster pack.
func is_openable_pack(item: ItemInstance) -> bool:
	if not pack_opening_system:
		return false
	return pack_opening_system.is_booster_pack(item)


## Serializes store-specific state for saving.
func get_save_data() -> Dictionary:
	return {
		"pack_inventory_count": _pack_inventory_count,
	}


## Restores store-specific state from save data.
func load_save_data(data: Dictionary) -> void:
	_pack_inventory_count = int(data.get("pack_inventory_count", 0))


func _on_store_entered(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	_seed_starter_inventory()
	EventBus.store_opened.emit(String(STORE_ID))


func get_store_actions() -> Array:
	var actions: Array = super()
	actions.append({"id": &"open_pack", "label": "Open Pack", "icon": ""})
	actions.append({"id": &"host_tournament", "label": "Host Tournament", "icon": ""})
	return actions


func _on_store_exited(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	EventBus.store_closed.emit(String(STORE_ID))


func _on_seasonal_event_started(event_id: String) -> void:
	if event_id.begins_with("tournament"):
		_on_tournament_started(StringName(event_id))


func _on_tournament_started(_event_id: StringName) -> void:
	pass


func _on_tournament_resolved(
	_winner_id: StringName, _prize_amount: float
) -> void:
	pass


func _on_inventory_item_added(
	store_id: StringName, item_id: StringName
) -> void:
	if store_id != STORE_ID:
		return
	var entry: Dictionary = ContentRegistry.get_entry(item_id)
	if entry.is_empty() and _inventory_system:
		var item: ItemInstance = _inventory_system.get_item(String(item_id))
		if item and item.definition:
			entry = ContentRegistry.get_entry(StringName(item.definition.id))
	if _is_sealed_pack(entry):
		_pack_inventory_count += 1


func _seed_starter_inventory() -> void:
	if not _inventory_system:
		return
	var resolved: StringName = ContentRegistry.resolve(String(STORE_ID))
	if resolved.is_empty():
		resolved = STORE_ID
	var existing: Array[ItemInstance] = (
		_inventory_system.get_items_for_store(String(resolved))
	)
	if not existing.is_empty():
		return
	var entry: Dictionary = ContentRegistry.get_entry(resolved)
	if entry.is_empty():
		push_error("PocketCreaturesStoreController: no entry for %s" % STORE_ID)
		return
	var starter_items: Variant = entry.get("starting_inventory", [])
	if starter_items is Array:
		for item_id: Variant in starter_items:
			if item_id is String:
				_add_starter_item(item_id as String)


func _add_starter_item(raw_id: String) -> void:
	if raw_id.is_empty():
		return
	var canonical: StringName = ContentRegistry.resolve(raw_id)
	if canonical.is_empty():
		push_error("PocketCreaturesStoreController: unknown item_id '%s'" % raw_id)
		return
	var entry: Dictionary = ContentRegistry.get_entry(canonical)
	if entry.is_empty():
		return
	var def: ItemDefinition = _build_definition_from_entry(
		canonical, entry
	)
	var instance: ItemInstance = ItemInstance.create_from_definition(def)
	_inventory_system.add_item(STORE_ID, instance)
	if _is_sealed_pack(entry):
		_pack_inventory_count += 1


func _build_definition_from_entry(
	canonical_id: StringName, data: Dictionary,
) -> ItemDefinition:
	var def: ItemDefinition = ItemDefinition.new()
	def.id = String(canonical_id)
	if data.has("item_name"):
		def.item_name = str(data["item_name"])
	if data.has("base_price"):
		def.base_price = float(data["base_price"])
	if data.has("category"):
		def.category = str(data["category"])
	if data.has("subcategory"):
		def.subcategory = str(data["subcategory"])
	if data.has("rarity"):
		def.rarity = str(data["rarity"])
	if data.has("store_type"):
		def.store_type = str(data["store_type"])
	var raw_tags: Variant = data.get("tags", [])
	def.tags = ItemDefinition._normalize_string_name_array(raw_tags)
	return def


func _is_sealed_pack(entry: Dictionary) -> bool:
	var cat: String = str(entry.get("category", ""))
	var sub: String = str(entry.get("subcategory", ""))
	return cat == "booster_packs" and sub == "sealed"
