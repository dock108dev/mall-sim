## Tests for HintOverlayUI visibility, positioning, dismiss, and replacement.
extends GutTest


var _overlay: HintOverlayUI


func before_each() -> void:
	# Modal-coexistence tests drive InputFocus directly, so make sure each test
	# starts with an empty stack and the prior test's frames don't leak.
	InputFocus._reset_for_tests()
	_overlay = preload(
		"res://game/scenes/ui/hint_overlay_ui.tscn"
	).instantiate() as HintOverlayUI
	add_child_autofree(_overlay)


func after_each() -> void:
	InputFocus._reset_for_tests()


func test_starts_hidden() -> void:
	assert_false(
		_overlay.visible,
		"HintOverlayUI should be hidden on ready"
	)


func test_visible_on_hint_shown() -> void:
	EventBus.onboarding_hint_shown.emit(
		&"test_hint", "Welcome to the mall!", "top_center"
	)
	assert_true(
		_overlay.visible,
		"Overlay should become visible after onboarding_hint_shown"
	)
	assert_true(
		_overlay._is_showing,
		"_is_showing should be true while hint is displayed"
	)


func test_displays_message_text() -> void:
	EventBus.onboarding_hint_shown.emit(
		&"hint_stock", "Stock your shelves!", "center"
	)
	assert_eq(
		_overlay._message_label.text, "Stock your shelves!",
		"Message label should show the hint message"
	)


func test_replaces_current_hint() -> void:
	EventBus.onboarding_hint_shown.emit(
		&"hint_1", "First hint", "top_center"
	)
	EventBus.onboarding_hint_shown.emit(
		&"hint_2", "Second hint", "bottom_left"
	)
	assert_eq(
		_overlay._message_label.text, "Second hint",
		"New hint should replace the current one"
	)
	assert_true(
		_overlay._is_showing,
		"Should still be showing after replacement"
	)


func test_dismiss_hides_panel() -> void:
	EventBus.onboarding_hint_shown.emit(
		&"hint_dismiss", "Dismissible hint", "center"
	)
	_overlay._dismiss()
	_overlay._on_dismiss_finished()
	assert_false(
		_overlay.visible,
		"Overlay should be hidden after dismiss completes"
	)
	assert_false(
		_overlay._is_showing,
		"_is_showing should be false after dismiss"
	)


func test_does_not_block_input_when_hidden() -> void:
	assert_eq(
		_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Hidden overlay should not intercept mouse input"
	)


func test_blocks_input_when_showing() -> void:
	EventBus.onboarding_hint_shown.emit(
		&"hint_input", "Click me to dismiss", "center"
	)
	assert_eq(
		_overlay.mouse_filter, Control.MOUSE_FILTER_STOP,
		"Visible overlay should intercept mouse clicks for dismiss"
	)


func test_position_top_center() -> void:
	EventBus.onboarding_hint_shown.emit(
		&"hint_pos", "Top hint", "top_center"
	)
	assert_eq(
		_overlay.offset_top, 60.0,
		"top_center should set offset_top to 60"
	)


func test_position_bottom_left() -> void:
	EventBus.onboarding_hint_shown.emit(
		&"hint_pos", "Bottom left hint", "bottom_left"
	)
	assert_eq(
		_overlay.offset_bottom, -20.0,
		"bottom_left should set offset_bottom to -20"
	)


func test_position_bottom_right() -> void:
	EventBus.onboarding_hint_shown.emit(
		&"hint_pos", "Bottom right hint", "bottom_right"
	)
	assert_eq(
		_overlay.offset_right, -20.0,
		"bottom_right should set offset_right to -20"
	)


func test_position_center() -> void:
	EventBus.onboarding_hint_shown.emit(
		&"hint_pos", "Center hint", "center"
	)
	assert_eq(
		_overlay.offset_left, -160.0,
		"center should set offset_left to -160"
	)
	assert_eq(
		_overlay.offset_right, 160.0,
		"center should set offset_right to 160"
	)


# ── Modal coexistence ────────────────────────────────────────────────────────


func test_visible_hint_dismisses_when_modal_takes_focus() -> void:
	# Path 1 — modal opens while hint is showing.
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	EventBus.onboarding_hint_shown.emit(
		&"hint_path1", "Visible hint", "center"
	)
	assert_true(
		_overlay._is_showing,
		"Pre-condition: hint visible before modal opens"
	)
	InputFocus.push_context(InputFocus.CTX_MODAL)
	assert_false(
		_overlay._is_showing,
		"Hint must dismiss the same frame CTX_MODAL takes the top frame"
	)


func test_hint_suppressed_when_emitted_during_open_modal() -> void:
	# Path 2 — hint fires while CTX_MODAL is already on top. context_changed
	# would not re-fire here, so only the show-time guard catches it.
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	InputFocus.push_context(InputFocus.CTX_MODAL)
	EventBus.onboarding_hint_shown.emit(
		&"hint_path2", "Suppressed hint", "center"
	)
	assert_false(
		_overlay._is_showing,
		"No hint may begin animating while CTX_MODAL is on top"
	)
	assert_false(
		_overlay.visible,
		"Suppressed hint must not become visible"
	)


func test_suppressed_hint_does_not_appear_after_modal_closes() -> void:
	# OnboardingSystem._shown_hints owns dedupe; HintOverlayUI does not retry
	# on its own. Popping CTX_MODAL must not resurrect the suppressed hint.
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	InputFocus.push_context(InputFocus.CTX_MODAL)
	EventBus.onboarding_hint_shown.emit(
		&"hint_dedupe", "Once and done", "center"
	)
	InputFocus.pop_context()
	assert_false(
		_overlay._is_showing,
		"Hint must remain suppressed after the modal pops — dedupe lives in OnboardingSystem"
	)
	assert_false(
		_overlay.visible,
		"Hint must remain hidden after the modal pops"
	)


func test_non_modal_context_change_does_not_dismiss_visible_hint() -> void:
	# Guard rail — only CTX_MODAL transitions should dismiss; other context
	# pushes (e.g. mall hub → store gameplay) must leave the hint alone so
	# `onboarding_disabled` + auto-dismiss remain the only normal exits.
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	EventBus.onboarding_hint_shown.emit(
		&"hint_no_modal", "Stay up", "center"
	)
	assert_true(_overlay._is_showing, "Pre-condition: hint visible")
	InputFocus.push_context(InputFocus.CTX_MALL_HUB)
	assert_true(
		_overlay._is_showing,
		"Non-modal context change must not dismiss the hint"
	)
