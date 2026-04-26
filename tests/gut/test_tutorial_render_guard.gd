## ISSUE-003: Render-guard tests — tutorial overlay must not bleed across states.
extends GutTest


const _OverlayScene: PackedScene = preload(
	"res://game/scenes/ui/tutorial_overlay.tscn"
)

var _tutorial: TutorialSystem
var _overlay: TutorialOverlay
var _saved_game_state: GameManager.State
var _saved_tutorial_active: bool


func before_each() -> void:
	_saved_game_state = GameManager.current_state
	_saved_tutorial_active = GameManager.is_tutorial_active
	GameState.flags.clear()
	_tutorial = TutorialSystem.new()
	add_child_autofree(_tutorial)
	_overlay = _OverlayScene.instantiate() as TutorialOverlay
	_overlay.tutorial_system = _tutorial
	add_child_autofree(_overlay)
	_tutorial.initialize(true)


func after_each() -> void:
	GameManager.current_state = _saved_game_state
	GameManager.is_tutorial_active = _saved_tutorial_active
	GameState.flags.clear()
	InputFocus._reset_for_tests()


# ── _can_show_tutorial unit tests ────────────────────────────────────────────


func test_can_show_returns_false_in_main_menu() -> void:
	GameManager.current_state = GameManager.State.MAIN_MENU
	assert_false(
		_overlay._can_show_tutorial(),
		"_can_show_tutorial must return false in MAIN_MENU"
	)


func test_can_show_returns_false_in_day_summary() -> void:
	GameManager.current_state = GameManager.State.DAY_SUMMARY
	assert_false(
		_overlay._can_show_tutorial(),
		"_can_show_tutorial must return false in DAY_SUMMARY"
	)


func test_can_show_returns_false_when_modal_active() -> void:
	GameManager.current_state = GameManager.State.STORE_VIEW
	InputFocus.push_context(InputFocus.CTX_MODAL)
	assert_false(
		_overlay._can_show_tutorial(),
		"_can_show_tutorial must return false when a modal has input focus"
	)
	InputFocus.pop_context()


func test_can_show_returns_false_when_skipped_flag_set() -> void:
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	GameState.set_flag(&"tutorial_skipped", true)
	assert_false(
		_overlay._can_show_tutorial(),
		"_can_show_tutorial must return false when tutorial_skipped flag is set"
	)


func test_can_show_returns_true_in_mall_overview() -> void:
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	assert_true(
		_overlay._can_show_tutorial(),
		"_can_show_tutorial must return true in MALL_OVERVIEW"
	)


func test_can_show_returns_true_in_store_view() -> void:
	GameManager.current_state = GameManager.State.STORE_VIEW
	assert_true(
		_overlay._can_show_tutorial(),
		"_can_show_tutorial must return true in STORE_VIEW"
	)


# ── Acceptance criteria ───────────────────────────────────────────────────────


func test_no_tutorial_text_in_main_menu() -> void:
	GameManager.current_state = GameManager.State.MAIN_MENU
	_advance_to_click_store()
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_false(
		bar.visible,
		"Tutorial bar must not appear while game is in MAIN_MENU"
	)


func test_no_tutorial_text_in_day_summary() -> void:
	GameManager.current_state = GameManager.State.DAY_SUMMARY
	_advance_to_click_store()
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_false(
		bar.visible,
		"Tutorial bar must not appear while game is in DAY_SUMMARY"
	)


func test_no_tutorial_text_when_modal_open() -> void:
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	InputFocus.push_context(InputFocus.CTX_MODAL)
	_advance_to_click_store()
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_false(
		bar.visible,
		"Tutorial bar must not appear when a modal has input focus"
	)
	InputFocus.pop_context()


func test_click_store_step_visible_in_mall_overview() -> void:
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	_advance_to_click_store()
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_true(
		bar.visible,
		"Tutorial step 1 (click_store) must be visible in MALL_OVERVIEW"
	)


func test_click_store_step_not_visible_in_store_view() -> void:
	# If the player somehow triggers CLICK_STORE step while already in a store,
	# the bar must not appear.
	GameManager.current_state = GameManager.State.STORE_VIEW
	_advance_to_click_store()
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_false(
		bar.visible,
		"Tutorial step 1 (click_store) must not show when already in STORE_VIEW"
	)


func test_bar_hides_when_transitioning_to_day_summary() -> void:
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	_advance_to_click_store()
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_true(bar.visible, "Bar should be showing in MALL_OVERVIEW before transition")

	_emit_state(GameManager.State.DAY_SUMMARY)
	assert_false(
		bar.visible,
		"Tutorial bar must hide immediately when transitioning to DAY_SUMMARY"
	)


func test_bar_reshows_after_returning_from_day_summary() -> void:
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	_advance_to_click_store()
	_emit_state(GameManager.State.DAY_SUMMARY)
	_emit_state(GameManager.State.MALL_OVERVIEW)
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_true(
		bar.visible,
		"Tutorial bar must re-show when returning to MALL_OVERVIEW with click_store pending"
	)


func test_bar_hides_when_modal_opens_mid_session() -> void:
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	_advance_to_click_store()
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_true(bar.visible, "Bar should be visible before modal opens")

	InputFocus.push_context(InputFocus.CTX_MODAL)
	assert_false(
		bar.visible,
		"Tutorial bar must hide when modal context is pushed"
	)
	InputFocus.pop_context()


func test_bar_reshows_after_modal_closed() -> void:
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	_advance_to_click_store()
	InputFocus.push_context(InputFocus.CTX_MODAL)
	InputFocus.pop_context()
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_true(
		bar.visible,
		"Tutorial bar must re-show after modal context is popped"
	)


func test_open_inventory_step_visible_in_store_view() -> void:
	# Advance to CLICK_STORE in MALL_OVERVIEW, then enter store to get OPEN_INVENTORY.
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	_advance_to_click_store()
	GameManager.current_state = GameManager.State.STORE_VIEW
	EventBus.store_entered.emit(TutorialSystem.TUTORIAL_STORE_ID)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.OPEN_INVENTORY,
		"Tutorial should advance to OPEN_INVENTORY after store entry"
	)
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_true(
		bar.visible,
		"Tutorial step 2 (open_inventory) must be visible in STORE_VIEW"
	)


func test_skip_tutorial_sets_skipped_flag() -> void:
	_tutorial.skip_tutorial()
	assert_true(
		GameState.get_flag(&"tutorial_skipped"),
		"skip_tutorial must set tutorial_skipped flag in GameState"
	)


func test_skip_tutorial_clears_pending_step() -> void:
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	_advance_to_click_store()
	assert_eq(_overlay._pending_step_id, "click_store", "Pending step should be set")

	_tutorial.skip_tutorial()
	assert_eq(
		_overlay._pending_step_id, "",
		"skip_tutorial must clear _pending_step_id so overlay cannot re-show"
	)


func test_skipped_flag_suppresses_future_step_renders() -> void:
	GameState.set_flag(&"tutorial_skipped", true)
	GameManager.current_state = GameManager.State.MALL_OVERVIEW
	# Force a step-changed emission as if the system fired
	EventBus.tutorial_step_changed.emit("click_store")
	var bar: PanelContainer = _overlay.get_node("BottomBar")
	assert_false(
		bar.visible,
		"Bar must not show after tutorial_step_changed when tutorial_skipped flag is set"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _advance_to_click_store() -> void:
	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)


func _emit_state(new_state: GameManager.State) -> void:
	var old: GameManager.State = GameManager.current_state
	GameManager.current_state = new_state
	EventBus.game_state_changed.emit(int(old), int(new_state))
