## Unit tests for ShelfSlot — item assignment, availability guard, and deassignment.
extends GutTest


var _slot: ShelfSlot
var _slot_signals: Array[ShelfSlot] = []


func before_each() -> void:
	_slot = ShelfSlot.new()
	add_child_autofree(_slot)
	_slot_signals = []
	_slot.slot_changed.connect(_on_slot_changed)


func after_each() -> void:
	if _slot.slot_changed.is_connected(_on_slot_changed):
		_slot.slot_changed.disconnect(_on_slot_changed)


func _on_slot_changed(slot: ShelfSlot) -> void:
	_slot_signals.append(slot)


func test_slot_available_when_empty() -> void:
	assert_true(
		_slot.is_available(),
		"A freshly created ShelfSlot must report itself as available"
	)


func test_slot_unavailable_after_assignment() -> void:
	var item_id: StringName = &"inst_001"
	var ok: bool = _slot.assign_item(item_id)
	assert_true(ok, "assign_item must return true on first assignment")
	assert_false(
		_slot.is_available(),
		"Slot must not be available after an item is assigned"
	)
	assert_eq(
		_slot.get_item_id(),
		item_id,
		"get_item_id must return the assigned item ID"
	)


func test_double_assignment_rejected() -> void:
	var first_id: StringName = &"inst_first"
	var second_id: StringName = &"inst_second"
	_slot.assign_item(first_id)
	var ok: bool = _slot.assign_item(second_id)
	assert_false(ok, "Second assign_item on an occupied slot must return false")
	assert_eq(
		_slot.get_item_id(),
		first_id,
		"get_item_id must still return the first item ID after a rejected assignment"
	)


func test_deassign_restores_availability() -> void:
	_slot.assign_item(&"inst_temp")
	_slot.deassign()
	assert_true(
		_slot.is_available(),
		"Slot must be available again after deassign()"
	)
	assert_eq(
		_slot.get_item_id(),
		&"",
		"get_item_id must return empty StringName after deassign()"
	)


func test_capacity_is_one_item_per_slot() -> void:
	_slot.assign_item(&"inst_cap_test")
	assert_eq(
		_slot.get_capacity(),
		1,
		"get_capacity must always return 1 — a slot holds exactly one item"
	)
	assert_eq(
		_slot.get_occupied(),
		1,
		"get_occupied must return 1 when an item is assigned"
	)
