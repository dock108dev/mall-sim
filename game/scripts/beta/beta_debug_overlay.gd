## Beta debug overlay — compact telemetry panel for the Day-1 critical path.
##
## Three states cycled via F2: HIDDEN → COMPACT → EXPANDED → HIDDEN. Default
## is HIDDEN so the playable beta is not dominated by debug text. COMPACT
## shows a fixed 7-line summary (scene / input / modal / day-state /
## objective / hovered / distance) — that is enough to diagnose the
## prompt-alignment, focus-stack, and stage-gating issues we hit during
## beta polish without covering the viewport. EXPANDED appends the full
## per-interactable list (enabled state + distance) for deeper digging.
extends CanvasLayer

enum DisplayMode { HIDDEN, COMPACT, EXPANDED }

const REFRESH_INTERVAL: float = 0.15

const _MODE_LABEL := {
	DisplayMode.HIDDEN: "off",
	DisplayMode.COMPACT: "compact",
	DisplayMode.EXPANDED: "expanded",
}

const _COMPACT_PANEL_SIZE := Vector2(380.0, 220.0)
const _EXPANDED_PANEL_SIZE := Vector2(440.0, 540.0)

var _mode: DisplayMode = DisplayMode.HIDDEN
var _panel: PanelContainer
var _label: Label
var _accum: float = 0.0
var _player: Node3D = null
var _interaction_ray: Node = null


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.offset_left = 8.0
	_panel.offset_top = 8.0
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.text = "[BetaDebug] booting..."
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	margin.add_child(_label)

	_apply_mode()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F2:
		_cycle_mode()
	elif key_event.keycode == KEY_F8:
		_dump_state_to_console()


## Prints the FSM snapshot to stdout in a single block so a regression
## report can paste console output instead of guessing from the overlay.
## The snapshot itself comes from BetaDayOneController.get_state_snapshot
## so the overlay and the dump always agree on what state we think we're
## in.
func _dump_state_to_console() -> void:
	var controller: Node = _beta_controller()
	if controller == null or not controller.has_method("get_state_snapshot"):
		print("[BetaDebug] F8 dump — no beta controller in scene")
		return
	var snap: Dictionary = controller.call("get_state_snapshot")
	var ray: Node = _resolve_interaction_ray()
	var ray_dbg: Dictionary = {}
	if ray != null and ray.has_method("get_targeting_debug"):
		ray_dbg = ray.call("get_targeting_debug")
	print("---- [BetaDebug] F8 state dump ----")
	print("Day: %d  Time: %s  Stage: %s" % [
		int(snap.get("day", 0)),
		_format_time_minutes(float(snap.get("time_minutes", -1.0))),
		String(snap.get("stage", "—")),
	])
	print("Active objective: %s — %s" % [
		String(snap.get("active_objective_id", "—")),
		String(snap.get("active_objective_label", "—")),
	])
	var completed: Array[StringName] = snap.get("completed_objectives", []) as Array[StringName]
	print("Completed: %s" % str(completed))
	print("Can close day: %s | Reason: %s" % [
		bool(snap.get("can_close_day", false)),
		String(snap.get("close_day_reason", "")),
	])
	print("Focused: %s | Source: %s" % [
		String(ray_dbg.get("hovered_name", "")),
		String(ray_dbg.get("target_source", "none")),
	])
	print("InputFocus: %s | Modal: %s" % [_input_focus_text(), _modal_text()])
	print("---- end F8 dump ----")


func _format_time_minutes(minutes: float) -> String:
	if minutes < 0.0:
		return "—"
	var hour: int = int(minutes / 60.0) % 24
	var minute: int = int(minutes) % 60
	var period: String = "AM" if hour < 12 else "PM"
	var display_hour: int = hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%d:%02d %s" % [display_hour, minute, period]


func _process(delta: float) -> void:
	if _mode == DisplayMode.HIDDEN:
		return
	_accum += delta
	if _accum < REFRESH_INTERVAL:
		return
	_accum = 0.0
	_label.text = _build_debug_text()


## Cycles HIDDEN → COMPACT → EXPANDED → HIDDEN. Single key (F2) keeps muscle
## memory simple: tap once to peek, tap twice for full diagnostics, tap a
## third time to clear the screen for a clean screenshot.
func _cycle_mode() -> void:
	match _mode:
		DisplayMode.HIDDEN:
			_mode = DisplayMode.COMPACT
		DisplayMode.COMPACT:
			_mode = DisplayMode.EXPANDED
		DisplayMode.EXPANDED:
			_mode = DisplayMode.HIDDEN
	_apply_mode()


func _apply_mode() -> void:
	_panel.visible = _mode != DisplayMode.HIDDEN
	var size: Vector2 = (
		_EXPANDED_PANEL_SIZE if _mode == DisplayMode.EXPANDED else _COMPACT_PANEL_SIZE
	)
	_panel.offset_right = _panel.offset_left + size.x
	_panel.offset_bottom = _panel.offset_top + size.y
	# Force an immediate refresh so toggling does not show stale text from
	# the prior mode while waiting on the next tick.
	if _mode != DisplayMode.HIDDEN:
		_label.text = _build_debug_text()


func _build_debug_text() -> String:
	var lines: PackedStringArray = []
	lines.append("[BetaDebug] %s — F2 cycles" % _MODE_LABEL[_mode])
	lines.append("Scene: %s" % _current_scene_name())
	lines.append("Input: %s | Modal: %s" % [_input_focus_text(), _modal_text()])

	var controller: Node = _beta_controller()
	var stage_text: String = "—"
	var event_text: String = "—"
	if controller != null:
		stage_text = str(controller.get("_stage"))
		var active_event: Variant = controller.get("_active_event")
		if active_event is Dictionary:
			event_text = str((active_event as Dictionary).get("id", "—"))
	lines.append("Stage: %s | Event: %s" % [stage_text, event_text])

	# §F-J1 — close-day, time, and mouse-capture state. These three are the
	# spec's "are we in a sane state" checks: at any frame the user can read
	# the overlay and see whether the close-day key would do something,
	# whether the clock is moving as expected, and whether the cursor is
	# currently captured (a mismatch usually means a leaked modal frame).
	var close_text: String = _close_day_text(controller)
	var time_text: String = _time_text()
	var mouse_text: String = _mouse_capture_text()
	lines.append("Close: %s | Time: %s | Mouse: %s" % [
		close_text, time_text, mouse_text
	])

	var anchor_text: String = "—"
	if controller != null:
		anchor_text = _objective_anchor_for_stage(controller.get("_stage"))
	var hovered_text: String = _hovered_text()
	var nearest: Dictionary = _nearest_interactable_summary()
	var nearest_str: String = "—"
	if not nearest.is_empty():
		nearest_str = "%s (%s)" % [nearest["name"], nearest["dist"]]
	lines.append("Objective: %s" % anchor_text)
	lines.append("Hovered: %s" % hovered_text)
	lines.append("Nearest: %s" % nearest_str)

	# Interaction-targeting telemetry. Surfaces what the InteractionRay is
	# actually hitting / matching this frame so a "no prompt" report can be
	# diagnosed at a glance instead of from screenshots.
	_append_targeting_lines(lines)

	if _mode == DisplayMode.EXPANDED:
		lines.append("")
		lines.append("Day:%d Cash:$%d Rep:%d Trust:%d Hidden:%d" % [
			BetaRunState.day,
			BetaRunState.cash,
			BetaRunState.reputation,
			BetaRunState.manager_trust,
			BetaRunState.hidden_thread_score,
		])
		lines.append("")
		lines.append("Interactables (state / dist):")
		_append_interactable_rows(lines)
	return "\n".join(lines)


func _append_targeting_lines(lines: PackedStringArray) -> void:
	var ray: Node = _resolve_interaction_ray()
	if ray == null or not ray.has_method("get_targeting_debug"):
		return
	var d: Dictionary = ray.call("get_targeting_debug")
	var prompt_visible: bool = not String(d.get("hovered_name", "")).is_empty()
	var prompt_str: String = "yes" if prompt_visible else "no"
	var ray_collider: String = String(d.get("raycast_collider", ""))
	var ray_resolved: String = String(d.get("raycast_resolved", ""))
	var prox_target: String = String(d.get("proximity_target", ""))
	var prox_distance: float = float(d.get("proximity_distance", INF))
	var prox_facing: float = float(d.get("proximity_facing_dot", 0.0))
	var source: String = String(d.get("target_source", "none"))
	lines.append("RayHit: %s → %s" % [
		ray_collider if not ray_collider.is_empty() else "—",
		ray_resolved if not ray_resolved.is_empty() else "—",
	])
	if prox_distance == INF:
		lines.append("Prox: — | facing=%.2f" % prox_facing)
	else:
		lines.append("Prox: %s @ %.2fm | facing=%.2f" % [
			prox_target if not prox_target.is_empty() else "—",
			prox_distance,
			prox_facing,
		])
	lines.append("Prompt: %s | source=%s" % [prompt_str, source])


func _current_scene_name() -> String:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return "—"
	return scene.name


func _input_focus_text() -> String:
	if InputFocus == null:
		return "—"
	var ctx: StringName = InputFocus.current()
	if ctx == &"":
		return "(empty)"
	return String(ctx)


## §F-J1 — "yes" / "no — <reason>" so a screenshot of the overlay surfaces
## both the bit and why-it's-false at a glance.
func _close_day_text(controller: Node) -> String:
	if controller == null:
		return "—"
	if not controller.has_method("can_interact_day_end"):
		return "—"
	if bool(controller.call("can_interact_day_end")):
		return "yes"
	var reason: String = ""
	if controller.has_method("close_day_disabled_reason"):
		reason = String(controller.call("close_day_disabled_reason"))
	if reason.is_empty():
		return "no"
	return "no — %s" % reason


func _time_text() -> String:
	if GameManager == null:
		return "—"
	var time_sys: TimeSystem = GameManager.get_time_system()
	if time_sys == null:
		return "—"
	return _format_time_minutes(float(time_sys.game_time_minutes))


func _mouse_capture_text() -> String:
	match Input.mouse_mode:
		Input.MOUSE_MODE_CAPTURED:
			return "captured"
		Input.MOUSE_MODE_VISIBLE:
			return "visible"
		Input.MOUSE_MODE_HIDDEN:
			return "hidden"
		Input.MOUSE_MODE_CONFINED:
			return "confined"
		Input.MOUSE_MODE_CONFINED_HIDDEN:
			return "confined-hidden"
		_:
			return "?"


func _modal_text() -> String:
	match BetaRunState.input_mode:
		BetaRunState.INPUT_MODE_GAMEPLAY:
			return "none"
		BetaRunState.INPUT_MODE_DECISION_CARD:
			return "decision_card"
		BetaRunState.INPUT_MODE_PAUSE_MENU:
			return "pause_menu"
		BetaRunState.INPUT_MODE_DAY_SUMMARY:
			return "day_summary"
		_:
			return "unknown(%d)" % BetaRunState.input_mode


func _beta_controller() -> Node:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("beta_day_one_controller")
	if nodes.is_empty():
		return null
	return nodes[0]


func _objective_anchor_for_stage(stage: Variant) -> String:
	var stage_name: String = str(stage)
	match stage_name:
		"talk_to_customer":
			return "BetaDayOneCustomer"
		"pickup_stock":
			return "BetaBackroomPickup"
		"place_stock":
			return "BetaRestockShelf"
		"end_day":
			return "BetaDayEndTrigger"
		_:
			return "—"


func _hovered_text() -> String:
	var ray: Node = _resolve_interaction_ray()
	if ray == null:
		return "—"
	var hovered: Variant = ray.get("_hovered_target")
	if hovered == null or not is_instance_valid(hovered):
		return "—"
	var node: Node = hovered as Node
	if hovered is Interactable:
		return "%s (id=%s)" % [node.name, (hovered as Interactable).resolve_interactable_id()]
	return node.name


## Returns {"name": String, "dist": String} for the nearest enabled
## Interactable to the player. Empty Dictionary means no candidate. Used by
## both compact and expanded views so the player can always see "where the
## next E-press will land" without scanning the full list.
func _nearest_interactable_summary() -> Dictionary:
	var player_pos: Vector3 = _resolve_player_position()
	if player_pos == Vector3.INF:
		return {}
	var best: Interactable = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if not (node is Interactable):
			continue
		var i: Interactable = node as Interactable
		if not i.enabled:
			continue
		var parent_node: Node = i.get_parent()
		if not (parent_node is Node3D):
			continue
		var d: float = (parent_node as Node3D).global_position.distance_to(player_pos)
		if d < best_dist:
			best_dist = d
			best = i
	if best == null:
		return {}
	var parent: Node = best.get_parent()
	var label: String = parent.name if parent != null else best.name
	return {"name": label, "dist": "%.1fm" % best_dist}


func _append_interactable_rows(lines: PackedStringArray) -> void:
	var player_pos: Vector3 = _resolve_player_position()
	var rows: Array[String] = []
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if not (node is Interactable):
			continue
		var i: Interactable = node as Interactable
		var parent_node: Node = i.get_parent()
		var label: String = ""
		if parent_node != null:
			label = parent_node.name
		else:
			label = i.name
		var enabled_str: String = "READY" if i.enabled else "OFF"
		var dist_str: String = "—"
		if parent_node is Node3D and player_pos != Vector3.INF:
			var d: float = (parent_node as Node3D).global_position.distance_to(player_pos)
			dist_str = "%.1fm" % d
		rows.append("- %s [%s] %s" % [label, enabled_str, dist_str])
	rows.sort()
	for row: String in rows:
		lines.append(row)


func _resolve_interaction_ray() -> Node:
	if _interaction_ray != null and is_instance_valid(_interaction_ray):
		return _interaction_ray
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	_interaction_ray = scene.find_child("InteractionRay", true, false)
	return _interaction_ray


func _resolve_player_position() -> Vector3:
	if _player != null and is_instance_valid(_player):
		return _player.global_position
	var scene: Node = get_tree().current_scene
	if scene == null:
		return Vector3.INF
	var player: Node = scene.find_child("PlayerController", true, false)
	if player is Node3D:
		_player = player as Node3D
		return _player.global_position
	return Vector3.INF
