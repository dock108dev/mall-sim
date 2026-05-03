## DaySummary must surface the post-close cash balance alongside revenue and
## items sold so the player understands their wallet state when the day ends.
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func test_cash_balance_label_present_in_scene() -> void:
	var label: Label = _day_summary.get_node_or_null(
		"Root/Panel/Margin/VBox/CashBalanceLabel"
	)
	assert_not_null(
		label,
		"DaySummary must include CashBalanceLabel so the player sees their "
		+ "wallet state at end of day"
	)


func test_cash_balance_populated_from_day_closed_payload() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 100.0,
		"items_sold": 3,
		"net_cash": 1234.56,
		"store_revenue": {},
	}
	EventBus.day_closed.emit(1, payload)
	assert_string_contains(
		_day_summary._cash_balance_label.text, "1234.56",
		"CashBalanceLabel must reflect net_cash from the day_closed payload"
	)


func test_cash_balance_handles_missing_payload_key() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 100.0,
		"items_sold": 3,
		"store_revenue": {},
	}
	EventBus.day_closed.emit(1, payload)
	assert_string_contains(
		_day_summary._cash_balance_label.text, "0.00",
		"CashBalanceLabel must default to $0.00 when the payload is missing net_cash"
	)


func test_cash_balance_renders_zero_balance() -> void:
	_day_summary.show_summary(1, 0.0, 0.0, 0.0, 0)
	var payload: Dictionary = {
		"day": 1,
		"total_revenue": 0.0,
		"items_sold": 0,
		"net_cash": 0.0,
		"store_revenue": {},
	}
	EventBus.day_closed.emit(1, payload)
	assert_string_contains(
		_day_summary._cash_balance_label.text, "0.00",
		"CashBalanceLabel must render $0.00 when the player closes broke"
	)
