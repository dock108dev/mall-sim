## StoreDirector — sole owner of the `enter_store(store_id)` state machine
## (ISSUE-008, DESIGN.md §2.1 + §2.2, ownership.md row "store lifecycle / ready
## declaration").
##
## States: IDLE → REQUESTED → LOADING_SCENE → INSTANTIATING → VERIFYING
##         → READY | FAILED.
##
## Outcome is binary: `enter_store` resolves to `store_ready(store_id)` (state
## == READY) or `store_failed(store_id, reason)` (state == FAILED). There is no
## partial-success path and no fallback scene — DESIGN.md §1.2 ("Fail Loud,
## Never Grey") and §1.4 ("Atomic Store-Ready").
##
## Each transition emits an AuditLog checkpoint so headless CI can verify the
## state machine actually ran. Concurrent calls (state != IDLE) are rejected
## with `AuditLog.fail_check` and return false — no two loads in flight.
##
## Dependencies are looked up as autoloads by default (StoreRegistry,
## SceneRouter, AuditLog) but each can be injected for unit tests via the
## `set_*_for_tests` seams. The director never calls `change_scene_to_*`
## directly; SceneRouter is the only owner of that operation.
##
## A scene injector seam (`set_scene_injector`) lets a host scene replace the
## SceneRouter step with an in-tree injection (e.g. GameWorld's hub mode adds
## the store under its `StoreContainer` to preserve the 30+ runtime systems
## that a full viewport swap would destroy). When an injector is registered,
## the director calls it instead of SceneRouter and uses its returned node as
## the root passed to `StoreReadyContract.check`. SceneRouter remains the
## owner of full viewport transitions (main menu, etc.).
extends Node

signal store_ready(store_id: StringName)
signal store_failed(store_id: StringName, reason: String)

enum State {
	IDLE,
	REQUESTED,
	LOADING_SCENE,
	INSTANTIATING,
	VERIFYING,
	READY,
	FAILED,
}

const _STATE_CHECKPOINTS: Dictionary = {
	State.IDLE: &"director_state_idle",
	State.REQUESTED: &"director_state_requested",
	State.LOADING_SCENE: &"director_state_loading_scene",
	State.INSTANTIATING: &"director_state_instantiating",
	State.VERIFYING: &"director_state_verifying",
	State.READY: &"director_state_ready",
	State.FAILED: &"director_state_failed",
}

var state: State = State.IDLE
var _current_store: StringName = &""

var _injected_router: Node = null
var _injected_registry: Node = null
var _injected_audit: Node = null
var _injected_scene_provider: Callable = Callable()
var _scene_injector: Callable = Callable()


## Drives the full state machine for `store_id`. Returns true when state ends
## at READY, false on any failure path (unknown id, scene load error, contract
## violation, or rejected concurrent call).
# gdlint:disable=max-returns
func enter_store(store_id: StringName) -> bool:
	if state != State.IDLE:
		var rejection: String = (
			"enter_store(%s) rejected — state=%s already in flight"
			% [store_id, _state_name(state)]
		)
		_audit_fail(&"director_concurrent_enter", rejection)
		store_failed.emit(store_id, rejection)
		return false

	_current_store = store_id
	_to(State.REQUESTED, "store_id=%s" % store_id)

	var registry: Node = _get_registry()
	if registry == null:
		return await _fail("StoreRegistry autoload missing")

	var entry: StoreRegistryEntry = registry.resolve(store_id)
	if entry == null:
		return await _fail("unknown store_id: %s" % store_id)

	var scene_path: String = entry.scene_path
	_to(State.LOADING_SCENE, "path=%s" % scene_path)

	var scene_root: Node = null
	if _scene_injector.is_valid():
		# In-tree injection path (e.g. GameWorld hub mode). The injector is
		# responsible for loading, instantiating, and parenting the store
		# scene into its host container. Returning null is treated as a load
		# failure.
		var injected: Variant = await _scene_injector.call(scene_path, store_id)
		if injected is Node:
			scene_root = injected as Node
		if scene_root == null or not scene_root.is_inside_tree():
			return await _fail("scene injector returned no scene")
	else:
		var router: Node = _get_router()
		if router == null:
			return await _fail("SceneRouter autoload missing")
		if not router.has_method("route_to_path"):
			return await _fail("SceneRouter missing route_to_path()")
		if not router.has_signal("scene_ready") or not router.has_signal("scene_failed"):
			return await _fail("SceneRouter missing scene_ready/scene_failed signals")

		# Kick the router and race scene_ready against scene_failed. The router
		# is the sole owner of change_scene_to_*; we never call it here.
		router.route_to_path(scene_path, {"store_id": store_id})
		var route_result: Array = await _await_router_result(router)
		var ok: bool = route_result[0]
		if not ok:
			return await _fail("scene load failed: %s" % route_result[1])

		scene_root = _get_active_scene()
		if scene_root == null:
			return await _fail("no current_scene after route")

	_to(State.INSTANTIATING, "path=%s" % scene_path)

	# Wait for the controller to report initialized. Scenes that already report
	# initialized synchronously (common in unit fixtures) skip the await; scenes
	# with an explicit `controller_ready` signal get awaited up to the next
	# frame so the contract sees real runtime state, not partial wiring.
	if not _scene_reports_initialized(scene_root):
		if scene_root.has_signal("controller_ready"):
			await scene_root.controller_ready
		else:
			await get_tree().process_frame

	_to(State.VERIFYING, "store_id=%s" % store_id)

	var result: StoreReadyResult = StoreReadyContract.check(scene_root)
	if not result.ok:
		return await _fail(result.reason, result.failed_invariant())

	_to(State.READY, "store_id=%s" % store_id)
	store_ready.emit(store_id)
	# Reset to IDLE so subsequent enter_store calls are accepted. The READY
	# checkpoint above is the durable "we got there" record.
	state = State.IDLE
	return true
# gdlint:enable=max-returns


## Registers a callable that will be invoked instead of SceneRouter to bring
## the store scene into the tree. The callable signature is
## `(scene_path: String, store_id: StringName) -> Node` and may be a coroutine.
## It must return the scene root (already added to the tree) or null on
## failure. Pass `Callable()` to clear and revert to SceneRouter.
func set_scene_injector(callable: Callable) -> void:
	_scene_injector = callable


## Resets the director to IDLE. Test-only seam — production code reaches IDLE
## naturally after READY/FAILED paths.
func _reset_for_tests() -> void:
	state = State.IDLE
	_current_store = &""


func set_router_for_tests(router: Node) -> void:
	_injected_router = router


func set_registry_for_tests(registry: Node) -> void:
	_injected_registry = registry


func set_audit_for_tests(audit: Node) -> void:
	_injected_audit = audit


## Lets tests inject a fake "current scene" without driving an actual scene
## change. Pass `Callable()` to clear.
func set_scene_provider_for_tests(provider: Callable) -> void:
	_injected_scene_provider = provider


func _await_router_result(router: Node) -> Array:
	# Race the two router signals — whichever fires first wins. Godot has no
	# built-in `select`; we connect one-shot listeners that resolve a shared
	# state captured by reference (Array is mutable and acts as our box).
	var box: Array = [false, false, "", &""]  # [done, ok, reason, target]

	var on_ready: Callable = func(target: StringName, _payload: Dictionary) -> void:
		if box[0]:
			return
		box[0] = true
		box[1] = true
		box[3] = target
	var on_failed: Callable = func(target: StringName, reason: String) -> void:
		if box[0]:
			return
		box[0] = true
		box[1] = false
		box[2] = reason
		box[3] = target

	router.scene_ready.connect(on_ready, CONNECT_ONE_SHOT)
	router.scene_failed.connect(on_failed, CONNECT_ONE_SHOT)

	while not box[0]:
		await get_tree().process_frame

	if router.scene_ready.is_connected(on_ready):
		router.scene_ready.disconnect(on_ready)
	if router.scene_failed.is_connected(on_failed):
		router.scene_failed.disconnect(on_failed)

	return [box[1], box[2]]


func _scene_reports_initialized(scene_root: Node) -> bool:
	if not scene_root.has_method("is_controller_initialized"):
		return false
	var v: Variant = scene_root.call("is_controller_initialized")
	return v is bool and v == true


func _get_active_scene() -> Node:
	if _injected_scene_provider.is_valid():
		return _injected_scene_provider.call()
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.current_scene


func _get_router() -> Node:
	if _injected_router != null:
		return _injected_router
	return _autoload("SceneRouter")


func _get_registry() -> Node:
	if _injected_registry != null:
		return _injected_registry
	return _autoload("StoreRegistry")


func _get_audit() -> Node:
	if _injected_audit != null:
		return _injected_audit
	return _autoload("AuditLog")


func _autoload(name_str: String) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	return root.get_node_or_null(name_str)


func _to(next: State, detail: String) -> void:
	state = next
	_audit_pass(_STATE_CHECKPOINTS[next], detail)


func _fail(reason: String, failed_invariant: StringName = &"") -> bool:
	state = State.FAILED
	push_error("[StoreDirector] %s — %s" % [_current_store, reason])
	_audit_fail(_STATE_CHECKPOINTS[State.FAILED], "store_id=%s reason=%s" % [_current_store, reason])
	_raise_fail_card(_current_store, failed_invariant, reason)
	store_failed.emit(_current_store, reason)
	# Drop back to IDLE so the system can recover after a failed attempt.
	var failed_id: StringName = _current_store
	state = State.IDLE
	_current_store = &""
	# Yield once so callers using `await enter_store(...)` see a consistent
	# async return regardless of which step failed.
	await get_tree().process_frame
	# Re-record the failed id for tests that read state immediately after.
	_current_store = failed_id
	return false


func _audit_pass(checkpoint: StringName, detail: String) -> void:
	var log: Node = _get_audit()
	if log != null and log.has_method("pass_check"):
		log.pass_check(checkpoint, detail)
	else:
		print("AUDIT: PASS %s %s" % [checkpoint, detail])


func _audit_fail(checkpoint: StringName, reason: String) -> void:
	var log: Node = _get_audit()
	if log != null and log.has_method("fail_check"):
		log.fail_check(checkpoint, reason)
	else:
		print("AUDIT: FAIL %s %s" % [checkpoint, reason])


func _state_name(s: State) -> String:
	return State.keys()[s]


## Raises the full-screen FailCard (ISSUE-018). Looked up as an autoload so
## unit tests without the autoload tree simply skip the visual surface.
func _raise_fail_card(
	store_id: StringName, failed_invariant: StringName, reason: String
) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var card: Node = tree.root.get_node_or_null("FailCard")
	if card == null or not card.has_method("show_failure"):
		return
	card.call("show_failure", store_id, failed_invariant, reason)
