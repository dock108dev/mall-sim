extends GutTest


const BetaDayTwoPlaceholderPanelScript: GDScript = preload(
	"res://game/scripts/beta/beta_day_two_placeholder_panel.gd"
)

var _focus: Node
var _queue: Node
var _panel: ModalPanel


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	_queue = get_tree().root.get_node_or_null("ModalQueue")
	assert_not_null(_focus, "InputFocus autoload required")
	assert_not_null(_queue, "ModalQueue autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	if _queue != null:
		_queue._reset_for_tests()
	_panel = BetaDayTwoPlaceholderPanelScript.new() as ModalPanel
	add_child_autofree(_panel)


func after_each() -> void:
	if is_instance_valid(_panel):
		_panel._reset_for_tests()
	if _queue != null and is_instance_valid(_queue):
		_queue._reset_for_tests()
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func test_placeholder_copy_names_completed_slice_and_no_gameplay() -> void:
	_panel.call("show_placeholder")

	var body: Label = _panel.get("_body_label") as Label
	assert_not_null(body, "Placeholder must own body copy")
	if body == null:
		return
	assert_true(
		body.text.contains("vertical slice is complete"),
		"Placeholder must say the slice is complete; got: '%s'" % body.text
	)
	assert_true(
		body.text.contains("does not start unfinished store gameplay"),
		"Placeholder must explicitly avoid unfinished gameplay; got: '%s'" % body.text
	)


func test_placeholder_buttons_emit_stable_exit_signals() -> void:
	_panel.call("show_placeholder")
	watch_signals(_panel)

	var main_menu: Button = _panel.get("_main_menu_button") as Button
	var restart: Button = _panel.get("_restart_button") as Button
	assert_not_null(main_menu, "Placeholder must own Return to Menu")
	assert_not_null(restart, "Placeholder must own Restart Day 1")
	if main_menu == null or restart == null:
		return

	main_menu.pressed.emit()
	restart.pressed.emit()

	assert_signal_emitted(_panel, "main_menu_pressed")
	assert_signal_emitted(_panel, "restart_pressed")


func test_show_placeholder_claims_modal_focus() -> void:
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	var baseline: int = _focus.depth()

	_panel.call("show_placeholder")

	assert_eq(
		_focus.depth(),
		baseline + 1,
		"Placeholder must own one CTX_MODAL frame while open"
	)
	assert_true(bool(_panel.get("_focus_pushed")))
