## Composite "Day 1 playable" readiness checkpoint that runs above
## StoreReadyContract.
##
## StoreReadyContract proves the code-level invariants of a store scene; this
## autoload proves the entry state is actually *playable* — the player can see,
## act, and progress without any extra interaction. The two together form the
## deterministic pass/fail signal for the golden Day 1 entry path.
##
## Subscribes to StoreDirector.store_ready (signal-driven, never polled). On
## emission it runs ten read-only checks; passing all ten emits
## `AuditLog.pass_check(&"day1_playable_ready", …)`, otherwise the first
## failing condition is reported via
## `AuditLog.fail_check(&"day1_playable_failed", "<name>=<value>")`.
##
## The check never mutates game state. Any non-Day-1 entry will naturally fail
## the `first_sale_complete` condition (it becomes true after a sale) — that is
## the intended behaviour: this audit only reports green for a clean Day 1 state.
extends Node

const CHECKPOINT_PASS: StringName = &"day1_playable_ready"
const CHECKPOINT_FAIL: StringName = &"day1_playable_failed"

## First-person store entry registers `&"player_fp"` (StorePlayerBody) and may
## switch to `&"debug_overhead"` via the F3 toggle. `&"retro_games"` covers the
## orbit-only fallback path in `GameWorld._activate_store_camera` for stores
## without a `PlayerEntrySpawn` marker.
const _ALLOWED_CAMERA_SOURCES: Array[StringName] = [
	&"player_fp",
	&"debug_overhead",
	&"retro_games",
]

const _COND_ACTIVE_STORE: StringName = &"active_store_id"
const _COND_PLAYER_SPAWNED: StringName = &"player_spawned"
const _COND_CAMERA_SOURCE: StringName = &"camera_source"
const _COND_CAMERA_CURRENT: StringName = &"camera_current"
const _COND_INPUT_FOCUS: StringName = &"input_focus"
const _COND_FIXTURE_COUNT: StringName = &"fixture_count"
const _COND_STOCKABLE_SLOTS: StringName = &"stockable_shelf_slots"
const _COND_BACKROOM_COUNT: StringName = &"backroom_count"
const _COND_FIRST_SALE: StringName = &"first_sale_complete"
const _COND_OBJECTIVE: StringName = &"objective_active"


func _ready() -> void:
	var director: Node = _autoload("StoreDirector")
	if director != null and director.has_signal("store_ready"):
		var cb: Callable = Callable(self, "_on_store_ready")
		if not director.store_ready.is_connected(cb):
			director.store_ready.connect(cb)


## Test seam — runs the composite check synchronously without waiting for a
## signal. Returns the same pass/fail dictionary the signal handler emits.
func evaluate_for_test(store_id: StringName) -> Dictionary:
	return _evaluate(store_id)


func _on_store_ready(store_id: StringName) -> void:
	var failure: Dictionary = _evaluate(store_id)
	if failure.is_empty():
		_audit_pass("store_id=%s" % store_id)
	else:
		var reason: String = "%s=%s" % [failure["name"], failure["value"]]
		_audit_fail(reason)


## Returns {} on full pass, otherwise {"name": <cond>, "value": <observed>}
## describing the first failing condition. Pure: no game state is mutated.
# gdlint:disable=max-returns
func _evaluate(store_id: StringName) -> Dictionary:
	var game_state: Node = _autoload("GameState")
	var active_id: StringName = &""
	if game_state != null and "active_store_id" in game_state:
		active_id = game_state.active_store_id
	if active_id != store_id:
		return _fail_dict(_COND_ACTIVE_STORE,
			"%s (expected %s)" % [String(active_id), String(store_id)])

	var player_count: int = _count_players_in_scene()
	if player_count < 1:
		return _fail_dict(_COND_PLAYER_SPAWNED, str(player_count))

	var camera_source: StringName = _resolve_camera_source()
	if not _ALLOWED_CAMERA_SOURCES.has(camera_source):
		return _fail_dict(_COND_CAMERA_SOURCE, String(camera_source))

	if not _viewport_has_current_camera():
		return _fail_dict(_COND_CAMERA_CURRENT, "null")

	var input_ctx: StringName = _resolve_input_context()
	if input_ctx != &"store_gameplay":
		return _fail_dict(_COND_INPUT_FOCUS, String(input_ctx))

	var fixture_count: int = _count_fixtures_in_store()
	if fixture_count < 1:
		return _fail_dict(_COND_FIXTURE_COUNT, str(fixture_count))

	var stockable: int = _count_stockable_shelf_slots()
	if stockable < 1:
		return _fail_dict(_COND_STOCKABLE_SLOTS, str(stockable))

	var backroom: int = _resolve_backroom_count(store_id)
	if backroom < 1:
		return _fail_dict(_COND_BACKROOM_COUNT, str(backroom))

	var first_sale_done: bool = false
	if game_state != null and game_state.has_method("get_flag"):
		first_sale_done = bool(game_state.call("get_flag", &"first_sale_complete"))
	if first_sale_done:
		return _fail_dict(_COND_FIRST_SALE, "true")

	if not _objective_active():
		return _fail_dict(_COND_OBJECTIVE, "false")

	return {}
# gdlint:enable=max-returns


func _fail_dict(name: StringName, value: String) -> Dictionary:
	return {"name": String(name), "value": value}


## §F-40 — Returning `&""` on a missing autoload is intentional: `_evaluate`
## reports `camera_source=""` / `input_focus=""` via `AuditLog.fail_check`,
## which is louder and more diagnosable than a `push_error` here would be (the
## composite checkpoint name + observed value pinpoints which condition fell
## over). Production boot always loads CameraAuthority and InputFocus.
func _resolve_camera_source() -> StringName:
	var authority: Node = _autoload("CameraAuthority")
	if authority == null or not authority.has_method("current_source"):
		return &""
	return authority.call("current_source")


func _resolve_input_context() -> StringName:
	var focus: Node = _autoload("InputFocus")
	if focus == null or not focus.has_method("current"):
		return &""
	return focus.call("current")


## §F-59 — `tree == null` returning `0` falls through to the
## `_COND_PLAYER_SPAWNED` `_fail_dict` branch, so the audit reports
## `player_spawned=0` rather than crashing. Production boot always has a
## SceneTree by the time `store_ready` fires; the null arm is the same
## test-seam pattern documented in §F-40 for autoload-missing fallbacks.
func _count_players_in_scene() -> int:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0
	# StorePlayerBody (and the legacy PlayerController) joins the "player" group
	# via its scene file. The check guards against an FP store entry where the
	# scene loaded but the player body never spawned.
	return tree.get_nodes_in_group(&"player").size()


## §F-59 — Same test-seam pattern as `_count_players_in_scene`: viewport-null
## returns false, the audit reports `camera_current=null` via `_fail_dict`.
func _viewport_has_current_camera() -> bool:
	var vp: Viewport = get_viewport()
	if vp == null:
		return false
	return vp.get_camera_3d() != null


func _count_fixtures_in_store() -> int:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0
	# The "fixture" group is store-scoped by convention — only store scenes
	# add nodes to it — so a global group walk gives the same answer as a
	# StoreContainer-scoped one without the scene-tree assumptions.
	return tree.get_nodes_in_group(&"fixture").size()


func _count_stockable_shelf_slots() -> int:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0
	var count: int = 0
	for node: Node in tree.get_nodes_in_group(&"shelf_slot"):
		if not node.has_method("is_available"):
			continue
		if bool(node.call("is_available")):
			count += 1
	return count


func _resolve_backroom_count(store_id: StringName) -> int:
	var inventory: Node = _find_inventory_system()
	if inventory == null or not inventory.has_method("get_backroom_items_for_store"):
		return 0
	var items: Variant = inventory.call(
		"get_backroom_items_for_store", String(store_id)
	)
	if items is Array:
		return (items as Array).size()
	return 0


func _find_inventory_system() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var current: Node = tree.current_scene
	if current != null:
		var found: Node = current.find_child("InventorySystem", true, false)
		if found != null:
			return found
	if tree.root == null:
		return null
	return tree.root.find_child("InventorySystem", true, false)


func _objective_active() -> bool:
	var rail: Node = _autoload("ObjectiveRail")
	if rail == null:
		return false
	if rail.has_method("has_active_objective"):
		return bool(rail.call("has_active_objective"))
	return false


func _audit_pass(detail: String) -> void:
	var log: Node = _autoload("AuditLog")
	if log != null and log.has_method("pass_check"):
		log.call("pass_check", CHECKPOINT_PASS, detail)


func _audit_fail(reason: String) -> void:
	var log: Node = _autoload("AuditLog")
	if log != null and log.has_method("fail_check"):
		log.call("fail_check", CHECKPOINT_FAIL, reason)


func _autoload(name_str: String) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	return root.get_node_or_null(name_str)
