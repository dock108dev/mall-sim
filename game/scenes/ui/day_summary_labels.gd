## Static label-factory helpers for DaySummary. Pulled out so the overlay
## file stays focused on stat presentation while the per-label construction
## (with autowrap, color overrides, mouse-filter, and parent insertion) lives
## next to its kin. Each `create_*` returns the new Label and inserts it at
## the requested vbox position.
class_name DaySummaryLabels
extends Object


static func create_overdue_count(
	vbox: VBoxContainer, after_label: Label
) -> Label:
	var label := Label.new()
	label.name = "OverdueCountLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = false
	vbox.add_child(label)
	vbox.move_child(label, after_label.get_index() + 1)
	return label


static func create_discrepancy(
	vbox: VBoxContainer, after_label: Label, gui_input_handler: Callable
) -> Label:
	var label := Label.new()
	label.name = "DiscrepancyLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.tooltip_text = TranslationServer.translate("DAY_SUMMARY_CLICK_REPORT")
	label.gui_input.connect(gui_input_handler)
	vbox.add_child(label)
	vbox.move_child(label, after_label.get_index() + 1)
	return label


## Returns [warranty_attach_label, demo_status_label] — both are appended to
## `vbox` in the order the panel renders them.
static func create_electronics(vbox: VBoxContainer) -> Array:
	var warranty_attach := Label.new()
	warranty_attach.name = "WarrantyAttachLabel"
	warranty_attach.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warranty_attach.visible = false
	vbox.add_child(warranty_attach)
	var demo_status := Label.new()
	demo_status.name = "DemoStatusLabel"
	demo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demo_status.visible = false
	vbox.add_child(demo_status)
	return [warranty_attach, demo_status]


static func create_grading(vbox: VBoxContainer) -> Label:
	var label := Label.new()
	label.name = "GradingLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.78, 0.85, 0.60))
	label.visible = false
	vbox.add_child(label)
	return label


## Returns [story_beat_label, forward_hook_label].
static func create_narrative(vbox: VBoxContainer) -> Array:
	var story_beat := Label.new()
	story_beat.name = "StoryBeatLabel"
	story_beat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_beat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_beat.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))
	story_beat.visible = false
	vbox.add_child(story_beat)
	var forward_hook := Label.new()
	forward_hook.name = "ForwardHookLabel"
	forward_hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forward_hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	forward_hook.add_theme_color_override("font_color", Color(0.60, 0.80, 0.95))
	forward_hook.visible = false
	vbox.add_child(forward_hook)
	return [story_beat, forward_hook]
