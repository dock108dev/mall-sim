## BRAINDUMP North Star step 15 — Day summary must offer a "Return to Mall"
## option that advances the day and routes the player back to the mall hub
## overview, alongside the existing "Next Day" CTA.
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func test_mall_overview_button_present_in_button_row() -> void:
	var button: Button = _day_summary.get_node_or_null(
		"Root/Panel/Margin/VBox/ButtonRow/MallOverviewButton"
	)
	assert_not_null(
		button,
		"Day summary must include a MallOverviewButton in ButtonRow"
	)
	assert_string_contains(
		button.text, "Mall",
		"Mall overview button label must reference the mall hub"
	)


func test_continue_button_advances_with_next_day_label() -> void:
	var button: Button = _day_summary.get_node_or_null(
		"Root/Panel/Margin/VBox/ButtonRow/ContinueButton"
	)
	assert_not_null(button, "Day summary must keep the ContinueButton")
	assert_string_contains(
		button.text, "Next Day",
		"Continue button label must remain 'Next Day' for clarity"
	)


func test_mall_overview_press_emits_request_and_advances_day() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	var got_mall_request: Array[bool] = [false]
	var got_next_day: Array[bool] = [false]
	_day_summary.mall_overview_requested.connect(
		func() -> void: got_mall_request[0] = true
	)
	var next_day_handler: Callable = func() -> void:
		got_next_day[0] = true
	EventBus.next_day_confirmed.connect(next_day_handler)
	_day_summary._mall_overview_button.pressed.emit()
	EventBus.next_day_confirmed.disconnect(next_day_handler)
	assert_true(
		got_mall_request[0],
		"Mall overview button must emit mall_overview_requested"
	)
	assert_true(
		got_next_day[0],
		"Mall overview button must also advance the day via "
		+ "next_day_confirmed so wages/milestones/save still run"
	)
