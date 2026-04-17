## Unit tests for the ISSUE-149 Electronics demo-unit and lifecycle stubs.
extends GutTest


var _controller: Electronics


func before_each() -> void:
	_controller = Electronics.new()
	add_child_autofree(_controller)


func test_demo_unit_array_is_initialized_in_initialize() -> void:
	_controller.initialize()
	assert_eq(_controller._demo_unit_ids.size(), 0)


func test_designate_demo_stub_leaves_demo_list_empty() -> void:
	var result: bool = _controller.designate_demo(&"item_mp3_player")
	assert_false(result)
	assert_eq(_controller._demo_unit_ids.size(), 0)


func test_is_demo_unit_only_checks_membership() -> void:
	_controller._demo_unit_ids.clear()
	_controller._demo_unit_ids.append(&"item_camera")
	_controller._demo_unit_ids.append(&"item_console")
	assert_true(_controller.is_demo_unit(&"item_camera"))
	assert_true(_controller.is_demo_unit(&"item_console"))
	assert_false(_controller.is_demo_unit(&"item_headphones"))


func test_depreciation_tick_stub_is_callable() -> void:
	_controller._apply_depreciation_tick()
	assert_true(true)


func test_day_started_signal_invokes_safe_stub_path() -> void:
	EventBus.day_started.emit(7)
	assert_true(true)


func test_customer_entered_signal_does_not_require_demo_state() -> void:
	EventBus.customer_entered.emit({
		"store_id": Electronics.STORE_ID,
	})
	assert_true(true)
