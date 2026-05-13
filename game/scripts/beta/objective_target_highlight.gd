## Floating "next step" chip anchored above the active Day-1 chain
## interactable. Renders a small green "▶ E" panel projected from the
## target's world position to screen via `Camera3D.unproject_position`, so it
## works in first-person and orbit views without per-mesh material swaps or a
## custom outline shader.
##
## One chip is alive at a time. The active stage drives which 3D node the
## chip tracks; when the controller emits `EventBus.objective_changed` the
## chip re-resolves the target. The chip pulses on a loop to draw attention
## without strobing, and hides under `InputFocus.CTX_MODAL` so it does not
## fight with the day-summary / decision / morning-note panels.
##
## Owned by `BetaDayOneController._ensure_panels`. Not an autoload.
class_name BetaObjectiveTargetHighlight
extends CanvasLayer

## CanvasLayer ordering — below ObjectiveRail (40) and ModalDimOverlay (49)
## so the rail and dim layer both render above the chip.
const LAYER_INDEX: int = 35

## Visual spec from ISSUE-013: green echoing the `sign_backing_mat` neon
## emission so the chip reads as part of the store palette.
const CHIP_COLOR: Color = Color(0.3, 1.0, 0.5)

## Pulse contract: ~1.2s round trip, alpha 0.7 → 1.0 → 0.7, looping.
const PULSE_ALPHA_MIN: float = 0.7
const PULSE_ALPHA_MAX: float = 1.0
const PULSE_HALF_CYCLE_SECONDS: float = 0.6

## Pixel gap between the projected 3D position and the chip's bottom edge.
const CHIP_VERTICAL_OFFSET_PX: float = 24.0

const _CHIP_FONT_SIZE: int = 18
const _CHIP_BORDER_WIDTH: int = 2
const _CHIP_PADDING: int = 6
const _CHIP_CORNER_RADIUS: int = 6
const _CHIP_BG: Color = Color(0.05, 0.07, 0.05, 0.85)

## Stage → [scene-relative node path under the store root, world Y offset
## in metres above the parent origin]. The Y offset places the chip near
## the top of the visible geometry for each chain target so the projected
## screen position lands above the silhouette in both first-person and orbit
## views. Values derive from `retro_games.tscn` authored transforms:
## customer capsule top ~1.65 m, back-room stock box top ~0.9 m, restock
## shelf top ~1.15 m, day-end trigger sits on the counter at y=1.05 m.
const STAGE_TARGETS: Dictionary = {
	&"talk_to_customer": ["BetaDayOneCustomer", 1.9],
	&"back_room_inventory": ["BetaBackroomPickup", 1.3],
	&"stock_shelf": ["BetaRestockShelf", 1.7],
	&"end_day": ["BetaDayEndTrigger", 0.6],
}

var _chip: PanelContainer
var _chip_label: Label
var _target_node: Node3D = null
var _target_y_offset: float = 0.0
var _modal_dimmed: bool = false
var _pulse_tween: Tween = null


func _ready() -> void:
	add_to_group("beta_objective_target_highlight")
	layer = LAYER_INDEX
	_build_chip()
	_apply_visibility()
	_start_pulse()
	EventBus.objective_changed.connect(_on_objective_changed)
	InputFocus.context_changed.connect(_on_input_focus_changed)
	# Resolve initial stage if a controller is already alive (e.g. the
	# highlight is spawned mid-day by `_ensure_panels` after a save reload).
	_refresh_from_controller()


func _build_chip() -> void:
	_chip = PanelContainer.new()
	_chip.name = "Chip"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = _CHIP_BG
	style.border_color = CHIP_COLOR
	style.border_width_left = _CHIP_BORDER_WIDTH
	style.border_width_top = _CHIP_BORDER_WIDTH
	style.border_width_right = _CHIP_BORDER_WIDTH
	style.border_width_bottom = _CHIP_BORDER_WIDTH
	style.corner_radius_top_left = _CHIP_CORNER_RADIUS
	style.corner_radius_top_right = _CHIP_CORNER_RADIUS
	style.corner_radius_bottom_left = _CHIP_CORNER_RADIUS
	style.corner_radius_bottom_right = _CHIP_CORNER_RADIUS
	style.content_margin_left = _CHIP_PADDING
	style.content_margin_right = _CHIP_PADDING
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_chip.add_theme_stylebox_override("panel", style)
	add_child(_chip)

	_chip_label = Label.new()
	_chip_label.name = "Label"
	_chip_label.text = "▶ E"
	_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chip_label.add_theme_font_size_override("font_size", _CHIP_FONT_SIZE)
	_chip_label.add_theme_color_override("font_color", CHIP_COLOR)
	_chip.add_child(_chip_label)
	_chip.visible = false


## Restarts the looping alpha pulse. The tween is recreated rather than
## paused/resumed so a freed scene cannot leak a dangling tween reference.
func _start_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(
		_chip, "modulate:a", PULSE_ALPHA_MAX, PULSE_HALF_CYCLE_SECONDS
	)
	_pulse_tween.tween_property(
		_chip, "modulate:a", PULSE_ALPHA_MIN, PULSE_HALF_CYCLE_SECONDS
	)


func _process(_delta: float) -> void:
	if not _chip.visible:
		return
	if _target_node == null or not is_instance_valid(_target_node):
		_chip.visible = false
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var world_pos: Vector3 = (
		_target_node.global_position + Vector3(0.0, _target_y_offset, 0.0)
	)
	if camera.is_position_behind(world_pos):
		_chip.visible = false
		return
	var screen_pos: Vector2 = camera.unproject_position(world_pos)
	var chip_size: Vector2 = _chip.size
	_chip.position = Vector2(
		screen_pos.x - chip_size.x * 0.5,
		screen_pos.y - chip_size.y - CHIP_VERTICAL_OFFSET_PX
	)


func _on_objective_changed(_payload: Dictionary) -> void:
	_refresh_from_controller()


## Subscribes the chip's visibility to the modal stack so the day-summary,
## decision, and morning-note panels are not contested by the chip's pulse.
## Mirrors `interaction_prompt._on_input_focus_changed` (per ISSUE-004).
func _on_input_focus_changed(new_ctx: StringName, _old_ctx: StringName) -> void:
	_modal_dimmed = (new_ctx == InputFocus.CTX_MODAL)
	_apply_visibility()


func _refresh_from_controller() -> void:
	var controller: Node = _resolve_controller()
	if controller == null:
		_set_target(null, 0.0)
		return
	var stage: StringName = controller.current_stage()
	_apply_stage(stage, controller)


func _apply_stage(stage: StringName, controller: Node) -> void:
	var entry: Variant = STAGE_TARGETS.get(stage, null)
	if entry == null:
		_set_target(null, 0.0)
		return
	var arr: Array = entry as Array
	var node_path: String = str(arr[0])
	var y_offset: float = float(arr[1])
	var store_root: Node = controller.get_parent()
	if store_root == null:
		_set_target(null, 0.0)
		return
	var node: Node3D = store_root.get_node_or_null(node_path) as Node3D
	_set_target(node, y_offset)


func _set_target(node: Node3D, y_offset: float) -> void:
	_target_node = node
	_target_y_offset = y_offset
	_apply_visibility()


## Single chokepoint for chip visibility — every code path that toggles
## visibility flows through here. Visible iff a target exists AND no modal
## is active.
func _apply_visibility() -> void:
	if _chip == null:
		return
	var has_target: bool = (
		_target_node != null and is_instance_valid(_target_node)
	)
	_chip.visible = has_target and not _modal_dimmed


func _resolve_controller() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var node: Node = tree.get_first_node_in_group("beta_day_one_controller")
	if node == null:
		return null
	if not node.has_method("current_stage"):
		return null
	return node


## Test seam — returns the chip's PanelContainer so assertions can inspect
## visibility, style, and label without traversing the scene tree.
func get_chip() -> PanelContainer:
	return _chip


## Test seam — currently targeted 3D node, or null when no chain stage is
## active or the controller is not in the tree.
func get_target_node() -> Node3D:
	return _target_node


## Test seam — Y offset (metres) added to the target's world position when
## projecting to screen.
func get_target_y_offset() -> float:
	return _target_y_offset


## Test seam — true when the active pulse tween is running, so tests can
## confirm the looping alpha animation is wired without polling alpha
## changes frame-by-frame.
func is_pulse_active() -> bool:
	return _pulse_tween != null and _pulse_tween.is_valid()


## Test seam — drives the stage→target resolution path without going through
## EventBus, so fixtures that don't own a real BetaDayOneController can
## still verify the mapping.
func set_active_stage_for_test(stage: StringName, store_root: Node) -> void:
	var entry: Variant = STAGE_TARGETS.get(stage, null)
	if entry == null or store_root == null:
		_set_target(null, 0.0)
		return
	var arr: Array = entry as Array
	var node_path: String = str(arr[0])
	var y_offset: float = float(arr[1])
	var node: Node3D = store_root.get_node_or_null(node_path) as Node3D
	_set_target(node, y_offset)
