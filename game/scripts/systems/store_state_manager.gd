## Manages per-store state snapshots and background simulation for unvisited stores.
class_name StoreStateManager
extends Node

const BACKGROUND_SALE_BASE_CHANCE: float = 0.15
const BACKGROUND_SALE_INTERVAL: float = 60.0

var _store_states: Dictionary = {}
var _store_revenue: Dictionary = {}
var _inventory_system: InventorySystem
var _economy_system: EconomySystem
var _background_timer: float = 0.0


## Sets up references and connects to time signals.
func initialize(
	inventory: InventorySystem,
	economy: EconomySystem
) -> void:
	_inventory_system = inventory
	_economy_system = economy
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_started.connect(_on_day_started)


## Saves the current store's shelf slot state for later restoration.
func save_store_state(store_id: String) -> void:
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
	return _store_revenue.get(store_id, 0.0)


## Resets daily revenue tracking for all stores.
func reset_daily_revenue() -> void:
	_store_revenue.clear()


## Records revenue for a specific store.
func record_store_revenue(store_id: String, amount: float) -> void:
	var current: float = _store_revenue.get(store_id, 0.0)
	_store_revenue[store_id] = current + amount


## Runs simplified background sales for unvisited owned stores.
func simulate_background(delta: float) -> void:
	_background_timer += delta
	if _background_timer < BACKGROUND_SALE_INTERVAL:
		return
	_background_timer -= BACKGROUND_SALE_INTERVAL

	var active_store: String = GameManager.current_store_id
	for store_id: String in GameManager.owned_stores:
		if store_id == active_store:
			continue
		_simulate_store_sales(store_id)


## Serializes all per-store state for saving.
func get_save_data() -> Dictionary:
	var states_copy: Dictionary = {}
	for store_id: String in _store_states:
		states_copy[store_id] = _store_states[store_id].duplicate(true)
	return {
		"store_states": states_copy,
		"store_revenue": _store_revenue.duplicate(),
	}


## Restores per-store state from saved data.
func load_save_data(data: Dictionary) -> void:
	_store_states = {}
	var saved_states: Variant = data.get("store_states", {})
	if saved_states is Dictionary:
		for key: String in saved_states:
			_store_states[key] = (
				(saved_states as Dictionary)[key] as Dictionary
			).duplicate(true)

	_store_revenue = {}
	var saved_revenue: Variant = data.get("store_revenue", {})
	if saved_revenue is Dictionary:
		for key: String in saved_revenue:
			_store_revenue[key] = float(
				(saved_revenue as Dictionary)[key]
			)


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
	var sale_price: float = item.set_price
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
