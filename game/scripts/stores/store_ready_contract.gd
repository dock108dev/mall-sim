## Store-Ready contract — synchronous check of the 10 invariants that define
## a store scene as "READY" per DESIGN.md §1.4 and
## docs/research/store-ready-contract-examples.md.
##
## A store is READY iff ALL invariants pass. Partial success is not a state;
## see docs/architecture/ownership.md row 2 (store lifecycle / ready
## declaration). `check()` collects every failing invariant so callers can
## surface a complete diagnostic in one pass.
##
## The check is intentionally synchronous (no `await`) — it is called AFTER
## the scene has finished loading and the controller reports initialisation.
## Async waits belong in the scene transition state machine, not here.
##
## Invariants (StringName):
##   store_id_resolved      — scene.get_store_id() returns a non-empty StringName
##   scene_loaded           — scene != null and is inside the SceneTree
##   controller_initialized — scene.is_controller_initialized() == true
##   content_instantiated   — a `StoreContent` node exists and has ≥1 child
##   camera_current         — a `StoreCamera` (Camera2D/3D) exists and .current
##   player_present         — a `Player` node exists under the scene
##   input_gameplay         — scene.get_input_context() == &"store_gameplay"
##   no_modal_focus         — scene.has_blocking_modal() == false
##   interaction_count_ge_1 — ≥1 node in group "interactables" under the scene
##   objective_matches_action — scene.objective_matches_action() == true
class_name StoreReadyContract
extends RefCounted

const INV_STORE_ID: StringName = &"store_id_resolved"
const INV_SCENE_LOADED: StringName = &"scene_loaded"
const INV_CONTROLLER_INIT: StringName = &"controller_initialized"
const INV_CONTENT: StringName = &"content_instantiated"
const INV_CAMERA: StringName = &"camera_current"
const INV_PLAYER: StringName = &"player_present"
const INV_INPUT: StringName = &"input_gameplay"
const INV_NO_MODAL: StringName = &"no_modal_focus"
const INV_INTERACTIONS: StringName = &"interaction_count_ge_1"
const INV_OBJECTIVE: StringName = &"objective_matches_action"

const INVARIANTS: Array[StringName] = [
	INV_STORE_ID,
	INV_SCENE_LOADED,
	INV_CONTROLLER_INIT,
	INV_CONTENT,
	INV_CAMERA,
	INV_PLAYER,
	INV_INPUT,
	INV_NO_MODAL,
	INV_INTERACTIONS,
	INV_OBJECTIVE,
]


static func check(scene: Node) -> StoreReadyResult:
	var failures: Array[StringName] = []

	# 2. scene_loaded — evaluated first because every other check dereferences
	# `scene`. If the scene is missing, mark every downstream invariant failed
	# so the caller sees the full picture instead of one cause at a time.
	if scene == null or not scene.is_inside_tree():
		for inv: StringName in INVARIANTS:
			failures.append(inv)
		return StoreReadyResult.new(false, failures, "scene not loaded")

	# 1. store_id_resolved
	if not _store_id_resolved(scene):
		failures.append(INV_STORE_ID)

	# 2. scene_loaded — passed if we got here.

	# 3. controller_initialized
	if not _method_returns_true(scene, &"is_controller_initialized"):
		failures.append(INV_CONTROLLER_INIT)

	# 4. content_instantiated
	if not _content_instantiated(scene):
		failures.append(INV_CONTENT)

	# 5. camera_current
	if not _camera_current(scene):
		failures.append(INV_CAMERA)

	# 6. player_present
	if _find(scene, "Player") == null:
		failures.append(INV_PLAYER)

	# 7. input_gameplay
	if not _input_gameplay(scene):
		failures.append(INV_INPUT)

	# 8. no_modal_focus — scene must expose `has_blocking_modal()`; a missing
	# method is a contract violation (can't prove the negative), not a pass.
	if not scene.has_method("has_blocking_modal") or scene.has_blocking_modal():
		failures.append(INV_NO_MODAL)

	# 9. interaction_count_ge_1
	if _interaction_count(scene) < 1:
		failures.append(INV_INTERACTIONS)

	# 10. objective_matches_action
	if not _method_returns_true(scene, &"objective_matches_action"):
		failures.append(INV_OBJECTIVE)

	var ok: bool = failures.is_empty()
	var reason: String = "READY" if ok else "failed invariants: %s" % [failures]
	return StoreReadyResult.new(ok, failures, reason)


static func _store_id_resolved(scene: Node) -> bool:
	if not scene.has_method("get_store_id"):
		return false
	var id: Variant = scene.get_store_id()
	return id is StringName and (id as StringName) != &""


static func _method_returns_true(scene: Node, method: StringName) -> bool:
	if not scene.has_method(method):
		return false
	var v: Variant = scene.call(method)
	return v is bool and v == true


static func _content_instantiated(scene: Node) -> bool:
	var content: Node = _find(scene, "StoreContent")
	return content != null and content.get_child_count() > 0


static func _camera_current(scene: Node) -> bool:
	var cam: Node = _find(scene, "StoreCamera")
	if cam == null:
		return false
	# Camera2D and Camera3D both expose `current` — duck-type to avoid a hard
	# dependency on either class in a contract that must work for both.
	if not ("current" in cam):
		return false
	return cam.get("current") == true


static func _input_gameplay(scene: Node) -> bool:
	if not scene.has_method("get_input_context"):
		return false
	var ctx: Variant = scene.get_input_context()
	return ctx is StringName and (ctx as StringName) == &"store_gameplay"


static func _interaction_count(scene: Node) -> int:
	var tree: SceneTree = scene.get_tree()
	if tree == null:
		return 0
	var count: int = 0
	for n: Node in tree.get_nodes_in_group(&"interactables"):
		if n == scene or scene.is_ancestor_of(n):
			count += 1
	return count


## Try unique-name lookup first (`%Name`), then recursive find_child.
## Unique-name lookup only works when the node is owned by the scene root,
## which is true for authored .tscn scenes but not always for programmatic
## fixtures. The fallback keeps unit tests simple.
static func _find(scene: Node, node_name: String) -> Node:
	var unique: Node = scene.get_node_or_null(NodePath("%" + node_name))
	if unique != null:
		return unique
	return scene.find_child(node_name, true, false)
