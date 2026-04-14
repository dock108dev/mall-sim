## Tests for MilestonePopup slide animation, queue, and input passthrough.
extends GutTest


var _popup: MilestonePopup


func before_each() -> void:
	_popup = preload(
		"res://game/scenes/ui/milestone_popup.tscn"
	).instantiate() as MilestonePopup
	add_child_autofree(_popup)


func test_popup_starts_hidden() -> void:
	assert_false(
		_popup.visible,
		"MilestonePopup should be hidden on ready"
	)


func test_popup_does_not_block_input() -> void:
	assert_eq(
		_popup.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"MilestonePopup should not block player input"
	)


func test_popup_shows_on_milestone_completed() -> void:
	EventBus.milestone_completed.emit(
		"test_ms", "Test Milestone", "Bonus: $100"
	)
	assert_true(
		_popup.visible,
		"Popup should become visible after milestone_completed"
	)
	assert_true(
		_popup._is_showing,
		"_is_showing should be true while banner is displayed"
	)


func test_popup_displays_correct_text() -> void:
	EventBus.milestone_completed.emit(
		"test_ms", "Grand Opening", "Unlocked new store slot"
	)
	assert_eq(
		_popup._name_label.text, "Grand Opening",
		"Name label should show milestone name"
	)
	assert_eq(
		_popup._reward_label.text, "Unlocked new store slot",
		"Reward label should show reward description"
	)


func test_popup_queues_consecutive_milestones() -> void:
	EventBus.milestone_completed.emit(
		"ms_1", "First", "Reward 1"
	)
	EventBus.milestone_completed.emit(
		"ms_2", "Second", "Reward 2"
	)
	EventBus.milestone_completed.emit(
		"ms_3", "Third", "Reward 3"
	)
	assert_eq(
		_popup._queue.size(), 2,
		"Two milestones should be queued while first is showing"
	)
	assert_eq(
		_popup._name_label.text, "First",
		"First milestone should be currently displayed"
	)


func test_popup_starts_offscreen_above() -> void:
	EventBus.milestone_completed.emit(
		"test_ms", "Test", "Reward"
	)
	assert_true(
		_popup.position.y < 0.0,
		"Popup should start off-screen above (negative y)"
	)


func test_banner_finished_shows_next_queued() -> void:
	EventBus.milestone_completed.emit(
		"ms_1", "First", "Reward 1"
	)
	EventBus.milestone_completed.emit(
		"ms_2", "Second", "Reward 2"
	)

	_popup._on_banner_finished()

	assert_true(
		_popup._is_showing,
		"Should be showing next queued milestone"
	)
	assert_eq(
		_popup._name_label.text, "Second",
		"Second milestone should now be displayed"
	)
	assert_eq(
		_popup._queue.size(), 0,
		"Queue should be empty after dequeue"
	)


func test_banner_finished_hides_when_queue_empty() -> void:
	EventBus.milestone_completed.emit(
		"ms_1", "Only One", "Reward"
	)

	_popup._on_banner_finished()

	assert_false(
		_popup._is_showing,
		"Should not be showing after last banner finishes"
	)
	assert_false(
		_popup.visible,
		"Popup should be hidden after last banner finishes"
	)
