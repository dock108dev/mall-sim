class_name BetaDayTwoPlaceholderPanel
extends ModalPanel

signal main_menu_pressed()
signal restart_pressed()

var _title_label: Label
var _body_label: Label
var _main_menu_button: Button
var _restart_button: Button


func _ready() -> void:
	layer = 82
	visible = false

	var blocker := ColorRect.new()
	blocker.color = BetaModalTheme.COLOR_BLOCKER
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 360)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340
	panel.offset_top = -180
	panel.offset_right = 340
	panel.offset_bottom = 180
	panel.add_theme_stylebox_override("panel", BetaModalTheme.make_panel_style())
	blocker.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	panel.add_child(root)

	_title_label = Label.new()
	_title_label.text = "Day 2 Preview"
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", BetaModalTheme.COLOR_TEXT_HEADER)
	root.add_child(_title_label)

	_body_label = Label.new()
	_body_label.text = (
		"The Day 1 vertical slice is complete. Day 2 is a placeholder for the next "
		+ "slice, so it does not start unfinished store gameplay yet."
	)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_color_override("font_color", BetaModalTheme.COLOR_TEXT_PRIMARY)
	root.add_child(_body_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	root.add_child(button_row)

	_main_menu_button = Button.new()
	_main_menu_button.text = "Return to Menu"
	_main_menu_button.custom_minimum_size = Vector2(0, 48)
	_main_menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BetaModalTheme.apply_button_theme(_main_menu_button)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	button_row.add_child(_main_menu_button)

	_restart_button = Button.new()
	_restart_button.text = "Restart Day 1"
	_restart_button.custom_minimum_size = Vector2(0, 48)
	_restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BetaModalTheme.apply_button_theme(_restart_button)
	_restart_button.pressed.connect(_on_restart_pressed)
	button_row.add_child(_restart_button)


func show_placeholder() -> void:
	enqueue(ModalQueue.Priority.DAY_SUMMARY, {})


func _on_queued_open(_payload: Dictionary) -> void:
	_register_modal_focusables([_main_menu_button, _restart_button])
	_focus_modal_control_deferred(_main_menu_button)


func _unhandled_input(event: InputEvent) -> void:
	if not _modal_can_handle_input():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_accept"):
		if _activate_focused_modal_button():
			get_viewport().set_input_as_handled()
		return
	if _is_modal_focus_previous_event(event):
		if _cycle_modal_focus(false):
			get_viewport().set_input_as_handled()
		return
	if _is_modal_focus_next_event(event):
		if _cycle_modal_focus(true):
			get_viewport().set_input_as_handled()


func _on_main_menu_pressed() -> void:
	main_menu_pressed.emit()


func _on_restart_pressed() -> void:
	restart_pressed.emit()
