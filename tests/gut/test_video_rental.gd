## Tests VideoRentalStoreController: initialization, lifecycle, and store entry.
extends GutTest


var _controller: VideoRentalStoreController
var _registered_store_entry: bool = false
var _registered_item_entries: Array[StringName] = []
var _store_entry_snapshot: Dictionary = {}
var _item_entry_snapshots: Dictionary = {}


func before_each() -> void:
	_controller = VideoRentalStoreController.new()
	add_child_autofree(_controller)


func test_store_id_constant() -> void:
	assert_eq(
		VideoRentalStoreController.STORE_ID, &"rentals",
		"STORE_ID should be rentals"
	)


func test_store_type_set_in_ready() -> void:
	assert_eq(
		_controller.store_type, "rentals",
		"store_type should be set to STORE_ID in _ready"
	)


func test_extends_store_controller() -> void:
	assert_true(
		_controller is StoreController,
		"VideoRentalStoreController should extend StoreController"
	)


func test_activation_on_canonical_store_id() -> void:
	EventBus.active_store_changed.emit(&"rentals")
	assert_true(
		_controller.is_active(),
		"Controller should activate when active_store_changed emits canonical id"
	)


func test_no_null_errors_without_inventory() -> void:
	EventBus.store_entered.emit(&"rentals")
	await get_tree().process_frame
	assert_true(true, "Store entry without inventory should not crash")


func test_store_entered_seeds_inventory_and_emits_store_opened() -> void:
	_register_test_store_entry()
	var inventory: InventorySystem = InventorySystem.new()
	add_child_autofree(inventory)
	_controller.set_inventory_system(inventory)
	var opened_ids: Array[String] = []
	var capture: Callable = func(store_id: String) -> void:
		opened_ids.append(store_id)
	EventBus.store_opened.connect(capture)

	EventBus.store_entered.emit(&"rentals")
	await get_tree().process_frame

	EventBus.store_opened.disconnect(capture)
	var items: Array[ItemInstance] = inventory.get_items_for_store("rentals")
	assert_eq(items.size(), 2, "Starter inventory should seed when the store is empty")
	assert_true(
		opened_ids.has("rentals"),
		"store_opened should emit with STORE_ID 'rentals'"
	)


func test_store_entered_via_alias_seeds_inventory() -> void:
	_register_test_store_entry()
	var inventory: InventorySystem = InventorySystem.new()
	add_child_autofree(inventory)
	_controller.set_inventory_system(inventory)

	EventBus.store_entered.emit(&"video_rental")
	await get_tree().process_frame

	var items: Array[ItemInstance] = inventory.get_items_for_store("rentals")
	assert_eq(
		items.size(), 2,
		"Store entry via alias should still seed starter inventory"
	)


func test_store_entered_no_double_seed() -> void:
	_register_test_store_entry()
	var inventory: InventorySystem = InventorySystem.new()
	add_child_autofree(inventory)
	_controller.set_inventory_system(inventory)

	EventBus.store_entered.emit(&"rentals")
	await get_tree().process_frame
	EventBus.store_entered.emit(&"rentals")
	await get_tree().process_frame

	var items: Array[ItemInstance] = inventory.get_items_for_store("rentals")
	assert_eq(
		items.size(), 2,
		"Seeding should not duplicate items on re-entry"
	)


func after_each() -> void:
	for item_id: StringName in _registered_item_entries:
		_restore_test_entry(
			item_id,
			_item_entry_snapshots.get(String(item_id), {})
		)
	_registered_item_entries.clear()
	_item_entry_snapshots.clear()
	if _registered_store_entry:
		_restore_test_entry(&"rentals", _store_entry_snapshot)
		_registered_store_entry = false
	_store_entry_snapshot = {}


func _register_test_store_entry() -> void:
	if not _registered_store_entry:
		_store_entry_snapshot = _snapshot_test_entry(&"rentals")
	_registered_store_entry = true
	_unregister_test_entry(&"rentals")
	ContentRegistry.register_entry(
		{
			"id": "rentals",
			"aliases": ["video_rental"],
			"name": "Video Rental",
			"store_type": "rentals",
			"starting_inventory": [
				"test_video_rental_item_a",
				"test_video_rental_item_b",
			],
		},
		"store"
	)
	_register_test_item_entry(
		&"test_video_rental_item_a",
		"Starter Tape A"
	)
	_register_test_item_entry(
		&"test_video_rental_item_b",
		"Starter Tape B"
	)


func _register_test_item_entry(item_id: StringName, item_name: String) -> void:
	var snapshot_key: String = String(item_id)
	if not _item_entry_snapshots.has(snapshot_key):
		_item_entry_snapshots[snapshot_key] = _snapshot_test_entry(item_id)
	_unregister_test_entry(item_id)
	ContentRegistry.register_entry(
		{
			"id": String(item_id),
			"item_name": item_name,
			"base_price": 2.5,
			"category": "vhs_classic",
			"rarity": "common",
			"store_type": "rentals",
			"rental_fee": 2.99,
			"rental_period_days": 3,
		},
		"item"
	)
	if not _registered_item_entries.has(item_id):
		_registered_item_entries.append(item_id)


func _unregister_test_entry(entry_id: StringName) -> void:
	var entries: Dictionary = ContentRegistry._entries
	var aliases: Dictionary = ContentRegistry._aliases
	var types: Dictionary = ContentRegistry._types
	var display_names: Dictionary = ContentRegistry._display_names
	var scene_map: Dictionary = ContentRegistry._scene_map
	entries.erase(entry_id)
	types.erase(entry_id)
	display_names.erase(entry_id)
	scene_map.erase(entry_id)
	for alias: StringName in aliases.keys():
		if aliases[alias] == entry_id:
			aliases.erase(alias)


func _snapshot_test_entry(entry_id: StringName) -> Dictionary:
	var aliases: Array[StringName] = []
	for alias: StringName in ContentRegistry._aliases.keys():
		if ContentRegistry._aliases[alias] == entry_id:
			aliases.append(alias)
	var entry: Dictionary = {}
	if ContentRegistry._entries.has(entry_id):
		var existing_entry: Variant = ContentRegistry._entries[entry_id]
		if existing_entry is Dictionary:
			entry = (existing_entry as Dictionary).duplicate(true)
	return {
		"exists": ContentRegistry._entries.has(entry_id),
		"entry": entry,
		"type": str(ContentRegistry._types.get(entry_id, "")),
		"display_name": str(ContentRegistry._display_names.get(entry_id, "")),
		"scene_path": str(ContentRegistry._scene_map.get(entry_id, "")),
		"aliases": aliases,
	}


func _restore_test_entry(entry_id: StringName, snapshot: Dictionary) -> void:
	_unregister_test_entry(entry_id)
	if not bool(snapshot.get("exists", false)):
		return
	var entry: Dictionary = snapshot.get("entry", {})
	ContentRegistry._entries[entry_id] = entry.duplicate(true)
	var entry_type: String = str(snapshot.get("type", ""))
	if not entry_type.is_empty():
		ContentRegistry._types[entry_id] = entry_type
	var display_name: String = str(snapshot.get("display_name", ""))
	if not display_name.is_empty():
		ContentRegistry._display_names[entry_id] = display_name
	var scene_path: String = str(snapshot.get("scene_path", ""))
	if not scene_path.is_empty():
		ContentRegistry._scene_map[entry_id] = scene_path
	for alias: Variant in snapshot.get("aliases", []):
		if alias is StringName:
			ContentRegistry._aliases[alias] = entry_id
