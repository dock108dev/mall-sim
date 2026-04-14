## Controller for the retro game store with testing and refurbishment.
class_name RetroGameStoreController
extends StoreController

const STORE_ID: StringName = &"retro_games"
const TESTING_STATION_FIXTURE_ID: String = "testing_station"

var _testing_station_slot: Node = null
var _refurbishment_system: RefurbishmentSystem = null


func _ready() -> void:
	store_type = STORE_ID
	super._ready()
	_find_testing_station()
	EventBus.item_stocked.connect(_on_item_stocked)


## Sets the RefurbishmentSystem reference.
func set_refurbishment_system(
	system: RefurbishmentSystem
) -> void:
	_refurbishment_system = system


## Returns the RefurbishmentSystem, or null if not set.
func get_refurbishment_system() -> RefurbishmentSystem:
	return _refurbishment_system


## Returns the testing station slot node, or null if not placed.
func get_testing_station_slot() -> Node:
	return _testing_station_slot


## Returns true if the store has a testing station fixture placed.
func has_testing_station() -> bool:
	return _testing_station_slot != null


## Returns true if the given item is valid for the testing station.
func can_test_item(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	if item.definition.store_type != STORE_ID:
		return false
	if item.tested:
		return false
	return true


## Places an item on the testing station and marks it as tested.
## Returns true on success.
func test_item(instance_id: String) -> bool:
	if not _inventory_system:
		push_warning(
			"RetroGameStoreController: no InventorySystem set"
		)
		return false
	if not _testing_station_slot:
		push_warning(
			"RetroGameStoreController: no testing station placed"
		)
		return false
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not can_test_item(item):
		push_warning(
			"RetroGameStoreController: item '%s' cannot be tested"
			% instance_id
		)
		return false
	item.tested = true
	EventBus.item_tested.emit(instance_id, true)
	return true


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


func _on_item_stocked(item_id: String, shelf_id: String) -> void:
	if not _testing_station_slot:
		return
	var station_slot_id: String = str(
		_testing_station_slot.get("slot_id")
	)
	if station_slot_id.is_empty() or shelf_id != station_slot_id:
		return
	test_item(item_id)
