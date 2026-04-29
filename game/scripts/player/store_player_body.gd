## Store-interior player avatar.
##
## Provides movement (WASD via InputMap `move_*`) and an `interact` action.
## Reads InputFocus to gate input — the `store_gameplay` context is pushed and
## popped by `StoreController` (the per-store root) on `EventBus.store_entered`
## / `store_exited`, so this body is purely a reader of focus. See
## `docs/architecture/ownership.md` row 5.
##
## `interact_pressed(interactable)` is only emitted when:
##   * `current_interactable` is non-null (set by the interaction-ray system), and
##   * `InputFocus.current()` is exactly `&"store_gameplay"` (no modal stealing
##     focus, no menu active).
##
## Fails loudly — not silently — when the runtime contract is broken:
##   * parent has no `get_store_id()` method (not inside a store scene root)
##   * InputFocus autoload is missing
## In both cases `AuditLog.fail_check(&"player_spawned", ...)` fires and the
## ErrorBanner is raised; see DESIGN.md §1.2 "Fail Loud, Never Grey".
##
## Note on class name: `PlayerController` is already taken by the legacy
## floating orbit-camera controller in `player_controller.gd`.
## This file introduces the CharacterBody avatar under a distinct class name
## (`StorePlayerBody`) so the existing public surface is
## preserved, while the node is still named `Player` in the scene tree to
## satisfy `StoreReadyContract` (`INV_PLAYER`).
class_name StorePlayerBody
extends CharacterBody3D

signal interact_pressed(interactable: Node)

const CHECKPOINT_PLAYER_SPAWNED: StringName = &"player_spawned"
const CTX_STORE_GAMEPLAY: StringName = &"store_gameplay"

const ACTION_INTERACT: StringName = &"interact"
const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_MOVE_FORWARD: StringName = &"move_forward"
const ACTION_MOVE_BACK: StringName = &"move_back"

## Ground movement speed in meters per second.
@export var move_speed: float = 4.0

## Rectangular footprint clamp applied after `move_and_slide`. Defense in
## depth: even if a wall collider is missing or misconfigured, the body cannot
## leave the store footprint. Defaults match the shipping retro_games interior
## (7×5 floor with 0.3 m margin to the wall surface). When `retro_games.tscn`
## room geometry is resized these values must be updated in lockstep — they
## are exported so future store .tscn files can override per-store. Only X and
## Z are clamped; Y is left to gravity / verticality.
@export var bounds_min: Vector3 = Vector3(-3.2, 0.0, -2.2)
@export var bounds_max: Vector3 = Vector3(3.2, 0.0, 2.2)

## The interaction ray / proximity system writes the hovered interactable here.
## Cleared back to `null` when nothing is hoverable. Public so the HUD and the
## objective director can render prompts off the same source of truth.
var current_interactable: Node = null


func _ready() -> void:
	if not _assert_inside_store_scene():
		return
	if not _assert_input_focus_present():
		return

	_emit_spawned_checkpoint()


func _physics_process(_delta: float) -> void:
	if not _gameplay_allowed():
		velocity = Vector3.ZERO
		return
	var input_vec: Vector2 = Input.get_vector(
		ACTION_MOVE_LEFT,
		ACTION_MOVE_RIGHT,
		ACTION_MOVE_FORWARD,
		ACTION_MOVE_BACK,
	)
	var dir: Vector3 = Vector3(input_vec.x, 0.0, input_vec.y)
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	# Leave velocity.y to gravity-free 0 — store floors are flat; a gravity
	# pass can land when a store introduces verticality.
	move_and_slide()
	_clamp_to_store_footprint()


func _clamp_to_store_footprint() -> void:
	var pos: Vector3 = global_position
	pos.x = clampf(pos.x, bounds_min.x, bounds_max.x)
	pos.z = clampf(pos.z, bounds_min.z, bounds_max.z)
	global_position = pos


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION_INTERACT):
		return
	if current_interactable == null:
		return
	if not _gameplay_allowed():
		return
	interact_pressed.emit(current_interactable)


## Test seam — sets the hovered interactable. Production code should assign
## `current_interactable` directly; this wrapper exists so tests reading this
## file document the contract.
func set_current_interactable(node: Node) -> void:
	current_interactable = node


func _gameplay_allowed() -> bool:
	var ifocus: Node = _input_focus()
	if ifocus == null or not ifocus.has_method("current"):
		return false
	return ifocus.call("current") == CTX_STORE_GAMEPLAY


func _emit_spawned_checkpoint() -> void:
	var log: Node = _audit_log()
	if log == null:
		return
	var scene_path: String = ""
	var root: Node = get_tree().current_scene if get_tree() != null else null
	if root != null:
		scene_path = root.scene_file_path
	log.call("pass_check", CHECKPOINT_PLAYER_SPAWNED,
		"scene=%s path=%s" % [scene_path, get_path()])


func _assert_inside_store_scene() -> bool:
	var parent: Node = get_parent()
	# Walk up until we find a node exposing the store-root contract, or the
	# scene root. This mirrors StoreReadyContract — a store root is any node
	# that implements `get_store_id()`.
	var node: Node = parent
	while node != null:
		if node.has_method("get_store_id"):
			return true
		node = node.get_parent()
	_fail_spawn("parent chain has no store root (get_store_id missing)")
	return false


func _assert_input_focus_present() -> bool:
	if _input_focus() != null:
		return true
	_fail_spawn("InputFocus autoload missing at /root/InputFocus")
	return false


func _fail_spawn(reason: String) -> void:
	push_error("[StorePlayerBody] %s" % reason)
	var log: Node = _audit_log()
	if log != null:
		log.call("fail_check", CHECKPOINT_PLAYER_SPAWNED, reason)
	var banner: Node = _error_banner()
	if banner != null and banner.has_method("show_failure"):
		banner.call("show_failure", "Player spawn contract violated", reason)
	# §F-15: push_error + ErrorBanner + AuditLog already fired above; assert crashes in
	# debug builds only — release handles the failure via the UI paths above.
	assert(false, "StorePlayerBody spawn contract: %s" % reason)


func _input_focus() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("InputFocus")


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
