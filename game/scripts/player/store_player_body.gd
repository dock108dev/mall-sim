## Store-interior player avatar.
##
## Provides movement (WASD via InputMap `move_*`), sprint, mouse-look (yaw on
## the body, pitch on the embedded `Camera3D`), and an `interact` action.
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
const CAMERA_SOURCE: StringName = &"player_fp"

const ACTION_INTERACT: StringName = &"interact"
const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_MOVE_FORWARD: StringName = &"move_forward"
const ACTION_MOVE_BACK: StringName = &"move_back"
const ACTION_SPRINT: StringName = &"sprint"
## Action that toggles the orbit/top-down dev debug view. Bound to F1 in the
## project InputMap; see project.godot. Independent of the legacy F3
## `toggle_debug` action which drives the AuditOverlay HUD.
const ACTION_TOGGLE_DEBUG_CAMERA: StringName = &"toggle_debug_camera"
## Camera source token used when the orbit camera is the active debug view.
## Matches `Day1ReadinessAudit._ALLOWED_CAMERA_SOURCES`.
const CAMERA_SOURCE_DEBUG_OVERHEAD: StringName = &"debug_overhead"
## NodePath to the orbit `PlayerController` authored as a sibling of this
## body in the store scene root. Stores without an orbit controller skip the
## toggle silently — F1 is a dev-only convenience, not a hard contract.
const _ORBIT_CONTROLLER_SIBLING_PATH: NodePath = ^"../PlayerController"

const PITCH_LIMIT_RAD: float = deg_to_rad(80.0)

## Walk speed in meters per second.
@export var move_speed: float = 4.0

## Multiplier applied to `move_speed` while the `sprint` action is held.
## Default 1.5 keeps run pace inside the 5.5–7.0 m/s target range for the
## shipping walk speed (3.0–4.5).
@export var sprint_multiplier: float = 1.5

## Radians of view rotation per pixel of mouse motion. Tuned for default
## desktop mouse DPI; players can rebind in settings.
@export var mouse_sensitivity: float = 0.002

## Rectangular footprint clamp applied after `move_and_slide`. Defense in
## depth: even if a wall collider is missing or misconfigured, the body cannot
## leave the store footprint. Defaults match the shipping retro_games interior
## (16×20 floor with 0.3 m margin from the wall surface; walls sit at ±8.0 X
## and ±10.0 Z). Per-store overrides come from the `PlayerEntrySpawn` marker's
## `bounds_min` / `bounds_max` metadata, applied by `GameWorld._spawn_player_in_store`
## right after instantiation. Only X and Z are clamped; Y is left to gravity /
## verticality.
@export var bounds_min: Vector3 = Vector3(-7.7, 0.0, -9.7)
@export var bounds_max: Vector3 = Vector3(7.7, 0.0, 9.7)

## The interaction ray / proximity system writes the hovered interactable here.
## Cleared back to `null` when nothing is hoverable. Public so the HUD and the
## objective director can render prompts off the same source of truth.
var current_interactable: Node = null

## Cached project-wide gravity magnitude. Read once at construction so the
## physics step never pays the ProjectSettings lookup cost. Falls back to 9.8
## m/s² when the setting is missing (test fixtures without a project loaded).
var _gravity: float = float(
	ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
)

## True while the F1 debug orbit/top-down view is the active camera. The body
## stops driving movement and mouse-look while this is set so the orbit
## `PlayerController` owns input. Default false — gameplay opens in FP mode.
var _debug_view: bool = false

@onready var _camera: Camera3D = $StoreCamera


func _ready() -> void:
	if not _assert_inside_store_scene():
		return
	if not _assert_input_focus_present():
		return

	_emit_spawned_checkpoint()
	_register_camera()
	_lock_cursor_and_track_focus()
	_set_hud_fp_mode(true)


func _exit_tree() -> void:
	# Always release the cursor on teardown so the menu/hub regains a visible
	# pointer; cursor mode is global and would otherwise persist across scenes.
	# This intentionally does not touch InputFocus — the focus stack is owned by
	# StoreController (ownership.md row 5).
	InputHelper.unlock_cursor()


func _physics_process(delta: float) -> void:
	if _debug_view:
		velocity = Vector3.ZERO
		return
	if not _gameplay_allowed():
		velocity = Vector3.ZERO
		return
	var input_vec: Vector2 = Input.get_vector(
		ACTION_MOVE_LEFT,
		ACTION_MOVE_RIGHT,
		ACTION_MOVE_FORWARD,
		ACTION_MOVE_BACK,
	)
	# Move in body-relative directions so WASD follows mouse-look yaw.
	var local_dir: Vector3 = Vector3(input_vec.x, 0.0, input_vec.y)
	var dir: Vector3 = (transform.basis * local_dir)
	dir.y = 0.0
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
	var speed: float = move_speed
	if InputMap.has_action(ACTION_SPRINT) and Input.is_action_pressed(ACTION_SPRINT):
		speed = move_speed * sprint_multiplier
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	# Apply gravity while airborne so the body settles, walks down ramps, and
	# never floats. move_and_slide clamps velocity.y on floor contact.
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	_clamp_to_store_footprint()


func _clamp_to_store_footprint() -> void:
	var pos: Vector3 = global_position
	pos.x = clampf(pos.x, bounds_min.x, bounds_max.x)
	pos.z = clampf(pos.z, bounds_min.z, bounds_max.z)
	global_position = pos


func _unhandled_input(event: InputEvent) -> void:
	# Debug-build gate matches the established pattern for dev-only surfaces
	# (`debug_overlay.gd`, `audit_overlay.gd`, retro_games F3 toggle); a
	# release player who hits F1 by accident must not be able to unlock the
	# cursor and bypass the FP camera contract.
	if OS.is_debug_build() and event.is_action_pressed(ACTION_TOGGLE_DEBUG_CAMERA):
		_toggle_debug_view()
		return
	if event is InputEventMouseMotion:
		if _gameplay_allowed() and not _debug_view:
			_apply_mouse_look(event as InputEventMouseMotion)
		return
	if not event.is_action_pressed(ACTION_INTERACT):
		return
	if current_interactable == null:
		return
	if not _gameplay_allowed():
		return
	if _debug_view:
		return
	interact_pressed.emit(current_interactable)


## §F-64 — Yaw rotates the body itself and runs unconditionally; pitch needs
## the embedded `Camera3D`. The `_camera == null` arm is the same test-seam
## fallback documented in §F-54 — the production `.tscn` always supplies the
## camera, so the body without it is reachable only under unit-test isolation
## that free-instances the script. Skipping the pitch update there keeps tests
## drivable without staging a camera child.
func _apply_mouse_look(event: InputEventMouseMotion) -> void:
	var yaw_delta: float = -event.relative.x * mouse_sensitivity
	rotate_y(yaw_delta)
	if _camera == null:
		return
	var pitch: float = _camera.rotation.x - event.relative.y * mouse_sensitivity
	pitch = clampf(pitch, -PITCH_LIMIT_RAD, PITCH_LIMIT_RAD)
	_camera.rotation.x = pitch


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


## §F-54 — `_camera == null` only triggers when this body is free-instanced in
## a unit test without the packed scene; the production `.tscn` ships a
## `Camera3D` child so `@onready var _camera = $Camera3D` is always non-null at
## runtime. `authority == null` is the same test-seam pattern documented in
## §F-44 for other autoload readers — `CameraAuthority` is an autoload
## (`docs/architecture/ownership.md` row 4) and the only way to reach this
## branch is a stubbed `/root` tree. Both paths therefore stay silent.
func _register_camera() -> void:
	if _camera == null:
		return
	var authority: Node = _camera_authority()
	if authority == null:
		return
	authority.call("request_current", _camera, CAMERA_SOURCE)


## §F-54 — `_assert_input_focus_present` already aborted `_ready` if the
## autoload was missing, so reaching this with `ifocus == null` requires the
## same test-seam construction that justifies §F-44. The `has_signal` guard
## is defense-in-depth against stub `Node`s used in tests; the production
## `InputFocus` autoload always exposes `context_changed`.
##
## §F-70 — `bus == null or not bus.has_signal("game_state_changed")` is the
## same test-seam fallback as the InputFocus arm: `EventBus` is an autoload
## (`docs/architecture/ownership.md` row 3) and ships `game_state_changed`
## by contract, so production paths never hit the silent return. Skipping
## the connect under unit-test isolation keeps the cursor-tracking partial
## (focus-stack listener still runs) without crashing on a stub `/root`.
func _lock_cursor_and_track_focus() -> void:
	InputHelper.lock_cursor()
	var ifocus: Node = _input_focus()
	if ifocus != null and ifocus.has_signal("context_changed"):
		if not ifocus.is_connected("context_changed", _on_input_focus_changed):
			ifocus.connect("context_changed", _on_input_focus_changed)
	# PauseMenu unlocks the cursor on open but does not push to InputFocus, so
	# the context_changed listener cannot relock on resume. Track GameManager
	# state transitions to recapture the cursor when gameplay returns.
	var bus: Node = _event_bus()
	if bus == null or not bus.has_signal("game_state_changed"):
		return
	if not bus.is_connected("game_state_changed", _on_game_state_changed):
		bus.connect("game_state_changed", _on_game_state_changed)


func _on_input_focus_changed(new_ctx: StringName, _old_ctx: StringName) -> void:
	if _debug_view:
		# Dev orbit view owns the cursor; do not steal it back when gameplay
		# focus returns (e.g. a modal closing on top of the debug view).
		return
	if new_ctx == CTX_STORE_GAMEPLAY:
		InputHelper.lock_cursor()
	else:
		InputHelper.unlock_cursor()


func _on_game_state_changed(_old_state: int, new_state: int) -> void:
	# Relock the cursor only when gameplay resumes and this body still owns
	# focus (e.g. PauseMenu closing). Other transitions (entering a modal,
	# leaving the store, going to a menu) are owned by the focus stack and
	# the existing context_changed listener.
	if new_state != GameManager.State.GAMEPLAY:
		return
	if _debug_view:
		return
	if not _gameplay_allowed():
		return
	InputHelper.lock_cursor()


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


func _camera_authority() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("CameraAuthority")


func _event_bus() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("EventBus")


## Switches the in-store HUD between the first-person corner overlay layout
## and the legacy top-bar layout. The HUD is a CanvasLayer instantiated by
## `GameWorld._setup_ui` and lives under the world UI layer.
##
## §F-80 — Three silent returns covering the same headless-test seam: `tree
## == null` (autoload-out-of-tree, §F-44 family), `scene_root == null`
## (no current scene staged), and `hud == null or not has_method("set_fp_mode")`
## (HUD child not present or stub Control). Production `GameWorld._setup_ui`
## creates the HUD before any store is injected, so the FP-mode flip is a
## guaranteed dispatch at runtime; missing-HUD only happens when this body
## is free-instanced for unit testing without staging GameWorld.
func _set_hud_fp_mode(enabled: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var scene_root: Node = tree.current_scene
	if scene_root == null:
		return
	var hud: Node = scene_root.find_child("HUD", true, false)
	if hud == null or not hud.has_method("set_fp_mode"):
		return
	hud.call("set_fp_mode", enabled)


## Flips between the first-person body camera and the legacy orbit/top-down
## debug view. The orbit `PlayerController` is expected as a sibling of this
## body in the store scene root (see `_ORBIT_CONTROLLER_SIBLING_PATH`); stores
## without that node skip the toggle silently. Mouse capture, HUD layout, and
## the active camera flip together so the dev view is fully drivable on F1
## and reverses cleanly on a second press.
func _toggle_debug_view() -> void:
	if _debug_view:
		_exit_debug_view()
	else:
		_enter_debug_view()


## §F-81 — Both branches escalate via `push_warning` rather than silently
## ignoring the toggle. F1 is a dev-only convenience (gated by §F-73's
## `OS.is_debug_build()` check in `_unhandled_input`); the orbit controller
## is authored as a sibling in stores that opt into the dev view (currently
## `retro_games.tscn`). Stores without the sibling skip the toggle with a
## visible warning so a future scene that drops the orbit child surfaces the
## regression instead of silently degrading the dev experience.
func _enter_debug_view() -> void:
	var orbit: Node = get_node_or_null(_ORBIT_CONTROLLER_SIBLING_PATH)
	if orbit == null:
		push_warning(
			"StorePlayerBody: orbit PlayerController missing at %s; F1 toggle ignored"
			% String(_ORBIT_CONTROLLER_SIBLING_PATH)
		)
		return
	var orbit_cam: Camera3D = orbit.get_node_or_null("StoreCamera") as Camera3D
	if orbit_cam == null:
		push_warning(
			"StorePlayerBody: orbit StoreCamera missing; F1 toggle aborted"
		)
		return
	orbit.process_mode = Node.PROCESS_MODE_INHERIT
	if orbit.has_method("set_input_listening"):
		orbit.set_input_listening(true)
	var authority: Node = _camera_authority()
	if authority != null:
		authority.call("request_current", orbit_cam, CAMERA_SOURCE_DEBUG_OVERHEAD)
	InputHelper.unlock_cursor()
	_set_hud_fp_mode(false)
	_debug_view = true


func _exit_debug_view() -> void:
	var orbit: Node = get_node_or_null(_ORBIT_CONTROLLER_SIBLING_PATH)
	if orbit != null:
		orbit.process_mode = Node.PROCESS_MODE_DISABLED
	# Clear debug flag before restoring the FP surfaces so the focus listener
	# does not short-circuit the cursor lock against a stale `_debug_view`.
	_debug_view = false
	if _camera != null:
		var authority: Node = _camera_authority()
		if authority != null:
			authority.call("request_current", _camera, CAMERA_SOURCE)
	InputHelper.lock_cursor()
	_set_hud_fp_mode(true)
