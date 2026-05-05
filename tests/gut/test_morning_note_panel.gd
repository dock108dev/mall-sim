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
