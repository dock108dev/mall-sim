## Minimal PocketCreatures store controller for ISSUE-148 lifecycle hooks.
class_name PocketCreaturesStore
extends StoreController

const STORE_ID: StringName = &"pocket_creatures"
const STORE_TYPE: StringName = &"pocket_creatures"

var _pack_inventory_count: int = 0
var _initialized: bool = false


func _ready() -> void:
	initialize()
	super._ready()


## Initializes store identity, pack tracking, and event hooks.
func initialize() -> void:
	if _initialized:
		return
	initialize_store(STORE_ID, STORE_TYPE)
	_pack_inventory_count = 0
	_connect_signal(EventBus.active_store_changed, _on_active_store_changed)
	_connect_signal(EventBus.inventory_item_added, _on_inventory_item_added)
	_connect_signal(EventBus.seasonal_event_started, _on_seasonal_event_started)
	_initialized = true


## Opens a sealed pack. Full RNG is owned by ISSUE-059.
func open_pack(_item_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	return result


## Returns the tracked count of sealed packs in stock.
func get_pack_count() -> int:
	return _pack_inventory_count


func _on_store_entered(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	_seed_starter_inventory()
	EventBus.store_opened.emit(String(STORE_ID))


func _on_store_exited(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	EventBus.store_closed.emit(String(STORE_ID))


func _on_tournament_started(_event_id: StringName) -> void:
	pass


func _on_inventory_item_added(
	store_id: StringName, item_id: StringName
) -> void:
	if store_id != STORE_ID:
		return
	var entry: Dictionary = ContentRegistry.get_entry(item_id)
	if _is_sealed_pack(entry):
		_pack_inventory_count += 1


func _on_seasonal_event_started(event_id: String) -> void:
	if event_id.begins_with("tournament"):
		_on_tournament_started(StringName(event_id))


func _seed_starter_inventory() -> void:
	if not _inventory_system:
		return
	var existing: Array[ItemInstance] = _inventory_system.get_items_for_store(
		String(STORE_ID)
	)
	if not existing.is_empty():
		return
	var store_entry: Dictionary = ContentRegistry.get_entry(STORE_ID)
	var starter_items: Variant = store_entry.get("starting_inventory", [])
	if not (starter_items is Array):
		return
	for item_id: Variant in starter_items:
		if item_id is String:
			_add_starter_item(item_id as String)


func _add_starter_item(raw_id: String) -> void:
	var canonical: StringName = ContentRegistry.resolve(raw_id)
	var entry: Dictionary = ContentRegistry.get_entry(canonical)
	if entry.is_empty():
		return
	var def := ItemDefinition.new()
	def.id = String(canonical)
	def.item_name = str(entry.get("item_name", canonical))
	def.category = str(entry.get("category", ""))
	def.subcategory = str(entry.get("subcategory", ""))
	def.base_price = float(entry.get("base_price", 0.0))
	def.store_type = String(STORE_ID)
	_inventory_system.add_item(STORE_ID, ItemInstance.create_from_definition(def))
	if _is_sealed_pack(entry):
		_pack_inventory_count += 1


func _is_sealed_pack(entry: Dictionary) -> bool:
	return (
		str(entry.get("category", "")) == "booster_packs"
		and str(entry.get("subcategory", "")) == "sealed"
	)
