## Tests that ToastNotificationUI suppresses display while CTX_MODAL is on top
## of the InputFocus stack — toasts queue silently and the active card is
## requeued so the modal owns the screen, then the queue drains in FIFO order
## once the modal pops.
extends GutTest


var _ui: ToastNotificationUI
var _focus: Node


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	assert_not_null(_focus, "InputFocus autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	_ui = ToastNotificationUI.new()
	_ui.size = Vector2(1152, 648)
	add_child_autofree(_ui)
	# Re-seed the UI's modal flag now that the autoload stack is empty —
	# `_ready` already ran with whatever the prior test left on the stack.
	_ui._reset_for_tests()


func after_each() -> void:
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func test_new_toast_during_modal_queues_silently() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_focus.push_context(InputFocus.CTX_MODAL)
	EventBus.toast_requested.emit("Suppressed", &"system", 3.0)
	assert_false(
		_ui._is_showing,
		"No toast may animate while CTX_MODAL is on top"
	)
	assert_eq(
		_ui._queue.size(), 1,
		"The toast must be queued silently for replay after the modal closes"
	)
	assert_eq(
		_ui._queue[0]["message"], "Suppressed",
		"Queued entry must preserve the original message"
	)


func test_active_toast_is_requeued_when_modal_opens() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	EventBus.toast_requested.emit("In flight", &"sale", 5.0)
	assert_true(_ui._is_showing, "Pre-condition: toast active before modal opens")
	_focus.push_context(InputFocus.CTX_MODAL)
	assert_false(
		_ui._is_showing,
		"Active toast must yield once CTX_MODAL takes the top frame"
	)
	assert_eq(
		_ui._queue.size(), 1,
		"The interrupted toast must be re-queued at the head of the queue"
	)
	assert_eq(
		_ui._queue[0]["message"], "In flight",
		"Re-queued entry must preserve the original message"
	)
	assert_eq(
		_ui._queue[0]["category"], &"sale",
		"Re-queued entry must preserve the original category"
	)


func test_queue_drains_in_fifo_order_after_modal_closes() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_focus.push_context(InputFocus.CTX_MODAL)
	EventBus.toast_requested.emit("First", &"system", 3.0)
	EventBus.toast_requested.emit("Second", &"system", 3.0)
	EventBus.toast_requested.emit("Third", &"system", 3.0)
	assert_eq(_ui._queue.size(), 3, "Pre-condition: three queued during modal")
	assert_false(_ui._is_showing, "Pre-condition: nothing showing during modal")
	_focus.pop_context()
	assert_true(
		_ui._is_showing,
		"First queued toast must begin animating immediately after modal pops"
	)
	if _ui._is_showing:
		var label: Label = _find_label_in_panel(_ui._active_panel)
		assert_not_null(label, "Active panel must exist after modal pops")
		if label:
			assert_eq(
				label.text, "First",
				"FIFO contract: oldest queued message displays first after the pop"
			)
	assert_eq(
		_ui._queue.size(), 2,
		"Two entries should remain queued behind the now-active toast"
	)


func test_no_toast_starts_during_modal_even_with_zero_active() -> void:
	# Defensive: even with a fully-empty UI, opening the modal first and then
	# emitting a toast must not let the toast slip through.
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_focus.push_context(InputFocus.CTX_MODAL)
	for i: int in range(3):
		EventBus.toast_requested.emit("Toast %d" % i, &"system", 3.0)
	assert_false(
		_ui._is_showing,
		"No toast may begin animating while CTX_MODAL is on top"
	)
	assert_eq(_ui._queue.size(), 3, "All emitted toasts must be queued")


func test_overflow_during_modal_still_caps_at_max_queue_size() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_focus.push_context(InputFocus.CTX_MODAL)
	for i: int in range(ToastNotificationUI.MAX_QUEUE_SIZE + 3):
		EventBus.toast_requested.emit("Item %d" % i, &"system", 3.0)
	assert_eq(
		_ui._queue.size(),
		ToastNotificationUI.MAX_QUEUE_SIZE,
		"Modal-suppression path must respect MAX_QUEUE_SIZE just like the live path"
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
