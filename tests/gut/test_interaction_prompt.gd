## Tests for InteractionPrompt visibility, label text, fade behaviour, and
## the screen-state / modal-context visibility guards added for ISSUE-004.
extends GutTest


var _prompt: CanvasLayer
var _saved_state: GameManager.State


func before_each() -> void:
	_saved_state = GameManager.current_state
	# STORE_VIEW lets the focus → visible path run; the new guards block
	# MAIN_MENU and DAY_SUMMARY explicitly, which is what the new tests cover.
	GameManager.current_state = GameManager.State.STORE_VIEW
	_prompt = preload(
		"res://game/scenes/ui/interaction_prompt.tscn"
	).instantiate()
	add_child_autofree(_prompt)


func after_each() -> void:
	GameManager.current_state = _saved_state
	if InputFocus != null:
		InputFocus._reset_for_tests()


func _emit_state(new_state: GameManager.State) -> void:
	var old: GameManager.State = GameManager.current_state
	GameManager.current_state = new_state
	EventBus.game_state_changed.emit(int(old), int(new_state))


func test_hidden_by_default() -> void:
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_false(
		panel.visible,
		"Panel should be hidden on ready"
	)
	assert_eq(
		panel.modulate.a, 0.0,
		"Panel alpha should be 0 on ready"
	)


func test_shows_on_interactable_focused() -> void:
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_true(
		panel.visible,
		"Panel should become visible after interactable_focused"
	)


func test_focus_fade_reaches_full_alpha() -> void:
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	await get_tree().create_timer(0.2).timeout
	assert_almost_eq(
		panel.modulate.a,
		1.0,
		0.05,
		"Panel alpha should tween to fully visible on focus"
	)


func test_label_text_driven_by_action_label() -> void:
	EventBus.interactable_focused.emit("Examine Item")
	var label: Label = _prompt.get_node("PanelContainer/Label")
	assert_eq(
		label.text, "Examine Item",
		"Label should display the action_label verbatim (callers include key prefix)"
	)


func test_label_displays_click_prefix() -> void:
	EventBus.interactable_focused.emit("[Click] Enter Store")
	var label: Label = _prompt.get_node("PanelContainer/Label")
	assert_eq(
		label.text, "[Click] Enter Store",
		"Label must preserve caller-supplied key prefix"
	)


func test_label_updates_on_new_focus() -> void:
	EventBus.interactable_focused.emit("[E] Enter Store")
	EventBus.interactable_focused.emit("[E] Stock Shelf")
	var label: Label = _prompt.get_node("PanelContainer/Label")
	assert_eq(
		label.text, "[E] Stock Shelf",
		"Label should update when a new interactable is focused"
	)


func test_hides_after_unfocused_tween_completes() -> void:
	EventBus.interactable_focused.emit("Use Register")
	EventBus.interactable_unfocused.emit()
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	await get_tree().create_timer(0.2).timeout
	assert_almost_eq(
		panel.modulate.a,
		0.0,
		0.05,
		"Panel alpha should tween back to zero on unfocus"
	)
	assert_false(
		panel.visible,
		"Panel should be hidden after unfocused fade completes"
	)


func test_does_not_block_mouse_input() -> void:
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_eq(
		panel.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Panel should not intercept mouse events"
	)


# ── Screen-state guard ─────────────────────────────────────────────────────────

func test_does_not_show_in_main_menu_state() -> void:
	_emit_state(GameManager.State.MAIN_MENU)
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_false(
		panel.visible,
		"Prompt must not appear when state is MAIN_MENU"
	)


func test_does_not_show_in_day_summary_state() -> void:
	_emit_state(GameManager.State.DAY_SUMMARY)
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_false(
		panel.visible,
		"Prompt must not appear when state is DAY_SUMMARY"
	)


func test_hides_when_state_changes_to_main_menu_after_focus() -> void:
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_true(panel.visible, "Pre-condition: prompt visible in STORE_VIEW")
	_emit_state(GameManager.State.MAIN_MENU)
	await get_tree().create_timer(0.2).timeout
	assert_false(
		panel.visible,
		"Prompt must hide once state changes to MAIN_MENU"
	)


# ── Modal context guard ────────────────────────────────────────────────────────

func test_hides_when_modal_context_pushed() -> void:
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_true(panel.visible, "Pre-condition: prompt visible without modal")
	InputFocus.push_context(InputFocus.CTX_MODAL)
	await get_tree().create_timer(0.2).timeout
	assert_false(
		panel.visible,
		"Prompt must hide while modal context is on top of InputFocus stack"
	)


func test_reappears_when_modal_context_popped() -> void:
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	InputFocus.push_context(InputFocus.CTX_MODAL)
	await get_tree().create_timer(0.2).timeout
	assert_false(panel.visible, "Pre-condition: hidden under modal")
	InputFocus.pop_context()
	assert_true(
		panel.visible,
		"Prompt must reappear when modal context is popped while focus target persists"
	)


func test_does_not_show_when_focus_arrives_during_modal() -> void:
	InputFocus.push_context(InputFocus.CTX_MODAL)
	EventBus.interactable_focused.emit("Enter Store")
	var panel: PanelContainer = _prompt.get_node("PanelContainer")
	assert_false(
		panel.visible,
		"Prompt must not become visible when focus arrives while modal is active"
	)
