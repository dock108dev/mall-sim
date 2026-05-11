## Day-1 opening modal — shows Vic's morning note before the chain arms.
##
## Owns the CTX_MODAL frame for the duration of the note (via the
## `ModalPanel` base) so input cannot reach the world or the chain's
## interactables until the player has read and dismissed the note.
##
## The "Got it" button grabs keyboard focus on open() so the player can
## dismiss with Enter or Space without touching the mouse — first
## interaction is keyboard-only by default.
class_name BetaManagerNotePanel
extends ModalPanel

signal note_dismissed()

var _body_label: RichTextLabel
var _dismiss_button: Button


func _ready() -> void:
	# Layer 79 sits below the decision card (80) and summary (81); only one
	# of these is visible at a time on Day 1, so the ordering matches the
	# narrative sequence.
	layer = 79
	visible = false

	var blocker := ColorRect.new()
	blocker.color = BetaModalTheme.COLOR_BLOCKER
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 320)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_top = -160
	panel.offset_right = 280
	panel.offset_bottom = 160
	panel.add_theme_stylebox_override("panel", BetaModalTheme.make_panel_style())
	blocker.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.custom_minimum_size = Vector2(0, 220)
	_body_label.add_theme_color_override(
		"default_color", BetaModalTheme.COLOR_TEXT_PRIMARY
	)
	v.add_child(_body_label)

	_dismiss_button = Button.new()
	_dismiss_button.text = "Got it"
	_dismiss_button.custom_minimum_size = Vector2(0, 48)
	BetaModalTheme.apply_button_theme(_dismiss_button)
	_dismiss_button.pressed.connect(_on_dismiss_pressed)
	v.add_child(_dismiss_button)


## Renders `body` and opens the modal. Grabs focus on the dismiss button so
## the player can press Enter/Space to dismiss without using the mouse.
func show_note(body: String) -> void:
	_body_label.text = body
	open()
	_dismiss_button.grab_focus()


func _on_dismiss_pressed() -> void:
	close()
	note_dismissed.emit()
