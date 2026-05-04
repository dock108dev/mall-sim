## Day summary must offer a "Main Menu" exit alongside the "Next Day" CTA
## and "Return to Mall" routing (BRAINDUMP Priority 9). Pressing it must
## emit `main_menu_requested` so the host scene can route to the menu, and
## must NOT emit `next_day_confirmed` — leaving the run skips wages /
## milestones / save / advance_to_next_day.
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func test_main_menu_button_present_in_button_row() -> void:
	var button: Button = _day_summary.get_node_or_null(
		"Root/Panel/Margin/VBox/ButtonRow/MainMenuButton"
	)
	assert_not_null(
		button,
		"Day summary must include a MainMenuButton in ButtonRow"
	)
	assert_string_contains(
		button.text, "Main Menu",
		"Main menu button label must reference the main menu"
	)


func test_main_menu_press_emits_request_signal() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	var got_main_menu: Array[bool] = [false]
	_day_summary.main_menu_requested.connect(
		func() -> void: got_main_menu[0] = true
	)
	_day_summary._main_menu_button.pressed.emit()
	assert_true(
		got_main_menu[0],
		"Main menu button must emit main_menu_requested"
	)


func test_main_menu_press_does_not_advance_day() -> void:
	# Leaving the run via Main Menu must not fire next_day_confirmed —
	# wages / milestones / save / advance_to_next_day stay parked because
	# the player is exiting the session.
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	var got_next_day: Array[bool] = [false]
	var next_day_handler: Callable = func() -> void:
		got_next_day[0] = true
	EventBus.next_day_confirmed.connect(next_day_handler)
	_day_summary._main_menu_button.pressed.emit()
	EventBus.next_day_confirmed.disconnect(next_day_handler)
	assert_false(
		got_next_day[0],
		"Main menu button must NOT emit next_day_confirmed — leaving the "
		+ "run skips wages / milestones / save / advance_to_next_day"
	)
