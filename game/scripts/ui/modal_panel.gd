## Base class for full-screen modal panels that claim CTX_MODAL on InputFocus.
##
## Provides a single source of truth for the open/close → push/pop contract:
##
##   - `open()` pushes exactly one `CTX_MODAL` frame on `InputFocus`. A second
##     `open()` without an intervening `close()` is a no-op and emits
##     `push_error` so the leak is visible.
##   - `close()` pops the frame iff this panel owns it.
##   - `_exit_tree()` is the safety net: if the panel is freed (e.g. scene
##     transition, parent freed) while still holding a frame, the dangling
##     `CTX_MODAL` is auto-popped and `push_error` records the leak.
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
extends CanvasLayer
class_name ModalPanel


## True iff this panel currently owns a CTX_MODAL frame on InputFocus.
## Read-only outside the class except for the `_reset_for_tests` seam.
var _focus_pushed: bool = false


## Default open: claims a CTX_MODAL frame and sets the panel visible.
## Subclasses with custom open semantics may override and call
## `_push_modal_focus()` at the appropriate point.
func open() -> void:
	_push_modal_focus()
	visible = true


## Default close: hides the panel and releases the CTX_MODAL frame.
## Subclasses with custom close semantics may override and call
## `_pop_modal_focus()` at the appropriate point.
func close() -> void:
	visible = false
	_pop_modal_focus()


## Pushes a CTX_MODAL frame on InputFocus. Guarded against double-push:
## a second call without an intervening pop is a no-op and emits `push_error`.
func _push_modal_focus() -> void:
	if _focus_pushed:
		push_error(
			"[ModalPanel] %s: open() called twice without close() — skipping push"
			% name
		)
		return
	InputFocus.push_context(InputFocus.CTX_MODAL)
	_focus_pushed = true


## Pops our CTX_MODAL frame iff we own one. Defensive: if a sibling pushed
## without going through this contract, leave the stack untouched and clear
## our flag rather than corrupt the sibling's frame.
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


## Auto-pops a dangling CTX_MODAL frame when the panel exits the tree while
## still holding a push. Surfaces the leak via `push_error` so the calling
## site can be fixed; pops only when CTX_MODAL is still on top.
func _exit_tree() -> void:
	if not _focus_pushed:
		return
	push_error(
		"[ModalPanel] %s freed with unreleased InputFocus push — auto-popping"
		% name
	)
	if InputFocus.current() == InputFocus.CTX_MODAL:
		InputFocus.pop_context()
	_focus_pushed = false


## Test seam — clears the bookkeeping flag without calling pop_context.
## Pair with `InputFocus._reset_for_tests()` to fully reset state in tests.
func _reset_for_tests() -> void:
	_focus_pushed = false
