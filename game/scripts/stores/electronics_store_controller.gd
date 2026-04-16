## Controller for the Consumer Electronics store. Manages product lifecycle,
## demo units, and warranty upsell tracking.
class_name ElectronicsStoreController
extends StoreController

const STORE_ID: StringName = &"electronics"
const DEMO_STATION_FIXTURE_ID: String = "demo_station"
const DEMO_DEGRADE_INTERVAL_DAYS: int = 10
const DEFAULT_MAX_DEMO_UNITS: int = 2
const DEFAULT_DEMO_INTEREST_BONUS: float = 0.20
const CONDITION_ORDER: Array[String] = [
	"mint", "near_mint", "good", "fair", "poor",
]

var _lifecycle: ElectronicsLifecycleManager = null
var _electronics_items: Array[ItemDefinition] = []
var _current_day: int = 1
var _economy_system: EconomySystem = null
var _demo_station_slots: Array[Node] = []
var _demo_item_ids: Array[String] = []
var _warranty_manager: WarrantyManager = WarrantyManager.new()
var _max_demo_units: int = DEFAULT_MAX_DEMO_UNITS
var _demo_interest_bonus: float = DEFAULT_DEMO_INTEREST_BONUS


func _ready() -> void:
	store_type = STORE_ID
	super._ready()
	_lifecycle = ElectronicsLifecycleManager.new()
	_find_demo_stations()
	_load_demo_config()
	EventBus.item_stocked.connect(_on_item_stocked)


## Provides the economy system reference for warranty claim costs.
func set_economy_system(econ: EconomySystem) -> void:
	_economy_system = econ


## Returns the warranty manager for use by CheckoutSystem.
func get_warranty_manager() -> WarrantyManager:
	return _warranty_manager


## Initializes the lifecycle system with loaded item data.
func initialize(data_loader: DataLoader, current_day: int) -> void:
	_current_day = current_day
	_electronics_items = data_loader.get_items_by_store(STORE_ID)
	_lifecycle.initialize(_electronics_items, current_day)
	_lifecycle.check_phase_transitions(_electronics_items, current_day)


## Returns the lifecycle phase name for an item.
func get_lifecycle_phase(item: ItemDefinition) -> String:
	if not _lifecycle:
		return "peak"
	return _lifecycle.get_phase_name(item, _current_day)


## Returns the lifecycle price multiplier for an item.
func get_lifecycle_multiplier(item: ItemDefinition) -> float:
	if not _lifecycle:
		return 1.0
	return _lifecycle.get_multiplier(item, _current_day)


## Returns the full market value for an electronics item including lifecycle.
func calculate_electronics_value(
	item: ItemInstance, economy: EconomySystem
) -> float:
	var base_value: float = economy.calculate_market_value(item)
	var lifecycle_mult: float = get_lifecycle_multiplier(item.definition)
	return base_value * lifecycle_mult


## Returns true if the item is available in the supplier catalog.
func is_item_available(item: ItemDefinition) -> bool:
	if not _lifecycle:
		return true
	return _lifecycle.is_available_for_purchase(item, _current_day)


## Returns items currently available for purchase from suppliers.
func get_available_catalog() -> Array[ItemDefinition]:
	var available: Array[ItemDefinition] = []
	for item: ItemDefinition in _electronics_items:
		if is_item_available(item):
			available.append(item)
	return available


## Returns the store type identifier for this controller.
func get_store_type() -> String:
	return STORE_ID


## Returns the current depreciated price for an item, clamped to its floor price.
func get_current_price(instance_id: String) -> float:
	if not _inventory_system:
		return 0.0
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not item or not item.definition:
		return 0.0
	var base_value: float = item.get_current_value()
	var lifecycle_mult: float = get_lifecycle_multiplier(item.definition)
	var floor_price: float = item.definition.base_price * item.definition.min_value_ratio
	return maxf(base_value * lifecycle_mult, floor_price)


## Attempts a purchase. Returns false and warns if the item is a demo unit.
func attempt_purchase(instance_id: String) -> bool:
	if not _inventory_system:
		return false
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not item:
		return false
	if item.is_demo:
		push_warning(
			"ElectronicsStoreController: item '%s' is a demo unit and cannot be purchased"
			% instance_id
		)
		return false
	return true


## Emits warranty_offer_presented if the sale price meets the eligibility threshold.
## Returns true if the offer was presented.
func present_warranty_offer(instance_id: String, sale_price: float) -> bool:
	if not WarrantyManager.is_eligible(sale_price):
		return false
	EventBus.warranty_offer_presented.emit(instance_id)
	return true


## Returns true if the store has at least one demo station fixture placed.
func has_demo_station() -> bool:
	return not _demo_station_slots.is_empty()


## Returns the demo interest bonus value from content JSON.
func get_demo_interest_bonus() -> float:
	return _demo_interest_bonus


## Returns the max number of demo units allowed.
func get_max_demo_units() -> int:
	return _max_demo_units


## Returns the current number of active demo items.
func get_active_demo_count() -> int:
	return _demo_item_ids.size()


## Returns true if more demo units can be designated.
func has_demo_slots_available() -> bool:
	return _demo_item_ids.size() < _max_demo_units \
		and _demo_item_ids.size() < _demo_station_slots.size()


## Returns true if there is an active demo item in the given category.
func has_active_demo_for_category(category: String) -> bool:
	if _demo_item_ids.is_empty() or not _inventory_system:
		return false
	for demo_id: String in _demo_item_ids:
		var item: ItemInstance = _inventory_system.get_item(demo_id)
		if item and item.definition \
				and item.definition.category == category:
			return true
	return false


## Returns true if the item can be placed on a demo station.
func can_demo_item(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	if _demo_station_slots.is_empty():
		return false
	if item.definition.store_type != STORE_ID:
		return false
	if item.is_demo:
		return false
	if not has_demo_slots_available():
		return false
	if item.condition == "poor":
		return false
	return true


## Places an item on the next available demo station. Returns true on success.
func place_demo_item(instance_id: String) -> bool:
	if not _inventory_system:
		push_warning(
			"ElectronicsStoreController: no InventorySystem set"
		)
		return false
	if _demo_station_slots.is_empty():
		push_warning(
			"ElectronicsStoreController: no demo stations placed"
		)
		return false
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not can_demo_item(item):
		push_warning(
			"ElectronicsStoreController: item '%s' cannot be demoed"
			% instance_id
		)
		return false
	var slot: Node = _get_next_available_demo_slot()
	if not slot:
		push_warning(
			"ElectronicsStoreController: no available demo slots"
		)
		return false
	item.is_demo = true
	item.demo_placed_day = _current_day
	_demo_item_ids.append(instance_id)
	var slot_id: String = str(slot.get("slot_id"))
	if not slot_id.is_empty():
		_inventory_system.move_item(instance_id, "shelf:%s" % slot_id)
	EventBus.demo_item_placed.emit(instance_id)
	return true


## Removes a specific demo item and returns it to backroom.
func remove_demo_item(instance_id: String = "") -> bool:
	if _demo_item_ids.is_empty() or not _inventory_system:
		return false
	var target_id: String = instance_id
	if target_id.is_empty():
		target_id = _demo_item_ids[0]
	if target_id not in _demo_item_ids:
		return false
	var item: ItemInstance = _inventory_system.get_item(target_id)
	if not item:
		_demo_item_ids.erase(target_id)
		return false
	var days_on_demo: int = _current_day - item.demo_placed_day
	item.is_demo = false
	item.demo_placed_day = 0
	_inventory_system.move_item(target_id, "backroom")
	_demo_item_ids.erase(target_id)
	EventBus.demo_item_removed.emit(target_id, days_on_demo)
	return true


## Returns the instance_ids of all current demo items.
func get_demo_item_ids() -> Array[String]:
	return _demo_item_ids


## Returns true if the given item is currently a demo unit.
func is_demo_unit(instance_id: String) -> bool:
	return instance_id in _demo_item_ids


## Returns true if a demo item is at 'poor' condition and needs removal.
func is_demo_item_worn_out(instance_id: String = "") -> bool:
	if _demo_item_ids.is_empty() or not _inventory_system:
		return false
	var target_id: String = instance_id
	if target_id.is_empty() and not _demo_item_ids.is_empty():
		target_id = _demo_item_ids[0]
	var item: ItemInstance = _inventory_system.get_item(target_id)
	if not item:
		return false
	return item.condition == "poor"


## Serializes electronics-specific state for saving.
func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"current_day": _current_day,
		"demo_item_ids": _demo_item_ids.duplicate(),
		"warranty": _warranty_manager.get_save_data(),
	}
	if _lifecycle:
		data["lifecycle"] = _lifecycle.get_save_data()
	return data


## Restores electronics-specific state from saved data.
func load_save_data(data: Dictionary) -> void:
	_current_day = int(data.get("current_day", 1))
	_demo_item_ids.clear()
	var saved_ids: Variant = data.get("demo_item_ids", [])
	if saved_ids is Array:
		for raw_id: Variant in saved_ids:
			_demo_item_ids.append(str(raw_id))
	if _lifecycle and data.has("lifecycle"):
		var lifecycle_data: Variant = data.get("lifecycle")
		if lifecycle_data is Dictionary:
			_lifecycle.load_save_data(lifecycle_data as Dictionary)
	var warranty_data: Variant = data.get("warranty", {})
	if warranty_data is Dictionary:
		_warranty_manager.load_save_data(warranty_data as Dictionary)


func _on_store_exited(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	_warranty_manager.reset_daily_totals()


func _on_day_started(day: int) -> void:
	_current_day = day
	if _lifecycle:
		_lifecycle.process_day(day, _electronics_items)
		_lifecycle.check_phase_transitions(_electronics_items, day)
	_process_demo_degradation()
	_process_warranty_claims(day)


func _on_item_stocked(item_id: String, shelf_id: String) -> void:
	if _demo_station_slots.is_empty():
		return
	if not _is_demo_station_slot_id(shelf_id):
		return
	if not has_demo_slots_available():
		return
	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(item_id)
	if not item:
		return
	if can_demo_item(item):
		item.is_demo = true
		item.demo_placed_day = _current_day
		_demo_item_ids.append(item_id)
		EventBus.demo_item_placed.emit(item_id)


func _find_demo_stations() -> void:
	_demo_station_slots.clear()
	for fixture: Node in _fixtures:
		if _is_demo_fixture(fixture):
			var slot: Node = _extract_slot_from_fixture(fixture)
			if slot:
				_demo_station_slots.append(slot)
	for slot: Node in _slots:
		if slot.get("fixture_id") == DEMO_STATION_FIXTURE_ID:
			if slot not in _demo_station_slots:
				_demo_station_slots.append(slot)


func _is_demo_fixture(fixture: Node) -> bool:
	var fixture_id: Variant = fixture.get("fixture_id")
	if fixture_id is String:
		return (fixture_id as String).begins_with("demo_station")
	return fixture_id == DEMO_STATION_FIXTURE_ID


func _extract_slot_from_fixture(fixture: Node) -> Node:
	for child: Node in fixture.get_children():
		if child.is_in_group("shelf_slot") \
				or child.get("slot_id") != null:
			return child
	return null


func _is_demo_station_slot_id(shelf_id: String) -> bool:
	for slot: Node in _demo_station_slots:
		if str(slot.get("slot_id")) == shelf_id:
			return true
	return false


func _get_next_available_demo_slot() -> Node:
	for slot: Node in _demo_station_slots:
		var slot_id: String = str(slot.get("slot_id"))
		if slot_id.is_empty():
			continue
		var is_occupied: bool = false
		for demo_id: String in _demo_item_ids:
			var item: ItemInstance = _inventory_system.get_item(demo_id)
			if item and item.current_location == "shelf:%s" % slot_id:
				is_occupied = true
				break
		if not is_occupied:
			return slot
	return null


func _load_demo_config() -> void:
	var entry: Dictionary = ContentRegistry.get_entry(STORE_ID)
	if entry.is_empty():
		return
	_max_demo_units = int(
		entry.get("max_demo_units", DEFAULT_MAX_DEMO_UNITS)
	)
	_demo_interest_bonus = float(
		entry.get("demo_interest_bonus", DEFAULT_DEMO_INTEREST_BONUS)
	)


func _process_demo_degradation() -> void:
	if _demo_item_ids.is_empty() or not _inventory_system:
		return
	var stale_ids: Array[String] = []
	for demo_id: String in _demo_item_ids:
		var item: ItemInstance = _inventory_system.get_item(demo_id)
		if not item:
			stale_ids.append(demo_id)
			continue
		var days_on_demo: int = _current_day - item.demo_placed_day
		if days_on_demo <= 0:
			continue
		if days_on_demo % DEMO_DEGRADE_INTERVAL_DAYS != 0:
			continue
		var new_condition: String = _degrade_condition(item.condition)
		if new_condition == item.condition:
			continue
		item.condition = new_condition
		EventBus.demo_item_degraded.emit(demo_id, new_condition)
	for stale_id: String in stale_ids:
		_demo_item_ids.erase(stale_id)


func _process_warranty_claims(day: int) -> void:
	_warranty_manager.reset_daily_totals()
	var claims: Array[Dictionary] = (
		_warranty_manager.process_daily_claims(day)
	)
	for claim: Dictionary in claims:
		var cost: float = claim.get("replacement_cost", 0.0)
		var item_id: String = claim.get("item_id", "")
		if _economy_system and cost > 0.0:
			_economy_system.force_deduct_cash(
				cost, "Warranty claim: %s" % item_id
			)
		EventBus.warranty_claim_triggered.emit(item_id, cost)
		EventBus.notification_requested.emit(
			"Warranty claim! Replacement cost: $%.2f" % cost
		)
	_warranty_manager.purge_expired(day)


func _degrade_condition(current: String) -> String:
	var idx: int = CONDITION_ORDER.find(current)
	if idx < 0 or idx >= CONDITION_ORDER.size() - 1:
		return current
	return CONDITION_ORDER[idx + 1]
