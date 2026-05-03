## Tests for TutorialOverlay UI display, animations, and signal handling.
extends GutTest


const _OverlayScene: PackedScene = preload(
	"res://game/scenes/ui/tutorial_overlay.tscn"
)

var _tutorial: TutorialSystem
var _overlay: TutorialOverlay
var _saved_tutorial_active: bool
var _saved_game_state: GameManager.State


func before_each() -> void:
	_saved_tutorial_active = GameManager.is_tutorial_active
	_saved_game_state = GameManager.current_state
	_tutorial = TutorialSystem.new()
	add_child_autofree(_tutorial)
	_overlay = _OverlayScene.instantiate() as TutorialOverlay
	_overlay.tutorial_system = _tutorial
	add_child_autofree(_overlay)


func after_each() -> void:
	GameManager.is_tutorial_active = _saved_tutorial_active
	GameManager.current_state = _saved_game_state
	GameState.flags.clear()
	InputFocus._reset_for_tests()


func test_overlay_hidden_on_ready() -> void:
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_false(
		bar.visible,
		"BottomBar should be hidden on ready"
	)


func test_prompt_updates_on_step_changed() -> void:
	# MOVE_TO_SHELF step requires STORE_VIEW state to be visible.
	GameManager.current_state = GameManager.State.STORE_VIEW
	_tutorial.initialize(true)

	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)

	var label: Label = _overlay.get_node(
		"BottomBar/HBox/PromptLabel"
	)
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_true(
		bar.visible,
		"BottomBar should be visible after step change in STORE_VIEW"
	)
	assert_ne(
		label.text, "",
		"PromptLabel should have text after step change"
	)
	# Tutorial moved from WELCOME → MOVE_TO_SHELF; the label reflects the new step.
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.MOVE_TO_SHELF,
		"Tutorial should be on MOVE_TO_SHELF after WELCOME timer expires"
	)


func test_skip_button_emits_signal() -> void:
	_tutorial.initialize(true)
	var skip_fired: Array = [false]
	var on_skip: Callable = func() -> void:
		skip_fired[0] = true
	EventBus.skip_tutorial_requested.connect(on_skip)

	_overlay._on_skip_pressed()

	assert_true(
		skip_fired[0],
		"skip_tutorial_requested should fire on skip press"
	)
	EventBus.skip_tutorial_requested.disconnect(on_skip)


func test_overlay_hidden_when_tutorial_already_complete() -> void:
	_tutorial.tutorial_completed = true
	var overlay2: TutorialOverlay = (
		_OverlayScene.instantiate() as TutorialOverlay
	)
	overlay2.tutorial_system = _tutorial
	add_child_autofree(overlay2)

	var bar: PanelContainer = overlay2.get_node("BottomBar")
	assert_false(
		bar.visible,
		"BottomBar should remain hidden when tutorial is complete"
	)


func test_scene_has_required_nodes() -> void:
	assert_not_null(
		_overlay.get_node("BottomBar"),
		"BottomBar node should exist"
	)
	assert_not_null(
		_overlay.get_node("BottomBar/HBox/StepIcon"),
		"StepIcon node should exist"
	)
	assert_not_null(
		_overlay.get_node("BottomBar/HBox/PromptLabel"),
		"PromptLabel node should exist"
	)
	assert_not_null(
		_overlay.get_node("BottomBar/HBox/SkipButton"),
		"SkipButton node should exist"
	)


func test_bottom_bar_mouse_filter_ignores_input() -> void:
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_eq(
		bar.mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"BottomBar should have MOUSE_FILTER_IGNORE for passthrough"
	)


func test_prompt_label_font_size() -> void:
	var label: Label = _overlay.get_node(
		"BottomBar/HBox/PromptLabel"
	)
	var font_size: int = label.get_theme_font_size("font_size")
	assert_gte(
		font_size, 14,
		"PromptLabel font size should be >= 14"
	)
