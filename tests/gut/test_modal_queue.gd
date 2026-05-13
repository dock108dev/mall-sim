## ModalQueue autoload — priority-ordered modal coordinator.
##
## Covers: API shape (Priority enum, QueueEntry inner class, signal +
## methods), immediate dispatch when idle, priority+FIFO ordering, dedup,
## auto-drain on notify_closed, cancel of pending entries, and the ModalPanel
## base-class wiring (close → notify_closed, _exit_tree → cancel/notify_closed,
## enqueue → request_open).
extends GutTest


const ModalPanelScript: GDScript = preload("res://game/scripts/ui/modal_panel.gd")


var _focus: Node
var _queue: Node


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	_queue = get_tree().root.get_node_or_null("ModalQueue")
	assert_not_null(_focus, "InputFocus autoload required")
	assert_not_null(_queue, "ModalQueue autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	if _queue != null:
		_queue._reset_for_tests()


func after_each() -> void:
	if _queue != null and is_instance_valid(_queue):
		_queue._reset_for_tests()
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func _make_panel() -> ModalPanel:
	var panel := ModalPanelScript.new() as ModalPanel
	# Real subclasses start hidden — the base CanvasLayer defaults to visible=true,
	# which would mask "panel was never opened" in invariant checks.
	panel.visible = false
	add_child_autofree(panel)
	return panel


# ── API shape ─────────────────────────────────────────────────────────────────

func test_priority_enum_has_required_levels() -> void:
	assert_eq(int(_queue.Priority.DAY_SUMMARY), 0)
	assert_eq(int(_queue.Priority.VIC_NOTE), 1)
	assert_eq(int(_queue.Priority.TUTORIAL), 2)
	assert_eq(int(_queue.Priority.TOAST), 3)
	assert_eq(int(_queue.Priority.PASSIVE_HUD), 4)


func test_active_changed_signal_exists() -> void:
	assert_true(
		_queue.has_signal("active_changed"),
		"ModalQueue must expose active_changed signal"
	)


func test_public_methods_present() -> void:
	for method_name: String in [
		"request_open", "notify_closed", "cancel", "is_busy"
	]:
		assert_true(
			_queue.has_method(method_name),
			"ModalQueue must expose %s()" % method_name
		)


# ── Immediate dispatch ────────────────────────────────────────────────────────

func test_request_open_dispatches_immediately_when_idle() -> void:
	var panel: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	_queue.request_open(panel, _queue.Priority.TOAST)

	assert_true(_queue.is_busy(), "queue must report busy after dispatch")
	assert_eq(_queue.active_panel(), panel, "panel must become active")
	assert_eq(_focus.current(), InputFocus.CTX_MODAL,
		"_open_from_queue must claim CTX_MODAL")
	assert_true(panel.visible, "_open_from_queue must show the panel")
	panel.close()


# ── Priority + FIFO ordering ──────────────────────────────────────────────────

func test_higher_priority_dispatches_before_lower_when_active_closes() -> void:
	var a: ModalPanel = _make_panel()
	var b: ModalPanel = _make_panel()
	var c: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	# a is active. Enqueue b (low priority) then c (high priority).
	_queue.request_open(a, _queue.Priority.TOAST)
	_queue.request_open(b, _queue.Priority.TUTORIAL)
	_queue.request_open(c, _queue.Priority.DAY_SUMMARY)

	assert_eq(_queue.active_panel(), a)
	assert_eq(_queue.pending_count(), 2)

	a.close()
	assert_eq(_queue.active_panel(), c,
		"high-priority panel must dispatch before lower-priority pending entry")

	c.close()
	assert_eq(_queue.active_panel(), b,
		"remaining pending entry must dispatch on notify_closed")
	b.close()


func test_fifo_within_same_priority() -> void:
	var active: ModalPanel = _make_panel()
	var first: ModalPanel = _make_panel()
	var second: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	_queue.request_open(active, _queue.Priority.TOAST)
	_queue.request_open(first, _queue.Priority.VIC_NOTE)
	_queue.request_open(second, _queue.Priority.VIC_NOTE)

	active.close()
	assert_eq(_queue.active_panel(), first,
		"first-enqueued same-priority panel must dispatch first")
	first.close()
	assert_eq(_queue.active_panel(), second)
	second.close()


# ── Deduplication ─────────────────────────────────────────────────────────────

func test_request_open_dedups_active_panel() -> void:
	var panel: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline_depth: int = _focus.depth()

	_queue.request_open(panel, _queue.Priority.VIC_NOTE)
	_queue.request_open(panel, _queue.Priority.VIC_NOTE)
	_queue.request_open(panel, _queue.Priority.DAY_SUMMARY)

	assert_eq(_queue.pending_count(), 0,
		"second/third request_open for the active panel must not enqueue")
	assert_eq(_focus.depth(), baseline_depth + 1,
		"dedup must not double-push CTX_MODAL")
	panel.close()


func test_request_open_dedups_pending_panel() -> void:
	var active: ModalPanel = _make_panel()
	var pending: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	_queue.request_open(active, _queue.Priority.TOAST)
	_queue.request_open(pending, _queue.Priority.VIC_NOTE)
	_queue.request_open(pending, _queue.Priority.VIC_NOTE)
	_queue.request_open(pending, _queue.Priority.DAY_SUMMARY)

	assert_eq(_queue.pending_count(), 1,
		"repeated request_open for a pending panel must not duplicate entries")
	active.close()
	pending.close()


# ── Auto-drain ────────────────────────────────────────────────────────────────

func test_notify_closed_drains_next_entry_without_caller_involvement() -> void:
	var first: ModalPanel = _make_panel()
	var second: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	_queue.request_open(first, _queue.Priority.TOAST)
	_queue.request_open(second, _queue.Priority.TOAST)

	assert_eq(_queue.active_panel(), first)
	first.close()

	assert_eq(_queue.active_panel(), second,
		"close() on active panel must auto-dispatch the next pending entry")
	assert_true(second.visible, "second panel must be visible after drain")
	assert_eq(_focus.current(), InputFocus.CTX_MODAL,
		"CTX_MODAL must stay on top through the hand-off")
	second.close()


func test_notify_closed_empties_queue_and_emits_active_changed_null() -> void:
	var panel: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_queue.request_open(panel, _queue.Priority.TOAST)

	watch_signals(_queue)
	panel.close()

	assert_signal_emitted_with_parameters(_queue, "active_changed", [null])
	assert_false(_queue.is_busy())


func test_notify_closed_is_noop_for_non_active_panel() -> void:
	var active: ModalPanel = _make_panel()
	var stranger: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_queue.request_open(active, _queue.Priority.TOAST)

	# notify_closed for a panel that is not the active entry must not affect
	# the active panel — direct-open escape hatches rely on this.
	_queue.notify_closed(stranger)

	assert_eq(_queue.active_panel(), active)
	active.close()


# ── Cancel ───────────────────────────────────────────────────────────────────

func test_cancel_removes_pending_entry() -> void:
	var active: ModalPanel = _make_panel()
	var pending: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	_queue.request_open(active, _queue.Priority.TOAST)
	_queue.request_open(pending, _queue.Priority.VIC_NOTE)
	assert_eq(_queue.pending_count(), 1)

	_queue.cancel(pending)
	assert_eq(_queue.pending_count(), 0)

	active.close()
	assert_false(_queue.is_busy(),
		"cancelled panel must not dispatch on notify_closed")


func test_cancel_is_noop_for_unknown_panel() -> void:
	var unknown: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	# Should not raise / push_error.
	_queue.cancel(unknown)
	assert_false(_queue.is_busy())


# ── ModalPanel base-class integration ────────────────────────────────────────

func test_modal_panel_close_calls_notify_closed() -> void:
	var first: ModalPanel = _make_panel()
	var second: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	_queue.request_open(first, _queue.Priority.TOAST)
	_queue.request_open(second, _queue.Priority.TOAST)

	first.close()  # base-class close() must drain via ModalQueue.notify_closed

	assert_eq(_queue.active_panel(), second)
	second.close()


func test_modal_panel_enqueue_routes_through_modal_queue() -> void:
	var panel: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	panel.enqueue(_queue.Priority.VIC_NOTE, {"day_number": 1})

	assert_eq(_queue.active_panel(), panel)
	assert_true(panel.visible)
	panel.close()


func test_modal_panel_exit_tree_cancels_when_pending() -> void:
	var active: ModalPanel = _make_panel()
	var pending: ModalPanel = ModalPanelScript.new() as ModalPanel
	add_child(pending)
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	_queue.request_open(active, _queue.Priority.TOAST)
	_queue.request_open(pending, _queue.Priority.VIC_NOTE)
	assert_eq(_queue.pending_count(), 1)

	# Free the pending panel before its dispatch turn — _exit_tree must
	# cancel it out of the queue.
	remove_child(pending)
	pending.free()

	assert_eq(_queue.pending_count(), 0,
		"_exit_tree must call ModalQueue.cancel(self) for pending panels")
	active.close()


func test_modal_panel_exit_tree_notifies_closed_when_active() -> void:
	var active: ModalPanel = ModalPanelScript.new() as ModalPanel
	add_child(active)
	var pending: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	_queue.request_open(active, _queue.Priority.TOAST)
	_queue.request_open(pending, _queue.Priority.VIC_NOTE)

	# Free the active panel mid-flight — _exit_tree must pop CTX_MODAL and
	# notify the queue so the pending panel dispatches.
	remove_child(active)
	active.free()

	assert_eq(_queue.active_panel(), pending,
		"_exit_tree must drain the queue when the active panel is freed")
	pending.close()


# ── Invariant: only one panel visible at a time ───────────────────────────────

func test_only_one_modal_panel_visible_through_dispatch_sequence() -> void:
	var day_summary: ModalPanel = _make_panel()
	var vic_note: ModalPanel = _make_panel()
	var tutorial: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	# Enqueue out of priority order — queue must serialize so only one is
	# visible at any point.
	_queue.request_open(tutorial, _queue.Priority.TUTORIAL)
	_queue.request_open(vic_note, _queue.Priority.VIC_NOTE)
	_queue.request_open(day_summary, _queue.Priority.DAY_SUMMARY)

	# The first request set tutorial active (queue was idle); higher-priority
	# entries are pending. Either way, exactly one visible at a time.
	var visible_count: int = _count_visible([tutorial, vic_note, day_summary])
	assert_eq(visible_count, 1,
		"only one panel may be visible at a time during the day-1 sequence")

	tutorial.close()
	visible_count = _count_visible([tutorial, vic_note, day_summary])
	assert_eq(visible_count, 1)

	# Whichever dispatched next, drain the rest and re-assert the invariant.
	_queue.active_panel().close()
	visible_count = _count_visible([tutorial, vic_note, day_summary])
	assert_eq(visible_count, 1)

	_queue.active_panel().close()
	visible_count = _count_visible([tutorial, vic_note, day_summary])
	assert_eq(visible_count, 0)


func _count_visible(panels: Array) -> int:
	var n: int = 0
	for p: ModalPanel in panels:
		if p.visible:
			n += 1
	return n


# ── Scene-transition clear ────────────────────────────────────────────────────

func test_clear_drops_active_and_pending_without_dispatch() -> void:
	var active: ModalPanel = _make_panel()
	var pending: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	_queue.request_open(active, _queue.Priority.TOAST)
	_queue.request_open(pending, _queue.Priority.VIC_NOTE)
	assert_eq(_queue.active_panel(), active)
	assert_eq(_queue.pending_count(), 1)

	# clear() is the SceneRouter pre-swap hook — the panels are about to be
	# freed by the scene tear-down, so the queue must drop them without
	# dispatching `pending` into the new scene's UI tree.
	_queue.clear()

	assert_false(_queue.is_busy(),
		"clear() must release the active entry without dispatching")
	assert_eq(_queue.pending_count(), 0,
		"clear() must drop every pending entry")


func test_clear_emits_active_changed_null() -> void:
	var panel: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	_queue.request_open(panel, _queue.Priority.TOAST)

	watch_signals(_queue)
	_queue.clear()

	assert_signal_emitted_with_parameters(_queue, "active_changed", [null])


func test_clear_when_idle_is_safe() -> void:
	# clear() may be called during scene transitions even when no modal is
	# active — must not push_error or emit unexpected signals.
	_queue.clear()
	assert_false(_queue.is_busy())
	assert_eq(_queue.pending_count(), 0)
