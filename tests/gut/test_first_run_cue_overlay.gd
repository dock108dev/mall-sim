## Tests for FirstRunCueOverlay visibility: day-1 gating, empty-inventory
## gating, dismissal on stock, and no-reappear-this-day after dismissal.
extends GutTest


class FakeInventorySystem extends Node:
	var _stock_by_store: Dictionary = {}

	func get_stock(store_id: StringName) -> Array:
		var result: Array = []
		if _stock_by_store.has(store_id):
			for item in _stock_by_store[store_id]:
				result.append(item)
		return result

	func set_stock(store_id: StringName, items: Array) -> void:
		_stock_by_store[store_id] = items


class FakeTimeSystem extends Node:
	var current_day: int = 1


var _overlay: FirstRunCueOverlay
var _inventory: FakeInventorySystem
var _time: FakeTimeSystem


func before_each() -> void:
	_inventory = FakeInventorySystem.new()
	add_child_autofree(_inventory)
	_time = FakeTimeSystem.new()
	add_child_autofree(_time)
	_overlay = preload(
		"res://game/scenes/ui/first_run_cue_overlay.tscn"
	).instantiate() as FirstRunCueOverlay
	_overlay.inventory_system = _inventory
	_overlay.time_system = _time
	add_child_autofree(_overlay)


func test_starts_hidden() -> void:
	assert_false(
		_overlay.visible,
		"FirstRunCueOverlay should be hidden on ready"
	)


func test_visible_on_day_1_with_empty_inventory() -> void:
	_time.current_day = 1
	EventBus.store_entered.emit(&"electronics")
	assert_true(
		_overlay.visible,
		"Cue should be visible on day 1 when inventory is empty"
	)


func test_hidden_on_day_1_when_inventory_not_empty() -> void:
	_time.current_day = 1
	_inventory.set_stock(&"electronics", ["item_1"])
	EventBus.store_entered.emit(&"electronics")
	assert_false(
		_overlay.visible,
		"Cue should not appear when inventory is non-empty"
	)


func test_hidden_on_day_2_even_when_empty() -> void:
	_time.current_day = 2
	EventBus.store_entered.emit(&"electronics")
	assert_false(
		_overlay.visible,
		"Cue should not appear on day > 1"
	)


func test_dismisses_when_inventory_becomes_non_empty() -> void:
	_time.current_day = 1
	EventBus.store_entered.emit(&"electronics")
	assert_true(_overlay.visible, "Precondition: cue is visible")
	_inventory.set_stock(&"electronics", ["item_1"])
	EventBus.inventory_updated.emit(&"electronics")
	assert_false(
		_overlay.visible,
		"Cue should dismiss after inventory becomes non-empty"
	)


func test_does_not_reappear_same_day_after_dismissal() -> void:
	_time.current_day = 1
	EventBus.store_entered.emit(&"electronics")
	_inventory.set_stock(&"electronics", ["item_1"])
	EventBus.inventory_updated.emit(&"electronics")
	assert_false(_overlay.visible, "Precondition: cue dismissed")
	_inventory.set_stock(&"electronics", [])
	EventBus.store_entered.emit(&"electronics")
	assert_false(
		_overlay.visible,
		"Cue should not reappear same day after it was dismissed"
	)


func test_hides_on_day_transition() -> void:
	_time.current_day = 1
	EventBus.store_entered.emit(&"electronics")
	assert_true(_overlay.visible, "Precondition: cue is visible")
	EventBus.day_started.emit(2)
	assert_false(
		_overlay.visible,
		"Cue should hide when day > 1"
	)


func test_inventory_update_for_other_store_does_not_dismiss() -> void:
	_time.current_day = 1
	EventBus.store_entered.emit(&"electronics")
	assert_true(_overlay.visible, "Precondition")
	_inventory.set_stock(&"rentals", ["tape_1"])
	EventBus.inventory_updated.emit(&"rentals")
	assert_true(
		_overlay.visible,
		"Updates to a non-active store should not dismiss the cue"
	)
