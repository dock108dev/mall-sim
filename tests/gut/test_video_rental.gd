## Tests VideoRental controller: initialization, stub methods, and lifecycle.
extends GutTest


var _controller: VideoRental
var _registered_store_entry: bool = false
var _registered_item_entries: Array[StringName] = []
var _store_entry_snapshot: Dictionary = {}
var _item_entry_snapshots: Dictionary = {}


func before_each() -> void:
	_controller = VideoRental.new()
	add_child_autofree(_controller)


func test_store_id_constant() -> void:
	assert_eq(
		VideoRental.STORE_ID, &"video_rental",
		"STORE_ID should be video_rental"
	)


func test_store_type_set_in_ready() -> void:
	assert_eq(
		_controller.store_type, "video_rental",
		"store_type should be set to STORE_ID in _ready"
	)


func test_extends_store_controller() -> void:
	assert_true(
		_controller is StoreController,
		"VideoRental should extend StoreController"
	)


func test_initialize_creates_empty_rentals() -> void:
	_controller.initialize()
	assert_eq(
		_controller._active_rentals.size(), 0,
		"_active_rentals should be empty after initialize"
	)


func test_initialize_connects_rental_lifecycle_signals() -> void:
	_controller.initialize()
	assert_true(
		EventBus.active_store_changed.is_connected(
			_controller._on_active_store_changed
		),
		"initialize should connect active_store_changed"
	)
	assert_true(
		EventBus.hour_changed.is_connected(_controller._on_hour_changed),
		"initialize should connect hour_changed"
	)
	assert_true(
		EventBus.day_started.is_connected(_controller._on_day_started),
		"initialize should connect day_started"
	)


func test_initialize_idempotent() -> void:
	_controller.initialize()
	_controller._active_rentals["test_item"] = 5
	_controller.initialize()
	assert_true(
		_controller._active_rentals.has("test_item"),
		"Second initialize should not reset state"
	)


func test_rent_item_stub_returns_false() -> void:
	var result: bool = _controller.rent_item(&"some_item", Node.new())
	assert_false(result, "rent_item stub should return false")


func test_get_rental_status_default_available() -> void:
	_controller.initialize()
	var status: StringName = _controller.get_rental_status(&"any_item")
	assert_eq(
		status, &"available",
		"get_rental_status should return available by default"
	)


func test_get_rental_status_rented() -> void:
	_controller.initialize()
	_controller._active_rentals["rented_item"] = 5
	var status: StringName = _controller.get_rental_status(&"rented_item")
	assert_eq(
		status, &"rented",
		"get_rental_status should return rented for tracked items"
	)


func test_check_overdue_rentals_no_crash() -> void:
	_controller.initialize()
	_controller._check_overdue_rentals()
	assert_true(true, "_check_overdue_rentals stub should not crash")


func test_process_daily_returns_no_crash() -> void:
	_controller.initialize()
	_controller._process_daily_returns()
	assert_true(true, "_process_daily_returns stub should not crash")


func test_save_data_round_trip() -> void:
	_controller.initialize()
	_controller._active_rentals["test_tape"] = 3
	var saved: Dictionary = _controller.get_save_data()
	_controller._active_rentals.clear()
	_controller.load_save_data(saved)
	assert_true(
		_controller._active_rentals.has("test_tape"),
		"Rental state should survive save/load round trip"
	)


func test_load_save_data_empty() -> void:
	_controller.initialize()
	_controller._active_rentals["old"] = 1
	_controller.load_save_data({})
	assert_eq(
		_controller._active_rentals.size(), 0,
		"load_save_data with empty dict should clear rentals"
	)


func test_activation_on_store_change() -> void:
	EventBus.active_store_changed.emit(&"video_rental")
	assert_true(
		_controller.is_active(),
		"Controller should activate on matching store ID"
	)


func test_activation_on_canonical_store_change() -> void:
	_register_test_store_entry()
	EventBus.active_store_changed.emit(&"rentals")
	assert_true(
		_controller.is_active(),
		"Controller should activate on canonical rentals alias"
	)


func test_no_null_errors_without_inventory() -> void:
	_controller.initialize()
	EventBus.store_entered.emit(&"video_rental")
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

	EventBus.store_entered.emit(&"video_rental")
	await get_tree().process_frame

	EventBus.store_opened.disconnect(capture)
	var items: Array[ItemInstance] = inventory.get_items_for_store("video_rental")
	assert_eq(items.size(), 2, "Starter inventory should seed when the store is empty")
	assert_eq(opened_ids.size(), 1, "store_opened should emit once for Video Rental")
	assert_eq(opened_ids[0], "video_rental", "store_opened should use STORE_ID")


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
