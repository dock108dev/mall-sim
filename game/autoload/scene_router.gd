## Sole owner of `get_tree().change_scene_to_*` calls.
##
## Per docs/architecture/ownership.md (row 1: Scene load / transition),
## SceneRouter is the only place in the codebase that may invoke
## `change_scene_to_file` / `change_scene_to_packed`. All other systems route
## through `route_to(target, payload)` (alias-driven) or the path/packed
## helpers exposed for legacy callers.
##
## A successful transition emits the `scene_ready(target, payload)` signal
## and prints the audit line `AUDIT: PASS scene_change_ok target=<...>` via
## AuditLog. The signal fires after the new scene root has been added to the
## tree (its `_ready` has run) and one additional `process_frame` has
## elapsed; per-scene readiness contracts (StoreReady, etc.) are layered on
## top of this by their owning controllers.
extends Node

signal scene_ready(target: StringName, payload: Dictionary)
signal scene_failed(target: StringName, reason: String)

const _DEFAULT_TARGETS: Dictionary = {
	&"main_menu": "res://game/scenes/ui/main_menu.tscn",
	&"gameplay": "res://game/scenes/bootstrap/gameplay_shell.tscn",
	&"mall_hub": "res://game/scenes/bootstrap/gameplay_shell.tscn",
	&"boot": "res://game/scenes/bootstrap/boot.tscn",
}

var _targets: Dictionary = {}
var _in_flight: bool = false


func _ready() -> void:
	for key in _DEFAULT_TARGETS:
		_targets[key] = _DEFAULT_TARGETS[key]


## Registers (or overrides) a `target` alias to a scene path. Used by tests or
## future systems that need to reach scenes outside the default alias table.
func register_target(target: StringName, scene_path: String) -> void:
	# §F-14: asserts crash on empty args in debug; release fallback is _fail() via push_error.
	assert(target != &"", "SceneRouter.register_target: empty target")
	assert(scene_path != "", "SceneRouter.register_target: empty scene_path")
	_targets[target] = scene_path


## Returns true if the alias is known.
func has_target(target: StringName) -> bool:
	return _targets.has(target)


## Routes to a named target. `payload` may carry a `scene_path` override for
## ad-hoc targets that aren't registered in the alias table.
func route_to(target: StringName, payload: Dictionary = {}) -> void:
	assert(target != &"", "SceneRouter.route_to: empty target")
	if _in_flight:
		push_warning("SceneRouter: route_to(%s) ignored — transition in flight" % target)
		return
	var path: String = String(payload.get("scene_path", ""))
	if path == "":
		path = String(_targets.get(target, ""))
	if path == "":
		_fail(target, "unknown target and no scene_path payload")
		return
	await _change_scene_to_file(target, path, payload)


## Path-based entry point used by legacy callers (e.g. SceneTransition fade
## wrappers). Prefer `route_to(target, payload)` in new code.
func route_to_path(scene_path: String, payload: Dictionary = {}) -> void:
	assert(scene_path != "", "SceneRouter.route_to_path: empty scene_path")
	if _in_flight:
		push_warning("SceneRouter: route_to_path(%s) ignored — transition in flight" % scene_path)
		return
	await _change_scene_to_file(_target_for_path(scene_path), scene_path, payload)


## Packed-scene entry point used by legacy callers. Prefer `route_to`.
func route_to_packed(scene: PackedScene, payload: Dictionary = {}) -> void:
	assert(scene != null, "SceneRouter.route_to_packed: null scene")
	if _in_flight:
		push_warning("SceneRouter: route_to_packed ignored — transition in flight")
		return
	_in_flight = true
	# Mirrors `_change_scene_to_file` — clear ModalQueue state before the
	# swap so freed panels can't drain into the new scene's UI tree.
	ModalQueue.clear()
	var target: StringName = _target_for_path(scene.resource_path)
	var err: int = get_tree().change_scene_to_packed(scene)
	if err != OK:
		_in_flight = false
		_fail(target, "change_scene_to_packed failed: %d" % err)
		return
	# change_scene_to_* queues the swap; the new root isn't in the tree yet.
	# Wait for tree_changed so the new scene root has been added (triggers its
	# _ready), then one more process_frame so @onready/_ready deferrals settle.
	await get_tree().tree_changed
	await get_tree().process_frame
	_in_flight = false
	_emit_pass(target, scene.resource_path)
	scene_ready.emit(target, payload)


func _change_scene_to_file(
	target: StringName, scene_path: String, payload: Dictionary
) -> void:
	_in_flight = true
	# Drop any active or pending ModalQueue entries before the swap so a
	# panel freed during scene teardown can't drain into the new scene's
	# UI tree (and a stale pending entry can't dispatch into a half-built
	# scene). The freed panels' own _exit_tree still pops any held
	# CTX_MODAL frame; this just makes the queue's notify_closed/cancel
	# calls become no-ops instead of dispatching the next entry.
	ModalQueue.clear()
	var err: int = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		_in_flight = false
		_fail(target, "change_scene_to_file failed: %d (%s)" % [err, scene_path])
		return
	# change_scene_to_* queues the swap; the new root isn't in the tree yet.
	# Wait for tree_changed so the new scene root has been added (triggers its
	# _ready), then one more process_frame so @onready/_ready deferrals settle.
	await get_tree().tree_changed
	await get_tree().process_frame
	_in_flight = false
	_emit_pass(target, scene_path)
	scene_ready.emit(target, payload)


func _target_for_path(scene_path: String) -> StringName:
	for key in _targets:
		if _targets[key] == scene_path:
			return key
	return StringName(scene_path)


func _emit_pass(target: StringName, scene_path: String) -> void:
	# §EH-38 (docs/audits/error-handling-report.md): AuditLog is an autoload
	# (project.godot) and `pass_check` is its owner-declared method
	# (audit_log.gd:21). The prior `_audit_log()` walker + has_method guard
	# pair was the §EH-13/§EH-15 dead-guard shape; the `print()` fallback was
	# unreachable in production and would have skipped the ring buffer
	# scanned by headless CI on a rename.
	var detail: String = "target=%s path=%s" % [target, scene_path]
	AuditLog.pass_check(&"scene_change_ok", detail)


func _fail(target: StringName, reason: String) -> void:
	# §EH-38: typed autoload — see _emit_pass above. fail_check is declared at
	# audit_log.gd:39. A rename now fails GDScript parse rather than silently
	# emitting only the push_error line (which the CI stderr scan catches as
	# ^ERROR, but without the structured AUDIT FAIL record).
	push_error("SceneRouter: %s — %s" % [target, reason])
	AuditLog.fail_check(&"scene_change_ok", "target=%s reason=%s" % [target, reason])
	scene_failed.emit(target, reason)
