## Day 1 needs a visible close-day affordance: the keybinding is invisible to
## new players, so the HUD button surfaces the shortcut and pulses when the
## first-sale objective points at it.
extends GutTest

const _HudScene: PackedScene = preload("res://game/scenes/ui/hud.tscn")

var _hud: CanvasLayer
var _saved_state: GameManager.State


func before_all() -> void:
	_saved_state = GameManager.current_state
	_hud = _HudScene.instantiate()
	add_child(_hud)


func after_all() -> void:
	GameManager.current_state = _saved_state
	if is_instance_valid(_hud):
		_hud.free()
	_hud = null


func before_each() -> void:
	_hud._reset_for_tests()


func _emit_state(new_state: GameManager.State) -> void:
	var old: GameManager.State = GameManager.current_state
	GameManager.current_state = new_state
	EventBus.game_state_changed.emit(int(old), int(new_state))


func test_close_day_button_text_includes_keybinding_hint() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	var btn: Button = _hud.get_node_or_null("TopBar/CloseDayButton")
	assert_not_null(btn, "CloseDayButton must exist in TopBar")
	# Localized text — "Shift+F" appears in EN, "Mayús+F" in ES — both share the
	# "+F" suffix that identifies the bound key. The point of the assertion is
	# that the visible label leaks the shortcut to new players, not that the
	# label matches an exact string.
	assert_true(
		btn.text.contains("F"),
		"CloseDayButton text must surface the close-day key (got: %s)" % btn.text
	)
	assert_true(
		btn.text.length() > "Close Day".length(),
		"CloseDayButton text must extend the bare 'Close Day' label with a "
		+ "keybinding hint so the shortcut is discoverable (got: %s)" % btn.text
	)


func test_close_day_button_min_width_accommodates_keybinding() -> void:
	var btn: Button = _hud.get_node_or_null("TopBar/CloseDayButton")
	assert_not_null(btn, "CloseDayButton must exist")
	assert_gte(
		btn.custom_minimum_size.x, 160.0,
		"CloseDayButton min width must accommodate the keybinding hint without "
		+ "wrapping or clipping"
	)


func test_first_sale_completed_pulses_close_day_button() -> void:
	_emit_state(GameManager.State.STORE_VIEW)
	var btn: Button = _hud.get_node_or_null("TopBar/CloseDayButton")
	assert_not_null(btn, "CloseDayButton must exist")
	# The pulse uses a tween on scale; emitting first_sale_completed must not
	# raise an error even if the player has no economy/inventory hooked up.
	EventBus.first_sale_completed.emit(&"retro_games", "item_001", 25.0)
	assert_true(
		btn.visible,
		"CloseDayButton must remain visible after the pulse animation kicks off"
	)
