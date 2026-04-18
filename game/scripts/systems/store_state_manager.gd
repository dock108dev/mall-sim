## Canonical owner of active store identity, slot ownership map, and storefront state.
class_name StoreStateManager
extends Node

const BACKGROUND_SALE_BASE_CHANCE: float = 0.15
const BACKGROUND_SALE_INTERVAL: float = 60.0
const LEASE_UNLOCK_REQUIREMENTS: Array[Dictionary] = [
	{},
	{"reputation": 25, "cost": 500},
	{"reputation": 40, "cost": 1500},
	{"reputation": 55, "cost": 4000},
	{"reputation": 70, "cost": 10000},
]

var active_store_id: StringName = &""
var owned_slots: Dictionary[int, StringName] = {}
var store_types: Dictionary = {}
var store_names: Dictionary = {}
var _store_states: Dictionary = {}
var _store_revenue: Dictionary = {}
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _background_timer: float = 0.0


func _ready() -> void:
	_connect_runtime_signals()


## Sets up references and connects to EventBus signals.
func initialize(
	inventory: InventorySystem,
	economy: EconomySystem
) -> void:
	_inventory_system = inventory
	_economy_system = economy
	_apply_state({})
	_connect_runtime_signals()


## Registers slot ownership. Returns false if slot is already owned.
func lease_store(
	slot_index: int,
	store_id: StringName,
	store_type: StringName = &"",
	emit_result: bool = true
) -> bool:
	var canonical_store_id: StringName = ContentRegistry.resolve(
		String(store_id)
	)
	if canonical_store_id.is_empty():
		push_error(
			"StoreStateManager: invalid store_id '%s' for lease_store()"
			% store_id
		)
		_emit_lease_result(
			store_id, false, "Invalid store ID.", emit_result
		)
		return false
	if owned_slots.has(slot_index):
		_emit_lease_result(
			canonical_store_id,
			false,
			"Slot %d is already owned." % slot_index,
			emit_result
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
	_emit_lease_result(canonical_store_id, true, "", emit_result)
	return true

## Returns the setup fee for a storefront slot index.
static func get_setup_fee_for_slot_index(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= LEASE_UNLOCK_REQUIREMENTS.size():
		return 0.0
	return float(LEASE_UNLOCK_REQUIREMENTS[slot_index].get("cost", 0.0))


## Returns the mall reputation required for a storefront slot index.
static func get_reputation_requirement_for_slot_index(
	slot_index: int
) -> float:
	if slot_index < 0 or slot_index >= LEASE_UNLOCK_REQUIREMENTS.size():
		return 0.0
	return float(
		LEASE_UNLOCK_REQUIREMENTS[slot_index].get("reputation", 0.0)
	)


## Updates the active store and optionally emits store transition signals.
func set_active_store(
	store_id: StringName,
	emit_transition_events: bool = true
) -> void:
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if not store_id.is_empty() and canonical.is_empty():
		push_error(
			"StoreStateManager: invalid store_id '%s' for set_active_store()"
			% store_id
		)
		return
	var previous: StringName = active_store_id
	active_store_id = canonical
	if previous != canonical:
		EventBus.store_switched.emit(String(previous), String(canonical))
	EventBus.active_store_changed.emit(canonical)
	if emit_transition_events and not canonical.is_empty():
		EventBus.store_entered.emit(canonical)
	if emit_transition_events and not previous.is_empty() and previous != canonical:
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


## Restores owned_slots from saved data.
func restore_owned_slots(slots: Dictionary) -> void:
	owned_slots = _deserialize_owned_slots(
		slots, "restore_owned_slots()"
	)
	EventBus.owned_slots_restored.emit(owned_slots)


## Registers canonical slot ownership without touching legacy GameManager state.
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
	if canonical.is_empty():
		return
	if owned_slots.get(slot_index, &"") == canonical:
		return
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


## Returns owned store IDs ordered by storefront slot.
func get_owned_store_ids() -> Array[StringName]:
	var owned_store_ids: Array[StringName] = []
	var slot_indices: Array[int] = []
	for slot_index: int in owned_slots:
		slot_indices.append(slot_index)
	slot_indices.sort()
	for slot_index: int in slot_indices:
		var canonical: StringName = owned_slots[slot_index]
		if canonical not in owned_store_ids:
			owned_store_ids.append(canonical)
	return owned_store_ids


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

	for store_id: StringName in get_owned_store_ids():
		if store_id == active_store_id:
			continue
		_simulate_store_sales(String(store_id))


## Serializes ownership and store type state for saving.
func serialize() -> Dictionary:
	var slots_data: Dictionary = {}
	for slot_index: int in owned_slots:
		slots_data[str(slot_index)] = String(owned_slots[slot_index])
	var types_data: Dictionary = {}
	for key: Variant in store_types:
		types_data[String(key)] = String(store_types[key])
	return {
		"owned_slots": slots_data,
		"store_types": types_data,
	}


## Restores ownership and store type state from saved data.
func deserialize(data: Dictionary) -> void:
	owned_slots = _deserialize_owned_slots(
		data.get("owned_slots", {}), "deserialize()"
	)

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


func _connect_runtime_signals() -> void:
	_connect_signal(EventBus.hour_changed, _on_hour_changed)
	_connect_signal(EventBus.day_started, _on_day_started)
	_connect_signal(EventBus.lease_requested, _on_lease_requested)
	_connect_signal(EventBus.store_leased, _on_store_leased)


func _connect_signal(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


func _emit_lease_result(
	store_id: StringName,
	success: bool,
	message: String,
	emit_result: bool
) -> void:
	if emit_result:
		EventBus.lease_completed.emit(store_id, success, message)


func _on_lease_requested(
	store_id: StringName,
	slot_index: int,
	store_name: String
) -> void:
	var canonical: StringName = ContentRegistry.resolve(String(store_id))
	if canonical.is_empty():
		push_error(
			"StoreStateManager: invalid store_id '%s' for lease_requested"
			% store_id
		)
		EventBus.lease_completed.emit(
			store_id, false, "Unknown store type."
		)
		return
	if slot_index < 0:
		EventBus.lease_completed.emit(
			canonical, false, "Invalid storefront slot."
		)
		return
	if owned_slots.has(slot_index):
		EventBus.lease_completed.emit(
			canonical,
			false,
			"Slot %d is already owned." % slot_index
		)
		return

	var lease_cost: float = get_setup_fee_for_slot_index(slot_index)
	var charged: bool = false
	if _economy_system and lease_cost > 0.0:
		charged = _economy_system.deduct_cash(
			lease_cost, "Store setup fee: %s" % canonical
		)
		if not charged:
			EventBus.lease_completed.emit(
				canonical, false, "Insufficient funds."
			)
			return

	var lease_registered: bool = lease_store(
		slot_index, canonical, canonical, false
	)
	if not lease_registered:
		if charged and _economy_system:
			_economy_system.add_cash(
				lease_cost, "Lease rollback: %s" % canonical
			)
		EventBus.lease_completed.emit(
			canonical, false, "Unable to complete lease."
		)
		return

	var display_name: String = store_name.strip_edges()
	if display_name.is_empty():
		display_name = ContentRegistry.get_display_name(canonical)
	set_store_name(canonical, display_name)

	EventBus.store_leased.emit(slot_index, String(canonical))
	EventBus.store_unlocked.emit(String(canonical), lease_cost)
	EventBus.lease_completed.emit(canonical, true, "")


func _deserialize_owned_slots(
	slots_data: Variant,
	context: String
) -> Dictionary[int, StringName]:
	var normalized: Dictionary[int, StringName] = {}
	if slots_data is not Dictionary:
		if slots_data != null and not str(slots_data).is_empty():
			push_error(
				"StoreStateManager: expected Dictionary for owned_slots in %s"
				% context
			)
		return normalized

	for key: Variant in slots_data:
		var idx: int = int(key)
		var raw_id: String = str((slots_data as Dictionary)[key])
		var canonical: StringName = ContentRegistry.resolve(raw_id)
		if canonical.is_empty():
			push_error(
				"StoreStateManager: unknown store_id '%s' in slot %d"
				% [raw_id, idx]
			)
			continue
		normalized[idx] = canonical
	return normalized


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
