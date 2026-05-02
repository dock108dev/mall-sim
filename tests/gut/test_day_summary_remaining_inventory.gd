## DaySummary must surface the end-of-day inventory total alongside revenue
## and items-sold so the player can see what stayed on the shelves, and must
## render gracefully when the player closes the day with zero sales.
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func test_inventory_remaining_label_present_in_scene() -> void:
	var label: Label = _day_summary.get_node_or_null(
		"Root/Panel/Margin/VBox/InventoryRemainingLabel"
	)
	assert_not_null(
		label,
		"DaySummary must include InventoryRemainingLabel so the player sees "
		+ "what stayed on shelves at end of day"
	)


func test_inventory_remaining_populated_from_day_closed_payload() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 100.0,
		"items_sold": 3,
		"inventory_remaining": 12,
		"store_revenue": {},
	}
	EventBus.day_closed.emit(1, payload)
	assert_string_contains(
		_day_summary._inventory_remaining_label.text, "12",
		"InventoryRemainingLabel must reflect inventory_remaining from "
		+ "EventBus.day_closed payload"
	)


func test_zero_sales_summary_renders_gracefully() -> void:
	# Player closes the day with zero stock placed and zero sales — the
	# summary must still display without errors.
	_day_summary.show_summary(1, 0.0, 0.0, 0.0, 0)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 0.0,
		"items_sold": 0,
		"inventory_remaining": 0,
		"store_revenue": {},
	}
	EventBus.day_closed.emit(1, payload)
	assert_string_contains(
		_day_summary._items_sold_label.text, "0",
		"ItemsSoldLabel must show 0 when the player closes with no sales"
	)
	assert_string_contains(
		_day_summary._revenue_label.text, "0.00",
		"RevenueLabel must show $0.00 when the player closes with no sales"
	)
	assert_string_contains(
		_day_summary._inventory_remaining_label.text, "0",
		"InventoryRemainingLabel must show 0 when nothing was stocked"
	)


func test_inventory_remaining_handles_missing_payload_key() -> void:
	# Defensive: older callers (or partial payloads) may omit the key entirely.
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 100.0,
		"items_sold": 3,
		"store_revenue": {},
	}
	EventBus.day_closed.emit(1, payload)
	assert_string_contains(
		_day_summary._inventory_remaining_label.text, "0",
		"InventoryRemainingLabel must default to 0 when the payload is missing "
		+ "inventory_remaining"
	)
