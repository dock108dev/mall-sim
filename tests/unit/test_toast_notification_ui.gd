## Unit tests for ToastNotificationUI: queue ordering, overflow guard, duration expiry,
## and category modulate mapping.
extends GutTest


var _ui: ToastNotificationUI


func before_each() -> void:
	_ui = ToastNotificationUI.new()
	_ui.size = Vector2(1152, 648)
	add_child_autofree(_ui)


# ---------------------------------------------------------------------------
# Queue ordering
# ---------------------------------------------------------------------------

func test_three_sequential_toasts_queued_in_fifo_order() -> void:
	EventBus.toast_requested.emit("Alpha", &"system", 5.0)
	EventBus.toast_requested.emit("Beta", &"system", 5.0)
	EventBus.toast_requested.emit("Gamma", &"system", 5.0)
	assert_eq(_ui._queue.size(), 2, "Two toasts should be queued behind the active one")
	assert_eq(_ui._queue[0]["message"], "Beta", "Beta should be first in queue (FIFO)")
	assert_eq(_ui._queue[1]["message"], "Gamma", "Gamma should be second in queue (FIFO)")


func test_second_toast_not_shown_until_first_finishes() -> void:
	EventBus.toast_requested.emit("First", &"system", 5.0)
	EventBus.toast_requested.emit("Second", &"system", 5.0)
	assert_true(_ui._is_showing, "First toast should be active")
	assert_eq(_ui._queue.size(), 1, "Second should remain queued")


func test_second_toast_shows_after_first_finishes() -> void:
	EventBus.toast_requested.emit("First", &"system", 5.0)
	EventBus.toast_requested.emit("Second", &"system", 5.0)
	_ui._on_toast_finished()
	assert_true(_ui._is_showing, "Second toast should now be active")
	assert_eq(_ui._queue.size(), 0, "Queue should be empty after second begins")


func test_queue_drains_to_empty_after_all_durations_elapse() -> void:
	EventBus.toast_requested.emit("One", &"system", 1.0)
	EventBus.toast_requested.emit("Two", &"system", 1.0)
	EventBus.toast_requested.emit("Three", &"system", 1.0)
	_ui._on_toast_finished()
	_ui._on_toast_finished()
	_ui._on_toast_finished()
	assert_false(_ui._is_showing, "Should not be showing after all toasts finish")
	assert_true(_ui._queue.is_empty(), "Queue should be empty after draining")


func test_fifo_order_preserved_through_queue_drain() -> void:
	EventBus.toast_requested.emit("One", &"system", 1.0)
	EventBus.toast_requested.emit("Two", &"system", 1.0)
	EventBus.toast_requested.emit("Three", &"system", 1.0)
	assert_eq(_ui._queue[0]["message"], "Two")
	_ui._on_toast_finished()
	assert_eq(_ui._queue[0]["message"], "Three")


# ---------------------------------------------------------------------------
# Overflow guard
# ---------------------------------------------------------------------------

func test_overflow_caps_queue_at_max_queue_size() -> void:
	EventBus.toast_requested.emit("Active", &"system", 10.0)
	var over_limit: int = ToastNotificationUI.MAX_QUEUE_SIZE + 2
	for i: int in range(over_limit):
		EventBus.toast_requested.emit("Item %d" % i, &"system", 3.0)
	assert_eq(
		_ui._queue.size(),
		ToastNotificationUI.MAX_QUEUE_SIZE,
		"Queue must not exceed MAX_QUEUE_SIZE"
	)


func test_overflow_drops_oldest_entries_silently() -> void:
	EventBus.toast_requested.emit("Active", &"system", 10.0)
	for i: int in range(ToastNotificationUI.MAX_QUEUE_SIZE + 1):
		EventBus.toast_requested.emit("Item %d" % i, &"system", 3.0)
	assert_eq(
		_ui._queue[0]["message"],
		"Item 1",
		"Oldest queued entry (Item 0) should have been silently dropped"
	)


func test_overflow_newest_entries_are_retained() -> void:
	EventBus.toast_requested.emit("Active", &"system", 10.0)
	var extra: int = ToastNotificationUI.MAX_QUEUE_SIZE + 1
	for i: int in range(extra):
		EventBus.toast_requested.emit("Item %d" % i, &"system", 3.0)
	var last_index: int = _ui._queue.size() - 1
	assert_eq(
		_ui._queue[last_index]["message"],
		"Item %d" % (extra - 1),
		"Most recent entry should remain in queue"
	)


# ---------------------------------------------------------------------------
# Duration expiry
# ---------------------------------------------------------------------------

func test_positive_duration_stored_in_queued_entry() -> void:
	EventBus.toast_requested.emit("Active", &"system", 5.0)
	EventBus.toast_requested.emit("Queued", &"system", 2.5)
	assert_eq(
		_ui._queue[0]["duration"],
		2.5,
		"Explicit positive duration should be stored as-is"
	)


func test_zero_duration_falls_back_to_default() -> void:
	EventBus.toast_requested.emit("Active", &"system", 5.0)
	EventBus.toast_requested.emit("ZeroDur", &"system", 0.0)
	assert_eq(
		_ui._queue[0]["duration"],
		ToastNotificationUI.DEFAULT_DURATION,
		"Duration of 0.0 should use DEFAULT_DURATION fallback"
	)


func test_negative_duration_falls_back_to_default() -> void:
	EventBus.toast_requested.emit("Active", &"system", 5.0)
	EventBus.toast_requested.emit("NegDur", &"system", -1.0)
	assert_eq(
		_ui._queue[0]["duration"],
		ToastNotificationUI.DEFAULT_DURATION,
		"Negative duration should use DEFAULT_DURATION fallback"
	)


func test_toast_visible_before_finish_callback() -> void:
	EventBus.toast_requested.emit("Visible", &"system", 5.0)
	assert_true(_ui._is_showing, "Toast should be visible immediately after request")
	assert_true(is_instance_valid(_ui._active_panel), "Active panel must exist")


func test_finish_callback_hides_toast_and_shows_next() -> void:
	EventBus.toast_requested.emit("First", &"system", 2.0)
	EventBus.toast_requested.emit("Second", &"system", 2.0)
	_ui._on_toast_finished()
	assert_true(
		_ui._is_showing,
		"Should still be showing after first finishes (second queued)"
	)
	assert_eq(_ui._queue.size(), 0, "Queue should be empty once second becomes active")


func test_finish_callback_with_empty_queue_stops_showing() -> void:
	EventBus.toast_requested.emit("Only", &"system", 1.0)
	_ui._on_toast_finished()
	assert_false(_ui._is_showing, "Should stop showing when no more toasts remain")


# ---------------------------------------------------------------------------
# Category modulate mapping
# ---------------------------------------------------------------------------

func test_category_system_maps_to_white() -> void:
	EventBus.toast_requested.emit("System toast", &"system", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Toast panel must contain a Label")
	if label:
		assert_eq(
			label.get_theme_color("font_color"),
			Color.WHITE,
			"&'system' category should use white"
		)


func test_category_milestone_maps_to_gold() -> void:
	EventBus.toast_requested.emit("Milestone toast", &"milestone", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Toast panel must contain a Label")
	if label:
		assert_eq(
			label.get_theme_color("font_color"),
			ToastNotificationUI.CATEGORY_COLORS[&"milestone"],
			"&'milestone' category should use gold"
		)


func test_category_staff_maps_to_orange() -> void:
	EventBus.toast_requested.emit("Staff toast", &"staff", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Toast panel must contain a Label")
	if label:
		assert_eq(
			label.get_theme_color("font_color"),
			ToastNotificationUI.CATEGORY_COLORS[&"staff"],
			"&'staff' category should use orange"
		)


func test_category_reputation_up_maps_to_gold() -> void:
	EventBus.toast_requested.emit("Rep up", &"reputation_up", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Toast panel must contain a Label")
	if label:
		assert_eq(
			label.get_theme_color("font_color"),
			ToastNotificationUI.CATEGORY_COLORS[&"reputation_up"],
			"&'reputation_up' category should use gold"
		)


func test_category_reputation_down_maps_to_red_orange() -> void:
	EventBus.toast_requested.emit("Rep down", &"reputation_down", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Toast panel must contain a Label")
	if label:
		assert_eq(
			label.get_theme_color("font_color"),
			ToastNotificationUI.CATEGORY_COLORS[&"reputation_down"],
			"&'reputation_down' category should use red-orange"
		)


func test_category_random_event_maps_to_amber() -> void:
	EventBus.toast_requested.emit("Random event", &"random_event", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Toast panel must contain a Label")
	if label:
		assert_eq(
			label.get_theme_color("font_color"),
			ToastNotificationUI.CATEGORY_COLORS[&"random_event"],
			"&'random_event' category should use amber"
		)


func test_unknown_category_falls_back_to_white_without_error() -> void:
	EventBus.toast_requested.emit("Unknown cat", &"unknown_xyz", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Toast panel must contain a Label")
	if label:
		assert_eq(
			label.get_theme_color("font_color"),
			ToastNotificationUI.DEFAULT_COLOR,
			"Unknown category should silently fall back to DEFAULT_COLOR (white)"
		)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _find_label_in_panel(panel: PanelContainer) -> Label:
	if not is_instance_valid(panel):
		return null
	for child: Node in panel.get_children():
		if child is MarginContainer:
			for inner: Node in child.get_children():
				if inner is Label:
					return inner as Label
	return null
