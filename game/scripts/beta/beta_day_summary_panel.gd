class_name BetaDaySummaryPanel
extends ModalPanel

signal continue_pressed()

var _title_label: Label
var _metrics_label: RichTextLabel
var _note_label: Label
var _continue_button: Button


func _ready() -> void:
	layer = 81
	visible = false
	var blocker := ColorRect.new()
	blocker.color = BetaModalTheme.COLOR_BLOCKER
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 380)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320
	panel.offset_top = -190
	panel.offset_right = 320
	panel.offset_bottom = 190
	panel.add_theme_stylebox_override("panel", BetaModalTheme.make_panel_style())
	blocker.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", BetaModalTheme.COLOR_TEXT_HEADER)
	v.add_child(_title_label)

	_metrics_label = RichTextLabel.new()
	_metrics_label.bbcode_enabled = true
	_metrics_label.fit_content = true
	_metrics_label.scroll_active = false
	_metrics_label.custom_minimum_size = Vector2(0, 170)
	_metrics_label.add_theme_color_override("default_color", BetaModalTheme.COLOR_TEXT_PRIMARY)
	v.add_child(_metrics_label)

	_note_label = Label.new()
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.add_theme_color_override("font_color", BetaModalTheme.COLOR_TEXT_MUTED)
	v.add_child(_note_label)

	_continue_button = Button.new()
	_continue_button.text = "Continue to next day"
	_continue_button.custom_minimum_size = Vector2(0, 48)
	BetaModalTheme.apply_button_theme(_continue_button)
	_continue_button.pressed.connect(_on_continue_pressed)
	v.add_child(_continue_button)


func show_summary(summary: Dictionary, is_final_day: bool = false) -> void:
	var day: int = int(summary.get("day", 1))
	_title_label.text = "Day %d Summary" % day
	_metrics_label.text = (
		"[b]Cash:[/b] %d\n"
		+ "[b]Reputation:[/b] %d\n"
		+ "[b]Manager Trust:[/b] %d\n"
		+ "[b]Hidden Thread Score:[/b] %d\n"
		+ "[b]Events Completed:[/b] %d / %d"
	) % [
		int(summary.get("cash", 0)),
		int(summary.get("reputation", 0)),
		int(summary.get("manager_trust", 0)),
		int(summary.get("hidden_thread_score", 0)),
		int(summary.get("events_completed", 0)),
		int(summary.get("events_target", 0)),
	]
	_note_label.text = str(summary.get("hidden_thread_note", ""))
	if is_final_day:
		_continue_button.text = "Finish beta and return to menu"
	else:
		_continue_button.text = "Continue to next day"
	open()


func _on_continue_pressed() -> void:
	continue_pressed.emit()
	close()
