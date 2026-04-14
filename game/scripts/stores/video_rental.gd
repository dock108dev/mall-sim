## Controller for the video rental store — rental lifecycle, state wiring, and initialization.
class_name VideoRental
extends StoreController

const STORE_ID: StringName = &"video_rental"
const STORE_TYPE: StringName = &"video_rental"

var _active_rentals: Dictionary = {}
var _initialized: bool = false


func _ready() -> void:
	store_type = STORE_ID
	super._ready()
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)


## Initializes rental tracking and connects lifecycle signals.
func initialize() -> void:
	if _initialized:
		return
	_active_rentals = {}
	EventBus.hour_changed.connect(_on_hour_changed)
	_initialized = true


## Attempts to rent an item to a customer. Stub for ISSUE-057.
func rent_item(_item_id: StringName, _customer: Node) -> bool:
	return false


## Returns the rental status of an item. Defaults to available.
func get_rental_status(item_id: StringName) -> StringName:
	if _active_rentals.has(String(item_id)):
		return &"rented"
	return &"available"


## Serializes rental state for saving.
func get_save_data() -> Dictionary:
	return {
		"active_rentals": _active_rentals.duplicate(true),
	}


## Restores rental state from save data.
func load_save_data(data: Dictionary) -> void:
	_active_rentals.clear()
	var saved: Variant = data.get("active_rentals", {})
	if saved is Dictionary:
		_active_rentals = (saved as Dictionary).duplicate(true)


func _on_store_entered(store_id: StringName) -> void:
	if store_id != STORE_ID and store_id != &"rentals":
		return
	_seed_starter_inventory()
	EventBus.store_opened.emit(String(STORE_ID))


func _on_store_exited(store_id: StringName) -> void:
	if store_id != STORE_ID and store_id != &"rentals":
		return
	EventBus.store_closed.emit(String(STORE_ID))


func _on_hour_changed(_hour: int) -> void:
	_check_overdue_rentals()


func _on_day_started(_day: int) -> void:
	_process_daily_returns()


## Checks for overdue rentals. Stub for ISSUE-058.
func _check_overdue_rentals() -> void:
	pass


## Processes daily returns. Stub for ISSUE-057 return flow.
func _process_daily_returns() -> void:
	pass


func _seed_starter_inventory() -> void:
	if not _inventory_system:
		return
	var resolved: StringName = ContentRegistry.resolve(String(STORE_ID))
	if resolved.is_empty():
		resolved = STORE_ID
	var existing: Array[ItemInstance] = (
		_inventory_system.get_items_for_store(String(resolved))
	)
	if not existing.is_empty():
		return
	var entry: Dictionary = ContentRegistry.get_entry(resolved)
	if entry.is_empty():
		push_error("VideoRental: no ContentRegistry entry for %s" % STORE_ID)
		return
	var starter_items: Variant = entry.get("starting_inventory", [])
	if starter_items is Array:
		for item_id: Variant in starter_items:
			if item_id is String:
				_add_starter_item(item_id as String)


func _add_starter_item(raw_id: String) -> void:
	if raw_id.is_empty():
		return
	var canonical: StringName = ContentRegistry.resolve(raw_id)
	if canonical.is_empty():
		push_error("VideoRental: unknown item_id '%s'" % raw_id)
		return
	var entry: Dictionary = ContentRegistry.get_entry(canonical)
	if entry.is_empty():
		return
	var def: ItemDefinition = _build_definition_from_entry(canonical, entry)
	var instance: ItemInstance = ItemInstance.create_from_definition(def)
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
