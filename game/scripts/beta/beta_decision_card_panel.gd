class_name BetaDecisionCardPanel
extends ModalPanel

signal choice_selected(choice_id: StringName, effects: Dictionary)

var _title_label: Label
var _body_label: RichTextLabel
var _choices_box: VBoxContainer


func _ready() -> void:
	layer = 80
	visible = false
	var blocker := ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.62)
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 420)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -350
	panel.offset_top = -210
	panel.offset_right = 350
	panel.offset_bottom = 210
	blocker.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var tag := Label.new()
	tag.text = "DAY 1 CUSTOMER DECISION"
	tag.add_theme_font_size_override("font_size", 18)
	root.add_child(tag)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_title_label)

	_body_label = RichTextLabel.new()
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.bbcode_enabled = false
	_body_label.custom_minimum_size = Vector2(0, 90)
	root.add_child(_body_label)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 8)
	root.add_child(_choices_box)


func show_event(event_data: Dictionary) -> void:
	_title_label.text = str(event_data.get("title", "Decision"))
	_body_label.text = str(event_data.get("body", ""))
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
		button.pressed.connect(_on_choice_pressed.bind(
			StringName(str(choice.get("id", "choice"))),
			(choice.get("effects", {}) as Dictionary)
		))
		_choices_box.add_child(button)
	open()


func _on_choice_pressed(choice_id: StringName, effects: Dictionary) -> void:
	choice_selected.emit(choice_id, effects)
	close()
