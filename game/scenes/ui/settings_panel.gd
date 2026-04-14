## Settings panel with audio, display, and controls tabs.
class_name SettingsPanel
extends CanvasLayer


const PANEL_NAME: String = "settings_panel"

signal closed
signal settings_saved

const _SNAPSHOT_KEYS: Array[String] = [
	"master_volume", "music_volume", "sfx_volume",
	"ambient_volume", "fullscreen", "vsync", "resolution",
	"ui_scale", "font_size", "colorblind_mode", "locale",
]

var _is_open: bool = false
var _anim_tween: Tween
var _snapshot: Dictionary = {}

## Action currently awaiting a keypress, empty when not listening.
var _listening_action: String = ""
## Tracks rebind buttons by action name for updating text.
var _rebind_buttons: Dictionary = {}
## Saved keybindings snapshot for cancel/restore.
var _saved_bindings: Dictionary = {}

@onready var _panel: PanelContainer = $PanelRoot
@onready var _tab_container: TabContainer = (
	$PanelRoot/Margin/VBox/TabContainer
)
@onready var _master_slider: HSlider = (
	$PanelRoot/Margin/VBox/TabContainer/Audio/VBox/MasterRow/Slider
)
@onready var _master_label: Label = (
	$PanelRoot/Margin/VBox/TabContainer/Audio/VBox/MasterRow/Value
)
@onready var _music_slider: HSlider = (
	$PanelRoot/Margin/VBox/TabContainer/Audio/VBox/MusicRow/Slider
)
@onready var _music_label: Label = (
	$PanelRoot/Margin/VBox/TabContainer/Audio/VBox/MusicRow/Value
)
@onready var _sfx_slider: HSlider = (
	$PanelRoot/Margin/VBox/TabContainer/Audio/VBox/SFXRow/Slider
)
@onready var _sfx_label: Label = (
	$PanelRoot/Margin/VBox/TabContainer/Audio/VBox/SFXRow/Value
)
@onready var _ambient_slider: HSlider = (
	$PanelRoot/Margin/VBox/TabContainer/Audio/VBox/AmbientRow/Slider
)
@onready var _ambient_label: Label = (
	$PanelRoot/Margin/VBox/TabContainer/Audio/VBox/AmbientRow/Value
)
@onready var _fullscreen_check: CheckButton = (
	$PanelRoot/Margin/VBox/TabContainer/Display/VBox/FullscreenRow/Check
)
@onready var _vsync_check: CheckButton = (
	$PanelRoot/Margin/VBox/TabContainer/Display/VBox/VSyncRow/Check
)
@onready var _resolution_option: OptionButton = (
	$PanelRoot/Margin/VBox/TabContainer/Display/VBox/ResolutionRow/Option
)
@onready var _ui_scale_slider: HSlider = (
	$PanelRoot/Margin/VBox/TabContainer/Display/VBox/UIScaleRow/Slider
)
@onready var _ui_scale_label: Label = (
	$PanelRoot/Margin/VBox/TabContainer/Display/VBox/UIScaleRow/Value
)
@onready var _font_size_option: OptionButton = (
	$PanelRoot/Margin/VBox/TabContainer/Display/VBox/FontSizeRow/Option
)
@onready var _colorblind_check: CheckButton = (
	$PanelRoot/Margin/VBox/TabContainer/Display/VBox/ColorblindRow/Check
)
@onready var _locale_option: OptionButton = (
	$PanelRoot/Margin/VBox/TabContainer/Display/VBox/LanguageRow/Option
)
@onready var _controls_list: VBoxContainer = (
	$PanelRoot/Margin/VBox/TabContainer/Controls/Outer/ScrollContainer/VBox
)
@onready var _controls_reset_button: Button = (
	$PanelRoot/Margin/VBox/TabContainer/Controls/Outer/ResetRow/ResetButton
)
@onready var _reset_defaults_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/ResetDefaultsButton
)
@onready var _conflict_dialog: ConfirmationDialog = $ConflictDialog
@onready var _apply_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/ApplyButton
)
@onready var _cancel_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/CancelButton
)
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)


func _ready() -> void:
	_panel.visible = false
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_ambient_slider.value_changed.connect(_on_ambient_changed)
	_apply_button.pressed.connect(_on_apply_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_close_button.pressed.connect(_on_cancel_pressed)
	_controls_reset_button.pressed.connect(_on_reset_keybindings_pressed)
	_reset_defaults_button.pressed.connect(_on_reset_defaults_pressed)
	_ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	_font_size_option.item_selected.connect(_on_font_size_selected)
	_colorblind_check.toggled.connect(_on_colorblind_toggled)
	_locale_option.item_selected.connect(_on_locale_selected)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.locale_changed.connect(_on_locale_changed)
	_populate_resolutions()
	_populate_font_sizes()
	_populate_locales()
	_populate_controls()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_snapshot_current()
	_load_from_settings()
	_refresh_controls()
	_tab_container.current_tab = 0
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_open(_panel)
	EventBus.panel_opened.emit(PANEL_NAME)


func close() -> void:
	if not _is_open:
		return
	_cancel_listen_mode()
	_is_open = false
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(_panel)
	_anim_tween.finished.connect(
		func() -> void:
			EventBus.panel_closed.emit(PANEL_NAME)
			closed.emit(),
		CONNECT_ONE_SHOT,
	)


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	# Listen mode: capture the keypress for rebinding
	if _listening_action != "":
		get_viewport().set_input_as_handled()
		if key_event.keycode == KEY_ESCAPE:
			_cancel_listen_mode()
			return
		_handle_rebind_input(key_event)
		return

	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func _snapshot_current() -> void:
	_snapshot.clear()
	for key: String in _SNAPSHOT_KEYS:
		_snapshot[key] = Settings.get(key)
	_snapshot_bindings()


func _snapshot_bindings() -> void:
	_saved_bindings.clear()
	for action: String in Settings.REBINDABLE_ACTIONS:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		if not events.is_empty():
			_saved_bindings[action] = events[0].duplicate()


func _restore_bindings() -> void:
	for action: String in Settings.REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		if _saved_bindings.has(action):
			var ev: InputEvent = _saved_bindings[action]
			InputMap.action_add_event(action, ev.duplicate())


func _load_from_settings() -> void:
	_master_slider.value = Settings.master_volume * 100.0
	_music_slider.value = Settings.music_volume * 100.0
	_sfx_slider.value = Settings.sfx_volume * 100.0
	_ambient_slider.value = Settings.ambient_volume * 100.0
	_fullscreen_check.button_pressed = Settings.fullscreen
	_vsync_check.button_pressed = Settings.vsync
	_select_resolution(Settings.resolution)
	_ui_scale_slider.value = Settings.ui_scale * 100.0
	_ui_scale_label.text = "%d%%" % int(Settings.ui_scale * 100.0)
	_font_size_option.selected = Settings.font_size
	_colorblind_check.button_pressed = Settings.colorblind_mode
	_select_locale(Settings.locale)


func _populate_resolutions() -> void:
	_resolution_option.clear()
	for res: Vector2i in Settings.COMMON_RESOLUTIONS:
		_resolution_option.add_item("%d x %d" % [res.x, res.y])


func _populate_font_sizes() -> void:
	_font_size_option.clear()
	for i: int in range(Settings.FONT_SIZE_LABEL_KEYS.size()):
		_font_size_option.add_item("%s (%dpx)" % [
			tr(Settings.FONT_SIZE_LABEL_KEYS[i]),
			Settings.FONT_SIZE_VALUES[i],
		])


func _populate_locales() -> void:
	_locale_option.clear()
	for entry: Dictionary in Settings.SUPPORTED_LOCALES:
		_locale_option.add_item(entry["name"])


func _select_locale(code: String) -> void:
	for i: int in Settings.SUPPORTED_LOCALES.size():
		if Settings.SUPPORTED_LOCALES[i]["code"] == code:
			_locale_option.selected = i
			return
	_locale_option.selected = 0


func _select_resolution(res: Vector2i) -> void:
	for i: int in Settings.COMMON_RESOLUTIONS.size():
		if Settings.COMMON_RESOLUTIONS[i] == res:
			_resolution_option.selected = i
			return
	_resolution_option.selected = 3


func _populate_controls() -> void:
	for child: Node in _controls_list.get_children():
		child.queue_free()
	_rebind_buttons.clear()

	for action: String in Settings.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_label := Label.new()
		name_label.text = _format_action_name(action)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size = Vector2(180, 0)
		row.add_child(name_label)

		var bind_button := Button.new()
		bind_button.text = _get_action_binding(action)
		bind_button.custom_minimum_size = Vector2(140, 0)
		bind_button.pressed.connect(
			_on_rebind_pressed.bind(action)
		)
		row.add_child(bind_button)
		_rebind_buttons[action] = bind_button

		_controls_list.add_child(row)


func _refresh_controls() -> void:
	for action: String in _rebind_buttons:
		var btn: Button = _rebind_buttons[action] as Button
		btn.text = _get_action_binding(action)


func _on_rebind_pressed(action: String) -> void:
	_cancel_listen_mode()
	_listening_action = action
	var btn: Button = _rebind_buttons[action] as Button
	btn.text = tr("SETTINGS_PRESS_KEY")


func _handle_rebind_input(key_event: InputEventKey) -> void:
	var action: String = _listening_action
	var new_event := InputEventKey.new()
	new_event.physical_keycode = key_event.physical_keycode

	# Check for duplicate binding
	var conflict: String = Settings.find_action_for_keycode(
		key_event.physical_keycode
	)
	if conflict != "" and conflict != action:
		_show_conflict_dialog(action, conflict, new_event)
		return

	_apply_rebind(action, new_event)


func _apply_rebind(action: String, new_event: InputEventKey) -> void:
	Settings.rebind_action(action, new_event)
	EventBus.keybind_changed.emit(action, new_event)
	_listening_action = ""
	_refresh_controls()


func _show_conflict_dialog(
	action: String,
	conflict: String,
	new_event: InputEventKey,
) -> void:
	var key_name: String = OS.get_keycode_string(
		DisplayServer.keyboard_get_keycode_from_physical(
			new_event.physical_keycode
		)
	)
	_conflict_dialog.dialog_text = (
		tr("SETTINGS_KEY_CONFLICT")
		% [
			key_name,
			_format_action_name(conflict),
			_format_action_name(conflict),
		]
	)

	# Disconnect any previous one-shot connections
	_disconnect_conflict_signals()

	_conflict_dialog.confirmed.connect(
		_on_conflict_confirmed.bind(action, conflict, new_event),
		CONNECT_ONE_SHOT,
	)
	_conflict_dialog.canceled.connect(
		_on_conflict_canceled, CONNECT_ONE_SHOT
	)
	_conflict_dialog.popup_centered()


func _disconnect_conflict_signals() -> void:
	for conn: Dictionary in _conflict_dialog.confirmed.get_connections():
		_conflict_dialog.confirmed.disconnect(conn["callable"])
	for conn: Dictionary in _conflict_dialog.canceled.get_connections():
		_conflict_dialog.canceled.disconnect(conn["callable"])


func _on_conflict_confirmed(
	action: String,
	conflict: String,
	new_event: InputEventKey,
) -> void:
	# Unbind the conflicting action
	InputMap.action_erase_events(conflict)
	_apply_rebind(action, new_event)


func _on_conflict_canceled() -> void:
	_cancel_listen_mode()


func _cancel_listen_mode() -> void:
	if _listening_action == "":
		return
	_listening_action = ""
	_refresh_controls()


func _on_reset_keybindings_pressed() -> void:
	_cancel_listen_mode()
	Settings.reset_keybindings_to_defaults()
	_refresh_controls()


func _on_reset_defaults_pressed() -> void:
	_cancel_listen_mode()
	Settings.reset_to_defaults()
	Settings.save_settings()
	_load_from_settings()
	_refresh_controls()
	_snapshot_current()


func _format_action_name(action: String) -> String:
	return action.replace("_", " ").capitalize()


func _get_action_binding(action: String) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return tr("SETTINGS_UNBOUND")
	var event: InputEvent = events[0]
	if event is InputEventKey:
		return (event as InputEventKey).as_text()
	if event is InputEventMouseButton:
		var btn: InputEventMouseButton = event as InputEventMouseButton
		match btn.button_index:
			MOUSE_BUTTON_LEFT:
				return tr("SETTINGS_LEFT_MOUSE")
			MOUSE_BUTTON_RIGHT:
				return tr("SETTINGS_RIGHT_MOUSE")
			MOUSE_BUTTON_MIDDLE:
				return tr("SETTINGS_MIDDLE_MOUSE")
			MOUSE_BUTTON_WHEEL_UP:
				return tr("SETTINGS_SCROLL_UP")
			MOUSE_BUTTON_WHEEL_DOWN:
				return tr("SETTINGS_SCROLL_DOWN")
			_:
				return tr("SETTINGS_MOUSE_BUTTON") % btn.button_index
	return event.as_text()


func _on_master_changed(value: float) -> void:
	_apply_volume_slider("master", _master_label, value)


func _on_music_changed(value: float) -> void:
	_apply_volume_slider("music", _music_label, value)


func _on_sfx_changed(value: float) -> void:
	_apply_volume_slider("sfx", _sfx_label, value)


func _on_ambient_changed(value: float) -> void:
	_apply_volume_slider("ambient", _ambient_label, value)


func _apply_volume_slider(
	channel: String, label: Label, value: float,
) -> void:
	label.text = "%d" % int(value)
	Settings.set(channel + "_volume", value / 100.0)
	Settings.apply_settings()


func _on_ui_scale_changed(value: float) -> void:
	_ui_scale_label.text = "%d%%" % int(value)
	Settings.ui_scale = value / 100.0
	Settings.apply_settings()


func _on_font_size_selected(index: int) -> void:
	Settings.font_size = index
	Settings.apply_settings()


func _on_colorblind_toggled(pressed: bool) -> void:
	Settings.colorblind_mode = pressed
	EventBus.colorblind_mode_changed.emit(pressed)


func _on_locale_selected(index: int) -> void:
	if index < 0 or index >= Settings.SUPPORTED_LOCALES.size():
		return
	Settings.locale = Settings.SUPPORTED_LOCALES[index]["code"]
	Settings.apply_settings()


func _on_apply_pressed() -> void:
	_cancel_listen_mode()
	_apply_ui_to_settings()
	Settings.apply_settings()
	Settings.save_settings()
	settings_saved.emit()
	close()


func _on_cancel_pressed() -> void:
	_cancel_listen_mode()
	_restore_snapshot()
	_restore_bindings()
	Settings.apply_settings()
	close()


func _apply_ui_to_settings() -> void:
	Settings.master_volume = _master_slider.value / 100.0
	Settings.music_volume = _music_slider.value / 100.0
	Settings.sfx_volume = _sfx_slider.value / 100.0
	Settings.ambient_volume = _ambient_slider.value / 100.0
	Settings.fullscreen = _fullscreen_check.button_pressed
	Settings.vsync = _vsync_check.button_pressed
	var idx: int = _resolution_option.selected
	if idx >= 0 and idx < Settings.COMMON_RESOLUTIONS.size():
		Settings.resolution = Settings.COMMON_RESOLUTIONS[idx]
	Settings.ui_scale = _ui_scale_slider.value / 100.0
	Settings.font_size = _font_size_option.selected
	Settings.colorblind_mode = _colorblind_check.button_pressed
	var locale_idx: int = _locale_option.selected
	if locale_idx >= 0 and locale_idx < Settings.SUPPORTED_LOCALES.size():
		Settings.locale = Settings.SUPPORTED_LOCALES[locale_idx]["code"]


func _restore_snapshot() -> void:
	for key: String in _SNAPSHOT_KEYS:
		if _snapshot.has(key):
			Settings.set(key, _snapshot[key])


func _on_locale_changed(_new_locale: String) -> void:
	_populate_font_sizes()
	_font_size_option.selected = Settings.font_size


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close()
