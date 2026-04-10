## Panel for saving and loading games with slot selection.
class_name SaveLoadPanel
extends CanvasLayer


const PANEL_NAME: String = "save_load"
const MANUAL_SLOTS: int = 3
const AUTO_SLOT: int = 0

enum Mode { SAVE, LOAD }

signal save_requested(slot: int)
signal load_requested(slot: int)

var save_manager: SaveManager
var _mode: Mode = Mode.SAVE
var _is_open: bool = false
var _pending_overwrite_slot: int = -1

@onready var _panel: PanelContainer = $PanelRoot
@onready var _title_label: Label = (
	$PanelRoot/Margin/VBox/Header/TitleLabel
)
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)
@onready var _slot_container: VBoxContainer = (
	$PanelRoot/Margin/VBox/SlotContainer
)
@onready var _confirm_dialog: PanelContainer = $ConfirmRoot
@onready var _confirm_label: Label = (
	$ConfirmRoot/Margin/VBox/ConfirmLabel
)
@onready var _confirm_yes: Button = (
	$ConfirmRoot/Margin/VBox/Buttons/YesButton
)
@onready var _confirm_no: Button = (
	$ConfirmRoot/Margin/VBox/Buttons/NoButton
)


func _ready() -> void:
	_panel.visible = false
	_confirm_dialog.visible = false
	_close_button.pressed.connect(close)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_on_confirm_no)
	EventBus.panel_opened.connect(_on_panel_opened)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not (event as InputEventKey).pressed:
		return
	if (event as InputEventKey).echo:
		return
	if event.is_action_pressed("ui_cancel") and _is_open:
		if _confirm_dialog.visible:
			_on_confirm_no()
		else:
			close()
		get_viewport().set_input_as_handled()


func open_save() -> void:
	_mode = Mode.SAVE
	_title_label.text = "Save Game"
	_open()


func open_load() -> void:
	_mode = Mode.LOAD
	_title_label.text = "Load Game"
	_open()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_confirm_dialog.visible = false
	_pending_overwrite_slot = -1
	_panel.visible = false
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _open() -> void:
	if _is_open:
		_refresh_slots()
		return
	_is_open = true
	_refresh_slots()
	_panel.visible = true
	EventBus.panel_opened.emit(PANEL_NAME)


func _refresh_slots() -> void:
	_clear_slots()
	if _mode == Mode.LOAD:
		_create_slot_row(AUTO_SLOT)
	for slot: int in range(1, MANUAL_SLOTS + 1):
		_create_slot_row(slot)


func _clear_slots() -> void:
	for child: Node in _slot_container.get_children():
		child.queue_free()


func _create_slot_row(slot: int) -> void:
	var exists: bool = false
	if save_manager:
		exists = save_manager.slot_exists(slot)

	var metadata: Dictionary = {}
	if exists and save_manager:
		metadata = save_manager.get_slot_metadata(slot)

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 60)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	row.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var slot_label := Label.new()
	slot_label.text = _get_slot_label(slot, exists)
	info_box.add_child(slot_label)

	var detail_label := Label.new()
	detail_label.add_theme_font_size_override("font_size", 12)
	if exists:
		detail_label.text = _format_metadata(metadata)
	else:
		detail_label.text = "Empty"
		detail_label.modulate = Color(0.5, 0.5, 0.5)
	info_box.add_child(detail_label)

	hbox.add_child(info_box)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(80, 0)

	if _mode == Mode.SAVE:
		if slot == AUTO_SLOT:
			return
		action_button.text = "Save"
		action_button.pressed.connect(
			_on_slot_save_pressed.bind(slot, exists)
		)
	else:
		action_button.text = "Load"
		if not exists:
			action_button.disabled = true
			row.modulate = Color(0.5, 0.5, 0.5)
		else:
			action_button.pressed.connect(
				_on_slot_load_pressed.bind(slot)
			)

	hbox.add_child(action_button)
	_slot_container.add_child(row)


func _get_slot_label(slot: int, exists: bool) -> String:
	if slot == AUTO_SLOT:
		return "Auto Save"
	if exists:
		return "Slot %d" % slot
	return "Slot %d — Empty" % slot


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
		parts.append(_format_timestamp(timestamp))

	if parts.is_empty():
		return "Saved game"
	return " | ".join(parts)


func _format_timestamp(iso_string: String) -> String:
	var date_part: String = iso_string.left(10)
	if date_part.is_empty():
		return iso_string
	return date_part


func _on_slot_save_pressed(
	slot: int, occupied: bool
) -> void:
	if occupied:
		_pending_overwrite_slot = slot
		_confirm_label.text = (
			"Overwrite Slot %d?" % slot
		)
		_confirm_dialog.visible = true
		return
	_do_save(slot)


func _on_slot_load_pressed(slot: int) -> void:
	load_requested.emit(slot)
	close()


func _on_confirm_yes() -> void:
	if _pending_overwrite_slot < 0:
		return
	var slot: int = _pending_overwrite_slot
	_pending_overwrite_slot = -1
	_confirm_dialog.visible = false
	_do_save(slot)


func _on_confirm_no() -> void:
	_pending_overwrite_slot = -1
	_confirm_dialog.visible = false


func _do_save(slot: int) -> void:
	save_requested.emit(slot)
	_refresh_slots()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close()
