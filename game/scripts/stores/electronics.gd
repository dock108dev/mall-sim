## Controller for the Consumer Electronics store. Manages demo unit designation
## and product depreciation hooks.
class_name Electronics
extends StoreController

const STORE_ID: StringName = &"consumer_electronics"
const STORE_TYPE: StringName = &"consumer_electronics"

var _demo_unit_ids: Array[StringName] = []
var _max_demo_units: int = 2
var _demo_interest_bonus: float = 0.20
var _purchase_intent_threshold: float = 0.55
var _launch_spike_days: int = 7
var _initialized: bool = false


func _ready() -> void:
	store_type = STORE_ID
	super._ready()
	_load_demo_config()


## Initializes electronics-specific state. Must be called after scene is ready.
func initialize() -> void:
	_demo_unit_ids = []
	_initialized = true


## Designates an item as a demo unit. Returns false if slots are full.
func designate_demo(item_id: StringName) -> bool:
	if _demo_unit_ids.size() >= _max_demo_units:
		return false
	if item_id in _demo_unit_ids:
		return false
	_demo_unit_ids.append(item_id)
	EventBus.demo_item_placed.emit(String(item_id))
	return true


## Removes a demo unit designation. Returns false if not found.
func undesignate_demo(item_id: StringName) -> bool:
	if item_id not in _demo_unit_ids:
		return false
	_demo_unit_ids.erase(item_id)
	EventBus.demo_item_removed.emit(String(item_id), 0)
	return true


## Returns true if the given item is currently designated as a demo unit.
func is_demo_unit(item_id: StringName) -> bool:
	return item_id in _demo_unit_ids


## Returns true if more demo units can be designated.
func has_demo_slots_available() -> bool:
	return _demo_unit_ids.size() < _max_demo_units


## Returns the browse conversion bonus from active demo units.
func get_demo_browse_bonus() -> float:
	if _demo_unit_ids.is_empty():
		return 0.0
	return _demo_interest_bonus


## Returns the max number of demo units allowed.
func get_max_demo_units() -> int:
	return _max_demo_units


## Returns the demo interest bonus value.
func get_demo_interest_bonus() -> float:
	return _demo_interest_bonus


## Returns the purchase intent threshold for customer conversion.
func get_purchase_intent_threshold() -> float:
	return _purchase_intent_threshold


## Returns the number of days the launch demand spike lasts.
func get_launch_spike_days() -> int:
	return _launch_spike_days


## Serializes electronics-specific state for saving.
func get_save_data() -> Dictionary:
	var demo_ids: Array[String] = []
	for id: StringName in _demo_unit_ids:
		demo_ids.append(String(id))
	return {
		"demo_unit_ids": demo_ids,
	}


## Restores electronics-specific state from saved data.
func load_save_data(data: Dictionary) -> void:
	_demo_unit_ids.clear()
	var saved_ids: Variant = data.get("demo_unit_ids", [])
	if saved_ids is Array:
		for raw_id: Variant in saved_ids:
			if raw_id is String:
				_demo_unit_ids.append(StringName(raw_id as String))


func _on_store_entered(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	_seed_starter_inventory()
	EventBus.store_opened.emit(String(STORE_ID))


func _on_store_exited(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	EventBus.store_closed.emit(String(STORE_ID))


func _on_day_started(day: int) -> void:
	_apply_depreciation_tick()


func _on_customer_entered(customer_data: Dictionary) -> void:
	if not _is_active:
		return
	var _bonus: float = get_demo_browse_bonus()


func _apply_depreciation_tick() -> void:
	pass


func _load_demo_config() -> void:
	var config: Dictionary = {}
	if GameManager.data_loader:
		config = GameManager.data_loader.get_electronics_config()
	if config.is_empty():
		var entry: Dictionary = ContentRegistry.get_entry(STORE_ID)
		if not entry.is_empty():
			config = entry
	if config.is_empty():
		push_warning(
			"Electronics: no config found in electronics.json or ContentRegistry"
		)
		return
	_max_demo_units = int(config.get("max_demo_units", _max_demo_units))
	_demo_interest_bonus = float(
		config.get("demo_interest_bonus", _demo_interest_bonus)
	)
	_purchase_intent_threshold = float(
		config.get("purchase_intent_threshold", _purchase_intent_threshold)
	)
	_launch_spike_days = int(
		config.get("launch_spike_days", _launch_spike_days)
	)


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
			"Electronics: no ContentRegistry entry for %s" % STORE_ID
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
	var canonical: StringName = ContentRegistry.resolve(raw_id as String)
	if canonical.is_empty():
		push_error("Electronics: unknown item_id '%s'" % raw_id)
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
	return def
