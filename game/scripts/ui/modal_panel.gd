## Base class for full-screen modal panels that claim CTX_MODAL on InputFocus.
##
## Provides a single source of truth for the open/close → push/pop contract:
##
##   - `enqueue(priority, payload)` is the normal call path: it routes through
##     `ModalQueue` so the panel only opens when no higher-priority modal is
##     active. The queue calls `_open_from_queue(payload)` when the panel
##     reaches the front, which subclasses observe via `_on_queued_open`.
##   - `open()` is preserved as a direct-open escape hatch for fatal overlays
##     and tests that bypass the queue. It pushes exactly one `CTX_MODAL`
##     frame on `InputFocus`. A second `open()` without an intervening
##     `close()` is a no-op and emits `push_error` so the leak is visible.
##   - `close()` pops the frame iff this panel owns it, then notifies
##     `ModalQueue` so the next queued panel can dispatch. The notify is a
##     no-op for direct-open panels (the queue did not own them).
##   - `_exit_tree()` is the safety net: if the panel is freed (e.g. scene
##     transition, parent freed) while still holding a frame, the dangling
##     `CTX_MODAL` is auto-popped and `push_error` records the leak. A panel
##     freed before its queue dispatch turn is cancelled out of the queue;
##     a panel freed while active drains the next entry via
##     `ModalQueue.notify_closed`.
##   - `_pop_modal_focus()` refuses to pop when CTX_MODAL is no longer on top
##     (a sibling pushed without going through this contract); it surfaces the
##     mismatch via `push_error` rather than corrupting the sibling's frame.
##
## Subclasses with custom open/close shapes (extra parameters, animations) may
## override `open()` / `close()` and call `_push_modal_focus()` /
## `_pop_modal_focus()` at the appropriate point. Subclasses that do not claim
## modal focus (passive overlays where world interactions remain reachable)
## simply skip the helper calls; the `_exit_tree` safety net is a no-op when
## nothing was pushed.
##
## Subclasses that override `_exit_tree()` for additional cleanup must call
## `super._exit_tree()` so the auto-pop guard still runs.
class_name ModalPanel
extends CanvasLayer


## True iff this panel currently owns a CTX_MODAL frame on InputFocus.
## Read-only outside the class except for the `_reset_for_tests` seam.
var _focus_pushed: bool = false
var _modal_focusables: Array[Control] = []


## Default open: claims a CTX_MODAL frame and sets the panel visible.
## Direct-open escape hatch — fatal overlays and tests may call this to
## bypass the queue. Normal callers should use `enqueue(priority, payload)`
## so panels open in priority order without overlapping. Subclasses with
## custom open semantics may override and call `_push_modal_focus()` at the
## appropriate point.
func open() -> void:
	_push_modal_focus()
	visible = true


## Default close: hides the panel, releases the CTX_MODAL frame, and lets
## `ModalQueue` dispatch the next pending panel. Safe to call on direct-open
## panels — `ModalQueue.notify_closed` no-ops when this panel was never the
## active queue entry. Subclasses with custom close semantics may override
## and call `_pop_modal_focus()` at the appropriate point.
func close() -> void:
	visible = false
	_modal_focusables.clear()
	_pop_modal_focus()
	ModalQueue.notify_closed(self)


## Normal call path — enqueue this panel through `ModalQueue` at the given
## priority with an optional payload. Returns immediately; the queue calls
## `_open_from_queue(payload)` when no higher-priority panel is ahead, which
## in turn invokes `_on_queued_open(payload)` for subclass-specific setup.
func enqueue(priority: int, payload: Dictionary = {}) -> void:
	ModalQueue.request_open(self, priority, payload)


## Called by `ModalQueue._dispatch` when this panel reaches the front of the
## queue. Claims the CTX_MODAL frame, makes the panel visible, and forwards
## the payload to `_on_queued_open` for subclass-specific configuration.
func _open_from_queue(payload: Dictionary) -> void:
	_push_modal_focus()
	visible = true
	_on_queued_open(payload)


## Subclass hook for payload-driven setup. Called after the CTX_MODAL frame
## is claimed and the panel is visible, so subclasses may safely read scene
## nodes and reconfigure UI from `payload`. Default implementation is a no-op
## for subclasses whose setup happens before `enqueue`.
func _on_queued_open(_payload: Dictionary) -> void:
	pass


## Registers the controls allowed to receive keyboard focus while this modal
## is active, then wires Tab / Shift+Tab traversal into a closed loop.
func _register_modal_focusables(controls: Array) -> void:
	_modal_focusables.clear()
	for control_variant: Variant in controls:
		if control_variant is not Control:
			continue
		var control: Control = control_variant as Control
		if not is_instance_valid(control):
			continue
		control.focus_mode = Control.FOCUS_ALL
		_modal_focusables.append(control)
	_wire_modal_focus_loop()


func _focus_modal_control_deferred(control: Control) -> void:
	call_deferred("_focus_modal_control", control)


func _focus_modal_control(control: Control) -> void:
	if not _modal_can_handle_input():
		return
	if not is_instance_valid(control):
		return
	if not control.is_inside_tree() or not control.visible:
		return
	if control is BaseButton and (control as BaseButton).disabled:
		return
	control.grab_focus()


func _cycle_modal_focus(forward: bool) -> bool:
	if not _modal_can_handle_input() or _modal_focusables.is_empty():
		return false
	var current: Control = get_viewport().gui_get_focus_owner()
	var index: int = _modal_focusables.find(current)
	if index < 0:
		index = 0 if forward else _modal_focusables.size() - 1
	else:
		var delta: int = 1 if forward else -1
		index = (index + delta + _modal_focusables.size()) % _modal_focusables.size()
	_focus_modal_control(_modal_focusables[index])
	return true


func _activate_focused_modal_button() -> bool:
	if not _modal_can_handle_input():
		return false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not _modal_focusables.has(focused):
		return false
	if focused is not Button:
		return false
	var button: Button = focused as Button
	if button.disabled or not button.visible:
		return false
	button.pressed.emit()
	return true


func _modal_can_handle_input() -> bool:
	return visible and _focus_pushed and InputFocus.current() == InputFocus.CTX_MODAL


func _is_modal_focus_next_event(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_focus_next"):
		return true
	if event is not InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return (
		key_event.pressed
		and not key_event.echo
		and key_event.keycode == KEY_TAB
		and not key_event.shift_pressed
	)


func _is_modal_focus_previous_event(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_focus_prev"):
		return true
	if event is not InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return (
		key_event.pressed
		and not key_event.echo
		and key_event.keycode == KEY_TAB
		and key_event.shift_pressed
	)


func _wire_modal_focus_loop() -> void:
	if _modal_focusables.is_empty():
		return
	for i: int in range(_modal_focusables.size()):
		var current: Control = _modal_focusables[i]
		var previous: Control = _modal_focusables[
			(i - 1 + _modal_focusables.size()) % _modal_focusables.size()
		]
		var next: Control = _modal_focusables[
			(i + 1) % _modal_focusables.size()
		]
		current.focus_previous = previous.get_path()
		current.focus_next = next.get_path()
		current.focus_neighbor_top = previous.get_path()
		current.focus_neighbor_left = previous.get_path()
		current.focus_neighbor_bottom = next.get_path()
		current.focus_neighbor_right = next.get_path()


## Pushes a CTX_MODAL frame on InputFocus. Guarded against double-push:
## a second call without an intervening pop is a no-op and emits `push_error`.
## Emits `EventBus.modal_opened(name)` after a successful push so the player-
## facing event log receives the open beat; the double-push guard suppresses
## the emit too, keeping open/close pairs balanced.
func _push_modal_focus() -> void:
	if _focus_pushed:
		push_error(
			"[ModalPanel] %s: open() called twice without close() — skipping push"
			% name
		)
		return
	InputFocus.push_context(InputFocus.CTX_MODAL)
	_focus_pushed = true
	EventBus.modal_opened.emit(name)


## Pops our CTX_MODAL frame iff we own one. Defensive: if a sibling pushed
## without going through this contract, leave the stack untouched and clear
## our flag rather than corrupt the sibling's frame. `EventBus.modal_closed`
## is emitted only on the matched-pair pop branch — the sibling-frame skip
## leaves the open/close pair unbalanced from the event-log perspective,
## which is the desired signal (an unmatched close would lie about the modal
## actually leaving CTX_MODAL ownership).
func _pop_modal_focus() -> void:
	if not _focus_pushed:
		return
	if InputFocus.current() != InputFocus.CTX_MODAL:
		push_error(
			(
				"[ModalPanel] %s: expected CTX_MODAL on top, got %s — "
				+ "leaving stack untouched to avoid corrupting sibling frame"
			)
			% [name, String(InputFocus.current())]
		)
		_focus_pushed = false
		return
	InputFocus.pop_context()
	_focus_pushed = false
	EventBus.modal_closed.emit(name)


## Auto-pops a dangling CTX_MODAL frame when the panel exits the tree while
## still holding a push, and reconciles `ModalQueue` state. A panel freed
## before its dispatch turn is cancelled out of the queue; a panel freed
## while active auto-pops the dangling frame and drains the next entry.
##
## The `push_error` safety net only fires when the panel is freed while
## CTX_MODAL is still on top of InputFocus — that is the real "caller
## forgot to close()" case the warning is for. When the stack has already
## been drained (test fixture called `InputFocus._reset_for_tests()` or
## an engine-shutdown reorder beat us to the pop) the cleanup proceeds
## silently. Without this gating, every test that mounts a modal-class
## panel and resets InputFocus in `after_each` produces a cascade of
## spurious `[ModalPanel] ... freed with unreleased InputFocus push`
## lines at suite teardown that GUT counts as errors.
func _exit_tree() -> void:
	if not _focus_pushed:
		ModalQueue.cancel(self)
		return
	var still_holds_ctx_modal: bool = (
		InputFocus.current() == InputFocus.CTX_MODAL
	)
	_focus_pushed = false
	if still_holds_ctx_modal:
		push_error(
			"[ModalPanel] %s freed with unreleased InputFocus push — auto-popping"
			% name
		)
		InputFocus.pop_context()
		# Mirror the matched-pair pop emit so on-screen log surfaces see a
		# `modal_closed` for the frame this panel held — without it, the
		# `modal_opened` entry that opened the panel would orphan in the
		# log timeline. Gated to the real-leak branch only; the silent
		# cleanup path (test fixture pre-reset the stack) has no
		# corresponding `modal_opened` to balance and the emit would just
		# noise up the `[MODAL]` event log at teardown.
		EventBus.modal_closed.emit(name)
	ModalQueue.notify_closed(self)


## Test seam — clears the bookkeeping flag without calling pop_context.
## Pair with `InputFocus._reset_for_tests()` to fully reset state in tests.
func _reset_for_tests() -> void:
	_focus_pushed = false
	_modal_focusables.clear()
