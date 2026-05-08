## Beta debug overlay — top-left panel showing scene, input focus, current
## modal, current objective, hovered interactable, and per-interactable
## state + distance. Required during beta stabilization (Phase 5 of the
## Shelf Life beta brief). Toggle with F2.
extends CanvasLayer

const REFRESH_INTERVAL: float = 0.15

var _label: Label
var _accum: float = 0.0
var _player: Node3D = null
var _interaction_ray: Node = null


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 8.0
	panel.offset_top = 8.0
	panel.offset_right = 460.0
	panel.offset_bottom = 540.0
	panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.text = "[BetaDebug] booting..."
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	margin.add_child(_label)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F2:
			visible = not visible


func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	if _accum < REFRESH_INTERVAL:
		return
	_accum = 0.0
	_label.text = _build_debug_text()


func _build_debug_text() -> String:
	var lines: PackedStringArray = []
	lines.append("[BetaDebug] (F2 hide)")
	lines.append("Scene: %s" % _current_scene_name())
	lines.append("Input Focus: %s" % _input_focus_text())
	lines.append("Modal: %s" % _modal_text())
	lines.append("Day: %d  Cash: $%d  Rep: %d  Trust: %d" % [
		BetaRunState.day,
		BetaRunState.cash,
		BetaRunState.reputation,
		BetaRunState.manager_trust,
	])
	lines.append("Hidden Thread: %d" % BetaRunState.hidden_thread_score)

	var controller: Node = _beta_controller()
	if controller != null:
		lines.append("Stage: %s" % str(controller.get("_stage")))
		var active_event: Variant = controller.get("_active_event")
		if active_event is Dictionary:
			var ev: Dictionary = active_event as Dictionary
			lines.append("Objective Event: %s" % str(ev.get("id", "—")))
		var anchor_name: String = _objective_anchor_for_stage(controller, controller.get("_stage"))
		lines.append("Objective Anchor: %s" % anchor_name)

	lines.append("Hovered: %s" % _hovered_text())
	lines.append("")
	lines.append("Interactables (enabled / dist):")
	_append_interactable_rows(lines)
	return "\n".join(lines)


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


func _objective_anchor_for_stage(controller: Node, stage: Variant) -> String:
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
	var name: String = (hovered as Node).name
	if hovered is Interactable:
		var i: Interactable = hovered as Interactable
		return "%s (id=%s)" % [name, i.resolve_interactable_id()]
	return name


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
