## Controller for the retro game store. Manages lifecycle, testing stations,
## refurbishment queue integration, and quality grade assessment.
class_name RetroGames
extends StoreController

const STORE_ID: StringName = &"retro_games"
const STORE_TYPE: StringName = &"retro_games"
const TESTING_STATION_FIXTURE_ID: String = "testing_station"
const GRADES_PATH: String = "res://game/content/stores/retro_games/grades.json"
## Ordered condition tiers used by refurb actions.
const CONDITION_ORDER: PackedStringArray = [
	"poor", "fair", "good", "near_mint", "mint",
]

var _testing_station_slot: Node = null
var _refurbishment_system: RefurbishmentSystem = null
var _testing_system: TestingSystem = null
var _testing_available: bool = false
var _store_definition: Dictionary = {}
var _initialized: bool = false
## Maps instance_id → grade_id for all graded items this session.
var _item_grades: Dictionary = {}
## Maps grade_id → grade entry dict (loaded from grades.json at boot).
var _grade_table: Dictionary = {}


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
	_load_grades()
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


## Returns true if the given item is valid for the testing station.
func can_test_item(item: ItemInstance) -> bool:
	if not item or not item.definition:
		return false
	if item.definition.store_type != String(STORE_ID):
		return false
	if item.tested:
		return false
	return true


## Places an item on the testing station and marks it as tested.
## Returns true on success.
func test_item(instance_id: String) -> bool:
	if not _inventory_system:
		push_warning("RetroGames: no InventorySystem set")
		return false
	if not _testing_station_slot:
		push_warning("RetroGames: no testing station placed")
		return false
	var item: ItemInstance = _inventory_system.get_item(instance_id)
	if not can_test_item(item):
		push_warning("RetroGames: item '%s' cannot be tested" % instance_id)
		return false
	item.tested = true
	return true


## Inspects item_id and emits inspection_ready with condition and grade data.
## Returns false if item_id cannot be resolved.
func inspect_item(item_id: StringName) -> bool:
	if not _inventory_system:
		push_warning("RetroGames: inspect_item called without InventorySystem")
		return false
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		push_warning("RetroGames: inspect_item — item '%s' not found" % item_id)
		return false
	var condition_data: Dictionary = {
		"instance_id": item.instance_id,
		"item_name": item.definition.item_name if item.definition else "",
		"condition": item.condition,
		"current_grade": _item_grades.get(item.instance_id, ""),
		"grades": _grade_table.values(),
	}
	EventBus.inspection_ready.emit(item_id, condition_data)
	return true


## Records grade_id on item_id, emits grade_assigned, then resolves and emits
## item_priced via PriceResolver. Returns false on invalid inputs.
func assign_grade(item_id: StringName, grade_id: String) -> bool:
	if not _inventory_system:
		push_warning("RetroGames: assign_grade called without InventorySystem")
		return false
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		push_warning("RetroGames: assign_grade — item '%s' not found" % item_id)
		return false
	if not _grade_table.has(grade_id):
		push_warning("RetroGames: assign_grade — unknown grade_id '%s'" % grade_id)
		return false
	_item_grades[item.instance_id] = grade_id
	EventBus.grade_assigned.emit(item_id, grade_id)
	var price: float = get_item_price(item_id)
	EventBus.item_priced.emit(item_id, price)
	return true


## Returns the current sale price for an inventory item resolved via
## PriceResolver. Applies the explicitly assigned grade; falls back to the
## item's current condition tier so Clean/Repair/Restore each produce a
## distinct multiplier visible in the AuditStep log.
func get_item_price(item_id: StringName) -> float:
	if not _inventory_system:
		return 0.0
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item or not item.definition:
		return 0.0
	var multipliers: Array = []
	var grade_id: String = _item_grades.get(item.instance_id, "")
	if grade_id.is_empty():
		grade_id = item.condition  # condition tier as fallback grade
	if not grade_id.is_empty() and _grade_table.has(grade_id):
		var grade: Dictionary = _grade_table[grade_id]
		multipliers.append({
			"label": "Condition",
			"factor": float(grade.get("price_multiplier", 1.0)),
			"detail": str(grade.get("label", grade_id)),
		})
	var vintage_trend: float = MarketTrendSystemSingleton.get_trend_modifier(&"vintage")
	if vintage_trend != 1.0:
		multipliers.append({
			"slot": "trend",
			"label": "Vintage Trend",
			"factor": vintage_trend,
			"detail": "Vintage shelf trend: %.2f" % vintage_trend,
		})
	var result: PriceResolver.Result = PriceResolver.resolve_for_item(
		item_id, item.definition.base_price, multipliers
	)
	return result.final_price


## Applies a single-tier condition bump (Clean action). Returns false if the
## item cannot be advanced or is not found.
func refurbish_clean(item_id: StringName) -> bool:
	return _apply_refurb_tier(item_id, 1)


## Applies a two-tier condition bump (Repair action).
func refurbish_repair(item_id: StringName) -> bool:
	return _apply_refurb_tier(item_id, 2)


## Restores item to mint condition (Restore action).
func refurbish_restore(item_id: StringName) -> bool:
	return _apply_refurb_tier(item_id, CONDITION_ORDER.size() - 1)


## Queues an item for refurbishment via the RefurbishmentSystem.
func _queue_refurbishment(item_id: StringName) -> void:
	if not _refurbishment_system:
		push_warning("RetroGames: no RefurbishmentSystem set")
		return
	_refurbishment_system.start_refurbishment(String(item_id))


## Advances item condition by `steps` tiers (capped at mint) and emits
## refurbishment_completed. Does not use the queue; single-click for the
## vertical slice. Returns false if item cannot be found or is already at max.
func _apply_refurb_tier(item_id: StringName, steps: int) -> bool:
	if not _inventory_system:
		push_warning("RetroGames: _apply_refurb_tier called without InventorySystem")
		return false
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		push_warning("RetroGames: _apply_refurb_tier — item '%s' not found" % item_id)
		return false
	var current_idx: int = CONDITION_ORDER.find(item.condition)
	if current_idx < 0:
		current_idx = 0
	var max_idx: int = CONDITION_ORDER.size() - 1
	if current_idx >= max_idx:
		push_warning("RetroGames: item '%s' is already at max condition" % item_id)
		return false
	var new_idx: int = mini(current_idx + steps, max_idx)
	var new_condition: String = CONDITION_ORDER[new_idx]
	item.condition = new_condition
	EventBus.refurbishment_completed.emit(String(item_id), true, new_condition)
	return true


## Serializes retro-games-specific state for saving.
func get_save_data() -> Dictionary:
	return {
		"testing_available": _testing_available,
		"item_grades": _item_grades.duplicate(),
	}


## Restores retro-games-specific state from saved data.
func load_save_data(data: Dictionary) -> void:
	_testing_available = bool(data.get("testing_available", false))
	var grades_data: Variant = data.get("item_grades", {})
	if grades_data is Dictionary:
		_item_grades = grades_data as Dictionary


func _load_grades() -> void:
	if not FileAccess.file_exists(GRADES_PATH):
		push_error("RetroGames: grades.json not found at '%s'" % GRADES_PATH)
		return
	var file: FileAccess = FileAccess.open(GRADES_PATH, FileAccess.READ)
	if not file:
		push_error("RetroGames: cannot open grades.json (error %d)" % FileAccess.get_open_error())
		return
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_error("RetroGames: grades.json parse error: %s" % json.get_error_message())
		return
	var data: Variant = json.get_data()
	if data is not Dictionary:
		push_error("RetroGames: grades.json root must be a Dictionary")
		return
	var grades_arr: Variant = (data as Dictionary).get("grades", [])
	if grades_arr is not Array:
		push_error("RetroGames: grades.json 'grades' key must be an Array")
		return
	for entry: Variant in grades_arr as Array:
		if entry is not Dictionary:
			continue
		var grade_entry: Dictionary = entry as Dictionary
		var gid: Variant = grade_entry.get("id", "")
		if gid is not String or (gid as String).is_empty():
			continue
		var raw_mult: Variant = grade_entry.get("price_multiplier", 1.0)
		var mult: float = float(raw_mult) if (raw_mult is float or raw_mult is int) else 0.0
		if not is_finite(mult) or mult <= 0.0:
			push_warning("RetroGames: skipping grade '%s' — invalid price_multiplier" % (gid as String))
			continue
		_grade_table[gid as String] = grade_entry


func _on_store_entered(store_id: StringName) -> void:
	if store_id != STORE_ID:
		return
	_seed_starter_inventory()
	_testing_available = has_testing_station()
	EventBus.store_opened.emit(String(STORE_ID))


func get_store_actions() -> Array:
	var actions: Array = super()
	actions.append({"id": &"test", "label": "Test", "icon": ""})
	actions.append({"id": &"refurbish", "label": "Refurbish", "icon": ""})
	return actions


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
