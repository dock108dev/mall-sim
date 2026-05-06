## Single owner of input/modal focus context (ownership.md row 5).
## Stack-based: gameplay, UI, modals, menus push their context on entry and
## pop on exit. The topmost wins. Gameplay scripts gate their input handlers
## with `InputFocus.current() == &"store_gameplay"`. Direct
## `set_process_input(...)` outside this autoload is forbidden — flagged by
## `tests/validate_input_focus.sh`.
##
## After every SceneRouter-driven transition, the new scene's controller is
## expected to push its context. An empty stack post-transition is a contract
## violation: AuditLog.fail + ErrorBanner.show_failure (no silent dead state).
## A depth >1 post-transition means the prior scene leaked a push and is
## reported as a non-fatal warning so the leaking call site can be found.
extends Node

signal context_changed(new_ctx: StringName, old_ctx: StringName)

const CHECKPOINT_NON_EMPTY: StringName = &"input_focus_non_empty"
const CTX_STORE_GAMEPLAY: StringName = &"store_gameplay"
const CTX_MALL_HUB: StringName = &"mall_hub"
const CTX_MODAL: StringName = &"modal"
const CTX_MAIN_MENU: StringName = &"main_menu"

## Hard upper bound on stack depth. Two or three frames is the normal range
## (gameplay + modal, occasionally + placement-mode retention). Anything past
## this is almost certainly a leak — the assert fires loudly in debug builds
## so the leaking call site can be found before release.
const MAX_STACK_DEPTH: int = 8

var _stack: Array[StringName] = []
var _router_connected: bool = false


func _ready() -> void:
	_try_connect_router()


## Pushes a new context onto the stack and emits `context_changed`.
func push_context(ctx: StringName) -> void:
	assert(ctx != &"", "InputFocus.push_context: empty context")
	var old: StringName = current()
	_stack.push_back(ctx)
	assert(
		_stack.size() <= MAX_STACK_DEPTH,
		(
			"InputFocus: stack depth %d exceeded MAX_STACK_DEPTH %d — "
			+ "likely a missing pop_context. stack=%s"
		)
		% [_stack.size(), MAX_STACK_DEPTH, _stack]
	)
	context_changed.emit(ctx, old)


## Pops the topmost context and returns it. Asserts on empty stack — popping
## without a matching push is a programmer error, not a runtime condition.
func pop_context() -> StringName:
	assert(not _stack.is_empty(), "InputFocus.pop_context: empty stack")
	var popped: StringName = _stack.pop_back()
	var new_ctx: StringName = current()
	context_changed.emit(new_ctx, popped)
	return popped


## Returns the topmost context, or `&""` when the stack is empty.
func current() -> StringName:
	if _stack.is_empty():
		return &""
	return _stack.back()


## Returns the current stack depth (for tests and the debug overlay).
func depth() -> int:
	return _stack.size()


## Returns a defensive copy of the full stack, bottom-to-top, for debug
## overlays and tests. Mutating the returned array does not affect state.
func stack_snapshot() -> Array[StringName]:
	return _stack.duplicate()


## Returns a human-readable reason why gameplay input is currently blocked,
## or an empty string when gameplay (`CTX_STORE_GAMEPLAY`) is the active
## context. Intended for the debug overlay and player-facing diagnostics.
func why_blocked() -> String:
	var ctx: StringName = current()
	if ctx == CTX_STORE_GAMEPLAY:
		return ""
	if ctx == &"":
		return "stack empty — transition or leaked pop"
	return "blocked by '%s' (depth=%d)" % [String(ctx), _stack.size()]


## Test seam — clears the stack without emitting signals.
func _reset_for_tests() -> void:
	_stack.clear()


func _try_connect_router() -> void:
	if _router_connected:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var router: Node = tree.root.get_node_or_null("SceneRouter")
	if router == null or not router.has_signal("scene_ready"):
		return
	router.scene_ready.connect(_on_scene_ready)
	_router_connected = true


func _on_scene_ready(target: StringName, _payload: Dictionary) -> void:
	# Defer one frame so the new scene's controller has a chance to push its
	# context before we audit. The new root's `_ready` already ran, but the
	# call_deferred lets any deferred pushes settle as well.
	call_deferred("_audit_non_empty", target)


func _audit_non_empty(target: StringName) -> void:
	if _stack.is_empty():
		_fail("input focus stack empty after transition target=%s" % target)
		return
	if _stack.size() > 1:
		# A fresh scene should start with exactly one context. Extra frames
		# mean the prior scene leaked one or more pushes. Surface as a
		# non-fatal warning so the call site can be fixed; the topmost frame
		# still gates input correctly, so gameplay is not in a dead state.
		push_warning(
			(
				"[InputFocus] stack depth %d after transition target=%s — "
				+ "prior scene leaked push(es): %s"
			)
			% [_stack.size(), target, _stack]
		)
	_pass("target=%s ctx=%s depth=%d" % [target, current(), _stack.size()])


func _pass(detail: String) -> void:
	var log: Node = _audit_log()
	if log != null:
		log.pass_check(CHECKPOINT_NON_EMPTY, detail)


func _fail(reason: String) -> void:
	push_error("[InputFocus] %s" % reason)
	var log: Node = _audit_log()
	if log != null:
		log.fail_check(CHECKPOINT_NON_EMPTY, reason)
	var banner: Node = _error_banner()
	if banner != null and banner.has_method("show_failure"):
		banner.call("show_failure", "Input focus violated", reason)


func _audit_log() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("AuditLog")


func _error_banner() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("ErrorBanner")
