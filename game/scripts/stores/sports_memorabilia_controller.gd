## Controller for the sports memorabilia store. Manages season cycle and
## card condition grading via PriceResolver.
class_name SportsMemorabiliaController
extends StoreController

const STORE_ID: StringName = &"sports"
const STORE_TYPE: StringName = &"sports_memorabilia"
const BOOSTED_CATEGORIES: PackedStringArray = ["memorabilia", "autograph"]
const DEFAULT_SEASON_BOOST: float = 1.5
## Minimum provenance_score for a card to pass the authentication check.
const AUTH_THRESHOLD: float = 0.5

var _season_cycle: SeasonCycleSystem = SeasonCycleSystem.new()
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
	EventBus.card_condition_selected.connect(_on_card_condition_selected)


## Initializes the season cycle system.
func initialize(starting_day: int) -> void:
	_season_cycle.initialize(starting_day)


## Returns the SeasonCycleSystem for external wiring (EconomySystem, etc.).
func get_season_cycle() -> SeasonCycleSystem:
	return _season_cycle


## Returns the demand multiplier for the given category.
func get_demand_multiplier(category: StringName) -> float:
	if not _season_boost_active:
		return 1.0
	if String(category) in BOOSTED_CATEGORIES:
		return _season_boost_value
	return 1.0


## Returns the current sale price for an inventory item, resolved via
## PriceResolver with condition and season-demand multipliers in the audit chain.
func get_item_price(item_id: StringName) -> float:
	if not _inventory_system:
		push_warning(
			"SportsMemorabiliaController: InventorySystem is required for pricing"
		)
		return 0.0
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item or not item.definition:
		push_warning(
			"SportsMemorabiliaController: item '%s' not found for pricing"
			% item_id
		)
		return 0.0
	var multipliers: Array = []
	if item.is_graded and not item.card_grade.is_empty():
		# Formal grade supersedes the player's condition assessment.
		var grade_factor: float = PriceResolver.GRADE_MULTIPLIERS.get(
			item.card_grade, 1.0
		)
		multipliers.append({
			"slot": "grade",
			"label": "Grade",
			"factor": grade_factor,
			"detail": "Certified Grade: %s" % item.card_grade,
		})
	else:
		var condition_factor: float = ItemInstance.CONDITION_MULTIPLIERS.get(
			item.condition, 1.0
		)
		multipliers.append({
			"label": "Condition",
			"factor": condition_factor,
			"detail": item.condition.capitalize().replace("_", " "),
		})
	var demand_factor: float = get_demand_multiplier(item.definition.category)
	if demand_factor != 1.0:
		multipliers.append({
			"slot": "seasonal",
			"label": "Season Demand",
			"factor": demand_factor,
			"detail": "Active season boost",
		})
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		StringName(item_id), item.definition.base_price, multipliers
	)
	return result.final_price


## Serializes sports-memorabilia-specific state for saving.
func get_save_data() -> Dictionary:
	return {
		"season_cycle": _season_cycle.get_save_data(),
		"season_boost_active": _season_boost_active,
	}


## Restores sports-memorabilia-specific state from saved data.
## The legacy "authentication" key is silently ignored for forward compatibility.
func load_save_data(data: Dictionary) -> void:
	var cycle_data: Variant = data.get("season_cycle", {})
	if cycle_data is Dictionary:
		_season_cycle.load_save_data(cycle_data as Dictionary)
	_season_boost_active = bool(data.get("season_boost_active", false))


func _defer_store_entered(store_id: StringName) -> void:
	_on_store_entered(store_id)


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


## Updates item condition and recalculates price via PriceResolver.
func _on_card_condition_selected(
	item_id: StringName, condition: String
) -> void:
	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		return
	if condition not in ItemInstance.CONDITION_MULTIPLIERS:
		push_warning(
			"SportsMemorabiliaController: unknown condition '%s'" % condition
		)
		return
	item.condition = condition
	var price: float = get_item_price(item_id)
	EventBus.price_set.emit(String(item_id), price)


## Returns the season demand modifier for a given category.
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
	if not ContentRegistry.exists(String(STORE_ID)):
		return
	var entry: Dictionary = ContentRegistry.get_entry(STORE_ID)
	if entry.is_empty():
		return
	_season_boost_value = float(
		entry.get("season_boost", DEFAULT_SEASON_BOOST)
	)


## Runs the authentication check for a sports card in inventory.
## Emits card_authenticated or card_rejected, then card_graded on success.
func authenticate_card(item_id: StringName) -> void:
	if not _inventory_system:
		push_warning(
			"SportsMemorabiliaController: InventorySystem required for authentication"
		)
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item or not item.definition:
		push_warning(
			"SportsMemorabiliaController: item '%s' not found for authentication"
			% item_id
		)
		return
	var score: float = item.definition.provenance_score
	if score < AUTH_THRESHOLD:
		item.authentication_status = "rejected"
		EventBus.card_rejected.emit(item_id)
		return
	item.authentication_status = "authenticated"
	item.is_authenticated = true
	EventBus.card_authenticated.emit(item_id)
	var grade: String = _compute_grade(score)
	item.card_grade = grade
	item.is_graded = true
	item.grade_value = PriceResolver.GRADE_ORDER.find(grade)
	EventBus.card_graded.emit(item_id, grade)


## Maps a provenance_score (must be >= AUTH_THRESHOLD) to a letter grade.
func _compute_grade(provenance_score: float) -> String:
	if provenance_score >= 0.95:
		return "S"
	if provenance_score >= 0.85:
		return "A"
	if provenance_score >= 0.75:
		return "B"
	if provenance_score >= 0.65:
		return "C"
	if provenance_score >= 0.55:
		return "D"
	return "F"


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
	if not item:
		return
	var condition_factor: float = ItemInstance.CONDITION_MULTIPLIERS.get(
		item.condition, 1.0
	)
	if condition_factor <= 1.0:
		return
	var bonus: float = final_price * (condition_factor - 1.0)
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
	if data.has("era"):
		def.era = str(data["era"])
	if data.has("provenance_score"):
		def.provenance_score = float(data["provenance_score"])
	return def
