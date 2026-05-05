# gdlint:disable=max-public-methods
## Owns all item instances and tracks their locations across stores.
class_name InventorySystem
extends Node

## Location string for items returned by customers and accepted into the
## back-room damaged bin. Damaged-bin items are not resold; the bin is the
## terminal location for a returned defective copy.
const DAMAGED_BIN_LOCATION: String = "back_room_damaged_bin"

var _items: Dictionary = {}
var _stock: Dictionary = {}
var _item_store_ids: Dictionary = {}
var _data_loader: DataLoader = null
var _shelf_assignments: Dictionary = {}
## Maps store_id -> {slot_id: definition_id} for emptied shelf slots awaiting refill.
var _empty_shelf_targets: Dictionary = {}
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


func _resolve_store_id(store_id: Variant) -> StringName:
	var raw: String = str(store_id)
	if raw.is_empty():
		return &""
	if ContentRegistry.exists(raw):
		var canonical: StringName = ContentRegistry.resolve(raw)
		if not canonical.is_empty():
			return canonical
	return StringName(raw)


## Adds an ItemInstance to a store's stock and emits inventory_updated.
func add_item(store_id: StringName, item: ItemInstance) -> void:
	if not item or item.instance_id.is_empty():
		push_error("InventorySystem: cannot add null/invalid item")
		return
	var canonical: StringName = _resolve_store_id(store_id)
	if canonical.is_empty():
		push_error("InventorySystem: invalid store_id '%s'" % store_id)
		return
	_store_item_without_signals(canonical, item)
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
	var previous_slot_id: String = _extract_shelf_slot_id(
		item.current_location
	)
	_remove_shelf_assignment_for_item(instance_id)
	if not sid.is_empty() and not def_id.is_empty() \
			and not previous_slot_id.is_empty():
		_remember_empty_shelf_target(
			sid, previous_slot_id, def_id
		)
	item.current_location = "sold"
	_items.erase(instance_id)
	_item_store_ids.erase(instance_id)
	if not sid.is_empty() and _stock.has(String(sid)):
		var store_stock: Dictionary = _stock[String(sid)]
		store_stock.erase(instance_id)
		if store_stock.is_empty():
			_stock.erase(String(sid))
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
	var canonical: StringName = _resolve_store_id(store_id)
	if canonical.is_empty():
		return []
	if not _stock.has(String(canonical)):
		return []
	var result: Array[ItemInstance] = []
	for item: ItemInstance in (_stock[String(canonical)] as Dictionary).values():
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
	var canonical: String = String(_resolve_store_id(store_id))
	if canonical.is_empty():
		push_error("InventorySystem: invalid store_id '%s'" % store_id)
		return false
	if not _stock.has(canonical) or not (
		(_stock[canonical] as Dictionary).has(String(item_id))
	):
		push_warning(
			"InventorySystem: item '%s' not in store '%s'" % [item_id, canonical]
		)
		return false
	if not _shelf_assignments.has(canonical):
		_shelf_assignments[canonical] = {}
	_remove_shelf_assignment_for_item(String(item_id))
	var shelves: Dictionary = _shelf_assignments[canonical]
	shelves[String(shelf_slot_id)] = String(item_id)
	_clear_empty_shelf_target(
		StringName(canonical), String(shelf_slot_id)
	)
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
	var canonical: String = String(_resolve_store_id(store_id))
	if canonical.is_empty():
		return null
	if not _shelf_assignments.has(canonical):
		return null
	var shelves: Dictionary = _shelf_assignments[canonical]
	var slot_key: String = String(shelf_slot_id)
	if not shelves.has(slot_key):
		return null
	return get_item(shelves[slot_key])


## Refills one remembered empty shelf slot from matching backroom stock.
func restock_one_empty_shelf_slot(store_id: StringName) -> Dictionary:
	var canonical: StringName = _resolve_store_id(store_id)
	if canonical.is_empty():
		push_error("InventorySystem: invalid store_id '%s'" % store_id)
		return {}
	var empty_slots: Dictionary = _empty_shelf_targets.get(
		String(canonical), {}
	)
	for slot_id_variant: Variant in empty_slots.keys():
		var slot_id: String = str(slot_id_variant)
		var definition_id: String = str(
			empty_slots.get(slot_id_variant, "")
		)
		if definition_id.is_empty():
			continue
		var item: ItemInstance = _find_backroom_item_for_definition(
			canonical, definition_id
		)
		if not item:
			continue
		move_item(item.instance_id, "shelf:%s" % slot_id)
		return {
			"slot_id": slot_id,
			"item_id": definition_id,
			"instance_id": item.instance_id,
		}
	return {}


## Queues a restock operation for later processing.
func queue_restock(
	store_id: StringName, item_id: StringName, quantity: int
) -> void:
	if quantity <= 0:
		return
	var canonical: StringName = _resolve_store_id(store_id)
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
	var canonical: StringName = _resolve_store_id(def.store_type)
	if canonical.is_empty():
		push_warning(
			"InventorySystem: unresolved store_type '%s'" % def.store_type
		)
		return null
	add_item(canonical, item)
	return item


## Seeds `count` backroom items for `store_id` on Day 1, adding only as many as
## are needed to reach the target. No-op if backroom already has >= count items.
func seed_starting_items(store_id: StringName, count: int) -> void:
	if count <= 0:
		return
	if not _data_loader:
		push_warning("InventorySystem: seed_starting_items called without DataLoader")
		return
	var canonical: StringName = _resolve_store_id(store_id)
	if canonical.is_empty():
		push_warning("InventorySystem: seed_starting_items invalid store_id '%s'" % store_id)
		return
	var existing: int = get_backroom_items_for_store(String(canonical)).size()
	if existing >= count:
		return
	var defs: Array[ItemDefinition] = _data_loader.get_items_by_store(String(canonical))
	if defs.is_empty():
		push_warning(
			"InventorySystem: no item definitions for store '%s' — cannot seed" % canonical
		)
		return
	var to_add: int = count - existing
	for i: int in range(to_add):
		var def: ItemDefinition = defs[i % defs.size()]
		var item: ItemInstance = ItemInstance.create(def, "good", 0, def.base_price)
		item.current_location = "backroom"
		add_item(canonical, item)


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
	var sid: StringName = _get_store_id_for_item(item)
	if sid.is_empty() and item.definition:
		sid = _resolve_store_id(item.definition.store_type)
	if sid.is_empty():
		push_warning("InventorySystem: cannot register item without store_id")
		return false
	add_item(sid, item)
	return true


func move_item(instance_id: String, new_location: String) -> void:
	if not _items.has(instance_id):
		push_warning("InventorySystem: item '%s' not found" % instance_id)
		return
	var item: ItemInstance = _items[instance_id]
	var previous_slot_id: String = _extract_shelf_slot_id(
		item.current_location
	)
	if not previous_slot_id.is_empty():
		var previous_store_id: StringName = _get_store_id_for_item(item)
		_remove_shelf_assignment_for_item(instance_id)
		if not previous_store_id.is_empty() and item.definition:
			_remember_empty_shelf_target(
				previous_store_id,
				previous_slot_id,
				StringName(item.definition.id)
			)
	item.current_location = new_location
	if new_location.begins_with("shelf:"):
		var shelf_id: String = new_location.substr(6)
		var store_type: String = String(_get_store_id_for_item(item))
		if not store_type.is_empty():
			if not _shelf_assignments.has(store_type):
				_shelf_assignments[store_type] = {}
			var shelves: Dictionary = _shelf_assignments[store_type]
			shelves[shelf_id] = instance_id
			_clear_empty_shelf_target(
				StringName(store_type), shelf_id
			)
		EventBus.item_stocked.emit(instance_id, shelf_id)
	_invalidate_caches()
	EventBus.inventory_changed.emit()
	var sid: StringName = _get_store_id_for_item(item)
	if not sid.is_empty():
		EventBus.inventory_updated.emit(sid)


## Persists a condition change for an owned item and emits inventory updates.
func update_item_condition(
	instance_id: String, new_condition: String
) -> bool:
	if not _items.has(instance_id):
		push_warning("InventorySystem: item '%s' not found" % instance_id)
		return false
	if not ItemDefinition.CONDITION_ORDER.has(new_condition):
		push_error(
			"InventorySystem: invalid condition '%s' for '%s'"
			% [new_condition, instance_id]
		)
		return false
	var item: ItemInstance = _items[instance_id]
	if item.condition == new_condition:
		return true
	item.condition = new_condition
	_invalidate_caches()
	EventBus.inventory_changed.emit()
	var sid: StringName = _get_store_id_for_item(item)
	if not sid.is_empty():
		EventBus.inventory_updated.emit(sid)
	return true


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


## Returns every item currently sitting in the back-room damaged bin. Damaged
## bin items are excluded from resale paths (no shelf placement, no checkout
## stock lookup); ReturnsSystem reconciles the bin contents against its
## resolved-return ledger to surface inventory_variance_noted when the two
## diverge.
func get_damaged_bin_items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item: ItemInstance in _items.values():
		if item.current_location == DAMAGED_BIN_LOCATION:
			result.append(item)
	return result


## Moves an existing item into the damaged bin. Returns false when the
## instance is unknown so callers can surface the integrity error.
func move_to_damaged_bin(instance_id: String) -> bool:
	if not _items.has(instance_id):
		push_warning(
			"InventorySystem: move_to_damaged_bin missing instance '%s'"
			% instance_id
		)
		return false
	var item: ItemInstance = _items[instance_id]
	if item.current_location.begins_with("shelf:"):
		_remove_shelf_assignment_for_item(instance_id)
	item.current_location = DAMAGED_BIN_LOCATION
	_invalidate_caches()
	EventBus.inventory_changed.emit()
	var sid: StringName = _get_store_id_for_item(item)
	if not sid.is_empty():
		EventBus.inventory_updated.emit(sid)
	return true


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
	var canonical: StringName = _resolve_store_id(store_type)
	if canonical.is_empty():
		return []
	var result: Array[ItemInstance] = []
	for item: ItemInstance in get_stock(canonical):
		if item.current_location != "backroom":
			continue
		result.append(item)
	return result


func get_shelf_items_for_store(
	store_type: String
) -> Array[ItemInstance]:
	var canonical: StringName = _resolve_store_id(store_type)
	if canonical.is_empty():
		return []
	var result: Array[ItemInstance] = []
	for item: ItemInstance in get_stock(canonical):
		if not item.current_location.begins_with("shelf:"):
			continue
		result.append(item)
	return result


func get_items_for_store(store_type: String) -> Array[ItemInstance]:
	return get_stock(_resolve_store_id(store_type))


## Returns display-ready inventory rows for the requested store.
func get_store_inventory(store_id: StringName) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item: ItemInstance in get_items_for_store(String(store_id)):
		var definition_id: StringName = &""
		var display_name: String = "Unknown"
		var rarity: String = ""
		var icon_path: String = ""
		if item.definition:
			definition_id = StringName(item.definition.id)
			display_name = item.definition.item_name
			rarity = item.definition.rarity
			icon_path = item.definition.icon_path
		var price: float = (
			item.player_set_price if item.player_set_price > 0.0
			else item.get_current_value()
		)
		rows.append({
			"instance_id": StringName(item.instance_id),
			"definition_id": definition_id,
			"display_name": display_name,
			"condition": item.condition,
			"rarity": rarity,
			"current_price": price,
			"estimated_value": item.get_current_value(),
			"location": item.current_location,
			"icon_path": icon_path,
			"item": item,
		})
	return rows


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
			"store_id": String(_get_store_id_for_item(item)),
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
		"empty_shelf_targets": _empty_shelf_targets.duplicate(true),
		"shelf_assignments": _shelf_assignments.duplicate(true),
		"restock_queue": _restock_queue.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_items = {}
	_stock = {}
	_item_store_ids = {}
	_shelf_assignments = {}
	_empty_shelf_targets = {}
	_restock_queue = []
	_restock_pending = {}
	_invalidate_caches()
	if not _data_loader:
		var has_saved_items: bool = not (data.get("items", []) as Array).is_empty()
		if has_saved_items:
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
		# §SR-09: prices must be finite and non-negative; a hand-edited save
		# with NaN/Inf would propagate through every price calculation
		# downstream and lock comparison checks to false.
		item.acquired_price = _safe_finite_price(d.get("acquired_price", 0.0))
		item.current_location = str(
			d.get("current_location", "backroom")
		)
		item.player_set_price = _safe_finite_price(d.get("player_set_price", 0.0))
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
		var stored_store_id: StringName = _resolve_store_id(
			str(d.get("store_id", ""))
		)
		if stored_store_id.is_empty():
			stored_store_id = _get_store_id_for_definition(item.definition)
		if stored_store_id.is_empty():
			push_warning(
				"InventorySystem: unresolved store_id for item '%s' during load"
				% item.instance_id
			)
			continue
		_store_item_without_signals(stored_store_id, item)
	var saved_shelves: Variant = data.get("shelf_assignments", {})
	if saved_shelves is Dictionary:
		var raw_shelves: Dictionary = saved_shelves as Dictionary
		for store_key: Variant in raw_shelves:
			var canonical: StringName = _resolve_store_id(
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
	var saved_empty_targets: Variant = data.get("empty_shelf_targets", {})
	if saved_empty_targets is Dictionary:
		var raw_targets: Dictionary = saved_empty_targets as Dictionary
		for store_key: Variant in raw_targets:
			var canonical: StringName = _resolve_store_id(
				str(store_key)
			)
			if canonical.is_empty():
				push_warning(
					"InventorySystem: unresolved empty shelf store_id '%s' during load"
					% store_key
				)
				continue
			var targets: Variant = raw_targets[store_key]
			if targets is Dictionary:
				_empty_shelf_targets[String(canonical)] = (
					targets as Dictionary
				).duplicate(true)
	var saved_queue: Variant = data.get("restock_queue", [])
	if saved_queue is Array:
		for q_entry: Variant in saved_queue:
			if q_entry is not Dictionary:
				continue
			var queue_entry: Dictionary = (
				q_entry as Dictionary
			).duplicate(true)
			var canonical: StringName = _resolve_store_id(
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
	var canonical: StringName = _resolve_store_id(store_id)
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
	var canonical: StringName = _resolve_store_id(store_type)
	if canonical.is_empty():
		return false
	var entry: Dictionary = {}
	if ContentRegistry.exists(String(canonical)):
		entry = ContentRegistry.get_entry(canonical)
	var capacity: int = int(entry.get("backroom_capacity", 0))
	if capacity <= 0:
		return false
	var count: int = 0
	for item: ItemInstance in _items.values():
		if item.current_location != "backroom":
			continue
		if item.definition and _resolve_store_id(item.definition.store_type) == canonical:
			count += 1
	return count >= capacity


func _get_store_id_for_item(item: ItemInstance) -> StringName:
	if not item:
		return &""
	if _item_store_ids.has(item.instance_id):
		return StringName(_item_store_ids[item.instance_id])
	return _get_store_id_for_definition(item.definition)


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


func _remember_empty_shelf_target(
	store_id: StringName,
	slot_id: String,
	def_id: StringName
) -> void:
	if slot_id.is_empty() or def_id.is_empty():
		return
	var store_key: String = String(store_id)
	if store_key.is_empty():
		return
	if not _empty_shelf_targets.has(store_key):
		_empty_shelf_targets[store_key] = {}
	var targets: Dictionary = _empty_shelf_targets[store_key]
	targets[slot_id] = String(def_id)


func _clear_empty_shelf_target(store_id: StringName, slot_id: String) -> void:
	var store_key: String = String(store_id)
	if store_key.is_empty() or slot_id.is_empty():
		return
	if not _empty_shelf_targets.has(store_key):
		return
	var targets: Dictionary = _empty_shelf_targets[store_key]
	targets.erase(slot_id)
	if targets.is_empty():
		_empty_shelf_targets.erase(store_key)


func _extract_shelf_slot_id(location: String) -> String:
	if not location.begins_with("shelf:"):
		return ""
	return location.substr(6)


func _find_backroom_item_for_definition(
	store_id: StringName,
	definition_id: String
) -> ItemInstance:
	for item: ItemInstance in get_stock(store_id):
		if item.current_location != "backroom":
			continue
		if not item.definition:
			continue
		if item.definition.id != definition_id:
			continue
		return item
	return null


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
	var count: int = 0
	for item: ItemInstance in get_stock(store_id):
		if not item.definition:
			continue
		if item.definition.id == definition_id:
			count += 1
	return count


func _on_order_delivered(
	store_id: StringName, items: Array
) -> void:
	for item: Variant in items:
		if item is ItemInstance:
			add_item(store_id, item as ItemInstance)
			continue
		var instance_id: String = str(item)
		if instance_id.is_empty() or not _items.has(instance_id):
			continue
		if _item_store_ids.has(instance_id):
			continue
		_store_item_without_signals(store_id, _items[instance_id])


func _on_hour_changed(_hour: int) -> void:
	process_restock_queue()


func _store_item_without_signals(
	store_id: StringName, item: ItemInstance
) -> void:
	var canonical: StringName = _resolve_store_id(store_id)
	if canonical.is_empty():
		return
	var store_key: String = String(canonical)
	var previous_store_key: String = str(_item_store_ids.get(item.instance_id, ""))
	if not previous_store_key.is_empty() and previous_store_key != store_key:
		if _stock.has(previous_store_key):
			var previous_store: Dictionary = _stock[previous_store_key]
			previous_store.erase(item.instance_id)
			if previous_store.is_empty():
				_stock.erase(previous_store_key)
	_items[item.instance_id] = item
	if not _stock.has(store_key):
		_stock[store_key] = {}
	var store_stock: Dictionary = _stock[store_key]
	store_stock[item.instance_id] = item
	_item_store_ids[item.instance_id] = store_key


func _get_store_id_for_definition(definition: ItemDefinition) -> StringName:
	if not definition:
		return &""
	return _resolve_store_id(definition.store_type)


## §SR-09: Coerce a save-loaded price value to a finite, non-negative float.
## Rejects NaN/Inf and clamps to a 1e9 ceiling so a corrupt/edited save cannot
## inject a value that breaks downstream arithmetic or comparison logic.
func _safe_finite_price(value: Variant) -> float:
	var parsed: float
	if value is float:
		parsed = value as float
	elif value is int:
		parsed = float(value as int)
	else:
		return 0.0
	if is_nan(parsed) or is_inf(parsed):
		return 0.0
	return clampf(parsed, 0.0, 1.0e9)
