## Owns all item instances and tracks their locations across stores.
class_name InventorySystem
extends Node

var _items: Dictionary = {}  # instance_id -> ItemInstance
var _data_loader: DataLoader = null

## Cached shelf items, invalidated on location changes.
var _shelf_cache: Array[ItemInstance] = []
var _shelf_cache_dirty: bool = true

## Cached backroom items, invalidated on location changes.
var _backroom_cache: Array[ItemInstance] = []
var _backroom_cache_dirty: bool = true


## Sets up the system with a DataLoader reference and clears all state.
func initialize(data_loader: DataLoader) -> void:
	_data_loader = data_loader
	_items = {}
	_invalidate_caches()


## Creates a new ItemInstance from a definition id and registers it.
## Returns null if the definition is not found or backroom is at capacity.
func create_item(
	definition_id: String,
	condition: String,
	acquired_price: float
) -> ItemInstance:
	if not _data_loader:
		push_warning("InventorySystem: DataLoader not set")
		return null
	var def: ItemDefinition = _data_loader.get_item(definition_id)
	if not def:
		push_warning(
			"InventorySystem: definition '%s' not found"
			% definition_id
		)
		return null
	if _is_backroom_full(def.store_type):
		push_warning(
			"InventorySystem: backroom full for store type '%s'"
			% def.store_type
		)
		return null
	var item: ItemInstance = ItemInstance.create(
		def, condition, 0, acquired_price
	)
	item.current_location = "backroom"
	_items[item.instance_id] = item
	_invalidate_caches()
	EventBus.inventory_changed.emit()
	return item


## Registers an existing ItemInstance in the system.
## Returns false if backroom is at capacity when location is backroom.
func register_item(item: ItemInstance) -> bool:
	if not item or item.instance_id.is_empty():
		push_warning("InventorySystem: cannot register null/invalid item")
		return false
	if item.current_location == "backroom":
		if item.definition and _is_backroom_full(
			item.definition.store_type
		):
			push_warning(
				"InventorySystem: backroom full for store type '%s'"
				% item.definition.store_type
			)
			return false
	_items[item.instance_id] = item
	_invalidate_caches()
	EventBus.inventory_changed.emit()
	return true


## Updates an item's location. Emits item_stocked when moved to a shelf.
func move_item(instance_id: String, new_location: String) -> void:
	if not _items.has(instance_id):
		push_warning(
			"InventorySystem: item '%s' not found" % instance_id
		)
		return
	var item: ItemInstance = _items[instance_id]
	item.current_location = new_location
	_invalidate_caches()
	EventBus.inventory_changed.emit()
	if new_location.begins_with("shelf:"):
		var shelf_id: String = new_location.substr(6)
		EventBus.item_stocked.emit(item.instance_id, shelf_id)


## Returns all items at a specific location string.
func get_items_at_location(
	location: String
) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item: ItemInstance in _items.values():
		if item.current_location == location:
			result.append(item)
	return result


## Returns all items in the backroom (cached).
func get_backroom_items() -> Array[ItemInstance]:
	if _backroom_cache_dirty:
		_backroom_cache = []
		for item: ItemInstance in _items.values():
			if item.current_location == "backroom":
				_backroom_cache.append(item)
		_backroom_cache_dirty = false
	return _backroom_cache


## Returns all items on any shelf slot (cached).
func get_shelf_items() -> Array[ItemInstance]:
	if _shelf_cache_dirty:
		_shelf_cache = []
		for item: ItemInstance in _items.values():
			if item.current_location.begins_with("shelf:"):
				_shelf_cache.append(item)
		_shelf_cache_dirty = false
	return _shelf_cache


## Returns all backroom items for a specific store type.
func get_backroom_items_for_store(
	store_type: String
) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item: ItemInstance in _items.values():
		if item.current_location != "backroom":
			continue
		if item.definition and item.definition.store_type == store_type:
			result.append(item)
	return result


## Returns all shelf items for a specific store type.
func get_shelf_items_for_store(
	store_type: String
) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item: ItemInstance in _items.values():
		if not item.current_location.begins_with("shelf:"):
			continue
		if item.definition and item.definition.store_type == store_type:
			result.append(item)
	return result


## Returns all items (backroom + shelf) for a specific store type.
func get_items_for_store(
	store_type: String
) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item: ItemInstance in _items.values():
		if item.definition and item.definition.store_type == store_type:
			result.append(item)
	return result


## Returns an item by its instance_id, or null if not found.
func get_item(instance_id: String) -> ItemInstance:
	if not _items.has(instance_id):
		return null
	return _items[instance_id]


## Marks an item as sold and removes it from active tracking.
func remove_item(instance_id: String) -> void:
	if not _items.has(instance_id):
		push_warning(
			"InventorySystem: item '%s' not found for removal"
			% instance_id
		)
		return
	var item: ItemInstance = _items[instance_id]
	item.current_location = "sold"
	_items.erase(instance_id)
	_invalidate_caches()
	EventBus.inventory_changed.emit()


## Returns a count of all tracked items.
func get_item_count() -> int:
	return _items.size()


## Serializes all item instances and their state for saving.
func get_save_data() -> Dictionary:
	var items_data: Array[Dictionary] = []
	for item: ItemInstance in _items.values():
		var item_data: Dictionary = {
			"instance_id": item.instance_id,
			"definition_id": item.definition.id if item.definition else "",
			"condition": item.condition,
			"acquired_day": item.acquired_day,
			"acquired_price": item.acquired_price,
			"current_location": item.current_location,
			"set_price": item.set_price,
			"tested": item.tested,
			"is_demo": item.is_demo,
			"demo_placed_day": item.demo_placed_day,
			"authentication_status": item.authentication_status,
		}
		items_data.append(item_data)
	return {
		"items": items_data,
		"next_id": ItemInstance._next_id,
	}


## Restores item instances from saved data.
func load_save_data(data: Dictionary) -> void:
	_items = {}
	_invalidate_caches()
	if not _data_loader:
		push_warning("InventorySystem: DataLoader not set for load")
		return
	if data.has("next_id"):
		ItemInstance._next_id = int(data["next_id"])
	var items_data: Array = data.get("items", [])
	for entry: Variant in items_data:
		if entry is not Dictionary:
			continue
		var entry_dict: Dictionary = entry
		var def_id: String = str(entry_dict.get("definition_id", ""))
		var def: ItemDefinition = _data_loader.get_item(def_id)
		if not def:
			push_warning(
				"InventorySystem: definition '%s' missing during load"
				% def_id
			)
			continue
		var item := ItemInstance.new()
		item.definition = def
		item.instance_id = str(entry_dict.get("instance_id", ""))
		item.condition = str(entry_dict.get("condition", "good"))
		item.acquired_day = int(entry_dict.get("acquired_day", 0))
		item.acquired_price = float(
			entry_dict.get("acquired_price", 0.0)
		)
		item.current_location = str(
			entry_dict.get("current_location", "backroom")
		)
		item.set_price = float(entry_dict.get("set_price", 0.0))
		item.tested = bool(entry_dict.get("tested", false))
		item.is_demo = bool(entry_dict.get("is_demo", false))
		item.demo_placed_day = int(
			entry_dict.get("demo_placed_day", 0)
		)
		item.authentication_status = str(
			entry_dict.get("authentication_status", "none")
		)
		if item.instance_id.is_empty():
			push_warning(
				"InventorySystem: skipping item with empty instance_id"
			)
			continue
		_items[item.instance_id] = item


## Marks location caches as needing rebuild on next access.
func _invalidate_caches() -> void:
	_shelf_cache_dirty = true
	_backroom_cache_dirty = true


## Checks if the backroom is full for a given store type.
func _is_backroom_full(store_type: String) -> bool:
	if not _data_loader:
		return false
	var stores: Array[StoreDefinition] = _data_loader.get_all_stores()
	var capacity: int = 0
	for store: StoreDefinition in stores:
		if store.store_type == store_type:
			capacity = store.backroom_capacity
			break
	if capacity <= 0:
		return false
	var count: int = 0
	for item: ItemInstance in _items.values():
		if item.current_location != "backroom":
			continue
		if item.definition and item.definition.store_type == store_type:
			count += 1
	return count >= capacity
