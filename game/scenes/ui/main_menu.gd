## Main menu — entry point with new game, continue, load, settings, and quit.
extends Control


const SAVE_DIR := "user://"
const MAX_SAVE_PREVIEW_BYTES: int = SaveManager.MAX_SAVE_FILE_BYTES
const SLOT_PATHS: Dictionary = {
	0: "user://save_slot_0.json",
	1: "user://save_slot_1.json",
	2: "user://save_slot_2.json",
	3: "user://save_slot_3.json",
}
const _SETTINGS_PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/settings_panel.tscn"
)
const _LOAD_BUTTON_DEFAULT_TEXT: String = "Load Game"
const _LOAD_BUTTON_NO_SAVE_TEXT: String = "No Save Found"
const _LOAD_BUTTON_DISABLED_MODULATE: Color = Color(0.6, 0.6, 0.6, 1.0)

var _load_panel_visible: bool = false
var _settings_panel: SettingsPanel = null
var _any_saves_exist: bool = false
var _input_focus_pushed: bool = false

@onready var _continue_button: Button = $VBox/ContinueButton
@onready var _load_button: Button = $VBox/LoadButton
@onready var _load_container: PanelContainer = $LoadPanel
@onready var _slot_list: VBoxContainer = (
	$LoadPanel/Margin/VBox/SlotContainer
)
@onready var _load_close_button: Button = (
	$LoadPanel/Margin/VBox/Header/CloseButton
)
@onready var _version_label: Label = $VersionLabel
@onready var _new_game_dialog: ConfirmationDialog = (
	$NewGameConfirmDialog
)
@onready var _quit_dialog: ConfirmationDialog = $QuitConfirmDialog


func _ready() -> void:
	Settings.load_settings()
	GameManager.change_state(GameManager.State.MAIN_MENU)
	_push_main_menu_input_focus()
	_load_container.visible = false
	_load_close_button.pressed.connect(_close_load_panel)

	_version_label.text = "v%s" % ProjectSettings.get_setting(
		"application/config/version", "0.1.0"
	)

	_new_game_dialog.confirmed.connect(_on_new_game_confirmed)
	_quit_dialog.confirmed.connect(_on_quit_confirmed)

	_any_saves_exist = _has_any_saves()
	_refresh_load_button_state()

	var most_recent: int = _find_most_recent_slot()
	_continue_button.visible = most_recent >= 0
	if most_recent >= 0:
		_continue_button.pressed.connect(
			_on_continue_pressed.bind(most_recent)
		)

	if AuditLog != null:
		AuditLog.pass_check(&"main_menu_ready", "from=main_menu.gd")


func _exit_tree() -> void:
	_pop_main_menu_input_focus()


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED:
		return
	if not is_inside_tree() or not is_visible_in_tree():
		return
	_refresh_load_button_state()


func _push_main_menu_input_focus() -> void:
	if InputFocus == null:
		return
	InputFocus.push_context(InputFocus.CTX_MAIN_MENU)
	_input_focus_pushed = true


func _pop_main_menu_input_focus() -> void:
	if not _input_focus_pushed:
		return
	if InputFocus == null:
		_input_focus_pushed = false
		return
	if InputFocus.current() == InputFocus.CTX_MAIN_MENU:
		InputFocus.pop_context()
	_input_focus_pushed = false


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not (event as InputEventKey).pressed:
		return
	if event.is_action_pressed("ui_cancel") and _load_panel_visible:
		_close_load_panel()
		get_viewport().set_input_as_handled()


func _on_play_pressed() -> void:
	if _any_saves_exist:
		_new_game_dialog.popup_centered()
		return
	_start_new_game()


func _on_new_game_confirmed() -> void:
	_start_new_game()


func _start_new_game() -> void:
	_start_game_session(-1)


func _on_load_pressed() -> void:
	# Belt for the disabled-button contract: refresh the affordance and bail
	# if the save vanished between _ready and the click. See EH-10.
	if not _slot_zero_save_exists():
		_refresh_load_button_state()
		return
	if _load_panel_visible:
		_close_load_panel()
		return
	_refresh_load_slots()
	_load_container.visible = true
	_load_panel_visible = true


func _on_settings_pressed() -> void:
	if _load_panel_visible:
		_close_load_panel()
	if _settings_panel == null:
		_settings_panel = _SETTINGS_PANEL_SCENE.instantiate() as SettingsPanel
		add_child(_settings_panel)
	_settings_panel.open()


func _on_quit_pressed() -> void:
	_quit_dialog.popup_centered()


func _on_quit_confirmed() -> void:
	GameManager.quit_game()


func _on_continue_pressed(slot: int) -> void:
	_load_slot(slot)


func _close_load_panel() -> void:
	_load_container.visible = false
	_load_panel_visible = false


func _refresh_load_slots() -> void:
	for child: Node in _slot_list.get_children():
		child.queue_free()

	for slot: int in [0, 1, 2, 3]:
		_create_load_slot_row(slot)


func _create_load_slot_row(slot: int) -> void:
	var path: String = SLOT_PATHS.get(slot, "")
	var exists: bool = FileAccess.file_exists(path)
	var save_info: Dictionary = {}
	if exists:
		save_info = _read_slot_info(path)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 50)

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	if slot == 0:
		name_label.text = tr("MENU_AUTO_SAVE")
	else:
		name_label.text = tr("MENU_SLOT") % slot
	info_box.add_child(name_label)

	var detail_label := Label.new()
	detail_label.add_theme_font_size_override("font_size", 12)
	if exists and not save_info.is_empty():
		detail_label.text = _format_slot_info(save_info)
	else:
		detail_label.text = tr("MENU_EMPTY")
		detail_label.modulate = Color(0.5, 0.5, 0.5)
	info_box.add_child(detail_label)

	row.add_child(info_box)

	var load_button := Button.new()
	load_button.text = tr("MENU_LOAD")
	load_button.custom_minimum_size = Vector2(80, 0)
	if not exists:
		load_button.disabled = true
		row.modulate = Color(0.5, 0.5, 0.5)
	else:
		load_button.pressed.connect(_on_load_slot.bind(slot))
	row.add_child(load_button)

	_slot_list.add_child(row)


func _on_load_slot(slot: int) -> void:
	_close_load_panel()
	_load_slot(slot)


func _load_slot(slot: int) -> void:
	_start_game_session(slot)


func _start_game_session(slot: int) -> void:
	if slot >= 0:
		GameManager.load_game(slot)
		return
	GameManager.start_new_game()


func _has_any_saves() -> bool:
	for slot: int in [0, 1, 2, 3]:
		var path: String = SLOT_PATHS.get(slot, "")
		if FileAccess.file_exists(path):
			return true
	return false


func _slot_zero_save_exists() -> bool:
	var path: String = SLOT_PATHS.get(0, "")
	if path.is_empty():
		return false
	return FileAccess.file_exists(path)


func _refresh_load_button_state() -> void:
	if _load_button == null:
		return
	var has_save: bool = _slot_zero_save_exists()
	_load_button.disabled = not has_save
	if has_save:
		_load_button.text = _LOAD_BUTTON_DEFAULT_TEXT
		_load_button.modulate = Color.WHITE
	else:
		_load_button.text = _LOAD_BUTTON_NO_SAVE_TEXT
		_load_button.modulate = _LOAD_BUTTON_DISABLED_MODULATE


func _find_most_recent_slot() -> int:
	var best_slot: int = -1
	var best_time: String = ""

	for slot: int in [0, 1, 2, 3]:
		var path: String = SLOT_PATHS.get(slot, "")
		if not FileAccess.file_exists(path):
			continue
		var info: Dictionary = _read_slot_info(path)
		var meta: Dictionary = info.get("metadata", {}) as Dictionary
		var ts: String = str(meta.get("timestamp", ""))
		if ts.is_empty():
			continue
		if best_time.is_empty() or ts > best_time:
			best_time = ts
			best_slot = slot

	return best_slot


func _read_slot_info(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning(
			"MainMenu: failed to read save slot '%s' — %s"
			% [path, error_string(FileAccess.get_open_error())]
		)
		return {}
	if file.get_length() > MAX_SAVE_PREVIEW_BYTES:
		file.close()
		push_warning(
			(
				"MainMenu: save slot '%s' exceeds maximum preview size (%d bytes)"
				% [path, MAX_SAVE_PREVIEW_BYTES]
			)
		)
		return {}
	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_warning(
			"MainMenu: corrupt save file '%s' — %s"
			% [path, json.get_error_message()]
		)
		return {}
	var data: Variant = json.data
	if data is not Dictionary:
		return {}
	return data as Dictionary


func _format_slot_info(save_data: Dictionary) -> String:
	var metadata: Dictionary = (
		save_data.get("metadata", {}) as Dictionary
	)
	var day: int = int(metadata.get("day_number", 0))
	var timestamp: String = str(metadata.get("timestamp", ""))
	var store_raw: String = str(metadata.get("store_type", ""))

	var store_name: String = ""
	if not store_raw.is_empty():
		var canonical: StringName = ContentRegistry.resolve(store_raw)
		if not canonical.is_empty():
			store_name = ContentRegistry.get_display_name(canonical)
		else:
			store_name = store_raw.capitalize()

	var economy: Dictionary = (
		save_data.get("economy", {}) as Dictionary
	)
	var cash: float = float(
		economy.get("player_cash", economy.get("current_cash", 0.0))
	)

	var parts: Array[String] = []
	if day > 0:
		parts.append(tr("MENU_DAY") % day)
	if not store_name.is_empty():
		parts.append(store_name)
	if cash > 0.0:
		parts.append("$%s" % _format_cash(cash))
	if not timestamp.is_empty():
		parts.append(timestamp.left(10))

	if parts.is_empty():
		return tr("MENU_SAVED_GAME")
	return " | ".join(parts)


func _format_cash(amount: float) -> String:
	if amount >= 1000.0:
		return "%s,%03d" % [
			str(int(amount / 1000.0)),
			int(fmod(amount, 1000.0)),
		]
	return str(int(amount))
