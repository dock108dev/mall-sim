## Tests for the TestingSystem: item eligibility, test flow, and result handling.
extends GutTest


var _system: TestingSystem
var _inventory: InventorySystem


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)
	_system = TestingSystem.new()
	add_child_autofree(_system)
	_system._inventory_system = _inventory
	_system._setup_timer()


func _make_item(
	category: String = "cartridges",
	store_type: String = "retro_games",
	tested: bool = false,
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_cart_1"
	def.item_name = "Test Cartridge"
	def.base_price = 10.0
	def.category = category
	def.store_type = store_type
	def.rarity = "common"
	var item: ItemInstance = ItemInstance.create_from_definition(def)
	item.tested = tested
	_inventory._items[item.instance_id] = item
	return item


func test_can_test_untested_cartridge() -> void:
	var item: ItemInstance = _make_item()
	assert_true(
		_system.can_test(item),
		"Should be able to test an untested cartridge"
	)


func test_can_test_untested_console() -> void:
	var item: ItemInstance = _make_item("consoles")
	assert_true(
		_system.can_test(item),
		"Should be able to test an untested console"
	)


func test_cannot_test_already_tested() -> void:
	var item: ItemInstance = _make_item("cartridges", "retro_games", true)
	assert_false(
		_system.can_test(item),
		"Should not test an already-tested item"
	)


func test_cannot_test_non_testable_category() -> void:
	var item: ItemInstance = _make_item("accessories")
	assert_false(
		_system.can_test(item),
		"Accessories should not be testable"
	)


func test_cannot_test_wrong_store() -> void:
	var item: ItemInstance = _make_item("cartridges", "sports")
	assert_false(
		_system.can_test(item),
		"Items from other stores should not be testable"
	)


func test_cannot_test_null() -> void:
	assert_false(
		_system.can_test(null),
		"Null item should not be testable"
	)


func test_start_test_succeeds() -> void:
	var item: ItemInstance = _make_item()
	var started: bool = _system.start_test(item.instance_id)
	assert_true(started, "start_test should return true for eligible item")
	assert_true(_system.is_testing(), "Should be in testing state")
	assert_eq(
		_system.get_active_test_id(), item.instance_id,
		"Active test ID should match"
	)


func test_start_test_blocked_when_already_testing() -> void:
	var item1: ItemInstance = _make_item()
	_system.start_test(item1.instance_id)
	var def2 := ItemDefinition.new()
	def2.id = "test_cart_2"
	def2.item_name = "Other Cart"
	def2.base_price = 5.0
	def2.category = "cartridges"
	def2.store_type = "retro_games"
	def2.rarity = "common"
	var item2: ItemInstance = ItemInstance.create_from_definition(def2)
	_inventory._items[item2.instance_id] = item2
	assert_false(
		_system.can_test(item2),
		"Should not be able to test while another test is active"
	)


func test_start_test_rejects_ineligible() -> void:
	var item: ItemInstance = _make_item("accessories")
	var started: bool = _system.start_test(item.instance_id)
	assert_false(started, "start_test should return false for ineligible item")
	assert_false(_system.is_testing(), "Should not be in testing state")


func test_default_multipliers() -> void:
	assert_almost_eq(
		_system.get_working_multiplier(), 1.25, 0.001,
		"Default working multiplier should be 1.25"
	)
	assert_almost_eq(
		_system.get_not_working_multiplier(), 0.4, 0.001,
		"Default not-working multiplier should be 0.4"
	)


func test_default_duration() -> void:
	assert_almost_eq(
		_system.get_testing_duration(), 2.0, 0.001,
		"Default testing duration should be 2.0 seconds"
	)


func test_timer_completion_sets_tested() -> void:
	var item: ItemInstance = _make_item()
	_system.start_test(item.instance_id)
	_system._on_test_timer_timeout()
	assert_true(item.tested, "Item should be marked as tested after timer")
	assert_false(
		item.test_result.is_empty(),
		"test_result should be set after testing"
	)
	assert_true(
		item.test_result in ["tested_working", "tested_not_working"],
		"test_result should be either tested_working or tested_not_working"
	)
	assert_false(
		_system.is_testing(),
		"System should no longer be in testing state"
	)


func test_retesting_blocked() -> void:
	var item: ItemInstance = _make_item()
	_system.start_test(item.instance_id)
	_system._on_test_timer_timeout()
	assert_false(
		_system.can_test(item),
		"Already-tested item should not be testable again"
	)
	var restarted: bool = _system.start_test(item.instance_id)
	assert_false(restarted, "start_test should return false for tested item")


func test_signal_emitted_on_completion() -> void:
	var results: Array[String] = []
	var capture: Callable = func(
		_instance_id: String, result: String
	) -> void:
		results.append(result)
	EventBus.item_test_completed.connect(capture)
	var item: ItemInstance = _make_item()
	_system.start_test(item.instance_id)
	_system._on_test_timer_timeout()
	EventBus.item_test_completed.disconnect(capture)
	assert_eq(results.size(), 1, "Should emit exactly one completion signal")
	assert_true(
		results[0] in ["tested_working", "tested_not_working"],
		"Signal result should be valid"
	)


func test_legacy_item_tested_signal_emitted() -> void:
	var tested_results: Array[bool] = []
	var capture: Callable = func(
		_item_id: String, success: bool
	) -> void:
		tested_results.append(success)
	EventBus.item_tested.connect(capture)
	var item: ItemInstance = _make_item()
	_system.start_test(item.instance_id)
	_system._on_test_timer_timeout()
	EventBus.item_tested.disconnect(capture)
	assert_eq(
		tested_results.size(), 1,
		"Should emit legacy item_tested signal"
	)
