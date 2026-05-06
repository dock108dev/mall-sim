## Casts a ray from the active camera through the screen center to detect
## interactables.
##
## `intersect_ray` returns the closest collider along the ray, so the screen
## center is inherently nearest-wins even when multiple interactable Area3D
## volumes overlap behind the reticle. The cast uses `viewport.size / 2`
## explicitly so first-person play with a locked cursor and screen-anchored
## modes (drawer focus etc.) all aim at the same on-screen point. Walking
## near interactables off-axis does not produce hover events: there is no
## `body_entered` proximity path — focus is reticle-driven only.
extends Node

const INTERACTION_RAY_GROUP: StringName = &"interaction_ray"

## Maximum ray distance in meters. Sized for first-person store gameplay so
## the player must walk up to a fixture (counter-depth ~1m, aisle reach ~2m)
## to focus it; preserves the gaze-based feel inside the 16x20m store volume.
@export var ray_distance: float = 2.5
## Collision mask for interactable detection. Scans the dedicated
## `interactable_triggers` layer (named layer 5 in `project.godot` -> bit
## value 16) only, so walls and store fixtures never occlude an interactable
## that sits behind them in depth.
@export_flags_3d_physics var interaction_mask: int = 16

var _camera: Camera3D = null
var _hovered_target: Interactable = null
var _hovered_action_label: String = ""
## Tracks whether the currently hovered target is actionable. Mirrors
## `target.can_interact()` at the moment focus was applied so the E-press
## dispatch in `_unhandled_input` can short-circuit without re-querying the
## subclass override (and so unit tests can observe the cached value).
var _hovered_can_interact: bool = false
var _inventory_system: InventorySystem = null
var _open_panel_count: int = 0
## Debug-only overlay label. Created in `_ready` only when
## `OS.is_debug_build()` is true; left null in release export builds so the
## CanvasLayer/Label nodes are never instantiated.
var _debug_overlay: Label = null


func _ready() -> void:
	set_process(false)
	add_to_group(INTERACTION_RAY_GROUP)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.panel_closed.connect(_on_panel_closed)
	EventBus.active_camera_changed.connect(_on_active_camera_changed)
	if CameraManager.active_camera:
		_apply_camera(CameraManager.active_camera)
	if OS.is_debug_build():
		_setup_debug_overlay()


## Sets the InventorySystem reference for shelf item tooltip lookups.
func set_inventory_system(inv: InventorySystem) -> void:
	_inventory_system = inv


func _process(_delta: float) -> void:
	if _hovered_target and not is_instance_valid(_hovered_target):
		_set_hovered_target(null)
	if _open_panel_count > 0:
		if _hovered_target:
			_set_hovered_target(null)
	else:
		_update_raycast()
	if OS.is_debug_build() and _debug_overlay != null:
		_update_debug_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if _open_panel_count > 0:
		return
	if event.is_action_pressed("interact"):
		if _is_keyboard_captured_by_ui():
			return
		if _hovered_target and _hovered_can_interact:
			_log_interaction_dispatch(_hovered_target)
			_hovered_target.interact()
			EventBus.player_interacted.emit(_hovered_target)
		return

	if not event is InputEventMouseButton:
		return
	if _is_pointer_over_blocking_ui():
		return
	var mb_event := event as InputEventMouseButton
	if not mb_event.pressed:
		return
	if mb_event.button_index == MOUSE_BUTTON_LEFT:
		if _hovered_target and _hovered_can_interact:
			_log_interaction_dispatch(_hovered_target)
			_hovered_target.interact()
			EventBus.player_interacted.emit(_hovered_target)
	elif mb_event.button_index == MOUSE_BUTTON_RIGHT:
		if _hovered_target:
			EventBus.interactable_right_clicked.emit(
				_hovered_target, _hovered_target.interaction_type
			)


## Returns the currently hovered interactable, or null.
func get_hovered_target() -> Interactable:
	return _hovered_target


## Returns the action label of the currently hovered target, or "" when none.
func get_hovered_action_label() -> String:
	return _hovered_action_label if _hovered_target else ""


## Returns the distance from the active camera to the hovered target's origin,
## or -1.0 when no target is hovered or the camera is unavailable.
func get_hovered_camera_distance() -> float:
	if not is_instance_valid(_camera) or not is_instance_valid(_hovered_target):
		return -1.0
	return _camera.global_position.distance_to(_hovered_target.global_position)


## Returns the number of currently-open modal panels tracked from the
## EventBus.panel_opened/panel_closed pair. Exposed so debug overlays, audit
## tooling, and tests can read modal-lock depth without poking the private
## `_open_panel_count` field directly.
func get_open_panel_count() -> int:
	return _open_panel_count


func _on_active_camera_changed(camera: Camera3D) -> void:
	_apply_camera(camera)


func _apply_camera(camera: Camera3D) -> void:
	if _hovered_target:
		_set_hovered_target(null)
	_camera = camera if is_instance_valid(camera) else null
	set_process(_camera != null)


func _update_raycast() -> void:
	if not is_instance_valid(_camera):
		_camera = null
		set_process(false)
		return

	var viewport: Viewport = get_viewport()
	if not viewport:
		return
	var world: World3D = viewport.find_world_3d()
	if not world:
		return

	# Always cast from screen center so first-person play with a locked
	# cursor (where get_mouse_position() returns the locked center anyway)
	# and any cursor-visible context produce identical hover hits.
	var screen_center: Vector2 = Vector2(viewport.size) * 0.5
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_center)
	var ray_dir: Vector3 = _camera.project_ray_normal(screen_center)
	var ray_end: Vector3 = ray_origin + ray_dir * ray_distance

	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	var query: PhysicsRayQueryParameters3D = (
		PhysicsRayQueryParameters3D.create(
			ray_origin, ray_end, interaction_mask
		)
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result: Dictionary = space_state.intersect_ray(query)

	var new_target: Interactable = null
	if result.size() > 0:
		var collider: Node = result["collider"]
		var candidate: Interactable = _resolve_interactable(collider)
		if candidate and candidate.enabled:
			new_target = candidate

	if new_target != _hovered_target:
		_set_hovered_target(new_target)
	elif _hovered_target != null:
		_poll_hovered_can_interact()


## Re-queries `can_interact()` on the still-hovered target and re-emits the
## focus event when the result has changed since hover-entry. Without this
## poll, `_hovered_can_interact` and the HUD prompt remain stuck on the
## hover-entry snapshot — so a shelf that fills mid-hover, a register that
## acquires a customer mid-hover, or a counter that disables mid-hover would
## show a "Press E" badge that silently no-ops on press. `interact()` has
## an internal `can_interact()` re-check that already prevents phantom
## downstream signals, but the visual badge must match reality.
##
## Subclasses are expected to keep `can_interact()` cheap (pure state read,
## no allocations) since it now runs every frame while a target is hovered.
func _poll_hovered_can_interact() -> void:
	if not is_instance_valid(_hovered_target):
		return
	var current_can: bool = _hovered_target.can_interact()
	if current_can == _hovered_can_interact:
		return
	_hovered_can_interact = current_can
	var action_label: String
	if current_can:
		action_label = _build_action_label(_hovered_target)
		EventBus.interactable_focused.emit(action_label)
	else:
		action_label = _hovered_target.get_disabled_reason()
		EventBus.interactable_focused_disabled.emit(action_label)
	_hovered_action_label = action_label


func _set_hovered_target(new_target: Interactable) -> void:
	if _hovered_target == new_target:
		return

	if _hovered_target and is_instance_valid(_hovered_target):
		if _hovered_target.tree_exiting.is_connected(
			_on_hovered_target_tree_exiting
		):
			_hovered_target.tree_exiting.disconnect(
				_on_hovered_target_tree_exiting
			)
		_hovered_target.unhighlight()
		_hovered_target.unfocused.emit()

	_hovered_target = new_target if is_instance_valid(new_target) else null

	if _hovered_target:
		if not _hovered_target.tree_exiting.is_connected(
			_on_hovered_target_tree_exiting
		):
			_hovered_target.tree_exiting.connect(
				_on_hovered_target_tree_exiting
			)
		_hovered_target.highlight()
		_hovered_target.focused.emit()
		# Branch on the runtime `can_interact()` gate so the HUD layer can
		# render an active "Press E" prompt vs. a muted disabled-reason
		# info label without each consumer re-querying the subclass. The
		# cached `_hovered_can_interact` flag is also what the E-press
		# dispatch in `_unhandled_input` reads to short-circuit phantom
		# `interact()` calls between hover frames.
		_hovered_can_interact = _hovered_target.can_interact()
		var action_label: String
		if _hovered_can_interact:
			action_label = _build_action_label(_hovered_target)
			EventBus.interactable_focused.emit(action_label)
		else:
			action_label = _hovered_target.get_disabled_reason()
			EventBus.interactable_focused_disabled.emit(action_label)
		_hovered_action_label = action_label
		_log_interaction_focus(_hovered_target)
		# ISSUE-003: scoped hover event + pointing-hand cursor. The hover
		# transition runs every physics frame, so the cursor/label update
		# well inside the 100ms budget.
		EventBus.interactable_hovered.emit(
			_hovered_target.resolve_interactable_id(),
			_hovered_target.store_id,
			action_label
		)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		_emit_tooltip_for_target(_hovered_target)
	else:
		_hovered_action_label = ""
		_hovered_can_interact = false
		EventBus.interactable_unfocused.emit()
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		EventBus.item_tooltip_hidden.emit()


func _resolve_interactable(collider: Node) -> Interactable:
	return Interactable.from_collider(collider)


func _on_hovered_target_tree_exiting() -> void:
	var exiting_target: Interactable = _hovered_target
	if exiting_target and is_instance_valid(exiting_target):
		if exiting_target.tree_exiting.is_connected(
			_on_hovered_target_tree_exiting
		):
			exiting_target.tree_exiting.disconnect(
				_on_hovered_target_tree_exiting
			)
		exiting_target.unfocused.emit()
	_hovered_target = null
	_hovered_action_label = ""
	_hovered_can_interact = false
	EventBus.interactable_unfocused.emit()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	EventBus.item_tooltip_hidden.emit()


## Builds the InteractionPrompt label text for the focused target. Both-empty
## (verb and display_name) is treated as a content-authoring contract violation
## upstream — Interactable.display_name defaults to "Item" and prompt_text
## auto-resolves from PROMPT_VERBS in `_ready`, so reaching this branch
## requires the scene author to deliberately blank both. We return "" here
## rather than push_warning because this function fires every frame the cursor
## enters a new interactable; a per-hover warning would flood logs while
## adding no signal beyond the visibly-empty prompt panel. See
## docs/audits/error-handling-report.md §F-53.
func _build_action_label(target: Interactable) -> String:
	var verb: String = target.prompt_text.strip_edges()
	var target_name: String = target.display_name.strip_edges()
	if verb.is_empty() and target_name.is_empty():
		return ""
	if target_name.is_empty():
		return "Press E to %s" % verb.to_lower()
	if verb.is_empty():
		return target_name
	return "%s — Press E to %s" % [target_name, verb.to_lower()]


func _emit_tooltip_for_target(target: Interactable) -> void:
	if not target is ShelfSlot or not _inventory_system:
		EventBus.item_tooltip_hidden.emit()
		return
	var slot := target as ShelfSlot
	if not slot.is_occupied():
		EventBus.item_tooltip_hidden.emit()
		return
	var item: ItemInstance = _inventory_system.get_item(
		slot.get_item_instance_id()
	)
	if item:
		EventBus.item_tooltip_requested.emit(item)
	else:
		EventBus.item_tooltip_hidden.emit()


func _on_panel_opened(_panel_name: String) -> void:
	_open_panel_count += 1


func _on_panel_closed(_panel_name: String) -> void:
	_open_panel_count = maxi(_open_panel_count - 1, 0)


func _is_keyboard_captured_by_ui() -> bool:
	var viewport: Viewport = get_viewport()
	if not viewport:
		return false
	return viewport.gui_get_focus_owner() != null


func _is_pointer_over_blocking_ui() -> bool:
	var viewport: Viewport = get_viewport()
	if not viewport:
		return false
	var hovered: Control = viewport.gui_get_hovered_control()
	if hovered == null:
		return false
	var node: Control = hovered
	while node != null:
		if node.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true
		node = node.get_parent_control()
	return false


## §F-108 — Debug-build interaction telemetry. Mirrors the dead-prompt audit
## in docs/audits: every prompt that fires and every interaction the player
## dispatches gets a "[Interaction] <name>: <verb>" line so scene-edit
## regressions (a dead E-prompt, a misnamed verb, a stale display_name) show
## up in `tests/test_run.log` and dev consoles without needing to attach a
## debugger. `OS.is_debug_build()` short-circuits before any string formatting
## so release builds carry zero cost. Same gate family as §F-106 customer FSM
## trace and §F-58 retro_games F3 toggle.
func _log_interaction_focus(target: Interactable) -> void:
	if not OS.is_debug_build():
		return
	var verb: String = target.prompt_text.strip_edges()
	var display: String = target.display_name.strip_edges()
	print("[Interaction] %s: %s" % [display, verb])


func _log_interaction_dispatch(target: Interactable) -> void:
	if not OS.is_debug_build():
		return
	var verb: String = target.action_verb.strip_edges()
	var display: String = target.display_name.strip_edges()
	print("[Interaction] %s: %s (dispatched)" % [display, verb])


## Builds the top-left CanvasLayer + Label used by the debug interaction
## overlay. Only called from `_ready` when `OS.is_debug_build()` is true, so
## release export templates never allocate the node tree and pay no per-frame
## cost. Layer 128 keeps it above gameplay HUD without interfering with
## existing UI layers.
func _setup_debug_overlay() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 128
	canvas.name = "DebugInteractionOverlay"
	add_child(canvas)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(8, 8)
	canvas.add_child(panel)
	_debug_overlay = Label.new()
	_debug_overlay.add_theme_font_size_override("font_size", 13)
	var monospace: SystemFont = SystemFont.new()
	monospace.font_names = PackedStringArray(["monospace"])
	_debug_overlay.add_theme_font_override("font", monospace)
	panel.add_child(_debug_overlay)


func _update_debug_overlay() -> void:
	var focus_ctx: StringName = InputFocus.current()
	var focus_text: String = String(focus_ctx) if focus_ctx != &"" else "—"
	var focus_depth: int = InputFocus.depth()
	if not is_instance_valid(_hovered_target):
		_debug_overlay.text = (
			"[no interactable hovered]\n"
			+ "Panels:   %d\n"
			+ "Focus:    %s (depth %d)"
		) % [_open_panel_count, focus_text, focus_depth]
		return
	var t: Interactable = _hovered_target
	var reason: String = "—"
	if not _hovered_can_interact:
		var disabled_reason: String = t.get_disabled_reason()
		if not disabled_reason.is_empty():
			reason = disabled_reason
	_debug_overlay.text = (
		"Name:     %s\n"
		+ "Path:     %s\n"
		+ "Layer:    %d\n"
		+ "Mask:     %d\n"
		+ "Enabled:  %s\n"
		+ "Reason:   %s\n"
		+ "Panels:   %d\n"
		+ "Focus:    %s (depth %d)"
	) % [
		t.display_name,
		str(t.get_path()),
		t.collision_layer,
		t.collision_mask,
		str(t.enabled),
		reason,
		_open_panel_count,
		focus_text,
		focus_depth,
	]
