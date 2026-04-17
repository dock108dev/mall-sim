## Controller for the retro game store. Manages lifecycle, testing stations,
## and refurbishment queue integration.
class_name RetroGames
extends StoreController

const STORE_ID: StringName = &"retro_games"
const STORE_TYPE: StringName = &"retro_games"
const TESTING_STATION_FIXTURE_ID: String = "testing_station"

var _testing_station_slot: Node = null
var _refurbishment_system: RefurbishmentSystem = null
var _testing_system: TestingSystem = null
var _testing_available: bool = false
var _store_definition: Dictionary = {}
var _initialized: bool = false


func _ready() -> void:
	initialize()
	super._ready()
	_find_testing_station()


## Initializes Retro Games lifecycle state and EventBus wiring.
func initialize() -> void:
	if _initialized:
		return
	store_type = String(STORE_ID)
	_connect_lifecycle_signals()
	_store_definition = ContentRegistry.get_entry(STORE_ID)
	_connect_store_signal(EventBus.customer_purchased, _on_customer_purchased)
	_connect_store_signal(EventBus.inventory_item_added, _on_inventory_item_added)
	_connect_store_signal(EventBus.item_stocked, _on_item_stocked)
	_initialized = true


## Sets the RefurbishmentSystem reference.
func set_refurbishment_system(system: RefurbishmentSystem) -> void:
	_refurbishment_system = system


## Sets the TestingSystem reference.
func set_testing_system(system: TestingSystem) -> void:
	_testing_system = system


## Returns the TestingSystem, or null if not set.
func get_testing_system() -> TestingSystem:
	return _testing_system


## Returns the RefurbishmentSystem, or null if not set.
func get_refurbishment_system() -> RefurbishmentSystem:
	return _refurbishment_system


## Returns the loaded store definition data from ContentRegistry.
func get_store_definition() -> Dictionary:
	return _store_definition.duplicate(true)


## Returns the testing station slot node, or null if not placed.
func get_testing_station_slot() -> Node:
	return _testing_station_slot


## Returns true if the store has a testing station fixture placed.
func has_testing_station() -> bool:
	return _testing_station_slot != null


## Returns true if the given item can be tested.
func _can_test_item(item_id: StringName) -> bool:
	if not _testing_system or not _inventory_system:
		return false
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		return false
	return _testing_system.can_test(item)


## Queues an item for refurbishment via the RefurbishmentSystem.
func _queue_refurbishment(item_id: StringName) -> void:
	if not _refurbishment_system:
		push_warning("RetroGames: no RefurbishmentSystem set")
		return
	_refurbishment_system.start_refurbishment(String(item_id))


## Serializes retro-games-specific state for saving.
func get_save_data() -> Dictionary:
	return {
		"testing_available": _testing_available,
	}


## Restores retro-games-specific state from saved data.
func load_save_data(data: Dictionary) -> void:
	_testing_available = bool(data.get("testing_available", false))


func _on_store_entered(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	_seed_starter_inventory()
	_testing_available = has_testing_station()
	EventBus.store_opened.emit(String(STORE_ID))


func _on_store_exited(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	EventBus.store_closed.emit(String(STORE_ID))


func _on_customer_purchased(
	_store_id: StringName, item_id: StringName,
	_price: float, _customer_id: StringName
) -> void:
	if not _is_active:
		return
	_check_condition_note(item_id)


func _on_inventory_item_added(
	store_id: StringName, item_id: StringName
) -> void:
	if store_id != STORE_ID:
		return
	_check_needs_refurbishment(item_id)


func _on_item_stocked(item_id: String, shelf_id: String) -> void:
	if not _testing_station_slot:
		return
	var station_slot_id: String = str(
		_testing_station_slot.get("slot_id")
	)
	if station_slot_id.is_empty() or shelf_id != station_slot_id:
		return
	_try_auto_test(item_id)


func _check_condition_note(item_id: StringName) -> void:
	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item or not item.definition:
		return
	if item.definition.store_type != String(STORE_ID):
		return


func _check_needs_refurbishment(item_id: StringName) -> void:
	if not _inventory_system or not _refurbishment_system:
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		return
	if _refurbishment_system.can_refurbish(item):
		EventBus.notification_requested.emit(
			"%s could be refurbished" % item.definition.item_name
		)


func _try_auto_test(item_id: String) -> void:
	if not _testing_system:
		return
	_testing_system.start_test(item_id)


func _connect_store_signal(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


func _seed_starter_inventory() -> void:
	if not _inventory_system:
		return
	var existing: Array[ItemInstance] = (
		_inventory_system.get_items_for_store(String(STORE_ID))
	)
	if not existing.is_empty():
		return
	var entry: Dictionary = _store_definition
	if entry.is_empty():
		entry = ContentRegistry.get_entry(STORE_ID)
		_store_definition = entry
	if entry.is_empty():
		push_error(
			"RetroGames: no ContentRegistry entry for %s" % STORE_ID
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
		push_error("RetroGames: unknown item_id '%s'" % raw_id)
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


func _find_testing_station() -> void:
	for fixture: Node in _fixtures:
		if fixture.get("fixture_id") == TESTING_STATION_FIXTURE_ID:
			_assign_testing_station_slots(fixture)
			return
	for slot: Node in _slots:
		if slot.get("fixture_id") == TESTING_STATION_FIXTURE_ID:
			_testing_station_slot = slot
			return


func _assign_testing_station_slots(fixture: Node) -> void:
	for child: Node in fixture.get_children():
		if child.is_in_group("shelf_slot") or child.get("slot_id") != null:
			_testing_station_slot = child
			return
