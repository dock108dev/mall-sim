## Single owner of camera activation (ISSUE-010, docs/architecture/ownership.md row 4).
## All scenes that activate a Camera2D/Camera3D must route through
## `request_current(cam, source)`; direct `camera.current = true` writes outside
## this autoload are flagged by `tests/validate_camera_ownership.sh`.
##
## Companion to CameraManager — CameraManager observes/tracks viewport state,
## CameraAuthority is the write side that picks which camera is current and
## guarantees exactly one is active at a time. StoreDirector / StoreController
## must call `assert_single_active` before declaring `store_ready`.
extends Node

signal camera_changed(new_camera: Node, source: StringName)

const CAMERAS_GROUP: StringName = &"cameras"
const CHECKPOINT_SINGLE_ACTIVE: StringName = &"camera_single_active"

var _active: Node = null
var _active_source: StringName = &""


## Activates `cam` as the current viewport camera and clears all previously
## current cameras. `source` identifies the requester (store id, "mall_hub",
## "main_menu", …) for logging and post-mortem traceability.
##
## Returns true on success. Fails loud (push_error + AuditLog.fail) when the
## camera is null/invalid or not a Camera2D/Camera3D.
func request_current(cam: Variant, source: StringName) -> bool:
	assert(source != &"", "CameraAuthority.request_current: empty source")
	if cam == null or not is_instance_valid(cam):
		_fail("invalid camera (null or freed) from source=%s" % source)
		return false
	if not (cam is Camera3D or cam is Camera2D):
		_fail("not a Camera2D/Camera3D from source=%s (got %s)" % [source, cam.get_class()])
		return false

	_register_in_group(cam)
	_clear_others(cam)
	_make_current(cam)

	_active = cam
	_active_source = source
	camera_changed.emit(cam, source)
	return true


## Returns the currently active camera, or null if none is registered.
func current() -> Node:
	if _active != null and not is_instance_valid(_active):
		_active = null
		_active_source = &""
	return _active


## Returns the source StringName that activated the current camera.
func current_source() -> StringName:
	if current() == null:
		return &""
	return _active_source


## Walks the `cameras` group and asserts exactly one camera reports current.
## Emits AuditLog pass/fail. Used by StoreDirector right before `store_ready`.
func assert_single_active() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		_fail("no SceneTree (called outside running game)")
		return false

	var cams: Array[Node] = tree.get_nodes_in_group(CAMERAS_GROUP)
	var active: Array[Node] = []
	for c in cams:
		if not is_instance_valid(c):
			continue
		if _is_current(c):
			active.append(c)

	if active.size() != 1:
		var paths: Array = active.map(func(n: Node) -> String: return str(n.get_path()))
		_fail("expected exactly 1 current camera in group '%s', got %d: %s"
			% [CAMERAS_GROUP, active.size(), paths])
		return false

	_pass("active=%s source=%s" % [active[0].get_path(), _active_source])
	return true


## Test seam — clears tracked active camera without touching nodes.
func _reset_for_tests() -> void:
	_active = null
	_active_source = &""


func _register_in_group(cam: Node) -> void:
	if not cam.is_in_group(CAMERAS_GROUP):
		cam.add_to_group(CAMERAS_GROUP)


func _clear_others(keep: Node) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for c in tree.get_nodes_in_group(CAMERAS_GROUP):
		if c == keep or not is_instance_valid(c):
			continue
		_clear_current(c)


func _make_current(cam: Node) -> void:
	if cam is Camera3D:
		(cam as Camera3D).make_current()
	elif cam is Camera2D:
		(cam as Camera2D).make_current()


func _clear_current(cam: Node) -> void:
	if cam is Camera3D:
		(cam as Camera3D).clear_current()
	elif cam is Camera2D:
		# Camera2D has no clear_current(); disable it instead so it cannot
		# arbitrate as "current" on the next frame.
		var c2: Camera2D = cam as Camera2D
		if c2.is_current():
			c2.enabled = false


func _is_current(cam: Node) -> bool:
	if cam is Camera3D:
		return (cam as Camera3D).current
	if cam is Camera2D:
		return (cam as Camera2D).is_current()
	return false


func _pass(detail: String) -> void:
	var log: Node = _audit_log()
	if log != null:
		log.pass_check(CHECKPOINT_SINGLE_ACTIVE, detail)


func _fail(reason: String) -> void:
	push_error("[CameraAuthority] %s" % reason)
	var log: Node = _audit_log()
	if log != null:
		log.fail_check(CHECKPOINT_SINGLE_ACTIVE, reason)
	var banner: Node = _error_banner()
	if banner != null and banner.has_method("show_failure"):
		banner.call("show_failure", "Camera authority violated", reason)


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
