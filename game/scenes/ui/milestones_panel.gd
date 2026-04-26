## Panel displaying all milestones with progress and completion status.
class_name MilestonesPanel
extends CanvasLayer

const _MILESTONE_CARD_SCENE: PackedScene = preload(
	"res://game/scenes/ui/milestone_card.tscn"
)


const PANEL_NAME: String = "milestones"

var progression_system: ProgressionSystem
var _is_open: bool = false
var _focus_pushed: bool = false
var _anim_tween: Tween
var _rest_x: float = 0.0
var _backdrop: ColorRect

@onready var _panel: PanelContainer = $PanelRoot
@onready var _grid: VBoxContainer = (
	$PanelRoot/Margin/VBox/Scroll/Grid
)
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_close_button.pressed.connect(close)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.milestone_completed.connect(_on_milestone_completed)
	EventBus.toggle_milestones_panel.connect(_toggle)
	_setup_modal_backdrop()


func _exit_tree() -> void:
	if _focus_pushed:
		_pop_modal_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_M:
		_toggle()
		get_viewport().set_input_as_handled()
	elif key_event.is_action_pressed("ui_cancel") and _is_open:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_clamp_panel_to_viewport()
	_refresh_list()
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_open(_panel, _rest_x, false)
	EventBus.panel_opened.emit(PANEL_NAME)
	_push_modal_focus()
	_backdrop.visible = true


func close(immediate: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	PanelAnimator.kill_tween(_anim_tween)
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(
			_panel, _rest_x, false
		)
	_backdrop.visible = false
	_pop_modal_focus()
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _refresh_list() -> void:
	_clear_list()
	if not progression_system:
		return
	var milestones: Array[Dictionary] = (
		progression_system.get_milestones()
	)
	for milestone: Dictionary in milestones:
		_create_milestone_row(milestone)


func _clear_list() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()


func _create_milestone_row(milestone: Dictionary) -> void:
	var mid: String = milestone.get("id", "")
	var is_done: bool = progression_system.is_milestone_completed(mid)
	var progress: float = progression_system.get_milestone_progress(milestone)

	var card: MilestoneCard = _MILESTONE_CARD_SCENE.instantiate() as MilestoneCard
	_grid.add_child(card)
	card.configure({
		"milestone_id": mid,
		"name": milestone.get("display_name", mid),
		"description": milestone.get("description", ""),
		"reward": milestone.get("reward_type", ""),
		"is_completed": is_done,
		"progress": progress,
	})
	_grid.add_child(HSeparator.new())


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _push_modal_focus() -> void:
	if _focus_pushed:
		return
	InputFocus.push_context(InputFocus.CTX_MODAL)
	_focus_pushed = true


func _pop_modal_focus() -> void:
	if not _focus_pushed:
		return
	if InputFocus.current() != InputFocus.CTX_MODAL:
		push_error(
			(
				"MilestonesPanel: expected CTX_MODAL on top, got %s — "
				+ "leaving stack untouched to avoid corrupting sibling frame"
			)
			% String(InputFocus.current())
		)
		_focus_pushed = false
		return
	InputFocus.pop_context()
	_focus_pushed = false


## Test seam — clears _focus_pushed without calling pop_context.
func _reset_for_tests() -> void:
	_focus_pushed = false


func _clamp_panel_to_viewport() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.y < 64.0:
		return
	var max_h: float = vp_size.y - 32.0
	var current_h: float = _panel.offset_bottom - _panel.offset_top
	if current_h <= max_h:
		return
	var half_h: float = max_h / 2.0
	_panel.offset_top = -half_h
	_panel.offset_bottom = half_h


func _setup_modal_backdrop() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.5)
	_backdrop.mouse_filter = MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)
	move_child(_backdrop, 0)


func _on_backdrop_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		close()
		get_viewport().set_input_as_handled()


func _on_milestone_completed(
	_milestone_id: String,
	_milestone_name: String,
	_reward_description: String,
) -> void:
	if _is_open:
		_refresh_list()
