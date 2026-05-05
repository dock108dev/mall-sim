## DaySummary must render the manager-driven end-of-day comment after the
## day_closed → manager_end_of_day_comment → show_summary signal sequence.
## The label is created in _create_narrative_labels() and populated from the
## cached body styled as `— Vic: "..."`.
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func test_vic_comment_label_exists_after_ready() -> void:
	assert_not_null(
		_day_summary._vic_comment_label,
		"DaySummary must instantiate _vic_comment_label so the panel can "
		+ "show Vic's metric-driven end-of-day comment"
	)


func test_vic_comment_hidden_when_no_signal_received() -> void:
	# Showing the summary without a manager_end_of_day_comment must leave the
	# label hidden so legacy/test payloads still render cleanly.
	_day_summary.show_summary(1, 0.0, 0.0, 0.0, 0)
	assert_false(
		_day_summary._vic_comment_label.visible,
		"VicCommentLabel must hide when no comment was cached"
	)


func test_vic_comment_populated_after_signal_then_show_summary() -> void:
	EventBus.manager_end_of_day_comment.emit(
		"eod_warm_zero", "Tough day — nothing moved."
	)
	_day_summary.show_summary(1, 0.0, 0.0, 0.0, 0)
	assert_true(
		_day_summary._vic_comment_label.visible,
		"VicCommentLabel must be visible after a comment was cached"
	)
	var text: String = _day_summary._vic_comment_label.text
	assert_string_contains(text, "Vic", "Label must attribute the line to Vic")
	assert_string_contains(
		text, "Tough day — nothing moved.",
		"Label must contain the cached body verbatim"
	)


func test_vic_comment_quote_styling() -> void:
	EventBus.manager_end_of_day_comment.emit("eod_warm_normal", "Solid day.")
	_day_summary.show_summary(1, 100.0, 50.0, 50.0, 4)
	assert_eq(
		_day_summary._vic_comment_label.text,
		"— Vic: \"Solid day.\"",
		"Vic comment must render with the em-dash + quoted body styling"
	)


func test_vic_comment_cleared_after_consumption() -> void:
	# The cached comment must clear after show_summary so subsequent days that
	# do not emit a new comment do not re-render yesterday's line.
	EventBus.manager_end_of_day_comment.emit("eod_warm_normal", "Solid day.")
	_day_summary.show_summary(1, 100.0, 50.0, 50.0, 4)
	_day_summary.show_summary(2, 100.0, 50.0, 50.0, 4)
	assert_false(
		_day_summary._vic_comment_label.visible,
		"Vic comment must not persist into a day that emitted no new comment"
	)
