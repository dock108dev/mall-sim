## Tests for the center-screen crosshair reticle: visibility tracks
## InputFocus.current() so the reticle shows during store gameplay and hides
## under modals, mall hub, and main menu contexts.
extends GutTest


var _crosshair: CanvasLayer


func before_each() -> void:
	if InputFocus != null:
		InputFocus._reset_for_tests()
	_crosshair = preload(
		"res://game/scenes/ui/crosshair.tscn"
	).instantiate()
	add_child_autofree(_crosshair)


func after_each() -> void:
	if InputFocus != null:
		InputFocus._reset_for_tests()


func test_hidden_when_focus_stack_empty() -> void:
	assert_false(
		_crosshair.visible,
		"Crosshair must be hidden when no InputFocus context is active"
	)


func test_visible_under_store_gameplay_context() -> void:
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	assert_true(
		_crosshair.visible,
		"Crosshair must be visible while CTX_STORE_GAMEPLAY is on top"
	)


func test_hidden_under_modal_context() -> void:
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	assert_true(_crosshair.visible, "Pre-condition: visible during gameplay")
	InputFocus.push_context(InputFocus.CTX_MODAL)
	assert_false(
		_crosshair.visible,
		"Crosshair must hide when a modal context is pushed on top"
	)


func test_reappears_when_modal_popped() -> void:
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)
	InputFocus.push_context(InputFocus.CTX_MODAL)
	assert_false(_crosshair.visible, "Pre-condition: hidden under modal")
	InputFocus.pop_context()
	assert_true(
		_crosshair.visible,
		"Crosshair must reappear once modal pops back to gameplay"
	)


func test_hidden_under_mall_hub_context() -> void:
	InputFocus.push_context(InputFocus.CTX_MALL_HUB)
	assert_false(
		_crosshair.visible,
		"Crosshair must stay hidden in the mall hub"
	)


func test_hidden_under_main_menu_context() -> void:
	InputFocus.push_context(InputFocus.CTX_MAIN_MENU)
	assert_false(
		_crosshair.visible,
		"Crosshair must stay hidden in the main menu"
	)


func test_label_renders_plus_glyph() -> void:
	var label: Label = _crosshair.get_node("CenterContainer/Label")
	assert_eq(
		label.text, "+",
		"Reticle label must render the '+' glyph"
	)


func test_does_not_block_mouse_input() -> void:
	var center: CenterContainer = _crosshair.get_node("CenterContainer")
	var label: Label = _crosshair.get_node("CenterContainer/Label")
	assert_eq(
		center.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"CenterContainer must ignore mouse so it never blocks gameplay clicks"
	)
	assert_eq(
		label.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"Label must ignore mouse so it never blocks gameplay clicks"
	)
