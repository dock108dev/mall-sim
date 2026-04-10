## Controller for the Consumer Electronics store. Manages product lifecycle,
## demo units, and warranty upsell tracking.
class_name ElectronicsStoreController
extends StoreController

const STORE_ID: String = "consumer_electronics"
const DEMO_STATION_FIXTURE_ID: String = "demo_station"
const DEMO_DEGRADE_INTERVAL_DAYS: int = 10
const CONDITION_ORDER: Array[String] = [
	"mint", "near_mint", "good", "fair", "poor",
]

var _lifecycle: ElectronicsLifecycleManager = null
var _electronics_items: Array[ItemDefinition] = []
var _current_day: int = 1
var _inventory_system: InventorySystem = null
var _economy_system: EconomySystem = null
var _demo_station_slot: Node = null
var _demo_item_id: String = ""
var _warranty_manager: WarrantyManager = WarrantyManager.new()


func _ready() -> void:
	store_type = STORE_ID
	super._ready()
	_lifecycle = ElectronicsLifecycleManager.new()
	_find_demo_station()
	EventBus.day_started.connect(_on_day_started)
	EventBus.item_stocked.connect(_on_item_stocked)


## Provides the inventory system reference for demo station operations.
func set_inventory_system(inv: InventorySystem) -> void:
	_inventory_system = inv


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


## Returns true if the store has a demo station fixture placed.
func has_demo_station() -> bool:
	return _demo_station_slot != null


## Returns true if there is an active demo item in the given category.
func has_active_demo_for_category(category: String) -> bool:
	if _demo_item_id.is_empty() or not _inventory_system:
		return false
	var item: ItemInstance = _inventory_system.get_item(_demo_item_id)
	if not item or not item.definition:
		return false
	return item.definition.category == category


## Returns true if the item can be placed on the demo station.
func can_demo_item(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	if not _demo_station_slot:
		return false
	if item.definition.store_type != STORE_ID:
		return false
	if item.is_demo:
		return false
	if not _demo_item_id.is_empty():
		return false
	if item.condition == "poor":
		return false
	return true


## Places an item on the demo station. Returns true on success.
func place_demo_item(instance_id: String) -> bool:
	if not _inventory_system:
		push_warning(
			"ElectronicsStoreController: no InventorySystem set"
		)
		return false
	if not _demo_station_slot:
		push_warning(
			"ElectronicsStoreController: no demo station placed"
		)
		return false
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not can_demo_item(item):
		push_warning(
			"ElectronicsStoreController: item '%s' cannot be demoed"
			% instance_id
		)
		return false
	item.is_demo = true
	item.demo_placed_day = _current_day
	_demo_item_id = instance_id
	var slot_id: String = str(_demo_station_slot.get("slot_id"))
	if not slot_id.is_empty():
		_inventory_system.move_item(instance_id, "shelf:%s" % slot_id)
	EventBus.demo_item_placed.emit(instance_id)
	return true


## Removes the demo item and returns it to backroom. Returns true on success.
func remove_demo_item() -> bool:
	if _demo_item_id.is_empty() or not _inventory_system:
		return false
	var item: ItemInstance = _inventory_system.get_item(_demo_item_id)
	if not item:
		_demo_item_id = ""
		return false
	var days_on_demo: int = _current_day - item.demo_placed_day
	item.is_demo = false
	item.demo_placed_day = 0
	_inventory_system.move_item(_demo_item_id, "backroom")
	EventBus.demo_item_removed.emit(_demo_item_id, days_on_demo)
	_demo_item_id = ""
	if _demo_station_slot and _demo_station_slot.has_method("remove_item"):
		_demo_station_slot.remove_item()
	return true


## Returns the instance_id of the current demo item, or empty string.
func get_demo_item_id() -> String:
	return _demo_item_id


## Returns true if the demo item is at 'poor' condition and needs removal.
func is_demo_item_worn_out() -> bool:
	if _demo_item_id.is_empty() or not _inventory_system:
		return false
	var item: ItemInstance = _inventory_system.get_item(_demo_item_id)
	if not item:
		return false
	return item.condition == "poor"


## Serializes electronics-specific state for saving.
func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"current_day": _current_day,
		"demo_item_id": _demo_item_id,
		"warranty": _warranty_manager.get_save_data(),
	}
	if _lifecycle:
		data["lifecycle"] = _lifecycle.get_save_data()
	return data


## Restores electronics-specific state from saved data.
func load_save_data(data: Dictionary) -> void:
	_current_day = int(data.get("current_day", 1))
	_demo_item_id = str(data.get("demo_item_id", ""))
	if _lifecycle and data.has("lifecycle"):
		var lifecycle_data: Variant = data.get("lifecycle")
		if lifecycle_data is Dictionary:
			_lifecycle.load_save_data(lifecycle_data as Dictionary)
	var warranty_data: Variant = data.get("warranty", {})
	if warranty_data is Dictionary:
		_warranty_manager.load_save_data(warranty_data as Dictionary)


func _on_day_started(day: int) -> void:
	_current_day = day
	if _lifecycle:
		_lifecycle.process_day(day, _electronics_items)
		_lifecycle.check_phase_transitions(_electronics_items, day)
	_process_demo_degradation()
	_process_warranty_claims(day)


func _on_item_stocked(item_id: String, shelf_id: String) -> void:
	if not _demo_station_slot:
		return
	var station_slot_id: String = str(
		_demo_station_slot.get("slot_id")
	)
	if station_slot_id.is_empty() or shelf_id != station_slot_id:
		return
	if not _demo_item_id.is_empty():
		return
	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(item_id)
	if not item:
		return
	if can_demo_item(item):
		item.is_demo = true
		item.demo_placed_day = _current_day
		_demo_item_id = item_id
		EventBus.demo_item_placed.emit(item_id)


func _find_demo_station() -> void:
	for fixture: Node in _fixtures:
		if fixture.get("fixture_id") == DEMO_STATION_FIXTURE_ID:
			_assign_demo_station_slot(fixture)
			return
	for slot: Node in _slots:
		if slot.get("fixture_id") == DEMO_STATION_FIXTURE_ID:
			_demo_station_slot = slot
			return


func _assign_demo_station_slot(fixture: Node) -> void:
	for child: Node in fixture.get_children():
		if child.is_in_group("shelf_slot") or child.get("slot_id") != null:
			_demo_station_slot = child
			return


func _process_demo_degradation() -> void:
	if _demo_item_id.is_empty() or not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(_demo_item_id)
	if not item:
		_demo_item_id = ""
		return
	var days_on_demo: int = _current_day - item.demo_placed_day
	if days_on_demo <= 0:
		return
	if days_on_demo % DEMO_DEGRADE_INTERVAL_DAYS != 0:
		return
	var new_condition: String = _degrade_condition(item.condition)
	if new_condition == item.condition:
		return
	item.condition = new_condition
	EventBus.demo_item_degraded.emit(_demo_item_id, new_condition)


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
