## Controller for the sports memorabilia store. Manages season cycle and authentication.
class_name SportsMemorabiliaController
extends StoreController

const STORE_ID: StringName = &"sports"
const STORE_TYPE: StringName = &"sports_memorabilia"
const BOOSTED_CATEGORIES: PackedStringArray = ["memorabilia", "autograph"]
const DEFAULT_SEASON_BOOST: float = 1.5

var _season_cycle: SeasonCycleSystem = SeasonCycleSystem.new()
var _authentication: AuthenticationSystem = AuthenticationSystem.new()
var _season_boost_active: bool = false
var _season_boost_value: float = DEFAULT_SEASON_BOOST
var _market_event_connected: bool = false


func _ready() -> void:
	store_type = STORE_ID
	super._ready()
	_load_season_boost()
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.market_event_triggered.connect(_on_market_event)
	EventBus.provenance_accepted.connect(_on_provenance_accepted)
	EventBus.provenance_rejected.connect(_on_provenance_rejected)
	EventBus.haggle_completed.connect(_on_haggle_completed)


## Initializes both the season cycle and authentication systems.
func initialize(starting_day: int) -> void:
	_season_cycle.initialize(starting_day)


## Initializes the authentication system with required references.
func initialize_authentication(
	inventory: InventorySystem, economy: EconomySystem
) -> void:
	_authentication.initialize(inventory, economy)


## Returns the SeasonCycleSystem for external wiring (EconomySystem, etc.).
func get_season_cycle() -> SeasonCycleSystem:
	return _season_cycle


## Returns the AuthenticationSystem for UI dialog wiring.
func get_authentication_system() -> AuthenticationSystem:
	return _authentication


## Returns the demand multiplier for the given category.
func get_demand_multiplier(category: StringName) -> float:
	if not _season_boost_active:
		return 1.0
	if String(category) in BOOSTED_CATEGORIES:
		return _season_boost_value
	return 1.0


## Serializes sports-memorabilia-specific state for saving.
func get_save_data() -> Dictionary:
	return {
		"season_cycle": _season_cycle.get_save_data(),
		"season_boost_active": _season_boost_active,
	}


## Restores sports-memorabilia-specific state from saved data.
func load_save_data(data: Dictionary) -> void:
	var cycle_data: Variant = data.get("season_cycle", {})
	if cycle_data is Dictionary:
		_season_cycle.load_save_data(cycle_data as Dictionary)
	_season_boost_active = bool(data.get("season_boost_active", false))


func _on_day_started(day: int) -> void:
	_season_cycle.process_day(day)


func _on_store_entered(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	_connect_market_event_signals()
	_seed_starter_inventory()
	EventBus.store_opened.emit(String(STORE_ID))


func _on_store_exited(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	_disconnect_market_event_signals()
	EventBus.store_closed.emit(String(STORE_ID))


## Returns true if the item needs authentication at the given price.
func _is_authentication_eligible(
	item_id: StringName, price: float
) -> bool:
	if not _inventory_system:
		return false
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		return false
	return _authentication.needs_authentication(item, price)


## Returns the season demand modifier for a given category. Returns 1.0
## by default. Stub — full logic in ISSUE-054.
func _get_season_modifier(_category: StringName) -> float:
	return 1.0


func _on_customer_purchased(
	_store_id: StringName, _item_id: StringName,
	_price: float, _customer_id: StringName
) -> void:
	if not _is_active:
		return


func _on_market_event(
	_event_id: StringName,
	store_id: StringName,
	_effect: Dictionary,
) -> void:
	if store_id != STORE_ID:
		return


func _on_market_event_started(event_id: String) -> void:
	if not _is_event_sports_win(event_id):
		return
	_season_boost_active = true


func _on_market_event_ended(event_id: String) -> void:
	if not _is_event_sports_win(event_id):
		return
	_season_boost_active = false


func _is_event_sports_win(event_id: String) -> bool:
	if not GameManager.data_loader:
		return false
	var def: MarketEventDefinition = (
		GameManager.data_loader.get_market_event(event_id)
	)
	if not def:
		return false
	return def.event_type == "sports_win"


func _connect_market_event_signals() -> void:
	if _market_event_connected:
		return
	EventBus.market_event_started.connect(_on_market_event_started)
	EventBus.market_event_ended.connect(_on_market_event_ended)
	_market_event_connected = true


func _disconnect_market_event_signals() -> void:
	if not _market_event_connected:
		return
	EventBus.market_event_started.disconnect(_on_market_event_started)
	EventBus.market_event_ended.disconnect(_on_market_event_ended)
	_market_event_connected = false


func _load_season_boost() -> void:
	var entry: Dictionary = ContentRegistry.get_entry(STORE_ID)
	if entry.is_empty():
		return
	_season_boost_value = float(
		entry.get("season_boost", DEFAULT_SEASON_BOOST)
	)


## Triggers the provenance verification flow for a customer offer.
func request_provenance_check(
	item_id: String, customer: Node
) -> void:
	EventBus.provenance_requested.emit(item_id, customer)


func _on_provenance_accepted(item_id: String) -> void:
	if not _inventory_system:
		EventBus.provenance_completed.emit(
			item_id, false, "System not ready"
		)
		return
	var item: ItemInstance = _inventory_system.get_item(item_id)
	if not item:
		item = _resolve_offered_item(item_id)
	if not item:
		EventBus.provenance_completed.emit(
			item_id, false, "Item not found"
		)
		return
	item.authentication_status = "authenticated"
	_inventory_system.add_item(STORE_ID, item)
	EventBus.provenance_completed.emit(item_id, true, "")
	EventBus.notification_requested.emit(
		"Accepted: %s" % item.definition.item_name
	)


func _on_provenance_rejected(item_id: String) -> void:
	EventBus.notification_requested.emit(
		"Rejected item: %s" % item_id
	)


func _on_haggle_completed(
	store_id: StringName,
	item_id: StringName,
	final_price: float,
	_asking_price: float,
	accepted: bool,
	_offer_count: int,
) -> void:
	if store_id != STORE_ID:
		return
	if not accepted or not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item or item.authentication_status != "authenticated":
		return
	var bonus: float = maxf(
		final_price - item.definition.base_price,
		final_price * (_authentication.get_auth_multiplier() - 1.0),
	)
	if bonus <= 0.0:
		return
	EventBus.bonus_sale_completed.emit(item_id, bonus)


func _resolve_offered_item(item_id: String) -> ItemInstance:
	var base_id: String = item_id
	var underscore_idx: int = item_id.rfind("_")
	if underscore_idx > 0 and item_id.substr(underscore_idx + 1).is_valid_int():
		base_id = item_id.substr(0, underscore_idx)
	var canonical: StringName = ContentRegistry.resolve(base_id)
	if canonical.is_empty():
		return null
	var entry: Dictionary = ContentRegistry.get_entry(canonical)
	if entry.is_empty():
		return null
	var def: ItemDefinition = _build_definition_from_entry(
		canonical, entry
	)
	var inst: ItemInstance = (
		ItemInstance.create_from_definition(def)
	)
	inst.instance_id = item_id
	return inst


func _seed_starter_inventory() -> void:
	if not _inventory_system:
		return
	var existing: Array[ItemInstance] = (
		_inventory_system.get_items_for_store(String(STORE_ID))
	)
	if not existing.is_empty():
		return
	var entry: Dictionary = ContentRegistry.get_entry(STORE_ID)
	if entry.is_empty():
		push_error(
			"SportsMemorabilia: no ContentRegistry entry for %s"
			% STORE_ID
		)
		return
	var starter_items: Variant = entry.get("starting_inventory", [])
	if starter_items is Array:
		for item_data: Variant in starter_items:
			if item_data is Dictionary:
				_add_starter_item(item_data as Dictionary)


func _add_starter_item(item_data: Dictionary) -> void:
	var raw_id: Variant = item_data.get("item_id", "")
	if not raw_id is String or (raw_id as String).is_empty():
		return
	var canonical: StringName = ContentRegistry.resolve(
		raw_id as String
	)
	if canonical.is_empty():
		push_error(
			"SportsMemorabilia: unknown item_id '%s'" % raw_id
		)
		return
	var entry: Dictionary = ContentRegistry.get_entry(canonical)
	if entry.is_empty():
		return
	var def: ItemDefinition = _build_definition_from_entry(
		canonical, entry
	)
	var quantity: int = int(item_data.get("quantity", 1))
	var condition: String = str(item_data.get("condition", ""))
	for i: int in range(quantity):
		var instance: ItemInstance = (
			ItemInstance.create_from_definition(def, condition)
		)
		_inventory_system.add_item(STORE_ID, instance)


func _build_definition_from_entry(
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
	if data.has("suspicious_chance"):
		def.suspicious_chance = float(data["suspicious_chance"])
	return def
