extends GutTest


const DecisionPanelScript: GDScript = preload(
	"res://game/scripts/beta/beta_decision_card_panel.gd"
)
const ResultPanelScript: GDScript = preload(
	"res://game/scripts/beta/beta_customer_result_panel.gd"
)
const CloseDayPanelScene: PackedScene = preload(
	"res://game/scenes/ui/close_day_confirmation_panel.tscn"
)

var _focus: Node
var _queue: Node


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	_queue = get_tree().root.get_node_or_null("ModalQueue")
	assert_not_null(_focus, "InputFocus autoload required")
	assert_not_null(_queue, "ModalQueue autoload required")
	if _focus != null:
		_focus._reset_for_tests()
	if _queue != null:
		_queue._reset_for_tests()
	_focus.push_context(InputFocus.CTX_STORE_GAMEPLAY)


func after_each() -> void:
	if _queue != null and is_instance_valid(_queue):
		_queue._reset_for_tests()
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func test_decision_card_focuses_first_choice_on_open() -> void:
	var panel: BetaDecisionCardPanel = _add_decision_panel()

	panel.show_event(_event_payload())
	await get_tree().process_frame

	var buttons: Array = panel.get("_choice_buttons") as Array
	assert_eq(_focus.current(), InputFocus.CTX_MODAL)
	assert_eq(
		get_viewport().gui_get_focus_owner(),
		buttons[0],
		"Decision card must focus the first choice when it opens"
	)
	panel.close()


func test_decision_card_numeric_shortcut_selects_once() -> void:
	var panel: BetaDecisionCardPanel = _add_decision_panel()
	panel.show_event(_event_payload())
	await get_tree().process_frame
	watch_signals(panel)

	panel._unhandled_input(_key_event(KEY_2, 50))
	panel._unhandled_input(_key_event(KEY_2, 50))

	assert_signal_emit_count(panel, "choice_selected", 1)
	var params: Array = get_signal_parameters(panel, "choice_selected", 0)
	assert_eq(params[0], &"two")
	assert_false(panel.visible)
	assert_eq(_focus.current(), InputFocus.CTX_STORE_GAMEPLAY)


func test_decision_card_enter_activates_focused_choice() -> void:
	var panel: BetaDecisionCardPanel = _add_decision_panel()
	panel.show_event(_event_payload())
	await get_tree().process_frame
	watch_signals(panel)

	panel._unhandled_input(_action_event(&"ui_accept"))

	assert_signal_emit_count(panel, "choice_selected", 1)
	var params: Array = get_signal_parameters(panel, "choice_selected", 0)
	assert_eq(params[0], &"one")
	assert_eq(_focus.current(), InputFocus.CTX_STORE_GAMEPLAY)


func test_decision_card_escape_does_not_close() -> void:
	var panel: BetaDecisionCardPanel = _add_decision_panel()
	panel.show_event(_event_payload())
	await get_tree().process_frame
	watch_signals(panel)
	var depth: int = _focus.depth()

	panel._unhandled_input(_action_event(&"ui_cancel"))

	assert_true(panel.visible)
	assert_eq(_focus.depth(), depth)
	assert_signal_not_emitted(panel, "choice_selected")
	panel.close()


func test_decision_card_tab_focus_wraps_inside_choices() -> void:
	var panel: BetaDecisionCardPanel = _add_decision_panel()
	panel.show_event(_event_payload())
	await get_tree().process_frame
	var buttons: Array = panel.get("_choice_buttons") as Array

	panel._unhandled_input(_tab_event(false))
	assert_eq(get_viewport().gui_get_focus_owner(), buttons[1])

	panel._unhandled_input(_tab_event(true))
	assert_eq(get_viewport().gui_get_focus_owner(), buttons[0])
	panel.close()


func test_customer_result_focuses_continue_on_open() -> void:
	var panel: ModalPanel = _add_result_panel()

	panel.call("show_result", _result_payload())
	await get_tree().process_frame

	var button: Button = panel.get("_continue_button") as Button
	assert_eq(_focus.current(), InputFocus.CTX_MODAL)
	assert_eq(
		get_viewport().gui_get_focus_owner(),
		button,
		"Customer result must focus Continue when it opens"
	)
	panel.close()


func test_customer_result_enter_acknowledges_once() -> void:
	var panel: ModalPanel = _add_result_panel()
	panel.call("show_result", _result_payload())
	await get_tree().process_frame
	watch_signals(panel)

	panel.call("_unhandled_input", _action_event(&"ui_accept"))
	panel.call("_unhandled_input", _action_event(&"ui_accept"))

	assert_signal_emit_count(panel, "result_acknowledged", 1)
	var params: Array = get_signal_parameters(panel, "result_acknowledged", 0)
	assert_eq(params[0], &"customer_test")
	assert_eq(params[1], &"clean_exchange")
	assert_false(panel.visible)
	assert_eq(_focus.current(), InputFocus.CTX_STORE_GAMEPLAY)


func test_customer_result_escape_does_not_close() -> void:
	var panel: ModalPanel = _add_result_panel()
	panel.call("show_result", _result_payload())
	await get_tree().process_frame
	watch_signals(panel)
	var depth: int = _focus.depth()

	panel.call("_unhandled_input", _action_event(&"ui_cancel"))

	assert_true(panel.visible)
	assert_eq(_focus.depth(), depth)
	assert_signal_not_emitted(panel, "result_acknowledged")
	panel.close()


func test_customer_result_renders_authored_consequence_rows() -> void:
	var panel: ModalPanel = _add_result_panel()
	panel.call("show_result", _result_payload())
	await get_tree().process_frame

	var box: VBoxContainer = panel.get("_consequences_box") as VBoxContainer
	assert_not_null(box)
	if box != null:
		assert_eq(
			box.get_child_count(),
			4,
			"Customer result must render each authored consequence row"
		)
		assert_string_contains((box.get_child(2) as Label).text, "Inventory")
	panel.close()


func test_close_day_panel_escape_cancels_and_restores_gameplay() -> void:
	var panel: CloseDayConfirmationPanel = _add_close_day_panel()
	panel.show_with_reason("Stock the shelves first.")
	await get_tree().process_frame
	watch_signals(EventBus)

	panel._unhandled_input(_action_event(&"ui_cancel"))

	assert_false(panel.visible)
	assert_signal_not_emitted(EventBus, "day_close_confirmed")
	assert_eq(_focus.current(), InputFocus.CTX_STORE_GAMEPLAY)


func test_close_day_panel_enter_uses_focused_button_once() -> void:
	var panel: CloseDayConfirmationPanel = _add_close_day_panel()
	panel.show_with_reason("Stock the shelves first.")
	await get_tree().process_frame
	watch_signals(EventBus)
	panel._confirm_button.grab_focus()

	panel._unhandled_input(_action_event(&"ui_accept"))
	panel._unhandled_input(_action_event(&"ui_accept"))

	assert_signal_emit_count(EventBus, "day_close_confirmed", 1)
	assert_false(panel.visible)
	assert_eq(_focus.current(), InputFocus.CTX_STORE_GAMEPLAY)


func test_close_day_panel_queues_behind_active_decision() -> void:
	var decision: BetaDecisionCardPanel = _add_decision_panel()
	var close_day: CloseDayConfirmationPanel = _add_close_day_panel()
	decision.show_event(_event_payload())

	close_day.show_with_reason("Stock the shelves first.")

	assert_eq(_queue.active_panel(), decision)
	assert_eq(_queue.pending_count(), 1)
	assert_false(close_day.visible)

	decision.close()
	await get_tree().process_frame

	assert_eq(_queue.active_panel(), close_day)
	assert_true(close_day.visible)
	assert_eq(_focus.current(), InputFocus.CTX_MODAL)
	close_day.close()


func _add_decision_panel() -> BetaDecisionCardPanel:
	var panel: BetaDecisionCardPanel = (
		DecisionPanelScript.new() as BetaDecisionCardPanel
	)
	add_child_autofree(panel)
	return panel


func _add_result_panel() -> ModalPanel:
	var panel: ModalPanel = ResultPanelScript.new() as ModalPanel
	add_child_autofree(panel)
	return panel


func _add_close_day_panel() -> CloseDayConfirmationPanel:
	var panel: CloseDayConfirmationPanel = (
		CloseDayPanelScene.instantiate() as CloseDayConfirmationPanel
	)
	add_child_autofree(panel)
	return panel


func _event_payload() -> Dictionary:
	return {
		"title": "Wrong Platform",
		"body": "A customer needs a clean, readable choice.",
		"choices": [
			{"id": "one", "label": "Exchange it cleanly.", "effects": {}},
			{"id": "two", "label": "Offer the bundle.", "effects": {"cash": 15}},
			{"id": "three", "label": "Decline the return.", "effects": {}},
		],
	}


func _result_payload() -> Dictionary:
	return {
		"event_id": &"customer_test",
		"choice_id": &"clean_exchange",
		"customer_name": "Stressed Parent",
		"event_title": "Wrong Platform",
		"choice_label": "Swap it cleanly.",
		"effects": {"cash": 15, "reputation": 2},
		"result": {
			"headline": "Exchange Accepted",
			"customer_reaction": "The parent relaxes.",
			"store_outcome": "The line keeps moving.",
			"manager_note": "Clean call.",
			"consequences": [
				{"label": "Money", "text": "+$15 sale kept."},
				{"label": "Reputation", "text": "+2 satisfaction."},
				{"label": "Inventory", "text": "Correct copy out; wrong copy in."},
				{"label": "Policy", "text": "+2 manager trust."},
			],
		},
	}


func _action_event(action: StringName) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _key_event(keycode: int, unicode: int = 0) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.unicode = unicode
	event.pressed = true
	return event


func _tab_event(shift_pressed: bool) -> InputEventKey:
	var event: InputEventKey = _key_event(KEY_TAB)
	event.shift_pressed = shift_pressed
	return event
