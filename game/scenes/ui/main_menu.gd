## Main menu — entry point after boot with new game, continue, load, and quit.
extends Control


const SAVE_DIR := "user://saves/"
const SLOT_PATHS: Dictionary = {
	0: "user://saves/auto_save.json",
	1: "user://saves/slot_1.json",
	2: "user://saves/slot_2.json",
	3: "user://saves/slot_3.json",
}
const _SettingsPanelScene: PackedScene = preload(
	"res://game/scenes/ui/settings_panel.tscn"
)

var _load_panel_visible: bool = false
var _settings_panel: SettingsPanel = null

@onready var _continue_button: Button = $VBox/ContinueButton
@onready var _play_button: Button = $VBox/PlayButton
@onready var _load_button: Button = $VBox/LoadButton
@onready var _quit_button: Button = $VBox/QuitButton
@onready var _load_container: PanelContainer = $LoadPanel
@onready var _slot_list: VBoxContainer = (
	$LoadPanel/Margin/VBox/SlotContainer
)
@onready var _load_close_button: Button = (
	$LoadPanel/Margin/VBox/Header/CloseButton
)


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.MENU)
	_load_container.visible = false
	_load_close_button.pressed.connect(_close_load_panel)

	var most_recent: int = _find_most_recent_slot()
	_continue_button.visible = most_recent >= 0
	if most_recent >= 0:
		_continue_button.pressed.connect(
			_on_continue_pressed.bind(most_recent)
		)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not (event as InputEventKey).pressed:
		return
	if event.is_action_pressed("ui_cancel") and _load_panel_visible:
		_close_load_panel()
		get_viewport().set_input_as_handled()


func _on_play_pressed() -> void:
	_start_game_session(-1)


func _on_load_pressed() -> void:
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
		_settings_panel = _SettingsPanelScene.instantiate() as SettingsPanel
		add_child(_settings_panel)
	_settings_panel.open()


func _on_quit_pressed() -> void:
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
	var metadata: Dictionary = {}
	if exists:
		metadata = _read_slot_metadata(path)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 50)

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	if slot == 0:
		name_label.text = "Auto Save"
	else:
		name_label.text = "Slot %d" % slot
	info_box.add_child(name_label)

	var detail_label := Label.new()
	detail_label.add_theme_font_size_override("font_size", 12)
	if exists:
		detail_label.text = _format_metadata(metadata)
	else:
		detail_label.text = "Empty"
		detail_label.modulate = Color(0.5, 0.5, 0.5)
	info_box.add_child(detail_label)

	row.add_child(info_box)

	var load_button := Button.new()
	load_button.text = "Load"
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
	GameManager.pending_load_slot = slot
	GameManager.start_new_game()
	GameManager.change_scene(
		"res://game/scenes/world/game_world.tscn"
	)


func _find_most_recent_slot() -> int:
	var best_slot: int = -1
	var best_time: String = ""

	for slot: int in [0, 1, 2, 3]:
		var path: String = SLOT_PATHS.get(slot, "")
		if not FileAccess.file_exists(path):
			continue
		var meta: Dictionary = _read_slot_metadata(path)
		var ts: String = str(meta.get("timestamp", ""))
		if ts.is_empty():
			continue
		if best_time.is_empty() or ts > best_time:
			best_time = ts
			best_slot = slot

	return best_slot


func _read_slot_metadata(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning(
			"MainMenu: failed to read save slot '%s' — %s"
			% [path, error_string(FileAccess.get_open_error())]
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
	return (data as Dictionary).get("metadata", {}) as Dictionary


func _format_metadata(metadata: Dictionary) -> String:
	var day: int = int(metadata.get("day_number", 0))
	var timestamp: String = str(metadata.get("timestamp", ""))
	var store: String = str(metadata.get("store_type", ""))

	var parts: Array[String] = []
	if day > 0:
		parts.append("Day %d" % day)
	if not store.is_empty():
		parts.append(store.capitalize())
	if not timestamp.is_empty():
		parts.append(timestamp.left(10))

	if parts.is_empty():
		return "Saved game"
	return " | ".join(parts)
