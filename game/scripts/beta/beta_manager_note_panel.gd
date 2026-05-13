## Day-1 opening note — shows Vic's morning note before the chain arms.
##
## Inherits the `ModalPanel` lifecycle for `ModalQueue` ordering, but does
## NOT claim CTX_MODAL on InputFocus: the player can move and look around
## while the note is on screen, mirroring `MorningNotePanel`'s passive-
## overlay contract. Chain progression stays gated by the controller's
## `_stage` state rather than the input focus stack, and the ModalDimOverlay
## does not engage behind the note.
##
## The "Got it" button grabs keyboard focus on open() so the player can
## dismiss with Enter or Space without touching the mouse. The panel also
## responds to the `interact` action (E) and `ui_cancel` (Escape) so all
## three keyboard paths converge on the same dismiss.
class_name BetaManagerNotePanel
extends ModalPanel

signal note_dismissed()

var _body_label: RichTextLabel
var _dismiss_button: Button
var _showing: bool = false


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


## Renders `body` and opens the modal. Routes through `ModalQueue` at
## `VIC_NOTE` priority so the note dispatches strictly after any
## higher-priority panel (e.g. a Day-N-1 summary) has closed. Body text and
## button focus are applied in `_on_queued_open` so the panel renders the
## right body even when its dispatch is deferred behind another modal.
##
## §F-S9 trust contract — `_body_label.bbcode_enabled = true`. The two
## callers today are the constants `BetaDayOneController.VIC_NOTE_BODY` and
## `VIC_NOTE_DAY2_BODY`, both of which intentionally use `[b]…[/b]` markup,
## so escaping in this function would break the intended copy. Any future
## caller that passes content-derived or save-derived `body` text must
## escape `[` → `[lb]` at the call site (see `boot.gd._show_error_panel`
## and `checkout_panel.gd._set_reasoning_text` for the canonical pattern).
func show_note(body: String) -> void:
	enqueue(ModalQueue.Priority.VIC_NOTE, {"body": body})


func _on_queued_open(payload: Dictionary) -> void:
	# §F-S9 — `_body_label.bbcode_enabled = true` sink. Body must be either a
	# hardcoded constant with intentional BBCode markup, or pre-escaped at
	# the call site. See `show_note` docstring.
	_body_label.text = String(payload.get("body", ""))
	_showing = true
	# Grab focus after the panel is visible so the dismiss button can own
	# keyboard input (Enter / Space) without the player touching the mouse.
	_dismiss_button.grab_focus()


func _on_dismiss_pressed() -> void:
	close()
	note_dismissed.emit()


## Passive-overlay open path: toggle visibility only, no CTX_MODAL push.
## The base `_open_from_queue` would push CTX_MODAL — override so the note
## participates in ModalQueue ordering without freezing the player.
func _open_from_queue(payload: Dictionary) -> void:
	visible = true
	_on_queued_open(payload)


## Mirror the open override: close without popping a frame we never pushed.
## Still notify ModalQueue so the next queued panel can dispatch.
func close() -> void:
	visible = false
	_showing = false
	ModalQueue.notify_closed(self)


## E (interact) and Escape (ui_cancel) both dismiss the note. Mark input as
## handled so the press cannot also reach a world interactable behind the
## panel — the player should not accidentally restock a shelf in the same
## keypress that dismisses the note.
func _unhandled_input(event: InputEvent) -> void:
	if not _showing:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel"):
		_on_dismiss_pressed()
		get_viewport().set_input_as_handled()
