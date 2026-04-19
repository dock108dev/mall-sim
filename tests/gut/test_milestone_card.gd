## Tests for MilestoneCard in both notification and row display modes.
extends GutTest


var _card: MilestoneCard
const _SCENE: PackedScene = preload(
	"res://game/scenes/ui/milestone_card.tscn"
)


func _make_card(notification: bool) -> MilestoneCard:
	var c: MilestoneCard = _SCENE.instantiate() as MilestoneCard
	c.notification_mode = notification
	add_child_autofree(c)
	return c


# ── Notification mode ────────────────────────────────────────────────────────

func test_notification_starts_hidden() -> void:
	_card = _make_card(true)
	assert_false(_card.visible, "Notification card should start hidden")


func test_notification_does_not_block_input() -> void:
	_card = _make_card(true)
	assert_eq(
		_card.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"Notification card must not consume player input"
	)


func test_notification_shows_on_milestone_completed() -> void:
	_card = _make_card(true)
	EventBus.milestone_completed.emit("ms_test", "Grand Opening", "Bonus: $50")
	assert_true(_card.visible, "Card should become visible after milestone_completed")
	assert_true(_card._is_showing, "_is_showing should be true while card is displayed")


func test_notification_displays_correct_name() -> void:
	_card = _make_card(true)
	EventBus.milestone_completed.emit("ms_test", "Grand Opening", "Bonus: $50")
	assert_eq(_card._name_label.text, "Grand Opening")


func test_notification_queues_consecutive_completions() -> void:
	_card = _make_card(true)
	EventBus.milestone_completed.emit("ms_1", "First", "Reward 1")
	EventBus.milestone_completed.emit("ms_2", "Second", "Reward 2")
	EventBus.milestone_completed.emit("ms_3", "Third", "Reward 3")
	assert_eq(_card._queue.size(), 2, "Two entries should queue while one is showing")
	assert_eq(_card._name_label.text, "First", "First milestone should be displayed")


func test_notification_starts_offscreen_above() -> void:
	_card = _make_card(true)
	EventBus.milestone_completed.emit("ms_test", "Test", "Reward")
	assert_true(
		_card.position.y < 0.0,
		"Notification should begin above the screen (negative y)"
	)


func test_notification_finished_shows_next_queued() -> void:
	_card = _make_card(true)
	EventBus.milestone_completed.emit("ms_1", "First", "Reward 1")
	EventBus.milestone_completed.emit("ms_2", "Second", "Reward 2")

	_card._on_notification_finished()

	assert_true(_card._is_showing, "Should be showing the next queued milestone")
	assert_eq(_card._name_label.text, "Second", "Second milestone should now be displayed")
	assert_eq(_card._queue.size(), 0, "Queue should be empty after dequeue")


func test_notification_finished_hides_when_queue_empty() -> void:
	_card = _make_card(true)
	EventBus.milestone_completed.emit("ms_1", "Only One", "Reward")

	_card._on_notification_finished()

	assert_false(_card._is_showing, "Should not be showing after last notification finishes")
	assert_false(_card.visible, "Card should be hidden after last notification finishes")


# ── Row mode ─────────────────────────────────────────────────────────────────

func test_row_configure_sets_name_and_description() -> void:
	_card = _make_card(false)
	_card.configure({
		"milestone_id": "ms_row",
		"name": "High Roller",
		"description": "Earn $10 000 in a single day.",
		"reward": "Cash bonus",
		"is_completed": false,
		"progress": 0.4,
	})
	assert_eq(_card._name_label.text, "High Roller")
	assert_eq(_card._desc_label.text, "Earn $10 000 in a single day.")


func test_row_configure_shows_progress_when_incomplete() -> void:
	_card = _make_card(false)
	_card.configure({
		"milestone_id": "ms_row",
		"name": "High Roller",
		"description": "",
		"reward": "",
		"is_completed": false,
		"progress": 0.75,
	})
	assert_true(_card._progress_label.visible, "Progress label should be visible")
	assert_false(_card._done_label.visible, "Done label should be hidden")
	assert_eq(_card._progress_label.text, tr("MILESTONE_PROGRESS") % 75)


func test_row_configure_shows_done_label_when_completed() -> void:
	_card = _make_card(false)
	_card.configure({
		"milestone_id": "ms_done",
		"name": "Done Milestone",
		"description": "",
		"reward": "",
		"is_completed": true,
		"progress": 1.0,
	})
	assert_true(_card._done_label.visible, "Done label should be visible when completed")
	assert_false(_card._progress_label.visible, "Progress label should be hidden when completed")


func test_row_emits_clicked_signal() -> void:
	_card = _make_card(false)
	_card.configure({
		"milestone_id": "ms_click",
		"name": "Clickable",
		"description": "",
		"reward": "",
		"is_completed": false,
		"progress": 0.0,
	})
	watch_signals(_card)
	_card._on_gui_input(
		_build_left_click_event()
	)
	assert_signal_emitted_with_parameters(
		_card, "clicked", ["ms_click"]
	)


func _build_left_click_event() -> InputEventMouseButton:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	return mb


func test_row_title_label_is_hidden() -> void:
	_card = _make_card(false)
	assert_false(_card._title_label.visible, "TitleLabel should be hidden in row mode")


func test_notification_status_label_is_hidden() -> void:
	_card = _make_card(true)
	assert_false(_card._status_label.visible, "StatusLabel should be hidden in notification mode")
