## Tests for ToastNotificationUI queue, category tinting, and dismiss behavior.
extends GutTest


var _ui: ToastNotificationUI


func before_each() -> void:
	_ui = ToastNotificationUI.new()
	_ui.size = Vector2(1152, 648)
	add_child_autofree(_ui)


func test_subscribes_to_toast_requested() -> void:
	assert_true(
		EventBus.toast_requested.is_connected(_ui._on_toast_requested),
		"Should connect to EventBus.toast_requested in _ready"
	)


func test_single_toast_creates_panel() -> void:
	EventBus.toast_requested.emit("Hello", &"system", 3.0)
	assert_true(
		_ui._is_showing,
		"Should be showing after a toast is requested"
	)
	assert_true(
		is_instance_valid(_ui._active_panel),
		"Active panel should exist"
	)


func test_empty_message_ignored() -> void:
	EventBus.toast_requested.emit("", &"system", 3.0)
	assert_false(
		_ui._is_showing,
		"Empty message should not trigger a toast"
	)


func test_queues_second_toast() -> void:
	EventBus.toast_requested.emit("First", &"system", 3.0)
	EventBus.toast_requested.emit("Second", &"system", 3.0)
	assert_eq(
		_ui._queue.size(), 1,
		"Second toast should be queued while first is showing"
	)


func test_queue_overflow_drops_oldest() -> void:
	EventBus.toast_requested.emit("Active", &"system", 3.0)
	for i: int in range(6):
		EventBus.toast_requested.emit("Queued %d" % i, &"system", 3.0)
	assert_eq(
		_ui._queue.size(), ToastNotificationUI.MAX_QUEUE_SIZE,
		"Queue should cap at MAX_QUEUE_SIZE"
	)
	assert_eq(
		_ui._queue[0]["message"], "Queued 1",
		"Oldest pending toast should have been dropped"
	)


func test_category_color_milestone() -> void:
	EventBus.toast_requested.emit("Gold", &"milestone", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Should have a label in the toast panel")
	if label:
		var color: Color = label.get_theme_color("font_color")
		assert_eq(
			color,
			ToastNotificationUI.CATEGORY_COLORS[&"milestone"],
			"Milestone toast should use gold color"
		)


func test_category_color_staff() -> void:
	EventBus.toast_requested.emit("Orange", &"staff", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Should have a label in the toast panel")
	if label:
		var color: Color = label.get_theme_color("font_color")
		assert_eq(
			color,
			ToastNotificationUI.CATEGORY_COLORS[&"staff"],
			"Staff toast should use orange color"
		)


func test_category_color_reputation_up() -> void:
	EventBus.toast_requested.emit("Rep up", &"reputation_up", 4.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Should have a label in the toast panel")
	if label:
		var color: Color = label.get_theme_color("font_color")
		assert_eq(
			color,
			ToastNotificationUI.CATEGORY_COLORS[&"reputation_up"],
			"Reputation up toast should use gold color"
		)


func test_category_color_reputation_down() -> void:
	EventBus.toast_requested.emit("Rep down", &"reputation_down", 5.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Should have a label in the toast panel")
	if label:
		var color: Color = label.get_theme_color("font_color")
		assert_eq(
			color,
			ToastNotificationUI.CATEGORY_COLORS[&"reputation_down"],
			"Reputation down toast should use red-orange color"
		)


func test_unknown_category_uses_white() -> void:
	EventBus.toast_requested.emit("Default", &"unknown", 3.0)
	var label: Label = _find_label_in_panel(_ui._active_panel)
	assert_not_null(label, "Should have a label in the toast panel")
	if label:
		var color: Color = label.get_theme_color("font_color")
		assert_eq(
			color,
			ToastNotificationUI.DEFAULT_COLOR,
			"Unknown category should use white"
		)


func test_mouse_filter_ignore() -> void:
	assert_eq(
		_ui.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Root control should not block mouse input"
	)


func test_dismiss_clears_active() -> void:
	EventBus.toast_requested.emit("Dismissable", &"system", 10.0)
	assert_true(_ui._is_showing)
	_ui.dismiss()
	await get_tree().create_timer(0.3).timeout
	assert_false(
		_ui._is_showing,
		"Should no longer be showing after dismiss"
	)


func test_default_duration_applied() -> void:
	EventBus.toast_requested.emit("No dur", &"system", 0.0)
	assert_true(_ui._is_showing, "Zero duration should use default")


func _find_label_in_panel(panel: PanelContainer) -> Label:
	if not is_instance_valid(panel):
		return null
	for child: Node in panel.get_children():
		if child is MarginContainer:
			for inner: Node in child.get_children():
				if inner is Label:
					return inner as Label
	return null
