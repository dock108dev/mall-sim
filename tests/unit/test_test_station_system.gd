## Unit tests for TestingSystem: untested badge, status assignment, multiplier config, and signal contracts.
extends GutTest

const STORE_DEFS_PATH: String = "res://game/content/stores/store_definitions.json"
const RETRO_GAMES_STORE_ID: String = "retro_games"

var _system: TestingSystem
var _inventory: InventorySystem
var _testing_config: Dictionary


func before_each() -> void:
	_testing_config = _load_testing_config()
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)
	_system = TestingSystem.new()
	add_child_autofree(_system)
	_system._inventory_system = _inventory
	_system._setup_timer()
	if not _testing_config.is_empty():
		_system._tested_working_multiplier = float(
			_testing_config.get("tested_working_multiplier", TestingSystem.DEFAULT_WORKING_MULTIPLIER)
		)
		_system._tested_not_working_multiplier = float(
			_testing_config.get("tested_not_working_multiplier", TestingSystem.DEFAULT_NOT_WORKING_MULTIPLIER)
		)


func _load_testing_config() -> Dictionary:
	if not FileAccess.file_exists(STORE_DEFS_PATH):
		return {}
	var file := FileAccess.open(STORE_DEFS_PATH, FileAccess.READ)
	if not file:
		return {}
	var json_text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return {}
	var stores: Variant = json.get_data()
	if not stores is Array:
		return {}
	for entry: Variant in stores:
		if entry is Dictionary and entry.get("id", "") == RETRO_GAMES_STORE_ID:
			var cfg: Variant = entry.get("testing_config", {})
			if cfg is Dictionary:
				return cfg as Dictionary
	return {}


func _make_item(
	category: String = "cartridges",
	store_type: String = "retro_games",
	tested: bool = false,
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_station_item"
	def.item_name = "Test Station Item"
	def.base_price = 10.0
	def.category = category
	def.store_type = store_type
	def.rarity = "common"
	var item: ItemInstance = ItemInstance.create_from_definition(def, "good")
	item.tested = tested
	_inventory._items[item.instance_id] = item
	return item


func test_item_starts_with_untested_badge() -> void:
	var item: ItemInstance = _make_item()
	assert_false(item.tested, "Newly created item should have tested == false")
	assert_eq(item.test_result, "", "Newly created item should have empty test_result")


func test_working_item_gets_tested_working_status() -> void:
	_system._working_chance = 1.0
	var item: ItemInstance = _make_item()
	_system.start_test(item.instance_id)
	_system._on_test_timer_timeout()
	assert_true(item.tested, "Item should be marked as tested")
	assert_eq(item.test_result, "tested_working", "Item should have tested_working status")


func test_not_working_item_gets_tested_not_working_status() -> void:
	_system._working_chance = 0.0
	var item: ItemInstance = _make_item()
	_system.start_test(item.instance_id)
	_system._on_test_timer_timeout()
	assert_true(item.tested, "Item should be marked as tested")
	assert_eq(item.test_result, "tested_not_working", "Item should have tested_not_working status")


func test_working_multiplier_applied() -> void:
	var config_multiplier: float = float(
		_testing_config.get("tested_working_multiplier", TestingSystem.DEFAULT_WORKING_MULTIPLIER)
	)
	_system._working_chance = 1.0
	var item: ItemInstance = _make_item()
	_system.start_test(item.instance_id)
	_system._on_test_timer_timeout()
	assert_eq(item.test_result, "tested_working", "Item should be tested_working before checking multiplier")
	assert_almost_eq(
		_system.get_working_multiplier(),
		config_multiplier,
		0.001,
		"System working multiplier must match tested_working_multiplier from retro_games.json"
	)


func test_not_working_multiplier_applied() -> void:
	var config_multiplier: float = float(
		_testing_config.get("tested_not_working_multiplier", TestingSystem.DEFAULT_NOT_WORKING_MULTIPLIER)
	)
	_system._working_chance = 0.0
	var item: ItemInstance = _make_item()
	_system.start_test(item.instance_id)
	_system._on_test_timer_timeout()
	assert_eq(item.test_result, "tested_not_working", "Item should be tested_not_working before checking multiplier")
	assert_almost_eq(
		_system.get_not_working_multiplier(),
		config_multiplier,
		0.001,
		"System not-working multiplier must match tested_not_working_multiplier from retro_games.json"
	)


func test_retest_blocked() -> void:
	var item: ItemInstance = _make_item()
	_system.start_test(item.instance_id)
	_system._on_test_timer_timeout()
	var first_result: String = item.test_result
	assert_false(
		_system.can_test(item),
		"can_test should return false for already-tested item"
	)
	var restarted: bool = _system.start_test(item.instance_id)
	assert_false(restarted, "start_test should return false for already-tested item")
	assert_eq(
		item.test_result, first_result,
		"test_result should not change after blocked retest attempt"
	)


func test_item_test_completed_signal_emitted() -> void:
	var captured_ids: Array[String] = []
	var captured_results: Array[String] = []
	var capture: Callable = func(item_id: String, result: String) -> void:
		captured_ids.append(item_id)
		captured_results.append(result)
	EventBus.item_test_completed.connect(capture)
	var item: ItemInstance = _make_item()
	_system.start_test(item.instance_id)
	_system._on_test_timer_timeout()
	EventBus.item_test_completed.disconnect(capture)
	assert_eq(
		captured_ids.size(), 1,
		"item_test_completed signal should fire exactly once"
	)
	assert_eq(
		captured_ids[0], item.instance_id,
		"Signal should carry the correct item instance_id"
	)
	assert_eq(
		captured_results[0], item.test_result,
		"Signal result should match the item test_result"
	)
