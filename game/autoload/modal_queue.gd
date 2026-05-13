## Priority-ordered queue for ModalPanel-derived panels.
##
## Coordinates which panel currently owns the CTX_MODAL frame on InputFocus so
## that two panels never display at once. Callers enqueue a panel through
## `request_open(panel, priority, payload)`; the queue dispatches one panel at
## a time and starts the next one when the active panel closes.
##
## ModalPanel base class wires the close/exit-tree side: `close()` calls
## `notify_closed(self)` and `_exit_tree()` calls either `cancel(self)`
## (pending entry freed) or `notify_closed(self)` (active panel freed).
## External callers should not invoke `notify_closed` / `cancel` directly.
##
## Deduplication: a second `request_open` for a panel that is already active
## or already pending is a no-op — this prevents rapid-day-advance bugs from
## stacking DaySummary five deep.
##
## InputFocus is unchanged — a single `CTX_MODAL` context name remains and
## the queue ensures only one ModalPanel owns it at a time. ModalDimOverlay
## is also unchanged — its boolean transition logic handles back-to-back
## queue dispatches (CTX_MODAL stays on top through the hand-off) without
## flickering the dim.
extends Node


## Emitted when the active panel changes. Argument is the new active panel,
## or `null` when the queue empties.
signal active_changed(panel: ModalPanel)


## Priority levels. Lower numbers are dispatched first. DAY_SUMMARY must run
## before VIC_NOTE which runs before TUTORIAL which runs before TOAST which
## runs before PASSIVE_HUD overlays.
enum Priority {
	DAY_SUMMARY = 0,
	VIC_NOTE = 1,
	TUTORIAL = 2,
	TOAST = 3,
	PASSIVE_HUD = 4,
}


## Pending queue record. `sequence` is a strictly monotonic FIFO tie-breaker
## within a priority bucket; ms-timestamp would collide for two requests in
## the same frame.
class QueueEntry:
	var panel: ModalPanel
	var priority: int
	var sequence: int
	var payload: Dictionary


var _active: QueueEntry = null
var _queue: Array[QueueEntry] = []
var _sequence: int = 0


## Enqueue `panel` for opening at `priority` with `payload`. Dispatches
## immediately when no panel is active; otherwise inserts in
## (priority, sequence) order and dispatches when the current active panel
## calls `close()`. Deduplicated — a second request for an already-active or
## already-pending panel is a no-op.
func request_open(
	panel: ModalPanel, priority: int, payload: Dictionary = {}
) -> void:
	if panel == null:
		push_error("[ModalQueue] request_open: panel is null — ignoring")
		return
	if _active != null and _active.panel == panel:
		return
	for e: QueueEntry in _queue:
		if e.panel == panel:
			return
	var entry := QueueEntry.new()
	entry.panel = panel
	entry.priority = priority
	entry.sequence = _sequence
	_sequence += 1
	entry.payload = payload
	if _active == null:
		_dispatch(entry)
	else:
		_insert_sorted(entry)


## Drains the next queued entry. Called by `ModalPanel.close()` and by the
## active-panel branch of `ModalPanel._exit_tree()`. No-op when `panel` is
## not the current active entry — this lets panels that bypass the queue
## (direct `open()` escape hatch, test fixtures) close safely.
func notify_closed(panel: ModalPanel) -> void:
	if _active == null or _active.panel != panel:
		return
	_active = null
	active_changed.emit(null)
	if not _queue.is_empty():
		_dispatch(_queue.pop_front())


## Removes pending entries for `panel` from the queue. No-op when `panel` is
## active or not queued. Called by the pending-entry branch of
## `ModalPanel._exit_tree()` (panel freed before its dispatch turn).
func cancel(panel: ModalPanel) -> void:
	var i: int = 0
	while i < _queue.size():
		if _queue[i].panel == panel:
			_queue.remove_at(i)
			continue
		i += 1


## True iff any modal is currently active.
func is_busy() -> bool:
	return _active != null


## Returns the currently active panel, or `null` when the queue is idle.
## Public for tests and the debug overlay; mutating queue state from outside
## the contract is forbidden.
func active_panel() -> ModalPanel:
	if _active == null:
		return null
	return _active.panel


## Returns the depth of the pending queue (excludes the active entry).
func pending_count() -> int:
	return _queue.size()


func _dispatch(entry: QueueEntry) -> void:
	_active = entry
	entry.panel._open_from_queue(entry.payload)
	active_changed.emit(entry.panel)


func _insert_sorted(entry: QueueEntry) -> void:
	var i: int = 0
	while i < _queue.size():
		var e: QueueEntry = _queue[i]
		if (
			entry.priority < e.priority
			or (entry.priority == e.priority and entry.sequence < e.sequence)
		):
			break
		i += 1
	_queue.insert(i, entry)


## Drops every active and pending entry without dispatching anything else.
## Called by `SceneRouter` immediately before a scene change so that panels
## freed during the swap can't drain into the next scene's UI tree. The
## panels' own `_exit_tree` still pops any held `CTX_MODAL` frame; this just
## ensures `notify_closed`/`cancel` from those calls become no-ops instead
## of dispatching a stale entry into a half-built scene.
func clear() -> void:
	_active = null
	_queue.clear()
	active_changed.emit(null)


## Test seam — clears state without dispatching the next panel. Pair with
## `InputFocus._reset_for_tests()` to fully reset modal state between cases.
func _reset_for_tests() -> void:
	_active = null
	_queue.clear()
	_sequence = 0
