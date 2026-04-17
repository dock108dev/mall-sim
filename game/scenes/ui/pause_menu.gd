## Pause menu overlay with resume, save, settings, day summary, and quit.
class_name PauseMenu
extends CanvasLayer


const PANEL_NAME: String = "pause_menu"
const FADE_DURATION: float = 0.15
const SAVE_TOAST_DURATION: float = 2.0

signal return_to_menu_pressed
signal view_day_summary_requested

var completion_tracker: CompletionTracker
var tutorial_system: TutorialSystem
var save_manager: SaveManager
var settings_panel: SettingsPanel

var _is_open: bool = false
var _overlay_tween: Tween
var _panel_tween: Tween
var _open_panel_count: int = 0
var _day_summary_available: bool = false
var _save_toast_tween: Tween
var _pending_difficulty_tier: StringName = &""

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $PanelRoot
@onready var _resume_button: Button = (
	$PanelRoot/Margin/VBox/ResumeButton
)
@onready var _save_button: Button = (
	$PanelRoot/Margin/VBox/SaveButton
)
@onready var _save_toast: Label = (
	$PanelRoot/Margin/VBox/SaveToast
)
@onready var _settings_button: Button = (
	$PanelRoot/Margin/VBox/SettingsButton
)
@onready var _day_summary_button: Button = (
	$PanelRoot/Margin/VBox/DaySummaryButton
)
@onready var _menu_button: Button = (
	$PanelRoot/Margin/VBox/MenuButton
)
@onready var _completion_button: Button = (
	$PanelRoot/Margin/VBox/CompletionButton
)
@onready var _completion_label: Label = (
	$PanelRoot/Margin/VBox/CompletionLabel
)
@onready var _completion_panel: PanelContainer = (
	$CompletionPanel
)
@onready var _criteria_list: VBoxContainer = (
	$CompletionPanel/Margin/VBox/ScrollContainer/CriteriaList
)
@onready var _skip_tutorial_button: Button = (
	$PanelRoot/Margin/VBox/SkipTutorialButton
)
@onready var _difficulty_label: Label = (
	$PanelRoot/Margin/VBox/DifficultySection/DifficultyLabel
)
@onready var _difficulty_left: Button = (
	$PanelRoot/Margin/VBox/DifficultySection/DifficultyLeftButton
)
@onready var _difficulty_right: Button = (
	$PanelRoot/Margin/VBox/DifficultySection/DifficultyRightButton
)
@onready var _confirm_dialog: ConfirmationDialog = (
	$ConfirmDialog
)
@onready var _difficulty_confirm_dialog: ConfirmationDialog = (
	$DifficultyConfirmDialog
)


func _ready() -> void:
	_overlay.visible = false
	_panel.visible = false
	_save_toast.visible = false
	_day_summary_button.disabled = true
	_resume_button.pressed.connect(_on_resume_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_day_summary_button.pressed.connect(_on_day_summary_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_completion_button.pressed.connect(
		_on_completion_pressed
	)
	_skip_tutorial_button.pressed.connect(
		_on_skip_tutorial_pressed
	)
	_difficulty_left.pressed.connect(_on_difficulty_left_pressed)
	_difficulty_right.pressed.connect(_on_difficulty_right_pressed)
	_confirm_dialog.confirmed.connect(_on_quit_confirmed)
	_confirm_dialog.canceled.connect(_on_quit_canceled)
	_difficulty_confirm_dialog.confirmed.connect(
		_on_difficulty_downgrade_confirmed
	)
	_difficulty_confirm_dialog.canceled.connect(
		_on_difficulty_downgrade_canceled
	)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.panel_closed.connect(_on_panel_closed)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.day_started.connect(_on_day_started)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		if _is_open:
			_resume()
		elif _can_open():
			open()
		else:
			return
		get_viewport().set_input_as_handled()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	get_tree().paused = true
	GameManager.pause_game()
	_kill_tweens()
	_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_overlay.visible = true
	_overlay_tween = PanelAnimator.fade_in(_overlay, FADE_DURATION)
	_panel_tween = PanelAnimator.fade_in(_panel, FADE_DURATION)
	InputHelper.unlock_cursor()
	_save_toast.visible = false
	_update_completion_label()
	_update_difficulty_display()
	_day_summary_button.disabled = not _day_summary_available
	_skip_tutorial_button.visible = (
		tutorial_system != null and tutorial_system.tutorial_active
	)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_completion_panel.visible = false
	_kill_tweens()
	_overlay_tween = PanelAnimator.fade_out(
		_overlay, FADE_DURATION
	)
	_panel_tween = PanelAnimator.fade_out(_panel, FADE_DURATION)
	get_tree().paused = false


func is_open() -> bool:
	return _is_open


func _can_open() -> bool:
	if GameManager.current_state != GameManager.GameState.GAMEPLAY:
		return false
	if _open_panel_count > 0:
		return false
	return true


func _kill_tweens() -> void:
	PanelAnimator.kill_tween(_overlay_tween)
	PanelAnimator.kill_tween(_panel_tween)


func _resume() -> void:
	close()
	GameManager.resume_game()


func _on_resume_pressed() -> void:
	_resume()


func _on_save_pressed() -> void:
	if not save_manager:
		push_error("PauseMenu: save_manager not set")
		return
	var success: bool = save_manager.save_game(
		SaveManager.AUTO_SAVE_SLOT
	)
	if success:
		_show_save_toast()


func _show_save_toast() -> void:
	PanelAnimator.kill_tween(_save_toast_tween)
	_save_toast.visible = true
	_save_toast.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_save_toast_tween = create_tween()
	_save_toast_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_save_toast_tween.tween_interval(SAVE_TOAST_DURATION)
	_save_toast_tween.tween_property(
		_save_toast, "modulate",
		Color(1.0, 1.0, 1.0, 0.0), 0.3
	)
	_save_toast_tween.tween_callback(
		func() -> void:
			_save_toast.visible = false
	)


func _on_settings_pressed() -> void:
	if not settings_panel:
		push_error("PauseMenu: settings_panel not set")
		return
	settings_panel.open()


func _on_day_summary_pressed() -> void:
	if not _day_summary_available:
		return
	view_day_summary_requested.emit()


func _on_menu_pressed() -> void:
	_confirm_dialog.popup_centered()


func _on_quit_confirmed() -> void:
	if save_manager:
		save_manager.save_game(SaveManager.AUTO_SAVE_SLOT)
	get_tree().paused = false
	_is_open = false
	_completion_panel.visible = false
	_overlay.visible = false
	_panel.visible = false
	return_to_menu_pressed.emit()


func _on_quit_canceled() -> void:
	pass


func _on_skip_tutorial_pressed() -> void:
	if tutorial_system:
		tutorial_system.skip_tutorial()
	_skip_tutorial_button.visible = false


func _on_completion_pressed() -> void:
	_completion_panel.visible = not _completion_panel.visible
	if _completion_panel.visible:
		_populate_criteria_list()


func _on_panel_opened(_panel_name: String) -> void:
	_open_panel_count += 1


func _on_panel_closed(_panel_name: String) -> void:
	_open_panel_count = maxi(_open_panel_count - 1, 0)


func _on_day_ended(_day: int) -> void:
	_day_summary_available = true


func _on_day_started(_day: int) -> void:
	_day_summary_available = false


func _update_completion_label() -> void:
	if not completion_tracker:
		_completion_label.text = "Completion: --"
		return
	var pct: float = completion_tracker.get_completion_percentage()
	_completion_label.text = "Completion: %d%%" % int(pct)


func _populate_criteria_list() -> void:
	for child: Node in _criteria_list.get_children():
		child.queue_free()

	if not completion_tracker:
		return

	var criteria: Array[Dictionary] = (
		completion_tracker.get_completion_data()
	)
	for criterion: Dictionary in criteria:
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var check: Label = Label.new()
		var is_complete: bool = criterion.get("complete", false)
		check.text = "[x] " if is_complete else "[ ] "
		check.custom_minimum_size = Vector2(36, 0)
		row.add_child(check)

		var label: Label = Label.new()
		label.text = str(criterion.get("label", ""))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var progress: Label = Label.new()
		var current: float = float(criterion.get("current", 0))
		var required: float = float(criterion.get("required", 1))
		progress.text = "%d/%d" % [
			int(minf(current, required)), int(required)
		]
		progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		progress.custom_minimum_size = Vector2(60, 0)
		row.add_child(progress)

		_criteria_list.add_child(row)


func _update_difficulty_display() -> void:
	var current_id: StringName = DifficultySystemSingleton.get_current_tier_id()
	var display: String = DifficultySystemSingleton.get_display_name_for_tier(
		current_id
	)
	_difficulty_label.text = display
	var tier_ids: Array[StringName] = DifficultySystemSingleton.get_tier_ids()
	var idx: int = tier_ids.find(current_id)
	_difficulty_left.disabled = idx <= 0
	_difficulty_right.disabled = idx >= tier_ids.size() - 1


func _on_difficulty_left_pressed() -> void:
	_cycle_difficulty(-1)


func _on_difficulty_right_pressed() -> void:
	_cycle_difficulty(1)


func _cycle_difficulty(direction: int) -> void:
	var tier_ids: Array[StringName] = DifficultySystemSingleton.get_tier_ids()
	var current_id: StringName = DifficultySystemSingleton.get_current_tier_id()
	var idx: int = tier_ids.find(current_id)
	var new_idx: int = idx + direction
	if new_idx < 0 or new_idx >= tier_ids.size():
		return
	var new_tier_id: StringName = tier_ids[new_idx]
	if DifficultySystemSingleton.is_downgrade(new_tier_id):
		_pending_difficulty_tier = new_tier_id
		_difficulty_confirm_dialog.popup_centered()
		return
	_apply_difficulty(new_tier_id)


func _on_difficulty_downgrade_confirmed() -> void:
	if _pending_difficulty_tier.is_empty():
		return
	DifficultySystemSingleton.used_difficulty_downgrade = true
	_apply_difficulty(_pending_difficulty_tier)
	_pending_difficulty_tier = &""


func _on_difficulty_downgrade_canceled() -> void:
	_pending_difficulty_tier = &""


func _apply_difficulty(tier_id: StringName) -> void:
	DifficultySystemSingleton.apply_difficulty_change(tier_id)
	_update_difficulty_display()
