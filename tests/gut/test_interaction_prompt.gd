## Tests for InteractionPrompt visibility, label text, and fade behaviour.
extends GutTest


var _prompt: CanvasLayer


func before_each() -> void:
	_prompt = preload(
		"res://game/scenes/ui/interaction_prompt.tscn"
	).instantiate()
	add_child_autofree(_prompt)


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
