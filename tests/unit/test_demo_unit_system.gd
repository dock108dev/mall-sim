## Unit tests for Electronics demo unit designation, slot enforcement,
## purchase intent bonus, and EventBus signal contracts.
extends GutTest


var _controller: Electronics


func before_each() -> void:
	_controller = Electronics.new()
	add_child_autofree(_controller)
	_controller.initialize()


func test_item_designated_as_demo() -> void:
	var item_id: StringName = &"item_mp3_player"
	var result: bool = _controller.designate_demo(item_id)
	assert_true(result, "designate_demo should return true on first designation")
	assert_true(
		_controller.is_demo_unit(item_id),
		"Item should be tracked as a demo unit after designation"
	)
	assert_false(
		_controller.is_demo_unit(&"other_item"),
		"Non-designated item should not be reported as demo"
	)


func test_demo_slot_count_increments() -> void:
	assert_true(
		_controller.has_demo_slots_available(),
		"Slots should be available before any designation"
	)
	_controller.designate_demo(&"item_a")
	assert_true(
		_controller.has_demo_slots_available(),
		"Slots should still be available after one designation when max is 2"
	)
	_controller.designate_demo(&"item_b")
	assert_false(
		_controller.has_demo_slots_available(),
		"No slots should be available once max_demo_units is reached"
	)


func test_max_demo_slots_enforced() -> void:
	var max_units: int = _controller.get_max_demo_units()
	for i: int in range(max_units):
		var ok: bool = _controller.designate_demo(
			StringName("item_%d" % i)
		)
		assert_true(ok, "Designation %d should succeed below the limit" % i)
	var overflow: bool = _controller.designate_demo(&"item_overflow")
	assert_false(
		overflow,
		"designate_demo should return false when demo_slots_used == max_demo_units"
	)
	assert_false(
		_controller.is_demo_unit(&"item_overflow"),
		"Overflow item must not be added to demo unit list"
	)


func test_duplicate_designation_rejected() -> void:
	_controller.designate_demo(&"item_dup")
	var second: bool = _controller.designate_demo(&"item_dup")
	assert_false(second, "Re-designating the same item should return false")


func test_undesignate_returns_to_inventory() -> void:
	var item_id: StringName = &"item_camera"
	_controller.designate_demo(item_id)
	_controller.designate_demo(&"item_second")
	assert_true(_controller.is_demo_unit(item_id), "Precondition: item is demo")
	assert_false(
		_controller.has_demo_slots_available(),
		"Precondition: all slots filled before removal"
	)
	var result: bool = _controller.undesignate_demo(item_id)
	assert_true(result, "undesignate_demo should return true for a demo item")
	assert_false(
		_controller.is_demo_unit(item_id),
		"Item should no longer be marked as demo after undesignation"
	)
	assert_true(
		_controller.has_demo_slots_available(),
		"A demo slot should be free again after undesignation"
	)


func test_undesignate_nonexistent_returns_false() -> void:
	var result: bool = _controller.undesignate_demo(&"ghost_item")
	assert_false(result, "undesignate_demo should return false for unknown item")


func test_purchase_intent_bonus_applied() -> void:
	var bonus_when_empty: float = _controller.get_demo_browse_bonus()
	assert_almost_eq(
		bonus_when_empty, 0.0, 0.001,
		"Browse bonus should be 0.0 when no demo units are active"
	)
	_controller.designate_demo(&"item_pda")
	var bonus_with_demo: float = _controller.get_demo_browse_bonus()
	var expected_bonus: float = _controller.get_demo_interest_bonus()
	assert_almost_eq(
		bonus_with_demo, expected_bonus, 0.001,
		"Browse bonus should equal demo_interest_bonus from config when demo unit is active"
	)
	assert_gt(bonus_with_demo, 0.0, "Active demo bonus must be positive")


func test_purchase_intent_triggers_seek_saleable() -> void:
	var threshold: float = _controller.get_purchase_intent_threshold()
	var bonus: float = _controller.get_demo_interest_bonus()
	# A base intent just below threshold should exceed it once the demo bonus is added.
	var base_intent_below_threshold: float = threshold - bonus + 0.001
	var intent_without_demo: float = base_intent_below_threshold
	var intent_with_demo: float = base_intent_below_threshold + bonus
	assert_lt(
		intent_without_demo, threshold,
		"Base intent below threshold must not trigger purchase without demo"
	)
	assert_gte(
		intent_with_demo, threshold,
		"Base intent + demo bonus must meet or exceed purchase_intent_threshold"
	)


func test_demo_designated_signal() -> void:
	watch_signals(EventBus)
	var item_id: StringName = &"item_console"
	_controller.designate_demo(item_id)
	assert_signal_emitted(
		EventBus, "demo_item_placed",
		"demo_item_placed should be emitted after designate_demo"
	)
	var params: Array = get_signal_parameters(EventBus, "demo_item_placed")
	assert_eq(
		params[0] as String, String(item_id),
		"demo_item_placed should carry the correct item_id"
	)


func test_demo_removed_signal() -> void:
	var item_id: StringName = &"item_handheld"
	_controller.designate_demo(item_id)
	watch_signals(EventBus)
	_controller.undesignate_demo(item_id)
	assert_signal_emitted(
		EventBus, "demo_item_removed",
		"demo_item_removed should be emitted after undesignate_demo"
	)
	var params: Array = get_signal_parameters(EventBus, "demo_item_removed")
	assert_eq(
		params[0] as String, String(item_id),
		"demo_item_removed should carry the correct item_id"
	)
