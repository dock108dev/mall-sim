## Tests MorningNotePanel.dismiss() emits manager_note_dismissed on all three
## dismissal paths (E-key, left-click on the panel rect, auto-dismiss timer).
extends GutTest


const _NOTE_SCENE: PackedScene = preload(
	"res://game/scenes/ui/morning_note_panel.tscn"
)


func _make_panel() -> CanvasLayer:
	var panel: CanvasLayer = _NOTE_SCENE.instantiate() as CanvasLayer
	add_child_autofree(panel)
	return panel


func test_dismiss_emits_manager_note_dismissed_with_note_id() -> void:
	var panel := _make_panel()
	panel.show_note("day_1_morning", "Good morning.", "Day 1", false)
	var received: Array[String] = []
	EventBus.manager_note_dismissed.connect(
		func(note_id: String) -> void: received.append(note_id)
	)
	panel.dismiss()
	assert_eq(received.size(), 1, "dismiss() must emit exactly once")
	assert_eq(
		received[0], "day_1_morning",
		"manager_note_dismissed must carry the active note id"
	)


func test_dismiss_when_not_showing_emits_nothing() -> void:
	var panel := _make_panel()
	var received: Array[String] = []
	EventBus.manager_note_dismissed.connect(
		func(note_id: String) -> void: received.append(note_id)
	)
	panel.dismiss()
	assert_eq(
		received.size(), 0,
		"dismiss() must be a no-op when the panel is not showing"
	)


func test_auto_dismiss_timer_emits_signal() -> void:
	var panel := _make_panel()
	panel.show_note("day_2_morning", "Good morning.", "Day 2", true)
	var received: Array[String] = []
	EventBus.manager_note_dismissed.connect(
		func(note_id: String) -> void: received.append(note_id)
	)
	# Drive the countdown past zero in a single tick so dismiss() fires through
	# the auto-dismiss path inside _process().
	panel._process(panel.AUTO_DISMISS_SECONDS + 0.1)
	assert_eq(
		received.size(), 1,
		"Auto-dismiss timeout must reach dismiss() and emit the signal"
	)
	assert_eq(received[0], "day_2_morning")


## Calling show_note() twice in a row must replace the body, not stack it. The
## panel uses RichTextLabel and the explicit clear() before `.text =` is the
## guard against a future refactor that re-introduces `append_text()`.
func test_show_note_twice_replaces_body_does_not_stack() -> void:
	var panel := _make_panel()
	var body: String = "First clock-in. Vic walked you through the register."
	panel.show_note("day_1_morning", body, "Day 1", false)
	panel.show_note("day_1_morning", body, "Day 1", false)
	var body_label: RichTextLabel = panel.get_node("%BodyLabel") as RichTextLabel
	assert_eq(
		body_label.text, body,
		"Repeat show_note() must replace the body, not concatenate it"
	)


## A second show_note() with a different body must show only the new body —
## confirms clear() runs even when the new content is a strict substring of
## the old (the case where append_text() would silently double-render the
## suffix).
func test_show_note_replaces_with_different_body() -> void:
	var panel := _make_panel()
	panel.show_note("note_a", "Long body text.", "Day 1", false)
	panel.show_note("note_b", "Short.", "Day 2", false)
	var body_label: RichTextLabel = panel.get_node("%BodyLabel") as RichTextLabel
	assert_eq(
		body_label.text, "Short.",
		"Second show_note() body must fully replace the first"
	)
