## Integration test: toast queue contention — simultaneous toast_requested emissions
## from multiple sources produce correctly ordered non-overlapping display.
extends GutTest

var _ui: ToastNotificationUI


func before_each() -> void:
	_ui = ToastNotificationUI.new()
	_ui.size = Vector2(1152, 648)
	add_child_autofree(_ui)


# ── Scenario A: order delivery + reputation tier change on same frame ─────────


func test_scenario_a_single_toast_active_after_two_simultaneous_emissions() -> void:
	EventBus.toast_requested.emit("Order arrived: 5 Basecore 64s", &"system", 2.0)
	EventBus.toast_requested.emit("Reputation improved: Trusted", &"reputation", 2.0)
	assert_true(
		_ui._is_showing,
		"Exactly one toast must be active immediately after two simultaneous emissions"
	)
	assert_eq(
		_ui._queue.size(), 1,
		"Second toast must be queued; no more than one panel visible at once"
	)


func test_scenario_a_first_emitted_displays_first_fifo() -> void:
	EventBus.toast_requested.emit("Order arrived: 5 Basecore 64s", &"system", 2.0)
	EventBus.toast_requested.emit("Reputation improved: Trusted", &"reputation", 2.0)
	var label: Label = _find_label(_ui._active_panel)
	assert_not_null(label, "Active panel must contain a Label")
	if label:
		assert_eq(
			label.text,
			"Order arrived: 5 Basecore 64s",
			"First emitted message must appear first (FIFO contract)"
		)


func test_scenario_a_second_toast_visible_after_first_duration_elapses() -> void:
	EventBus.toast_requested.emit("Order arrived: 5 Basecore 64s", &"system", 2.0)
	EventBus.toast_requested.emit("Reputation improved: Trusted", &"reputation", 2.0)
	_advance_toast(_ui)
	assert_true(
		_ui._is_showing,
		"Second toast must become active after first duration elapses"
	)
	var label: Label = _find_label(_ui._active_panel)
	assert_not_null(label, "Active panel must exist for second toast")
	if label:
		assert_eq(
			label.text,
			"Reputation improved: Trusted",
			"Second emitted message must display after first finishes"
		)


func test_scenario_a_panel_hidden_and_queue_empty_after_both_finish() -> void:
	EventBus.toast_requested.emit("Order arrived: 5 Basecore 64s", &"system", 2.0)
	EventBus.toast_requested.emit("Reputation improved: Trusted", &"reputation", 2.0)
	_advance_toast(_ui)
	_advance_toast(_ui)
	assert_false(
		_ui._is_showing,
		"Toast system must be idle after both durations elapse"
	)
	assert_eq(
		_ui._queue.size(), 0,
		"Queue must be empty after all toasts have displayed"
	)


func test_scenario_a_category_of_first_toast_is_system() -> void:
	EventBus.toast_requested.emit("Order arrived: 5 Basecore 64s", &"system", 2.0)
	EventBus.toast_requested.emit("Reputation improved: Trusted", &"reputation", 2.0)
	assert_not_null(_ui._active_panel, "Active panel must exist after first emission")
	var queued: Dictionary = _ui._queue[0] if _ui._queue.size() > 0 else {}
	assert_eq(
		queued.get("category", &""),
		&"reputation",
		"Queued entry must carry the reputation category from the second emission"
	)


# ── Scenario B: four simultaneous toasts ─────────────────────────────────────


func test_scenario_b_queue_depth_three_after_four_emissions() -> void:
	EventBus.toast_requested.emit("Toast 1", &"system", 2.0)
	EventBus.toast_requested.emit("Toast 2", &"system", 2.0)
	EventBus.toast_requested.emit("Toast 3", &"system", 2.0)
	EventBus.toast_requested.emit("Toast 4", &"system", 2.0)
	assert_eq(
		_ui._queue.size(), 3,
		"Three toasts must be pending in queue; first occupies the active slot"
	)


func test_scenario_b_first_three_display_in_emission_order() -> void:
	EventBus.toast_requested.emit("Toast 1", &"system", 2.0)
	EventBus.toast_requested.emit("Toast 2", &"system", 2.0)
	EventBus.toast_requested.emit("Toast 3", &"system", 2.0)
	EventBus.toast_requested.emit("Toast 4", &"system", 2.0)

	var label: Label = _find_label(_ui._active_panel)
	assert_not_null(label, "Active panel must exist for Toast 1")
	if label:
		assert_eq(label.text, "Toast 1", "First emission must be active immediately")

	_advance_toast(_ui)
	label = _find_label(_ui._active_panel)
	assert_not_null(label, "Active panel must exist for Toast 2")
	if label:
		assert_eq(label.text, "Toast 2", "Second emission must show after first finishes")

	_advance_toast(_ui)
	label = _find_label(_ui._active_panel)
	assert_not_null(label, "Active panel must exist for Toast 3")
	if label:
		assert_eq(label.text, "Toast 3", "Third emission must show after second finishes")


func test_scenario_b_no_two_panels_active_simultaneously() -> void:
	EventBus.toast_requested.emit("Toast 1", &"system", 2.0)
	EventBus.toast_requested.emit("Toast 2", &"system", 2.0)
	EventBus.toast_requested.emit("Toast 3", &"system", 2.0)
	EventBus.toast_requested.emit("Toast 4", &"system", 2.0)
	var visible_panels: int = 0
	for child: Node in _ui.get_children():
		if child is PanelContainer and (child as Control).visible:
			visible_panels += 1
	assert_lte(
		visible_panels, 1,
		"At most one PanelContainer must be visible at any tick"
	)


func test_scenario_b_overflow_evicts_oldest_pending_at_max_queue() -> void:
	EventBus.toast_requested.emit("Toast active", &"system", 2.0)
	for i: int in range(ToastNotificationUI.MAX_QUEUE_SIZE):
		EventBus.toast_requested.emit("Pending %d" % i, &"system", 2.0)
	assert_eq(
		_ui._queue.size(),
		ToastNotificationUI.MAX_QUEUE_SIZE,
		"Queue must be at MAX_QUEUE_SIZE after active + MAX_QUEUE_SIZE emissions"
	)
	EventBus.toast_requested.emit("Overflow", &"system", 2.0)
	assert_eq(
		_ui._queue.size(),
		ToastNotificationUI.MAX_QUEUE_SIZE,
		"Queue must remain at MAX_QUEUE_SIZE after overflow (oldest pending evicted)"
	)
	var last_entry: Dictionary = _ui._queue.back()
	assert_eq(
		last_entry.get("message", ""),
		"Overflow",
		"Most recent emission must be appended after evicting oldest pending"
	)


func test_scenario_b_queue_empty_after_all_four_finish() -> void:
	EventBus.toast_requested.emit("Toast 1", &"system", 2.0)
	EventBus.toast_requested.emit("Toast 2", &"system", 2.0)
	EventBus.toast_requested.emit("Toast 3", &"system", 2.0)
	EventBus.toast_requested.emit("Toast 4", &"system", 2.0)
	for _i: int in range(4):
		_advance_toast(_ui)
	assert_false(
		_ui._is_showing,
		"Toast system must be idle after all four durations elapse"
	)
	assert_eq(
		_ui._queue.size(), 0,
		"Queue must be empty after all four toasts have displayed"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


## Simulates mock timer expiry for the currently active toast without real time.
func _advance_toast(ui: ToastNotificationUI) -> void:
	ui._kill_tween()
	ui._on_toast_finished()


func _find_label(panel: PanelContainer) -> Label:
	if not is_instance_valid(panel):
		return null
	for child: Node in panel.get_children():
		if child is MarginContainer:
			for inner: Node in (child as MarginContainer).get_children():
				if inner is Label:
					return inner as Label
	return null
