## Canonical owner of active store identity, slot ownership map, and storefront state.
class_name StoreStateManager
extends Node

const BACKGROUND_SALE_BASE_CHANCE: float = 0.15
const BACKGROUND_SALE_INTERVAL: float = 60.0

var active_store_id: StringName = &""
var owned_slots: Dictionary = {}
var store_types: Dictionary = {}
var store_names: Dictionary = {}
var _store_states: Dictionary = {}
var _store_revenue: Dictionary = {}
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _background_timer: float = 0.0


## Sets up references and connects to EventBus signals.
func initialize(
	inventory: InventorySystem,
	economy: EconomySystem
) -> void:
	_inventory_system = inventory
	_economy_system = economy
	_apply_state({})
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.store_leased.connect(_on_store_leased)


## Registers slot ownership. Returns false if slot is already owned.
func lease_store(
	slot_index: int,
	store_id: StringName,
	store_type: StringName = &""
) -> bool:
	var canonical_store_id: StringName = ContentRegistry.resolve(
		String(store_id)
	)
	if canonical_store_id.is_empty():
		push_error(
			"StoreStateManager: invalid store_id '%s' for lease_store()"
			% store_id
		)
		EventBus.lease_completed.emit(
			store_id, false, "Invalid store ID."
		)
		return false
	if owned_slots.has(slot_index):
		EventBus.lease_completed.emit(
			canonical_store_id, false, "Slot %d is already owned." % slot_index
		)
		return false
	owned_slots[slot_index] = canonical_store_id
	if not store_type.is_empty():
		var canonical_type: StringName = ContentRegistry.resolve(
			String(store_type)
		)
		if canonical_type.is_empty():
			canonical_type = store_type
		store_types[canonical_store_id] = canonical_type
	EventBus.lease_completed.emit(canonical_store_id, true, "")
	return true


## Updates the active store and emits active_store_changed.
func set_active_store(store_id: StringName) -> void:
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if not store_id.is_empty() and canonical.is_empty():
		push_error(
			"StoreStateManager: invalid store_id '%s' for set_active_store()"
			% store_id
		)
		return
	var previous: StringName = active_store_id
	active_store_id = canonical
	EventBus.active_store_changed.emit(canonical)
	if not canonical.is_empty():
		EventBus.store_entered.emit(canonical)
	if not previous.is_empty() and previous != canonical:
		EventBus.store_exited.emit(previous)


## Returns true if the given slot index has a registered owner.
func is_owned(slot_index: int) -> bool:
	return owned_slots.has(slot_index)


## Returns the store type for a given store_id, or empty if unknown.
func get_store_type(store_id: StringName) -> StringName:
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty():
		return &""
	return store_types.get(canonical, &"") as StringName


## Stores a custom name for a store.
func set_store_name(
	store_id: StringName, custom_name: String
) -> void:
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty():
		push_error(
			"StoreStateManager: invalid store_id '%s' for set_store_name()"
			% store_id
		)
		return
	store_names[String(canonical)] = custom_name


## Returns the custom name for a store, or the registry display name.
func get_store_name(store_id: StringName) -> String:
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty():
		return String(store_id)
	if store_names.has(String(canonical)):
		return store_names[String(canonical)]
	return ContentRegistry.get_display_name(canonical)


## Restores owned_slots from saved data and syncs GameManager.
func restore_owned_slots(slots: Dictionary) -> void:
	owned_slots = {}
	GameManager.owned_stores = []
	for key: Variant in slots:
		var idx: int = int(key)
		var raw_id: String = str(slots[key])
		var canonical: StringName = ContentRegistry.resolve(raw_id)
		if canonical.is_empty():
			push_error(
				"StoreStateManager: unknown store_id '%s' in slot %d"
				% [raw_id, idx]
			)
			continue
		owned_slots[idx] = canonical
		if canonical not in GameManager.owned_stores:
			GameManager.owned_stores.append(canonical)
	if GameManager.owned_stores.is_empty():
		GameManager.owned_stores = [GameManager.DEFAULT_STARTING_STORE]
	EventBus.owned_slots_restored.emit(owned_slots)


## Backward-compatible alias used by existing callers.
func register_slot_ownership(
	slot_index: int, store_id: StringName
) -> void:
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty():
		push_error(
			"StoreStateManager: invalid store_id '%s' for register_slot_ownership()"
			% store_id
		)
		return
	if owned_slots.has(slot_index):
		owned_slots[slot_index] = canonical
		return
	owned_slots[slot_index] = canonical


func _on_store_leased(
	slot_index: int, store_type: String
) -> void:
	var canonical: StringName = ContentRegistry.resolve(store_type)
	if not canonical.is_empty():
		register_slot_ownership(slot_index, canonical)


## Saves the current store's shelf slot state for later restoration.
func save_store_state(store_id: String) -> void:
	store_id = String(ContentRegistry.resolve(store_id))
	if store_id.is_empty():
		return
	if not _inventory_system:
		return

	var shelf_state: Dictionary = {}
	for item: ItemInstance in _inventory_system.get_shelf_items_for_store(
		store_id
	):
		var category: String = ""
		if item.definition:
			category = item.definition.category
		shelf_state[item.instance_id] = {
			"location": item.current_location,
			"category": category,
		}

	_store_states[store_id] = {
		"shelf_state": shelf_state,
	}


## Restores shelf slot visuals from saved state when re-entering a store.
func restore_store_state(
	store_id: String, store_controller: StoreController
) -> void:
	store_id = String(ContentRegistry.resolve(store_id))
	if store_id.is_empty() or not store_controller:
		return
	if not _store_states.has(store_id):
		return
	if not _inventory_system:
		return

	var state: Dictionary = _store_states[store_id]
	var shelf_state: Dictionary = state.get("shelf_state", {})

	for instance_id: String in shelf_state:
		var entry: Dictionary = shelf_state[instance_id]
		var location: String = entry.get("location", "")
		if not location.begins_with("shelf:"):
			continue

		var slot_id: String = location.substr(6)
		var slot: ShelfSlot = store_controller.get_slot_by_id(slot_id)
		if not slot or slot.is_occupied():
			continue

		var item: ItemInstance = _inventory_system.get_item(instance_id)
		if not item:
			continue

		var category: String = entry.get("category", "")
		slot.place_item(instance_id, category)


## Returns the total daily revenue for a specific store.
func get_store_revenue(store_id: String) -> float:
	var canonical: StringName = ContentRegistry.resolve(store_id)
	if canonical.is_empty():
		return 0.0
	return _store_revenue.get(String(canonical), 0.0)


## Resets daily revenue tracking for all stores.
func reset_daily_revenue() -> void:
	_store_revenue.clear()


## Records revenue for a specific store.
func record_store_revenue(store_id: String, amount: float) -> void:
	var canonical: StringName = ContentRegistry.resolve(store_id)
	if canonical.is_empty():
		push_warning(
			"StoreStateManager: cannot record revenue for unresolved store_id '%s'"
			% store_id
		)
		return
	var key: String = String(canonical)
	var current: float = _store_revenue.get(key, 0.0)
	_store_revenue[key] = current + amount


## Runs simplified background sales for unvisited owned stores.
func simulate_background(delta: float) -> void:
	_background_timer += delta
	if _background_timer < BACKGROUND_SALE_INTERVAL:
		return
	_background_timer -= BACKGROUND_SALE_INTERVAL

	for store_id: String in GameManager.owned_stores:
		if store_id == String(active_store_id):
			continue
		_simulate_store_sales(store_id)


## Serializes ownership and store type state for saving.
func serialize() -> Dictionary:
	var slots_data: Dictionary = {}
	for key: Variant in owned_slots:
		slots_data[key] = String(owned_slots[key])
	var types_data: Dictionary = {}
	for key: Variant in store_types:
		types_data[String(key)] = String(store_types[key])
	return {
		"owned_slots": slots_data,
		"store_types": types_data,
	}


## Restores ownership and store type state from saved data.
func deserialize(data: Dictionary) -> void:
	owned_slots = {}
	var saved_slots: Variant = data.get("owned_slots", {})
	if saved_slots is Dictionary:
		for key: Variant in saved_slots:
			var idx: int = int(key)
			var raw_id: String = str((saved_slots as Dictionary)[key])
			var canonical: StringName = ContentRegistry.resolve(raw_id)
			if canonical.is_empty():
				push_warning(
					"StoreStateManager: unresolved store_id '%s' "
					+ "in slot %d, skipping entry" % [raw_id, idx]
				)
				continue
			owned_slots[idx] = canonical

	store_types = {}
	var saved_types: Variant = data.get("store_types", {})
	if saved_types is Dictionary:
		for key: Variant in saved_types:
			var sid: StringName = StringName(str(key))
			var canonical_sid: StringName = ContentRegistry.resolve(String(sid))
			if canonical_sid.is_empty():
				push_warning(
					"StoreStateManager: unresolved store_id key '%s' in store_types"
					% sid
				)
				continue
			var raw_type: String = str((saved_types as Dictionary)[key])
			var canonical_type: StringName = ContentRegistry.resolve(raw_type)
			if canonical_type.is_empty():
				canonical_type = StringName(raw_type)
			store_types[canonical_sid] = canonical_type


## Serializes all per-store runtime state for saving.
func get_save_data() -> Dictionary:
	var states_copy: Dictionary = {}
	for store_id: String in _store_states:
		states_copy[store_id] = _store_states[store_id].duplicate(true)
	var base: Dictionary = serialize()
	base["store_states"] = states_copy
	base["store_revenue"] = _store_revenue.duplicate()
	base["store_names"] = store_names.duplicate()
	return base


## Restores all per-store runtime state from saved data.
func load_save_data(data: Dictionary) -> void:
	deserialize(data)
	_apply_state(data)


func _apply_state(data: Dictionary) -> void:
	_store_states = {}
	var saved_states: Variant = data.get("store_states", {})
	if saved_states is Dictionary:
		for key: String in saved_states:
			var canonical: StringName = ContentRegistry.resolve(key)
			if canonical.is_empty():
				push_warning(
					"StoreStateManager: unresolved store_id '%s' in store_states"
					% key
				)
				continue
			_store_states[String(canonical)] = (
				(saved_states as Dictionary)[key] as Dictionary
			).duplicate(true)

	_store_revenue = {}
	var saved_revenue: Variant = data.get("store_revenue", {})
	if saved_revenue is Dictionary:
		for key: String in saved_revenue:
			var canonical: StringName = ContentRegistry.resolve(key)
			if canonical.is_empty():
				push_warning(
					"StoreStateManager: unresolved store_id '%s' in store_revenue"
					% key
				)
				continue
			_store_revenue[String(canonical)] = float(
				(saved_revenue as Dictionary)[key]
			)

	store_names = {}
	var saved_names: Variant = data.get("store_names", {})
	if saved_names is Dictionary:
		for key: String in saved_names:
			var canonical: StringName = ContentRegistry.resolve(key)
			if canonical.is_empty():
				push_warning(
					"StoreStateManager: unresolved store_id '%s' in store_names"
					% key
				)
				continue
			store_names[String(canonical)] = str(
				(saved_names as Dictionary)[key]
			)
	_background_timer = 0.0


func _simulate_store_sales(store_id: String) -> void:
	if not _inventory_system or not _economy_system:
		return

	var shelf_items: Array[ItemInstance] = (
		_inventory_system.get_shelf_items_for_store(store_id)
	)
	if shelf_items.is_empty():
		return

	var sale_chance: float = BACKGROUND_SALE_BASE_CHANCE
	if randf() > sale_chance:
		return

	var item: ItemInstance = shelf_items.pick_random()
	var sale_price: float = item.player_set_price
	if sale_price <= 0.0:
		sale_price = _economy_system.calculate_market_value(item)

	_inventory_system.remove_item(item.instance_id)
	_economy_system.add_cash(sale_price, "Background sale: %s" % store_id)
	record_store_revenue(store_id, sale_price)

	var category: String = ""
	if item.definition:
		category = item.definition.category
	EventBus.item_sold.emit(item.instance_id, sale_price, category)


func _on_hour_changed(_hour: int) -> void:
	simulate_background(BACKGROUND_SALE_INTERVAL)


func _on_day_started(_day: int) -> void:
	reset_daily_revenue()
