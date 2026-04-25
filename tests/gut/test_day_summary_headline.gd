## ISSUE-012: Day-close summary headline — revenue delta, hoisted
## top-seller/forward-hook, and de-emphasized secondary CTA.
extends GutTest


var _day_summary: DaySummary


func before_each() -> void:
	_day_summary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(_day_summary)


func test_first_day_omits_delta() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	assert_string_contains(_day_summary._revenue_label.text, "$100.00")
	assert_false(
		_day_summary._revenue_label.text.contains("vs yesterday")
	)


func test_second_day_shows_positive_delta() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	_day_summary.show_summary(2, 150.0, 40.0, 110.0, 5)
	assert_string_contains(
		_day_summary._revenue_label.text, "+$50.00 vs yesterday"
	)


func test_second_day_shows_negative_delta() -> void:
	_day_summary.show_summary(1, 200.0, 40.0, 160.0, 6)
	_day_summary.show_summary(2, 120.0, 40.0, 80.0, 4)
	assert_string_contains(
		_day_summary._revenue_label.text, "-$80.00 vs yesterday"
	)


func test_show_last_does_not_shift_previous() -> void:
	_day_summary.show_summary(1, 100.0, 40.0, 60.0, 3)
	_day_summary.show_summary(2, 150.0, 40.0, 110.0, 5)
	_day_summary.show_last()
	assert_string_contains(
		_day_summary._revenue_label.text, "+$50.00 vs yesterday"
	)


func test_top_seller_row_positioned_above_detail_dump() -> void:
	# Godot VBox renders children top-to-bottom by ascending child index, so a
	# row "above" another has the smaller index.
	var top_idx: int = _day_summary._top_item_label.get_index()
	var profit_idx: int = _day_summary._profit_label.get_index()
	var rent_idx: int = _day_summary._rent_label.get_index()
	assert_lt(top_idx, profit_idx, "top seller must be above the profit detail row")
	assert_lt(top_idx, rent_idx, "top seller must be above the rent detail row")


func test_forward_hook_positioned_above_detail_dump() -> void:
	var hook_idx: int = _day_summary._forward_hook_label.get_index()
	var profit_idx: int = _day_summary._profit_label.get_index()
	var rent_idx: int = _day_summary._rent_label.get_index()
	assert_lt(hook_idx, profit_idx, "forward hook must be above the profit detail row")
	assert_lt(hook_idx, rent_idx, "forward hook must be above the rent detail row")


func test_secondary_button_is_de_emphasized() -> void:
	assert_true(
		_day_summary._review_inventory_button.flat,
		"Review Inventory button should be flat/secondary"
	)
	assert_lt(
		_day_summary._review_inventory_button.modulate.a, 1.0,
		"Secondary button should be dimmed"
	)
	assert_gt(
		_day_summary._continue_button.custom_minimum_size.x,
		_day_summary._review_inventory_button.custom_minimum_size.x,
		"Primary Continue CTA should be larger than secondary"
	)
