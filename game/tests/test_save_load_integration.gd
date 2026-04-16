## Integration test for full save/load round-trip across all serializable systems.
extends GutTest


var _save_manager: SaveManager
var _economy: EconomySystem
var _inventory: InventorySystem
var _time_system: TimeSystem
var _reputation: ReputationSystem
var _store_state_manager: StoreStateManager
var _trend_system: TrendSystem
var _progression_system: ProgressionSystem
var _staff_system: StaffSystem
var _order_system: OrderSystem
var _test_slot: int = 3
var _saved_owned_stores: Array[StringName] = []
var _saved_store_id: StringName = &""


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	_register_store_catalog()
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_store_id = GameManager.current_store_id

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()

	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)

	_reputation = ReputationSystem.new()
	_reputation.auto_connect_bus = false
	add_child_autofree(_reputation)

	_store_state_manager = StoreStateManager.new()
	add_child_autofree(_store_state_manager)
	_store_state_manager.initialize(_inventory, _economy)
	_store_state_manager.register_slot_ownership(0, &"sports")
	_store_state_manager.set_active_store(&"sports")

	_trend_system = TrendSystem.new()
	add_child_autofree(_trend_system)
	_trend_system.initialize(null)

	_progression_system = ProgressionSystem.new()
	add_child_autofree(_progression_system)
	_progression_system.initialize(_economy, _reputation)

	_order_system = OrderSystem.new()
	add_child_autofree(_order_system)
	_order_system.initialize(_inventory, _reputation, _progression_system)

	_staff_system = StaffSystem.new()
	add_child_autofree(_staff_system)
	_staff_system.initialize(_economy, _reputation, _inventory, null)

	_save_manager = SaveManager.new()
	add_child_autofree(_save_manager)
	_save_manager.initialize(_economy, _inventory, _time_system)
	_save_manager.set_reputation_system(_reputation)
	_save_manager.set_order_system(_order_system)
	_save_manager.set_store_state_manager(_store_state_manager)
	_save_manager.set_trend_system(_trend_system)
	_save_manager.set_progression_system(_progression_system)
	_save_manager.set_staff_system(_staff_system)

	GameManager.owned_stores = [&"sports"]
	GameManager.current_store_id = &"sports"


func after_each() -> void:
	_save_manager.delete_save(_test_slot)
	if FileAccess.file_exists(SaveManager.SLOT_INDEX_PATH):
		DirAccess.remove_absolute(SaveManager.SLOT_INDEX_PATH)
	GameManager.owned_stores = _saved_owned_stores
	GameManager.current_store_id = _saved_store_id


# --- EconomySystem round-trip ---


func test_economy_cash_round_trip() -> void:
	_economy._current_cash = 7777.77
	_economy._demand_modifiers = {"cards": 1.3, "tapes": 0.7}
	_economy._store_daily_revenue = {"sports": 250.0}

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_economy._current_cash = 0.0
	_economy._demand_modifiers = {}
	_economy._store_daily_revenue = {}

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")

	assert_almost_eq(
		_economy._current_cash, 7777.77, 0.01,
		"Cash should match pre-save value after load"
	)
	assert_almost_eq(
		float(_economy._demand_modifiers.get("cards", 0.0)),
		1.3, 0.01,
		"Demand modifier 'cards' should survive round-trip"
	)
	assert_almost_eq(
		float(_economy._demand_modifiers.get("tapes", 0.0)),
		0.7, 0.01,
		"Demand modifier 'tapes' should survive round-trip"
	)
	assert_almost_eq(
		float(_economy._store_daily_revenue.get("sports", 0.0)),
		250.0, 0.01,
		"Store daily revenue should survive round-trip"
	)


# --- InventorySystem round-trip ---


func test_inventory_stock_round_trip() -> void:
	var pre_save: Dictionary = _inventory.get_save_data()

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")

	var post_load: Dictionary = _inventory.get_save_data()
	_assert_dict_match(pre_save, post_load, "inventory")


# --- TimeSystem round-trip ---


func test_time_system_day_and_hour_round_trip() -> void:
	_time_system.current_day = 12
	_time_system.game_time_minutes = 900.0
	_time_system.current_hour = 15

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_time_system.current_day = 1
	_time_system.game_time_minutes = 420.0
	_time_system.current_hour = 7

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")

	assert_eq(
		_time_system.current_day, 12,
		"Current day should match pre-save value"
	)
	assert_almost_eq(
		_time_system.game_time_minutes, 900.0, 0.01,
		"Game time minutes should match pre-save value"
	)


# --- ReputationSystem round-trip ---


func test_reputation_tier_round_trip() -> void:
	_reputation.initialize_store("sports")
	_reputation.add_reputation("sports", 20.0)
	_reputation.initialize_store("retro_games")
	_reputation.add_reputation("retro_games", -15.0)

	var pre_save_sports: float = _reputation.get_reputation("sports")
	var pre_save_retro: float = _reputation.get_reputation(
		"retro_games"
	)

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_reputation.reset()

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")

	assert_almost_eq(
		_reputation.get_reputation("sports"),
		pre_save_sports, 0.01,
		"Sports reputation should match pre-save value"
	)
	assert_almost_eq(
		_reputation.get_reputation("retro_games"),
		pre_save_retro, 0.01,
		"Retro games reputation should match pre-save value"
	)


# --- TrendSystem round-trip ---


func test_trend_system_round_trip() -> void:
	var pre_save: Dictionary = _trend_system.get_save_data()

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_trend_system.load_save_data({})

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")

	var post_load: Dictionary = _trend_system.get_save_data()
	assert_eq(
		str(post_load.get("active_trends", [])),
		str(pre_save.get("active_trends", [])),
		"Active trends should match pre-save state"
	)
	assert_eq(
		post_load.get("days_until_next_shift", -1),
		pre_save.get("days_until_next_shift", -1),
		"Days until next shift should match pre-save state"
	)
	assert_eq(
		str(post_load.get("sales_since_shift", {})),
		str(pre_save.get("sales_since_shift", {})),
		"Sales since shift should match pre-save state"
	)


# --- ProgressionSystem round-trip ---


func test_progression_round_trip() -> void:
	_progression_system._total_revenue = 5000.0
	_progression_system._total_items_sold = 42
	_progression_system._unlocked_store_slots = 3
	_progression_system._unlocked_supplier_tier = 2
	_progression_system._cumulative_cash_earned = 8000.0
	_progression_system._mall_reputation = 37.5
	_progression_system._unlocked_slot_indices = {
		1: true,
		2: true,
	}

	var pre_save: Dictionary = _progression_system.get_save_data()

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_progression_system.load_save_data({})

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")

	var post_load: Dictionary = _progression_system.get_save_data()
	assert_almost_eq(
		float(post_load.get("total_revenue", 0.0)),
		5000.0, 0.01,
		"Total revenue should match pre-save value"
	)
	assert_eq(
		int(post_load.get("total_items_sold", 0)), 42,
		"Total items sold should match pre-save value"
	)
	assert_eq(
		int(post_load.get("unlocked_store_slots", 0)), 3,
		"Unlocked store slots should match pre-save value"
	)
	assert_eq(
		int(post_load.get("unlocked_supplier_tier", 0)), 2,
		"Unlocked supplier tier should match pre-save value"
	)
	assert_almost_eq(
		float(post_load.get("cumulative_cash_earned", 0.0)),
		8000.0, 0.01,
		"Cumulative cash earned should match pre-save value"
	)
	assert_almost_eq(
		float(post_load.get("mall_reputation", 0.0)),
		37.5, 0.01,
		"Mall reputation should match pre-save value"
	)
	var unlocked_slots: Array = post_load.get("unlocked_slot_indices", [])
	unlocked_slots.sort()
	assert_eq(
		unlocked_slots,
		[1, 2],
		"Unlocked slot indices should match pre-save value"
	)


func test_load_restores_progression_before_owned_slot_refresh() -> void:
	_progression_system._unlocked_slot_indices = {1: true}
	_progression_system._unlocked_store_slots = 2

	var unlock_visible_during_restore: Array[bool] = []
	var on_restore: Callable = func(_slots: Dictionary) -> void:
		unlock_visible_during_restore.append(
			_progression_system.is_slot_unlocked(1)
		)
	EventBus.owned_slots_restored.connect(on_restore)

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_progression_system.load_save_data({})
	_store_state_manager.owned_slots = {}

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")
	assert_eq(
		unlock_visible_during_restore,
		[true],
		"Progression unlocks should be restored before owned slot visuals refresh"
	)

	EventBus.owned_slots_restored.disconnect(on_restore)


# --- OrderSystem round-trip ---


func test_order_system_pending_orders_round_trip() -> void:
	_order_system.load_save_data({
		"pending_orders": [
			{
				"store_id": "sports",
				"supplier_tier": OrderSystem.SupplierTier.BASIC,
				"item_id": "sports_test_item",
				"quantity": 3,
				"unit_cost": 12.5,
				"delivery_day": 9,
			},
		],
		"daily_spending": {"0": 37.5},
	})

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_order_system.load_save_data({})

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")

	var post_load: Dictionary = _order_system.get_save_data()
	var orders: Array = post_load.get("pending_orders", [])
	assert_eq(orders.size(), 1, "Pending orders should survive round-trip")
	assert_eq(
		orders[0].get("store_id", ""), "sports",
		"Saved pending order should keep the store_id"
	)
	assert_eq(
		int(orders[0].get("delivery_day", 0)), 9,
		"Saved pending order should keep the delivery_day"
	)
	assert_almost_eq(
		float((post_load.get("daily_spending", {}) as Dictionary).get("0", 0.0)),
		37.5,
		0.01,
		"Daily spending should survive round-trip"
	)


# --- StaffSystem round-trip ---


func test_staff_system_round_trip() -> void:
	_staff_system._hired_staff = {
		"sports": [
			{
				"instance_id": "staff_1",
				"definition_id": "cashier_basic",
				"store_id": "sports",
				"hired_day": 3,
			},
		],
	}
	_staff_system._price_policies = {
		"sports": {"min_ratio": 1.1, "max_ratio": 1.8},
	}
	_staff_system._next_staff_id = 2

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_staff_system.load_save_data({})

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")

	var post_load: Dictionary = _staff_system.get_save_data()
	assert_eq(
		int(post_load.get("next_staff_id", 0)), 2,
		"Next staff id should match pre-save value"
	)
	var hired: Dictionary = post_load.get("hired_staff", {})
	assert_true(
		hired.has("sports"),
		"Hired staff should contain sports store"
	)
	var sports_staff: Array = hired.get("sports", [])
	assert_eq(
		sports_staff.size(), 1,
		"Sports store should have 1 staff member"
	)
	if sports_staff.size() > 0:
		var staff_entry: Dictionary = sports_staff[0] as Dictionary
		assert_eq(
			str(staff_entry.get("instance_id", "")), "staff_1",
			"Staff instance_id should survive round-trip"
		)
		assert_eq(
			str(staff_entry.get("definition_id", "")),
			"cashier_basic",
			"Staff definition_id should survive round-trip"
		)


func test_load_game_canonicalizes_legacy_store_ids() -> void:
	var legacy_save: Dictionary = {
		"save_version": SaveManager.CURRENT_SAVE_VERSION,
		"metadata": {
			"store_type": "consumer_electronics",
		},
		"save_metadata": {
			"store_type": "video_rental",
		},
		"time": _time_system.get_save_data(),
		"economy": _economy.get_save_data(),
		"inventory": _inventory.get_save_data(),
		"reputation": _reputation.get_save_data(),
		"owned_slots": {
			"0": "sports_memorabilia",
			"1": "video_rental",
			"2": "consumer_electronics",
		},
		"store_states": {
			"owned_slots": {
				"0": "sports_memorabilia",
				"1": "video_rental",
				"2": "consumer_electronics",
			},
			"store_types": {
				"sports_memorabilia": "sports_memorabilia",
				"video_rental": "video_rental",
				"consumer_electronics": "consumer_electronics",
			},
			"store_states": {
				"video_rental": {
					"shelf_state": {},
				},
			},
			"store_revenue": {
				"video_rental": 123.0,
			},
			"store_names": {
				"consumer_electronics": "Electronica",
			},
		},
	}
	_write_save_file(_test_slot, legacy_save)

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed for legacy store IDs")
	assert_eq(
		GameManager.current_store_id, &"rentals",
		"Active store should resolve to the canonical rentals ID"
	)
	assert_eq(_store_state_manager.owned_slots[0], &"sports")
	assert_eq(_store_state_manager.owned_slots[1], &"rentals")
	assert_eq(_store_state_manager.owned_slots[2], &"electronics")
	assert_eq(
		_store_state_manager.get_store_type(&"sports_memorabilia"),
		&"sports",
		"Legacy store_type keys should load as canonical IDs"
	)
	assert_eq(
		_store_state_manager.get_store_type(&"video_rental"),
		&"rentals",
		"Legacy rental IDs should load as canonical IDs"
	)
	assert_almost_eq(
		_store_state_manager.get_store_revenue("video_rental"),
		123.0,
		0.01,
		"Legacy revenue keys should load as canonical IDs"
	)
	assert_eq(
		_store_state_manager.get_store_name(&"consumer_electronics"),
		"Electronica",
		"Legacy store_names should load as canonical IDs"
	)


# --- Full session round-trip ---


func test_full_session_round_trip() -> void:
	_economy._current_cash = 3500.0
	_economy._items_sold_today = 8
	_economy._demand_modifiers = {"electronics": 1.1}
	_economy._store_daily_revenue = {"sports": 800.0}

	_time_system.current_day = 10
	_time_system.game_time_minutes = 720.0

	_reputation.initialize_store("sports")
	_reputation.add_reputation("sports", 10.0)

	_progression_system._total_revenue = 2000.0
	_progression_system._total_items_sold = 20

	_staff_system._hired_staff = {
		"sports": [
			{
				"instance_id": "staff_0",
				"definition_id": "cashier_basic",
				"store_id": "sports",
				"hired_day": 1,
			},
		],
	}
	_staff_system._next_staff_id = 1

	var pre_economy: Dictionary = _economy.get_save_data()
	var pre_time: Dictionary = _time_system.get_save_data()
	var pre_reputation: Dictionary = _reputation.get_save_data()
	var pre_trends: Dictionary = _trend_system.get_save_data()
	var pre_progression: Dictionary = _progression_system.get_save_data()
	var pre_staff: Dictionary = _staff_system.get_save_data()
	var pre_inventory: Dictionary = _inventory.get_save_data()

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed")

	_economy._current_cash = 0.0
	_economy._items_sold_today = 0
	_economy._demand_modifiers = {}
	_economy._store_daily_revenue = {}
	_time_system.current_day = 1
	_time_system.game_time_minutes = 420.0
	_reputation.reset()
	_trend_system.load_save_data({})
	_progression_system.load_save_data({})
	_staff_system.load_save_data({})

	var loaded: bool = _save_manager.load_game(_test_slot)
	assert_true(loaded, "Load should succeed")

	_assert_dict_match(
		pre_economy, _economy.get_save_data(), "economy"
	)
	_assert_dict_match(
		pre_time, _time_system.get_save_data(), "time"
	)
	_assert_dict_match(
		pre_reputation, _reputation.get_save_data(), "reputation"
	)
	_assert_dict_match(
		pre_trends, _trend_system.get_save_data(), "trends"
	)
	_assert_dict_match(
		pre_progression, _progression_system.get_save_data(),
		"progression"
	)
	_assert_dict_match(
		pre_staff, _staff_system.get_save_data(), "staff"
	)
	_assert_dict_match(
		pre_inventory, _inventory.get_save_data(), "inventory"
	)


func test_save_dict_round_trip_preserves_runtime_shape() -> void:
	_store_state_manager.register_slot_ownership(1, &"rentals")
	_store_state_manager.set_active_store(&"rentals")
	_economy._current_cash = 2750.5
	_time_system.current_day = 7
	_time_system.game_time_minutes = 810.0
	_trend_system._active_trends = [
		{
			"target_type": "category",
			"target": "sports",
			"trend_type": TrendSystem.TrendType.HOT,
			"multiplier": 1.7,
			"announced_day": 6,
			"active_day": 7,
			"end_day": 10,
			"fade_end_day": 12,
		},
	]
	_trend_system._days_until_next_shift = 4
	_trend_system._sales_since_shift = {"sports": 3.0}
	_staff_system._hired_staff = {
		"sports": [
			{
				"instance_id": "staff_1",
				"definition_id": "cashier_basic",
				"store_id": "sports",
				"hired_day": 2,
			},
		],
		"rentals": [
			{
				"instance_id": "staff_2",
				"definition_id": "cashier_basic",
				"store_id": "rentals",
				"hired_day": 4,
			},
		],
	}
	_staff_system._next_staff_id = 2
	_reputation.initialize_store("rentals")
	_reputation.add_reputation("rentals", 8.0)

	var pre_save: Dictionary = _sanitize_save_dict(
		_save_manager._collect_save_data()
	)

	assert_true(_save_manager.save_game(_test_slot), "Precondition: save must succeed")

	_economy.load_save_data({})
	_inventory.load_save_data({})
	_time_system.load_save_data({})
	_reputation.load_save_data({})
	_store_state_manager.load_save_data({})
	_trend_system.load_save_data({})
	_progression_system.load_save_data({})
	_staff_system.load_save_data({})

	assert_true(_save_manager.load_game(_test_slot), "Precondition: load must succeed")

	var post_load: Dictionary = _sanitize_save_dict(
		_save_manager._collect_save_data()
	)
	_assert_dict_match(pre_save, post_load, "save_dict")
	assert_eq(
		GameManager.current_store_id,
		&"rentals",
		"GameManager current_store_id should restore the saved active store"
	)
	assert_eq(
		_store_state_manager.active_store_id,
		&"rentals",
		"StoreStateManager active_store_id should restore the saved active store"
	)


func test_load_game_restores_empty_active_store() -> void:
	_store_state_manager.set_active_store(&"")

	assert_true(_save_manager.save_game(_test_slot), "Precondition: save must succeed")

	_store_state_manager.set_active_store(&"sports")

	watch_signals(EventBus)
	assert_true(_save_manager.load_game(_test_slot), "Precondition: load must succeed")
	assert_eq(
		GameManager.current_store_id,
		&"",
		"Loading a hallway save should keep the active store empty"
	)
	assert_eq(
		_store_state_manager.active_store_id,
		&"",
		"StoreStateManager should restore an empty active store for hallway saves"
	)
	assert_signal_emitted(
		EventBus,
		"active_store_changed",
		"Loading should emit active_store_changed so UI panels refresh"
	)


# --- Helpers ---


func _assert_dict_match(
	expected: Dictionary,
	actual: Dictionary,
	label: String
) -> void:
	for key: String in expected:
		assert_true(
			actual.has(key),
			"%s: missing key '%s' after load" % [label, key]
		)
		if actual.has(key):
			var expected_str: String = _canonical_string(expected[key])
			var actual_str: String = _canonical_string(actual[key])
			assert_eq(
				actual_str, expected_str,
				"%s.%s mismatch" % [label, key]
			)


func _sanitize_save_dict(data: Dictionary) -> Dictionary:
	var sanitized: Dictionary = data.duplicate(true)
	var metadata: Variant = sanitized.get("metadata", {})
	if metadata is Dictionary:
		(metadata as Dictionary).erase("timestamp")
		(metadata as Dictionary).erase("play_time")
	var save_metadata: Variant = sanitized.get("save_metadata", {})
	if save_metadata is Dictionary:
		(save_metadata as Dictionary).erase("saved_at")
		(save_metadata as Dictionary).erase("timestamp")
		(save_metadata as Dictionary).erase("play_time")
	return sanitized


func _canonical_string(value: Variant) -> String:
	return JSON.stringify(_canonicalize_variant(value))


func _canonicalize_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var normalized: Dictionary = {}
		var keys: Array[String] = []
		for key: Variant in value:
			keys.append(str(key))
		keys.sort()
		for key: String in keys:
			normalized[key] = _canonicalize_variant(
				(value as Dictionary).get(key)
			)
		return normalized
	if value is Array:
		var normalized_array: Array = []
		for entry: Variant in value:
			normalized_array.append(_canonicalize_variant(entry))
		return normalized_array
	return value


func _write_save_file(slot: int, save_data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(
		_save_manager._get_slot_path(slot), FileAccess.WRITE
	)
	assert_not_null(file, "Failed to open save file for test setup")
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()


func _register_store_catalog() -> void:
	ContentRegistry.register_entry(
		{
			"id": "sports",
			"aliases": ["sports_memorabilia"],
			"name": "Sports Memorabilia",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "retro_games",
			"name": "Retro Game Store",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "rentals",
			"aliases": ["video_rental"],
			"name": "Video Rental",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "electronics",
			"aliases": ["consumer_electronics"],
			"name": "Consumer Electronics",
		},
		"store"
	)
