## Day summary must surface backroom and shelf inventory counts as separate
## fields (BRAINDUMP Priority 9: 'Remaining Backroom Inventory: 7' /
## 'Remaining Shelf Inventory: 0'). These come from new payload keys
## populated by DayCycleController._show_day_summary.
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func test_backroom_label_present_in_scene() -> void:
	var label: Label = _day_summary.get_node_or_null(
		"Root/Panel/Margin/VBox/BackroomInventoryLabel"
	)
	assert_not_null(
		label,
		"DaySummary must include BackroomInventoryLabel for the BRAINDUMP "
		+ "'Remaining Backroom Inventory' field"
	)


func test_shelf_label_present_in_scene() -> void:
	var label: Label = _day_summary.get_node_or_null(
		"Root/Panel/Margin/VBox/ShelfInventoryLabel"
	)
	assert_not_null(
		label,
		"DaySummary must include ShelfInventoryLabel for the BRAINDUMP "
		+ "'Remaining Shelf Inventory' field"
	)


func test_backroom_label_populated_from_payload() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 100.0,
		"items_sold": 3,
		"backroom_inventory_remaining": 7,
		"shelf_inventory_remaining": 0,
		"store_revenue": {},
	}
	EventBus.day_closed.emit(1, payload)
	assert_string_contains(
		_day_summary._backroom_inventory_label.text, "7",
		"BackroomInventoryLabel must reflect backroom_inventory_remaining "
		+ "from EventBus.day_closed payload"
	)


func test_shelf_label_populated_from_payload() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 100.0,
		"items_sold": 3,
		"backroom_inventory_remaining": 7,
		"shelf_inventory_remaining": 2,
		"store_revenue": {},
	}
	EventBus.day_closed.emit(1, payload)
	assert_string_contains(
		_day_summary._shelf_inventory_label.text, "2",
		"ShelfInventoryLabel must reflect shelf_inventory_remaining "
		+ "from EventBus.day_closed payload"
	)


func test_split_labels_default_to_zero_when_keys_missing() -> void:
	# Defensive: legacy/test payloads that omit the new keys must still render.
	_day_summary.show_summary(1, 0.0, 0.0, 0.0, 0)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 0.0,
		"items_sold": 0,
		"store_revenue": {},
	}
	EventBus.day_closed.emit(1, payload)
	assert_string_contains(
		_day_summary._backroom_inventory_label.text, "0",
		"BackroomInventoryLabel must default to 0 when payload omits the key"
	)
	assert_string_contains(
		_day_summary._shelf_inventory_label.text, "0",
		"ShelfInventoryLabel must default to 0 when payload omits the key"
	)
