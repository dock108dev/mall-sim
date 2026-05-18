class_name BetaDecisionCardPanel
extends ModalPanel

signal choice_selected(choice_id: StringName, effects: Dictionary)

var _title_label: Label
var _body_label: RichTextLabel
var _choices_box: VBoxContainer
var _choice_buttons: Array[Button] = []
var _selection_locked: bool = false


func _ready() -> void:
	layer = 80
	visible = false
	var blocker := ColorRect.new()
	blocker.color = BetaModalTheme.COLOR_BLOCKER
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 420)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360
	panel.offset_top = -210
	panel.offset_right = 360
	panel.offset_bottom = 210
	panel.add_theme_stylebox_override("panel", BetaModalTheme.make_panel_style())
	blocker.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	var tag := Label.new()
	tag.text = "DAY 1 — CUSTOMER DECISION"
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", BetaModalTheme.COLOR_TEXT_HEADER)
	root.add_child(tag)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", BetaModalTheme.COLOR_TEXT_PRIMARY)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_title_label)

	_body_label = RichTextLabel.new()
	_body_label.fit_content = true
	_body_label.scroll_active = false
	# §F-S13 — bbcode MUST stay disabled. `_on_queued_open` binds
	# `event_data.get("body", "")` from `customer_events.json` content; with
	# BBCode disabled the text renders verbatim. Flipping this to `true`
	# without first escaping `[` → `[lb]` at the binding site would expose
	# `[url=…]` / `[img=res://…]` / `[font=…]` injection from content.
	_body_label.bbcode_enabled = false
	_body_label.custom_minimum_size = Vector2(0, 110)
	_body_label.add_theme_color_override("default_color", BetaModalTheme.COLOR_TEXT_PRIMARY)
	root.add_child(_body_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 8)
	root.add_child(_choices_box)


func show_event(event_data: Dictionary) -> void:
	# Decision cards share the DAY_SUMMARY priority tier with the day-end
	# summary — they're the player's blocking decision points, and only one
	# is ever live at a time in a given day. Payload-driven setup runs in
	# `_on_queued_open` so a deferred dispatch still renders the right event.
	enqueue(
		ModalQueue.Priority.DAY_SUMMARY,
		{"event": event_data},
	)


func _on_queued_open(payload: Dictionary) -> void:
	var event_data: Dictionary = payload.get("event", {}) as Dictionary
	_title_label.text = str(event_data.get("title", "Decision"))
	_body_label.text = str(event_data.get("body", ""))
	_selection_locked = false
	_choice_buttons.clear()
	_register_modal_focusables([])
	for child: Node in _choices_box.get_children():
		child.queue_free()
	var choices: Array = event_data.get("choices", []) as Array
	for choice_variant: Variant in choices:
		if choice_variant is not Dictionary:
			continue
		var choice: Dictionary = choice_variant as Dictionary
		var button := Button.new()
		button.text = str(choice.get("label", "Choose"))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		BetaModalTheme.apply_button_theme(button)
		button.pressed.connect(_on_choice_pressed.bind(
			StringName(str(choice.get("id", "choice"))),
			(choice.get("effects", {}) as Dictionary)
		))
		_choices_box.add_child(button)
		_choice_buttons.append(button)
	_register_modal_focusables(_choice_buttons)
	if not _choice_buttons.is_empty():
		_focus_modal_control_deferred(_choice_buttons[0])


func _on_choice_pressed(choice_id: StringName, effects: Dictionary) -> void:
	if _selection_locked or not visible:
		return
	_selection_locked = true
	choice_selected.emit(choice_id, effects)
	close()


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
		return
	if event is not InputEventKey:
		return
	var index: int = _numeric_choice_index(event as InputEventKey)
	if index >= 0:
		_press_choice_index(index)
		get_viewport().set_input_as_handled()


func _press_choice_index(index: int) -> void:
	if index < 0 or index >= _choice_buttons.size():
		return
	var button: Button = _choice_buttons[index]
	if button.disabled or not button.visible:
		return
	_focus_modal_control(button)
	button.pressed.emit()


func _numeric_choice_index(event: InputEventKey) -> int:
	if not event.pressed or event.echo:
		return -1
	var keycodes: Array[int] = [
		event.keycode,
		event.physical_keycode,
		event.key_label,
	]
	for keycode: int in keycodes:
		if keycode >= KEY_1 and keycode <= KEY_9:
			return keycode - KEY_1
	if event.unicode >= 49 and event.unicode <= 57:
		return event.unicode - 49
	return -1
