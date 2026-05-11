## Tests for MilestoneCard in both notification and row display modes.
extends GutTest


var _card: MilestoneCard
const _SCENE: PackedScene = preload(
	"res://game/scenes/ui/milestone_card.tscn"
)
const _CONFIRM_ID: String = "employee_register_unlock"
const _TOAST_ID: String = "ms_test"


func _make_card(notification: bool) -> MilestoneCard:
	var c: MilestoneCard = _SCENE.instantiate() as MilestoneCard
	c.notification_mode = notification
	add_child_autofree(c)
	return c


func after_each() -> void:
	if is_instance_valid(_card):
		_card._reset_for_tests()
	InputFocus._reset_for_tests()


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


# ── Confirm mode (requires_confirm milestones) ───────────────────────────────

func test_confirm_milestone_shows_continue_button() -> void:
	_card = _make_card(true)
	EventBus.milestone_completed.emit(_CONFIRM_ID, "Showing the Ropes", "Register access unlocked")
	assert_true(
		_card._continue_button.visible,
		"Continue button must be visible for a requires_confirm milestone"
	)


func test_confirm_milestone_grabs_focus_on_open() -> void:
	_card = _make_card(true)
	EventBus.milestone_completed.emit(_CONFIRM_ID, "Showing the Ropes", "Register access unlocked")
	assert_true(
		_card._continue_button.has_focus(),
		"Continue button must grab keyboard focus when confirm modal opens"
	)


func test_confirm_milestone_pushes_modal_context() -> void:
	_card = _make_card(true)
	var baseline: int = InputFocus.depth()
	EventBus.milestone_completed.emit(_CONFIRM_ID, "Showing the Ropes", "Register access unlocked")
	assert_eq(
		InputFocus.depth(), baseline + 1,
		"Confirm modal must push exactly one CTX_MODAL frame"
	)
	assert_eq(InputFocus.current(), InputFocus.CTX_MODAL)


func test_confirm_milestone_shows_inline_reward() -> void:
	_card = _make_card(true)
	EventBus.milestone_completed.emit(_CONFIRM_ID, "Showing the Ropes", "Register access unlocked")
	assert_true(
		_card._inline_reward_label.visible,
		"Inline reward label must be visible in confirm mode when reward present"
	)
	assert_eq(_card._inline_reward_label.text, "Register access unlocked")


func test_continue_press_pops_modal_and_hides_card() -> void:
	_card = _make_card(true)
	var baseline: int = InputFocus.depth()
	EventBus.milestone_completed.emit(_CONFIRM_ID, "Showing the Ropes", "Register access unlocked")

	_card._on_continue_pressed()
	# Skip the slide-out tween for the visibility/state assertion.
	_card._on_notification_finished()

	assert_eq(
		InputFocus.depth(), baseline,
		"Continue press must pop the CTX_MODAL frame back to baseline"
	)
	assert_false(_card._is_showing, "Card should not be showing after continue + finish")
	assert_false(_card.visible, "Card should be hidden after continue + finish")
	assert_false(_card._continue_button.visible, "Continue button should be hidden after dismiss")


func test_toast_milestone_keeps_continue_button_hidden() -> void:
	_card = _make_card(true)
	EventBus.milestone_completed.emit(_TOAST_ID, "Toast Milestone", "Bonus")
	assert_false(
		_card._continue_button.visible,
		"Continue button must stay hidden for an auto-dismiss toast milestone"
	)


func test_toast_milestone_does_not_steal_focus() -> void:
	_card = _make_card(true)
	var baseline: int = InputFocus.depth()
	EventBus.milestone_completed.emit(_TOAST_ID, "Toast Milestone", "Bonus")
	assert_eq(
		InputFocus.depth(), baseline,
		"Auto-dismiss toast must not push CTX_MODAL"
	)
	assert_false(
		_card._continue_button.has_focus(),
		"Auto-dismiss toast must not grab keyboard focus from gameplay"
	)


func test_notification_title_label_is_hidden() -> void:
	_card = _make_card(true)
	assert_false(
		_card._title_label.visible,
		"Static 'Milestone Complete!' TitleLabel must be hidden in notification mode "
		+ "to remove duplicate-title look"
	)
