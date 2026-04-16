## Owns all item instances and tracks their locations across stores.
class_name InventorySystem
extends Node

var _items: Dictionary = {}
var _data_loader: DataLoader = null
var _shelf_assignments: Dictionary = {}
var _restock_queue: Array[Dictionary] = []
var _shelf_cache: Array[ItemInstance] = []
var _shelf_cache_dirty: bool = true
var _backroom_cache: Array[ItemInstance] = []
var _backroom_cache_dirty: bool = true
## Maps "store_id::def_id" → {reorder_min, reorder_quantity} config.
var _reorder_configs: Dictionary = {}
## Idempotency guard: true when restock_requested has fired and stock is still low.
var _restock_pending: Dictionary = {}


func _ready() -> void:
	EventBus.order_delivered.connect(_on_order_delivered)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.customer_purchased.connect(_on_customer_purchased)


func initialize(data_loader: DataLoader) -> void:
	_data_loader = data_loader
	_apply_state({})


## Adds an ItemInstance to a store's stock and emits inventory_updated.
func add_item(store_id: StringName, item: ItemInstance) -> void:
	if not item or item.instance_id.is_empty():
		push_error("InventorySystem: cannot add null/invalid item")
		return
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty():
		push_error("InventorySystem: invalid store_id '%s'" % store_id)
		return
	_items[item.instance_id] = item
	_invalidate_caches()
	EventBus.inventory_changed.emit()
	EventBus.inventory_updated.emit(canonical)
	if item.definition:
		_reset_restock_pending_if_replenished(
			canonical, StringName(item.definition.id)
		)


## Removes an item from stock. Returns false if not found.
func remove_item(instance_id: String) -> bool:
	if not _items.has(instance_id):
		push_warning("InventorySystem: item '%s' not found" % instance_id)
		return false
	var item: ItemInstance = _items[instance_id]
	var sid: StringName = _get_store_id_for_item(item)
	var def_id: StringName = StringName(
		item.definition.id if item.definition else ""
	)
	_remove_shelf_assignment_for_item(instance_id)
	item.current_location = "sold"
	_items.erase(instance_id)
	_invalidate_caches()
	EventBus.inventory_changed.emit()
	if not sid.is_empty():
		EventBus.inventory_updated.emit(sid)
	if not sid.is_empty() and not def_id.is_empty():
		_check_restock_threshold(sid, def_id)
	return true


func deduct_stock(_store_id: StringName, instance_id: String) -> bool:
	return remove_item(instance_id)


## Returns all ItemInstances for the given store; empty if none.
func get_stock(store_id: StringName) -> Array[ItemInstance]:
	var canonical: String = String(
		ContentRegistry.resolve(String(store_id))
	)
	if canonical.is_empty():
		return []
	var result: Array[ItemInstance] = []
	for item: ItemInstance in _items.values():
		if item.definition and item.definition.store_type == canonical:
			result.append(item)
	return result


## Links an item to a shelf slot. Returns false if item not in stock.
func assign_to_shelf(
	store_id: StringName,
	item_id: StringName,
	shelf_slot_id: StringName
) -> bool:
	if not _items.has(String(item_id)):
		push_warning(
			"InventorySystem: item '%s' not in stock" % item_id
		)
		return false
	var canonical: String = String(
		ContentRegistry.resolve(String(store_id))
	)
	if canonical.is_empty():
		push_error("InventorySystem: invalid store_id '%s'" % store_id)
		return false
	if not _shelf_assignments.has(canonical):
		_shelf_assignments[canonical] = {}
	var shelves: Dictionary = _shelf_assignments[canonical]
	shelves[String(shelf_slot_id)] = String(item_id)
	var item: ItemInstance = _items[String(item_id)]
	item.current_location = "shelf:%s" % String(shelf_slot_id)
	_invalidate_caches()
	EventBus.item_stocked.emit(String(item_id), String(shelf_slot_id))
	EventBus.inventory_changed.emit()
	EventBus.inventory_updated.emit(StringName(canonical))
	return true


## Returns the item at a shelf slot, or null if empty.
func get_shelf_item(
	store_id: StringName, shelf_slot_id: StringName
) -> ItemInstance:
	var canonical: String = String(
		ContentRegistry.resolve(String(store_id))
	)
	if canonical.is_empty():
		return null
	if not _shelf_assignments.has(canonical):
		return null
	var shelves: Dictionary = _shelf_assignments[canonical]
	var slot_key: String = String(shelf_slot_id)
	if not shelves.has(slot_key):
		return null
	return get_item(shelves[slot_key])


## Queues a restock operation for later processing.
func queue_restock(
	store_id: StringName, item_id: StringName, quantity: int
) -> void:
	if quantity <= 0:
		return
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty():
		push_error("InventorySystem: invalid store_id '%s'" % store_id)
		return
	_restock_queue.append({
		"store_id": String(canonical),
		"item_id": String(item_id),
		"quantity": quantity,
	})


## Configures automatic reorder for a definition in a store.
## When stock falls strictly below reorder_min, EventBus.restock_requested fires once.
func set_reorder_config(
	store_id: StringName,
	def_id: StringName,
	reorder_min: int,
	reorder_quantity: int,
) -> void:
	var key: String = _get_reorder_key(store_id, def_id)
	_reorder_configs[key] = {
		"reorder_min": reorder_min,
		"reorder_quantity": reorder_quantity,
	}


## Processes one pending restock entry, adding items via add_item.
func process_restock_queue() -> void:
	if _restock_queue.is_empty():
		return
	var entry: Dictionary = _restock_queue.pop_front()
	var sid: String = str(entry.get("store_id", ""))
	var item_id: String = str(entry.get("item_id", ""))
	var quantity: int = int(entry.get("quantity", 0))
	if not _data_loader:
		push_warning("InventorySystem: DataLoader not set for restock")
		return
	var def: ItemDefinition = _data_loader.get_item(item_id)
	if not def:
		push_warning(
			"InventorySystem: definition '%s' not found for restock"
			% item_id
		)
		return
	for i: int in range(quantity):
		var item: ItemInstance = ItemInstance.create(
			def, "good", 0, def.base_price
		)
		item.current_location = "backroom"
		add_item(StringName(sid), item)


func create_item(
	definition_id: String, condition: String, acquired_price: float
) -> ItemInstance:
	if not _data_loader:
		push_warning("InventorySystem: DataLoader not set")
		return null
	var def: ItemDefinition = _data_loader.get_item(definition_id)
	if not def:
		push_warning(
			"InventorySystem: definition '%s' not found" % definition_id
		)
		return null
	if _is_backroom_full(def.store_type):
		push_warning(
			"InventorySystem: backroom full for '%s'" % def.store_type
		)
		return null
	var item: ItemInstance = ItemInstance.create(
		def, condition, 0, acquired_price
	)
	item.current_location = "backroom"
	_items[item.instance_id] = item
	_invalidate_caches()
	EventBus.inventory_changed.emit()
	var canonical: StringName = ContentRegistry.resolve(def.store_type)
	if not canonical.is_empty():
		EventBus.inventory_updated.emit(canonical)
	return item


func register_item(item: ItemInstance) -> bool:
	if not item or item.instance_id.is_empty():
		push_warning("InventorySystem: cannot register null/invalid item")
		return false
	if item.current_location == "backroom":
		if item.definition and _is_backroom_full(
			item.definition.store_type
		):
			push_warning(
				"InventorySystem: backroom full for '%s'"
				% item.definition.store_type
			)
			return false
	_items[item.instance_id] = item
	_invalidate_caches()
	EventBus.inventory_changed.emit()
	var sid: StringName = _get_store_id_for_item(item)
	if not sid.is_empty():
		EventBus.inventory_updated.emit(sid)
	return true


func move_item(instance_id: String, new_location: String) -> void:
	if not _items.has(instance_id):
		push_warning("InventorySystem: item '%s' not found" % instance_id)
		return
	var item: ItemInstance = _items[instance_id]
	if item.current_location.begins_with("shelf:"):
		_remove_shelf_assignment_for_item(instance_id)
	item.current_location = new_location
	if new_location.begins_with("shelf:"):
		var shelf_id: String = new_location.substr(6)
		var store_type: String = ""
		if item.definition:
			store_type = String(
				ContentRegistry.resolve(item.definition.store_type)
			)
		if not store_type.is_empty():
			if not _shelf_assignments.has(store_type):
				_shelf_assignments[store_type] = {}
			var shelves: Dictionary = _shelf_assignments[store_type]
			shelves[shelf_id] = instance_id
		EventBus.item_stocked.emit(instance_id, shelf_id)
	_invalidate_caches()
	EventBus.inventory_changed.emit()
	var sid: StringName = _get_store_id_for_item(item)
	if not sid.is_empty():
		EventBus.inventory_updated.emit(sid)


func get_items_at_location(location: String) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item: ItemInstance in _items.values():
		if item.current_location == location:
			result.append(item)
	return result


func get_backroom_items() -> Array[ItemInstance]:
	if _backroom_cache_dirty:
		_backroom_cache = []
		for item: ItemInstance in _items.values():
			if item.current_location == "backroom":
				_backroom_cache.append(item)
		_backroom_cache_dirty = false
	return _backroom_cache


func get_shelf_items() -> Array[ItemInstance]:
	if _shelf_cache_dirty:
		_shelf_cache = []
		for item: ItemInstance in _items.values():
			if item.current_location.begins_with("shelf:"):
				_shelf_cache.append(item)
		_shelf_cache_dirty = false
	return _shelf_cache


func get_backroom_items_for_store(
	store_type: String
) -> Array[ItemInstance]:
	var canonical: String = String(ContentRegistry.resolve(store_type))
	var result: Array[ItemInstance] = []
	for item: ItemInstance in _items.values():
		if item.current_location != "backroom":
			continue
		if item.definition and item.definition.store_type == canonical:
			result.append(item)
	return result


func get_shelf_items_for_store(
	store_type: String
) -> Array[ItemInstance]:
	var canonical: String = String(ContentRegistry.resolve(store_type))
	var result: Array[ItemInstance] = []
	for item: ItemInstance in _items.values():
		if not item.current_location.begins_with("shelf:"):
			continue
		if item.definition and item.definition.store_type == canonical:
			result.append(item)
	return result


func get_items_for_store(store_type: String) -> Array[ItemInstance]:
	var canonical: String = String(ContentRegistry.resolve(store_type))
	var result: Array[ItemInstance] = []
	for item: ItemInstance in _items.values():
		if item.definition and item.definition.store_type == canonical:
			result.append(item)
	return result


func get_item(instance_id: String) -> ItemInstance:
	if not _items.has(instance_id):
		return null
	return _items[instance_id]


func get_item_count() -> int:
	return _items.size()


func serialize() -> Dictionary:
	return get_save_data()


func deserialize(data: Dictionary) -> void:
	load_save_data(data)


func get_save_data() -> Dictionary:
	var items_data: Array[Dictionary] = []
	for item: ItemInstance in _items.values():
		items_data.append({
			"instance_id": item.instance_id,
			"definition_id": item.definition.id if item.definition else "",
			"condition": item.condition,
			"acquired_day": item.acquired_day,
			"acquired_price": item.acquired_price,
			"current_location": item.current_location,
			"player_set_price": item.player_set_price,
			"tested": item.tested,
			"test_result": item.test_result,
			"is_demo": item.is_demo,
			"demo_placed_day": item.demo_placed_day,
			"authentication_status": item.authentication_status,
			"rental_due_day": item.rental_due_day,
		})
	return {
		"items": items_data,
		"next_id": ItemInstance._next_id,
		"shelf_assignments": _shelf_assignments.duplicate(true),
		"restock_queue": _restock_queue.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_items = {}
	_shelf_assignments = {}
	_restock_queue = []
	_restock_pending = {}
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
		var d: Dictionary = entry
		var def_id: String = str(d.get("definition_id", ""))
		var def: ItemDefinition = _data_loader.get_item(def_id)
		if not def:
			push_warning(
				"InventorySystem: definition '%s' missing during load"
				% def_id
			)
			continue
		var item := ItemInstance.new()
		item.definition = def
		item.instance_id = str(d.get("instance_id", ""))
		item.condition = str(d.get("condition", "good"))
		item.acquired_day = int(d.get("acquired_day", 0))
		item.acquired_price = float(d.get("acquired_price", 0.0))
		item.current_location = str(
			d.get("current_location", "backroom")
		)
		item.player_set_price = float(d.get("player_set_price", 0.0))
		item.tested = bool(d.get("tested", false))
		item.test_result = str(d.get("test_result", ""))
		item.is_demo = bool(d.get("is_demo", false))
		item.demo_placed_day = int(d.get("demo_placed_day", 0))
		item.authentication_status = str(
			d.get("authentication_status", "none")
		)
		item.rental_due_day = int(d.get("rental_due_day", -1))
		if item.instance_id.is_empty():
			push_warning(
				"InventorySystem: skipping item with empty instance_id"
			)
			continue
		_items[item.instance_id] = item
	var saved_shelves: Variant = data.get("shelf_assignments", {})
	if saved_shelves is Dictionary:
		var raw_shelves: Dictionary = saved_shelves as Dictionary
		for store_key: Variant in raw_shelves:
			var canonical: StringName = ContentRegistry.resolve(
				str(store_key)
			)
			if canonical.is_empty():
				push_warning(
					"InventorySystem: unresolved shelf store_id '%s' during load"
					% store_key
				)
				continue
			var shelves: Variant = raw_shelves[store_key]
			if shelves is Dictionary:
				_shelf_assignments[String(canonical)] = (
					shelves as Dictionary
				).duplicate(true)
	var saved_queue: Variant = data.get("restock_queue", [])
	if saved_queue is Array:
		for q_entry: Variant in saved_queue:
			if q_entry is not Dictionary:
				continue
			var queue_entry: Dictionary = (
				q_entry as Dictionary
			).duplicate(true)
			var canonical: StringName = ContentRegistry.resolve(
				str(queue_entry.get("store_id", ""))
			)
			if canonical.is_empty():
				push_warning(
					"InventorySystem: unresolved restock store_id '%s' during load"
					% queue_entry.get("store_id", "")
				)
				continue
			queue_entry["store_id"] = String(canonical)
			_restock_queue.append(queue_entry)


func _get_reorder_key(store_id: StringName, def_id: StringName) -> String:
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty():
		canonical = store_id
	return "%s::%s" % [String(canonical), String(def_id)]


func _check_restock_threshold(
	store_id: StringName, def_id: StringName
) -> void:
	var key: String = _get_reorder_key(store_id, def_id)
	if not _reorder_configs.has(key):
		return
	if _restock_pending.get(key, false):
		return
	var config: Dictionary = _reorder_configs[key]
	var reorder_min: int = config.get("reorder_min", 0)
	var count: int = _count_definition_stock(store_id, String(def_id))
	if count < reorder_min:
		_restock_pending[key] = true
		var qty: int = config.get("reorder_quantity", 1)
		EventBus.restock_requested.emit(store_id, def_id, qty)


func _reset_restock_pending_if_replenished(
	store_id: StringName, def_id: StringName
) -> void:
	var key: String = _get_reorder_key(store_id, def_id)
	if not _reorder_configs.has(key):
		return
	var config: Dictionary = _reorder_configs[key]
	var reorder_min: int = config.get("reorder_min", 0)
	var count: int = _count_definition_stock(store_id, String(def_id))
	if count >= reorder_min:
		_restock_pending[key] = false


func _invalidate_caches() -> void:
	_shelf_cache_dirty = true
	_backroom_cache_dirty = true


func _is_backroom_full(store_type: String) -> bool:
	var canonical: String = String(ContentRegistry.resolve(store_type))
	if canonical.is_empty():
		return false
	var entry: Dictionary = ContentRegistry.get_entry(
		StringName(canonical)
	)
	var capacity: int = int(entry.get("backroom_capacity", 0))
	if capacity <= 0:
		return false
	var count: int = 0
	for item: ItemInstance in _items.values():
		if item.current_location != "backroom":
			continue
		if item.definition and item.definition.store_type == canonical:
			count += 1
	return count >= capacity


func _get_store_id_for_item(item: ItemInstance) -> StringName:
	if not item or not item.definition:
		return &""
	return ContentRegistry.resolve(item.definition.store_type)


func _remove_shelf_assignment_for_item(instance_id: String) -> void:
	for store_id: String in _shelf_assignments:
		var shelves: Dictionary = _shelf_assignments[store_id]
		for slot_id: String in shelves:
			if shelves[slot_id] == instance_id:
				shelves.erase(slot_id)
				EventBus.item_removed_from_shelf.emit(
					instance_id, slot_id
				)
				return


func _on_customer_purchased(
	store_id: StringName,
	item_id: StringName,
	_price: float,
	_customer_id: StringName
) -> void:
	var instance_id: String = String(item_id)
	if not _items.has(instance_id):
		return
	var item: ItemInstance = _items[instance_id]
	if item.current_location == "rented":
		return
	var def_id: StringName = StringName(
		item.definition.id if item.definition else ""
	)
	deduct_stock(store_id, instance_id)
	if def_id.is_empty():
		return
	var remaining: int = _count_definition_stock(store_id, String(def_id))
	EventBus.stock_changed.emit(store_id, def_id, remaining)
	if remaining == 0:
		EventBus.out_of_stock.emit(store_id, def_id)


func _count_definition_stock(
	store_id: StringName, definition_id: String
) -> int:
	var canonical: String = String(
		ContentRegistry.resolve(String(store_id))
	)
	if canonical.is_empty():
		return 0
	var count: int = 0
	for item: ItemInstance in _items.values():
		if not item.definition:
			continue
		if item.definition.id == definition_id \
				and item.definition.store_type == canonical:
			count += 1
	return count


func _on_order_delivered(
	store_id: StringName, items: Array
) -> void:
	for item: Variant in items:
		if item is ItemInstance:
			add_item(store_id, item as ItemInstance)


func _on_hour_changed(_hour: int) -> void:
	process_restock_queue()
