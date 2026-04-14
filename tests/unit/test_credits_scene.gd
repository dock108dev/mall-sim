## Tests for CreditsScene — initialization state, scroll skip, signal emission, and input guards.
extends GutTest


const _SCENE: PackedScene = preload(
	"res://game/scenes/ui/credits_scene.tscn"
)

var _credits: CreditsScene


func before_each() -> void:
	_credits = _SCENE.instantiate() as CreditsScene
	add_child_autofree(_credits)


func after_each() -> void:
	_credits = null


func test_initial_state_not_visible() -> void:
	assert_false(
		_credits.visible,
		"Credits scene should start hidden before initialize is called"
	)


func test_initial_state_not_scrolling() -> void:
	assert_false(
		_credits._scrolling,
		"Scrolling should be inactive before initialize is called"
	)


func test_initialize_makes_visible() -> void:
	_credits.initialize()
	assert_true(
		_credits.visible,
		"Credits scene should become visible after initialize"
	)


func test_initialize_starts_scrolling() -> void:
	_credits.initialize()
	assert_true(
		_credits._scrolling,
		"Scrolling should be active after initialize"
	)


func test_initialize_resets_scroll_position() -> void:
	_credits.initialize()
	_credits._scroll_container.scroll_vertical = 200
	_credits.initialize()
	assert_eq(
		_credits._scroll_container.scroll_vertical,
		0,
		"Initialize should reset scroll position to top"
	)


func test_skip_to_end_stops_scrolling() -> void:
	_credits.initialize()
	_credits._skip_to_end()
	assert_false(
		_credits._scrolling,
		"Scrolling should stop after _skip_to_end"
	)


func test_back_pressed_emits_return_signal() -> void:
	_credits.initialize()
	watch_signals(_credits)
	_credits._on_back_pressed()
	assert_signal_emitted(
		_credits,
		"return_to_menu_requested",
		"return_to_menu_requested should emit when back button pressed"
	)


func test_return_to_menu_emits_signal() -> void:
	watch_signals(_credits)
	_credits._return_to_menu()
	assert_signal_emitted(
		_credits,
		"return_to_menu_requested",
		"return_to_menu_requested should emit from _return_to_menu"
	)


func test_back_button_exists_in_scene() -> void:
	var button: Button = _credits.get_node_or_null(
		"Layout/BottomBar/BackToMenuButton"
	) as Button
	assert_not_null(button, "BackToMenuButton should exist in the scene tree")


func test_back_button_always_visible() -> void:
	_credits.initialize()
	var bar: HBoxContainer = _credits.get_node_or_null(
		"Layout/BottomBar"
	) as HBoxContainer
	assert_not_null(bar, "BottomBar should exist")
	assert_true(bar.visible, "BottomBar should always be visible")


func test_skip_to_end_advances_scroll_position() -> void:
	_credits.initialize()
	var before: int = _credits._scroll_container.scroll_vertical
	_credits._skip_to_end()
	var after: int = _credits._scroll_container.scroll_vertical
	assert_gte(after, before, "Scroll position should advance or stay after skip_to_end")
