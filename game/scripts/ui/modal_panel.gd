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
