## Tests the auto-advance behavior on the day-summary panel: countdown
## visibility, hover-pause, day-30 disable, manual advance via the
## `interact` action, and tear-down on hide.
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func test_auto_advance_starts_on_show_summary_under_day_30() -> void:
	_day_summary.show_summary(1, 100.0, 25.0, 75.0, 4)
	assert_true(_day_summary._auto_advance._running)
	assert_false(_day_summary._auto_advance._disabled)
	assert_true(_day_summary._auto_advance_bar.visible)
	assert_true(_day_summary._auto_advance_label.visible)


func test_auto_advance_disabled_on_day_30() -> void:
	_day_summary.show_summary(30, 100.0, 25.0, 75.0, 4)
	assert_false(_day_summary._auto_advance._running)
	assert_true(_day_summary._auto_advance._disabled)
	assert_false(_day_summary._auto_advance_bar.visible)


func test_panel_hover_pauses_auto_advance() -> void:
	_day_summary.show_summary(2, 100.0, 25.0, 75.0, 4)
	_day_summary._on_panel_mouse_entered()
	assert_true(_day_summary._auto_advance._paused)
	_day_summary._on_panel_mouse_exited()
	assert_false(_day_summary._auto_advance._paused)


func test_hide_summary_stops_auto_advance() -> void:
	_day_summary.show_summary(1, 100.0, 25.0, 75.0, 4)
	_day_summary.hide_summary()
	assert_false(_day_summary._auto_advance._running)


func test_auto_advance_remaining_seeded_to_constant() -> void:
	_day_summary.show_summary(1, 100.0, 25.0, 75.0, 4)
	assert_almost_eq(
		_day_summary._auto_advance._remaining,
		DaySummaryAutoAdvance.AUTO_ADVANCE_SECONDS,
		0.01,
	)


func test_auto_advance_label_text_includes_countdown() -> void:
	_day_summary.show_summary(1, 100.0, 25.0, 75.0, 4)
	assert_true(_day_summary._auto_advance_label.text.contains("12"))
