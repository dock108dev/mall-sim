## Tests for MilestoneBanner milestone_unlocked animation queue.
extends GutTest


var _banner: MilestoneBanner


func before_each() -> void:
	_banner = preload(
		"res://game/scenes/ui/milestone_banner.tscn"
	).instantiate() as MilestoneBanner
	add_child_autofree(_banner)


func test_banner_starts_hidden() -> void:
	assert_false(_banner.visible, "MilestoneBanner should start hidden")


func test_banner_does_not_block_input() -> void:
	assert_eq(
		_banner.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"MilestoneBanner should not block player input"
	)


func test_banner_shows_on_milestone_unlocked() -> void:
	EventBus.milestone_unlocked.emit(&"test_milestone", {})
	assert_true(
		_banner.visible,
		"Banner should show after milestone_unlocked"
	)
	assert_true(
		_banner._is_showing,
		"Banner should mark itself as showing"
	)


func test_banner_displays_name_and_description() -> void:
	_banner._show_banner({
		"name": "Grand Opening",
		"description": "Lease your first store.",
	})
	assert_eq(_banner._name_label.text, "Grand Opening")
	assert_eq(_banner._description_label.text, "Lease your first store.")


func test_banner_queues_consecutive_unlocks() -> void:
	EventBus.milestone_unlocked.emit(&"first", {})
	EventBus.milestone_unlocked.emit(&"second", {})
	EventBus.milestone_unlocked.emit(&"third", {})
	assert_eq(
		_banner._queue.size(), 2,
		"Two milestones should queue while one is showing"
	)


func test_banner_starts_offscreen_above() -> void:
	EventBus.milestone_unlocked.emit(&"test_milestone", {})
	assert_true(
		_banner.position.y < 0.0,
		"Banner should begin above the screen"
	)


func test_banner_finished_shows_next_queued() -> void:
	EventBus.milestone_unlocked.emit(&"first", {})
	EventBus.milestone_unlocked.emit(&"second", {})

	_banner._on_banner_finished()

	assert_true(_banner._is_showing)
	assert_eq(
		_banner._queue.size(), 0,
		"Queue should be empty after showing next milestone"
	)


func test_banner_finished_hides_when_queue_empty() -> void:
	EventBus.milestone_unlocked.emit(&"first", {})

	_banner._on_banner_finished()

	assert_false(_banner._is_showing)
	assert_false(_banner.visible)
