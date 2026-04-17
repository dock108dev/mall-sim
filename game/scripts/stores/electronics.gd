## Controller for the Consumer Electronics store lifecycle and demo-unit hooks.
class_name Electronics
extends StoreController

const STORE_ID: StringName = &"consumer_electronics"
const STORE_TYPE: StringName = &"consumer_electronics"

var _demo_unit_ids: Array[StringName]
var _initialized: bool = false


func _ready() -> void:
	initialize()
	super._ready()


## Initializes store identity, signal wiring, and demo-unit tracking.
func initialize() -> void:
	if _initialized:
		return
	initialize_store(STORE_ID, STORE_TYPE)
	_demo_unit_ids = []
	_connect_signal(EventBus.active_store_changed, _on_active_store_changed)
	_connect_signal(EventBus.day_started, _on_day_started)
	_connect_signal(EventBus.customer_entered, _on_customer_entered)
	_initialized = true


## Demo-unit designation logic lands in ISSUE-061.
func designate_demo(_item_id: StringName) -> bool:
	return false


## Returns true when the given item is in the active demo-unit list.
func is_demo_unit(item_id: StringName) -> bool:
	return item_id in _demo_unit_ids


## Demo browse conversion logic lands in ISSUE-061.
func get_demo_browse_bonus() -> float:
	return 0.0


func _on_store_entered(store_id: StringName) -> void:
	if not _matches_store_id(store_id):
		return
	_seed_starter_inventory()
	EventBus.store_opened.emit(String(STORE_ID))


func _on_store_exited(store_id: StringName) -> void:
	if not _matches_store_id(store_id):
		return
	EventBus.store_closed.emit(String(STORE_ID))


func _on_active_store_changed(store_id: StringName) -> void:
	var is_matching_store: bool = _matches_store_id(store_id)
	if is_matching_store:
		_is_active = true
		_on_store_activated()
	elif _is_active:
		_is_active = false
		_on_store_deactivated()


func _on_day_started(_day: int) -> void:
	_apply_depreciation_tick()


func _on_customer_entered(_customer_data: Dictionary) -> void:
	if not _is_active:
		return
	var _browse_bonus: float = get_demo_browse_bonus()


## MarketValueSystem depreciation integration lands in ISSUE-062.
func _apply_depreciation_tick() -> void:
	pass


func _matches_store_id(store_id: StringName) -> bool:
	if store_id == STORE_ID:
		return true
	if not ContentRegistry.exists(String(store_id)):
		return false
	return (
		ContentRegistry.resolve(String(store_id))
		== ContentRegistry.resolve(String(STORE_ID))
	)


func _seed_starter_inventory() -> void:
	if not _inventory_system:
		return
	var existing: Array[ItemInstance] = _inventory_system.get_items_for_store(
		String(STORE_ID)
	)
	if not existing.is_empty():
		return
	var entry: Dictionary = ContentRegistry.get_entry(STORE_ID)
	if entry.is_empty():
		push_error("Electronics: no ContentRegistry entry for %s" % STORE_ID)
		return
	var starter_items: Variant = entry.get("starting_inventory", [])
	if not (starter_items is Array):
		return
	for starter_item: Variant in starter_items:
		if starter_item is String:
			_add_starter_item(starter_item as String)
			continue
		if starter_item is Dictionary:
			_add_starter_items_from_entry(starter_item as Dictionary)


func _add_starter_items_from_entry(item_data: Dictionary) -> void:
	var raw_id: String = str(item_data.get("item_id", ""))
	if raw_id.is_empty():
		return
	var quantity: int = max(1, int(item_data.get("quantity", 1)))
	var condition: String = str(item_data.get("condition", ""))
	for _count: int in range(quantity):
		_add_starter_item(raw_id, condition)


func _add_starter_item(raw_id: String, condition: String = "") -> void:
	if raw_id.is_empty():
		return
	var canonical: StringName = ContentRegistry.resolve(raw_id)
	if canonical.is_empty():
		push_error("Electronics: unknown item_id '%s'" % raw_id)
		return
	var entry: Dictionary = ContentRegistry.get_entry(canonical)
	if entry.is_empty():
		return
	var item_definition: ItemDefinition = _build_definition_from_entry(
		canonical, entry
	)
	var instance: ItemInstance = ItemInstance.create_from_definition(
		item_definition, condition
	)
	_inventory_system.add_item(STORE_ID, instance)


func _build_definition_from_entry(
	canonical_id: StringName, data: Dictionary
) -> ItemDefinition:
	var item_definition: ItemDefinition = ItemDefinition.new()
	item_definition.id = String(canonical_id)
	item_definition.item_name = str(data.get("item_name", canonical_id))
	item_definition.base_price = float(data.get("base_price", 0.0))
	item_definition.category = StringName(str(data.get("category", "")))
	item_definition.rarity = str(data.get("rarity", "common"))
	item_definition.store_type = StringName(str(data.get("store_type", STORE_TYPE)))
	return item_definition
