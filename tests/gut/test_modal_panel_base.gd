## ModalPanel base class — verifies the open/close/_exit_tree contract that
## all modal panels inherit. Covers: single-push semantics, double-open guard,
## close round-trip, _exit_tree auto-pop on freed-while-open, and the
## sibling-frame protection in _pop_modal_focus.
extends GutTest


const ModalPanelScript: GDScript = preload("res://game/scripts/ui/modal_panel.gd")


var _focus: Node


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	assert_not_null(_focus, "InputFocus autoload required")
	if _focus != null:
		_focus._reset_for_tests()


func after_each() -> void:
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func _make_panel() -> ModalPanel:
	var panel := ModalPanelScript.new() as ModalPanel
	add_child_autofree(panel)
	return panel


func test_open_pushes_ctx_modal_once() -> void:
	var panel: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	panel.open()

	assert_eq(_focus.depth(), baseline + 1, "open() pushes exactly one frame")
	assert_eq(_focus.current(), InputFocus.CTX_MODAL)
	assert_true(panel._focus_pushed, "panel records ownership")


func test_close_pops_ctx_modal() -> void:
	var panel: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	panel.open()
	panel.close()

	assert_eq(_focus.depth(), baseline, "close() pops the frame")
	assert_eq(_focus.current(), InputFocus.CTX_STORE_GAMEPLAY)
	assert_false(panel._focus_pushed)


func test_double_open_no_double_push_emits_push_error() -> void:
	var panel: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	panel.open()
	panel.open()

	assert_eq(
		_focus.depth(), baseline + 1,
		"second open() must not push a second frame"
	)
	# Cleanup so after_each resets cleanly.
	panel.close()


func test_double_close_is_idempotent() -> void:
	var panel: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	panel.open()
	panel.close()
	panel.close()

	assert_eq(
		_focus.depth(), baseline,
		"second close() must not pop a frame the panel does not own"
	)


func test_repeated_open_close_does_not_leak() -> void:
	var panel: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	for i: int in range(5):
		panel.open()
		assert_eq(_focus.depth(), baseline + 1)
		panel.close()
		assert_eq(_focus.depth(), baseline)


func test_exit_tree_auto_pops_dangling_frame() -> void:
	var panel := ModalPanelScript.new() as ModalPanel
	add_child(panel)
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	panel.open()
	assert_eq(_focus.depth(), baseline + 1)

	# Free without close() — _exit_tree must clean up.
	remove_child(panel)
	panel.free()

	assert_eq(
		_focus.depth(), baseline,
		"_exit_tree must auto-pop the dangling CTX_MODAL frame"
	)


func test_pop_skips_when_ctx_modal_not_on_top() -> void:
	# Sibling pushes after our open() — our pop must NOT corrupt their frame.
	var panel: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	panel.open()
	# Simulate a sibling/system pushing a non-modal context above ours.
	_focus.push_context(&"foreign_ctx")
	var depth_after_foreign: int = _focus.depth()
	assert_eq(_focus.current(), &"foreign_ctx")

	# close() finds a non-CTX_MODAL top — must skip the pop, clear the flag,
	# and leave the foreign frame alone.
	panel.close()

	assert_eq(
		_focus.depth(), depth_after_foreign,
		"close() must not pop when CTX_MODAL is no longer on top"
	)
	assert_eq(_focus.current(), &"foreign_ctx")
	assert_false(panel._focus_pushed, "flag cleared even when pop is skipped")
	# Cleanup: pop the foreign frame, then the leftover CTX_MODAL frame the
	# panel did not pop. Depth then returns to baseline.
	_focus.pop_context()
	_focus.pop_context()
	assert_eq(_focus.depth(), baseline)


func test_reset_for_tests_clears_flag_without_popping() -> void:
	var panel: ModalPanel = _make_panel()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	panel.open()
	assert_true(panel._focus_pushed)

	panel._reset_for_tests()

	assert_false(panel._focus_pushed)
	assert_eq(
		_focus.current(), InputFocus.CTX_MODAL,
		"_reset_for_tests must NOT call pop_context"
	)
