## Pause menu overlay with resume, save, settings, and return to menu.
class_name PauseMenu
extends CanvasLayer


const PANEL_NAME: String = "pause_menu"

signal save_pressed
signal settings_pressed
signal return_to_menu_pressed

var _is_open: bool = false

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: PanelContainer = $PanelRoot
@onready var _resume_button: Button = (
	$PanelRoot/Margin/VBox/ResumeButton
)
@onready var _save_button: Button = (
	$PanelRoot/Margin/VBox/SaveButton
)
@onready var _settings_button: Button = (
	$PanelRoot/Margin/VBox/SettingsButton
)
@onready var _menu_button: Button = (
	$PanelRoot/Margin/VBox/MenuButton
)
@onready var _confirm_dialog: ConfirmationDialog = (
	$ConfirmDialog
)


func _ready() -> void:
	_overlay.visible = false
	_panel.visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_confirm_dialog.confirmed.connect(_on_quit_confirmed)
	_confirm_dialog.canceled.connect(_on_quit_canceled)
	EventBus.panel_opened.connect(_on_panel_opened)


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
	GameManager.change_state(GameManager.GameState.PAUSED)
	_overlay.visible = true
	_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.panel_opened.emit(PANEL_NAME)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_overlay.visible = false
	_panel.visible = false
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _can_open() -> bool:
	return (
		GameManager.current_state == GameManager.GameState.PLAYING
	)


func _resume() -> void:
	close()
	GameManager.change_state(GameManager.GameState.PLAYING)


func _on_resume_pressed() -> void:
	_resume()


func _on_save_pressed() -> void:
	save_pressed.emit()


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func _on_menu_pressed() -> void:
	_confirm_dialog.popup_centered()


func _on_quit_confirmed() -> void:
	close()
	return_to_menu_pressed.emit()


func _on_quit_canceled() -> void:
	pass


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close()
