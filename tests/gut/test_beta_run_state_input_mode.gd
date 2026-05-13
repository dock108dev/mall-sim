## BetaRunState.set_input_mode is bookkeeping for the debug overlay only —
## cursor lock and input gating are owned by InputFocus (push/pop via
## ModalPanel). These tests guard against regressions where the cursor side
## effects or InputFocus stack writes get reintroduced.
extends GutTest


var _cursor_locked_count: int = 0
var _cursor_unlocked_count: int = 0
var _emitted_modes: Array[int] = []
var _focus: Node


func before_each() -> void:
	_cursor_locked_count = 0
	_cursor_unlocked_count = 0
	_emitted_modes.clear()
	EventBus.cursor_locked.connect(_on_cursor_locked)
	EventBus.cursor_unlocked.connect(_on_cursor_unlocked)
	BetaRunState.input_mode_changed.connect(_on_input_mode_changed)
	_focus = get_tree().root.get_node_or_null("InputFocus")
	if _focus != null:
		_focus._reset_for_tests()
	BetaRunState.input_mode = BetaRunState.INPUT_MODE_GAMEPLAY


func after_each() -> void:
	if EventBus.cursor_locked.is_connected(_on_cursor_locked):
		EventBus.cursor_locked.disconnect(_on_cursor_locked)
	if EventBus.cursor_unlocked.is_connected(_on_cursor_unlocked):
		EventBus.cursor_unlocked.disconnect(_on_cursor_unlocked)
	if BetaRunState.input_mode_changed.is_connected(_on_input_mode_changed):
		BetaRunState.input_mode_changed.disconnect(_on_input_mode_changed)
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()
	BetaRunState.input_mode = BetaRunState.INPUT_MODE_GAMEPLAY


func _on_cursor_locked() -> void:
	_cursor_locked_count += 1


func _on_cursor_unlocked() -> void:
	_cursor_unlocked_count += 1


func _on_input_mode_changed(new_mode: int) -> void:
	_emitted_modes.append(new_mode)


func test_set_input_mode_decision_card_does_not_emit_cursor_signals() -> void:
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DECISION_CARD)

	assert_eq(
		_cursor_unlocked_count, 0,
		"set_input_mode(DECISION_CARD) must not unlock the cursor — that authority lives in ModalPanel/InputFocus"
	)
	assert_eq(
		_cursor_locked_count, 0,
		"set_input_mode(DECISION_CARD) must not lock the cursor"
	)


func test_set_input_mode_day_summary_does_not_emit_cursor_signals() -> void:
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DAY_SUMMARY)

	assert_eq(
		_cursor_unlocked_count, 0,
		"set_input_mode(DAY_SUMMARY) must not unlock the cursor"
	)
	assert_eq(
		_cursor_locked_count, 0,
		"set_input_mode(DAY_SUMMARY) must not lock the cursor"
	)


func test_set_input_mode_gameplay_does_not_emit_cursor_signals() -> void:
	BetaRunState.input_mode = BetaRunState.INPUT_MODE_DECISION_CARD

	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)

	assert_eq(
		_cursor_locked_count, 0,
		"Returning to GAMEPLAY mode must not lock the cursor — locking is driven by ModalPanel close popping CTX_MODAL"
	)
	assert_eq(
		_cursor_unlocked_count, 0,
		"Returning to GAMEPLAY mode must not unlock the cursor"
	)


func test_set_input_mode_does_not_push_input_focus() -> void:
	if _focus == null:
		pending("InputFocus autoload required")
		return
	var baseline: int = _focus.depth()

	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DAY_SUMMARY)
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DECISION_CARD)
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_GAMEPLAY)

	assert_eq(
		_focus.depth(), baseline,
		"set_input_mode must never push or pop InputFocus — that authority is owned by ModalPanel"
	)


func test_set_input_mode_emits_input_mode_changed_signal() -> void:
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DAY_SUMMARY)

	assert_eq(
		_emitted_modes,
		[BetaRunState.INPUT_MODE_DAY_SUMMARY],
		"set_input_mode must still emit input_mode_changed for the debug overlay"
	)


func test_set_input_mode_equality_guard_skips_redundant_emit() -> void:
	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DAY_SUMMARY)
	_emitted_modes.clear()

	BetaRunState.set_input_mode(BetaRunState.INPUT_MODE_DAY_SUMMARY)

	assert_eq(
		_emitted_modes,
		[] as Array[int],
		"Re-setting the same mode must early-return without re-emitting"
	)
