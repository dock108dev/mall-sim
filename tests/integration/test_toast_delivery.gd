## Integration test: toast delivery chain — toast_requested emitted →
## ToastNotificationUI queues message → panel visible with correct text and category.
extends GutTest

var _ui: ToastNotificationUI


func before_each() -> void:
	_ui = ToastNotificationUI.new()
	_ui.size = Vector2(1152, 648)
	add_child_autofree(_ui)


# ── Queue growth ───────────────────────────────────────────────────────────────


func test_toast_requested_received() -> void:
	EventBus.toast_requested.emit("First", &"system", 3.0)
	var size_before: int = _ui._queue.size()
	EventBus.toast_requested.emit("Second", &"system", 3.0)
	assert_eq(
		_ui._queue.size(), size_before + 1,
		"Second toast_requested must increment _queue by 1 while first is showing"
	)


# ── Visibility after emit ──────────────────────────────────────────────────────


func test_toast_panel_visible_after_emit() -> void:
	EventBus.toast_requested.emit("Visible test", &"system", 3.0)
	await get_tree().process_frame
	assert_true(
		_ui.modulate.a > 0.0,
		"Toast root Control node must have modulate.a > 0.0 after emit"
	)


# ── Label text matches emitted message ────────────────────────────────────────


func test_toast_label_matches_message() -> void:
	const MSG: String = "Label match test"
	EventBus.toast_requested.emit(MSG, &"system", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Active panel must contain a Label node")
	if label:
		assert_eq(label.text, MSG, "Label text must equal the emitted message")


# ── Category tint: milestone (gold) ───────────────────────────────────────────


func test_milestone_category_tint() -> void:
	EventBus.toast_requested.emit("Milestone toast", &"milestone", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Active panel must contain a Label node")
	if label:
		var color: Color = label.get_theme_color("font_color")
		assert_almost_eq(color.r, 1.0, 0.05, "Milestone tint r must be ~1.0")
		assert_almost_eq(color.g, 0.85, 0.05, "Milestone tint g must be ~0.85")
		assert_almost_eq(color.b, 0.0, 0.05, "Milestone tint b must be ~0.0")
		assert_almost_eq(color.a, 1.0, 0.05, "Milestone tint a must be ~1.0")


# ── Category tint: staff (orange) ─────────────────────────────────────────────


func test_staff_category_tint() -> void:
	EventBus.toast_requested.emit("Staff toast", &"staff", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Active panel must contain a Label node")
	if label:
		var color: Color = label.get_theme_color("font_color")
		var expected: Color = ToastNotificationUI.CATEGORY_COLORS[&"staff"]
		assert_almost_eq(color.r, expected.r, 0.05, "Staff tint r must match orange")
		assert_almost_eq(color.g, expected.g, 0.05, "Staff tint g must match orange")
		assert_almost_eq(color.b, expected.b, 0.05, "Staff tint b must match orange")
		assert_almost_eq(color.a, 1.0, 0.05, "Staff tint a must be ~1.0")


# ── FIFO ordering ─────────────────────────────────────────────────────────────


func test_queue_fifo_ordering() -> void:
	EventBus.toast_requested.emit("First message", &"system", 3.0)
	EventBus.toast_requested.emit("Second message", &"system", 3.0)
	assert_eq(
		_ui._queue.size(), 1,
		"Exactly one toast should be pending in queue after two rapid emits"
	)
	var first_label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(first_label, "Active panel must exist for first toast")
	if first_label:
		assert_eq(
			first_label.text, "First message",
			"First emitted message must be displayed first"
		)
	_ui.dismiss()
	await get_tree().create_timer(0.25).timeout
	var second_label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(second_label, "Active panel must exist for second toast after first dismisses")
	if second_label:
		assert_eq(
			second_label.text, "Second message",
			"Second message must display only after first auto-dismisses"
		)


# ── Queue overflow cap ────────────────────────────────────────────────────────


func test_overflow_drop() -> void:
	EventBus.toast_requested.emit("Active", &"system", 3.0)
	for i: int in range(6):
		EventBus.toast_requested.emit("Pending %d" % i, &"system", 3.0)
	assert_true(
		_ui._queue.size() <= ToastNotificationUI.MAX_QUEUE_SIZE,
		"Queue must not exceed MAX_QUEUE_SIZE after 6 rapid emissions with one active"
	)


# ── Mouse filter ──────────────────────────────────────────────────────────────


func test_no_input_block() -> void:
	assert_eq(
		_ui.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"ToastNotificationUI root node must not block mouse input"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _find_label_in_panel(panel: PanelContainer) -> Label:
	if not is_instance_valid(panel):
		return null
	for child: Node in panel.get_children():
		if child is MarginContainer:
			for inner: Node in child.get_children():
				if inner is Label:
					return inner as Label
	return null
