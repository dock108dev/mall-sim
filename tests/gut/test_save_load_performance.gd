## Tests save/load performance with large inventories and detects memory leaks
## over extended simulated gameplay sessions.
extends GutTest


const LARGE_INVENTORY_COUNT: int = 250
const PERFORMANCE_TARGET_MS: float = 1000.0
const SIMULATED_DAYS: int = 30
const MEMORY_GROWTH_THRESHOLD: float = 0.10

var _save_manager: SaveManager
var _economy: EconomySystem
var _inventory: InventorySystem
var _time_system: TimeSystem
var _reputation: ReputationSystem
var _test_slot: int = 1
var _saved_owned_stores: Array[String] = []
var _saved_store_id: String = ""


func before_each() -> void:
	_save_manager = SaveManager.new()
	add_child_autofree(_save_manager)

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
	add_child_autofree(_reputation)
	_reputation.initialize()

	_save_manager.initialize(
		_economy, _inventory, _time_system, _reputation
	)

	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_store_id = GameManager.current_store_id


func after_each() -> void:
	_save_manager.delete_save(_test_slot)
	_save_manager.delete_save(SaveManager.AUTO_SAVE_SLOT)
	GameManager.owned_stores = _saved_owned_stores
	GameManager.current_store_id = _saved_store_id


# --- Save performance with 200+ items ---


func test_save_with_large_inventory_under_one_second() -> void:
	_populate_inventory(LARGE_INVENTORY_COUNT)
	assert_gte(
		_inventory.get_item_count(), 200,
		"Should have at least 200 items for performance test"
	)

	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"

	var start_ms: int = Time.get_ticks_msec()
	var result: bool = _save_manager.save_game(_test_slot)
	var elapsed_ms: int = Time.get_ticks_msec() - start_ms

	assert_true(result, "Save should succeed with large inventory")
	assert_lt(
		float(elapsed_ms), PERFORMANCE_TARGET_MS,
		"Save with %d items took %dms (target: <%dms)"
		% [LARGE_INVENTORY_COUNT, elapsed_ms, int(PERFORMANCE_TARGET_MS)]
	)
	gut.p(
		"Save performance: %d items in %dms"
		% [LARGE_INVENTORY_COUNT, elapsed_ms]
	)


# --- Load performance with 200+ items ---


func test_load_with_large_inventory_under_one_second() -> void:
	_populate_inventory(LARGE_INVENTORY_COUNT)
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"

	var saved: bool = _save_manager.save_game(_test_slot)
	assert_true(saved, "Save should succeed before load test")

	_inventory.initialize(null)
	assert_eq(
		_inventory.get_item_count(), 0,
		"Inventory should be empty after re-init"
	)

	var start_ms: int = Time.get_ticks_msec()
	var result: bool = _save_manager.load_game(_test_slot)
	var elapsed_ms: int = Time.get_ticks_msec() - start_ms

	assert_true(result, "Load should succeed with large inventory")
	assert_lt(
		float(elapsed_ms), PERFORMANCE_TARGET_MS,
		"Load with %d items took %dms (target: <%dms)"
		% [LARGE_INVENTORY_COUNT, elapsed_ms, int(PERFORMANCE_TARGET_MS)]
	)
	gut.p(
		"Load performance: %d items in %dms"
		% [LARGE_INVENTORY_COUNT, elapsed_ms]
	)


# --- Round-trip preserves all items ---


func test_large_inventory_round_trip_preserves_items() -> void:
	_populate_inventory(LARGE_INVENTORY_COUNT)
	var original_count: int = _inventory.get_item_count()
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"

	_save_manager.save_game(_test_slot)
	_inventory.initialize(null)
	_save_manager.load_game(_test_slot)

	assert_eq(
		_inventory.get_item_count(), original_count,
		"All %d items should survive round-trip" % original_count
	)


# --- Save file size is reasonable ---


func test_save_file_size_reasonable() -> void:
	_populate_inventory(LARGE_INVENTORY_COUNT)
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"
	_save_manager.save_game(_test_slot)

	var path: String = SaveManager.SAVE_DIR + "slot_%d.json" % _test_slot
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "Save file should exist")
	var size_bytes: int = file.get_length()
	file.close()

	var size_kb: float = float(size_bytes) / 1024.0
	gut.p(
		"Save file size: %.1f KB for %d items"
		% [size_kb, LARGE_INVENTORY_COUNT]
	)
	assert_lt(
		size_kb, 1024.0,
		"Save file should be under 1MB for %d items" % LARGE_INVENTORY_COUNT
	)


# --- Memory stability over 30-day simulation ---


func test_memory_stable_over_30_day_simulation() -> void:
	_populate_inventory(50)
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"
	_economy._current_cash = 5000.0

	var memory_snapshots: Dictionary = {}
	var baseline_mem: int = _get_static_memory_usage()
	memory_snapshots[1] = baseline_mem

	for day: int in range(1, SIMULATED_DAYS + 1):
		_time_system.current_day = day
		EventBus.day_started.emit(day)

		_simulate_daily_activity(day)

		EventBus.day_ended.emit(day)

		if day == 10 or day == 20 or day == 30:
			memory_snapshots[day] = _get_static_memory_usage()

	gut.p("Memory snapshots (bytes):")
	for snapshot_day: int in memory_snapshots:
		gut.p(
			"  Day %d: %d bytes (%.1f KB)"
			% [
				snapshot_day,
				memory_snapshots[snapshot_day],
				float(memory_snapshots[snapshot_day]) / 1024.0,
			]
		)

	if baseline_mem > 0:
		var day_30_mem: int = memory_snapshots.get(30, baseline_mem)
		var growth: float = (
			float(day_30_mem - baseline_mem) / float(baseline_mem)
		)
		gut.p(
			"Memory growth day 1->30: %.1f%%" % (growth * 100.0)
		)
		assert_lt(
			growth, MEMORY_GROWTH_THRESHOLD,
			"Memory growth should be under %d%% (actual: %.1f%%)"
			% [int(MEMORY_GROWTH_THRESHOLD * 100), growth * 100.0]
		)


# --- Economy collections stay bounded ---


func test_economy_collections_bounded_over_session() -> void:
	_populate_inventory(20)
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"

	for day: int in range(1, SIMULATED_DAYS + 1):
		_time_system.current_day = day
		EventBus.day_started.emit(day)
		_record_test_transactions(day)
		EventBus.day_ended.emit(day)

	var save_data: Dictionary = _economy.get_save_data()
	var history_size: int = (
		save_data.get("sales_history", []) as Array
	).size()

	assert_lte(
		history_size, EconomySystem.SALES_HISTORY_DAYS,
		"Sales history should be bounded to %d days (actual: %d)"
		% [EconomySystem.SALES_HISTORY_DAYS, history_size]
	)
	gut.p(
		"Sales history size after %d days: %d (max: %d)"
		% [SIMULATED_DAYS, history_size, EconomySystem.SALES_HISTORY_DAYS]
	)


# --- PerformanceManager cache cleanup ---


func test_performance_cache_cleared_on_day_start() -> void:
	var perf: PerformanceManager = PerformanceManager.new()
	add_child_autofree(perf)
	perf.initialize(_economy)

	var test_def: ItemDefinition = _create_test_definition("cache_test")
	var test_item: ItemInstance = ItemInstance.create(
		test_def, "good", 1, 10.0
	)
	test_item.instance_id = "cache_test_1"

	perf.get_cached_market_value(test_item)
	var stats_before: Dictionary = perf.get_cache_stats()
	assert_gt(
		stats_before.get("entries", 0) as int, 0,
		"Cache should have entries after lookup"
	)

	EventBus.day_started.emit(2)
	var stats_after: Dictionary = perf.get_cache_stats()
	assert_eq(
		stats_after.get("entries", -1) as int, 0,
		"Cache should be empty after day_started"
	)


# --- CustomerSystem pool cleanup ---


func test_customer_pool_cleared_on_reinitialize() -> void:
	var cs: CustomerSystem = CustomerSystem.new()
	add_child_autofree(cs)
	cs.initialize(null, null, null)

	cs.initialize(null, null, null)

	assert_eq(
		cs.get_active_customer_count(), 0,
		"Active customers should be zero after re-initialize"
	)


# --- Repeated save/load doesn't leak ---


func test_repeated_save_load_no_growth() -> void:
	_populate_inventory(100)
	GameManager.owned_stores = ["sports_memorabilia"]
	GameManager.current_store_id = "sports_memorabilia"

	var mem_before: int = _get_static_memory_usage()

	for i: int in range(10):
		_save_manager.save_game(_test_slot)
		_inventory.initialize(null)
		_save_manager.load_game(_test_slot)

	var mem_after: int = _get_static_memory_usage()

	if mem_before > 0:
		var growth: float = (
			float(mem_after - mem_before) / float(mem_before)
		)
		gut.p(
			"Memory after 10 save/load cycles: growth %.1f%%"
			% (growth * 100.0)
		)
		assert_lt(
			growth, MEMORY_GROWTH_THRESHOLD,
			"Repeated save/load should not leak memory (growth: %.1f%%)"
			% (growth * 100.0)
		)


# --- Helpers ---


func _populate_inventory(count: int) -> void:
	var conditions: Array[String] = [
		"mint", "near_mint", "good", "fair", "poor"
	]
	var rarities: Array[String] = [
		"common", "uncommon", "rare", "very_rare", "legendary"
	]
	var categories: Array[String] = [
		"sports_cards", "jerseys", "memorabilia",
		"retro_games", "consoles",
	]

	for i: int in range(count):
		var def: ItemDefinition = _create_test_definition(
			"perf_item_%d" % i
		)
		def.base_price = 5.0 + float(i % 50) * 2.0
		def.rarity = rarities[i % rarities.size()]
		def.category = categories[i % categories.size()]

		var cond: String = conditions[i % conditions.size()]
		var item: ItemInstance = ItemInstance.create(
			def, cond, 1, def.base_price
		)
		if i % 3 == 0:
			item.current_location = "shelf:slot_%d" % i
		else:
			item.current_location = "backroom"
		item.set_price = def.base_price * 1.5
		item.tested = i % 4 == 0
		item.authentication_status = (
			"authenticated" if i % 10 == 0 else "none"
		)
		_inventory._items[item.instance_id] = item


func _create_test_definition(item_id: String) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = item_id
	def.name = "Test Item %s" % item_id
	def.store_type = "sports_memorabilia"
	def.base_price = 10.0
	def.rarity = "common"
	def.category = "sports_cards"
	def.condition_range = PackedStringArray(
		["poor", "fair", "good", "near_mint", "mint"]
	)
	return def


func _simulate_daily_activity(day: int) -> void:
	for i: int in range(3):
		EventBus.item_sold.emit(
			"item_%d_%d" % [day, i], 15.0 + float(i), "sports_cards"
		)

	_economy._daily_transactions.append({
		"amount": 45.0,
		"reason": "Daily sales",
		"type": EconomySystem.TransactionType.REVENUE,
		"timestamp": 600,
	})


func _record_test_transactions(day: int) -> void:
	for i: int in range(5):
		EventBus.item_sold.emit(
			"txn_%d_%d" % [day, i],
			10.0 + float(i),
			"sports_cards"
		)


func _get_static_memory_usage() -> int:
	return Performance.get_monitor(
		Performance.MEMORY_STATIC
	) as int
