## Unit tests for GameState autoload (ISSUE-020).
## Verifies reset_new_game zeroes fields, set_active_store updates state and
## emits exactly once, and the autoload contains no scene/camera/input writes.
extends GutTest

const GameStateScript: GDScript = preload("res://game/autoload/game_state.gd")

var _state: Node


func before_each() -> void:
	_state = GameStateScript.new()
	add_child_autofree(_state)


func test_reset_new_game_zeroes_fields() -> void:
	_state.day = 7
	_state.money = 1234
	_state.active_store_id = &"sneaker_citadel"
	_state.set_flag(&"tutorial_done", true)

	_state.reset_new_game()

	assert_eq(_state.day, 0)
	assert_eq(_state.money, 0)
	assert_eq(_state.active_store_id, &"")
	assert_eq(_state.flags.size(), 0)
	assert_false(_state.get_flag(&"tutorial_done"))


func test_set_active_store_updates_id() -> void:
	_state.set_active_store(&"sneaker_citadel")
	assert_eq(_state.active_store_id, &"sneaker_citadel")


func test_set_active_store_emits_changed_exactly_once() -> void:
	watch_signals(_state)
	_state.set_active_store(&"sneaker_citadel")
	assert_signal_emit_count(_state, "changed", 1,
		"set_active_store should emit changed exactly once on a real mutation")


func test_set_active_store_no_op_does_not_emit() -> void:
	_state.set_active_store(&"sneaker_citadel")
	watch_signals(_state)
	_state.set_active_store(&"sneaker_citadel")
	assert_signal_emit_count(_state, "changed", 0,
		"setting the same store_id should not re-emit")


func test_reset_new_game_emits_changed_once() -> void:
	watch_signals(_state)
	_state.reset_new_game()
	assert_signal_emit_count(_state, "changed", 1)


func test_set_flag_emits_only_on_change() -> void:
	watch_signals(_state)
	_state.set_flag(&"tutorial_done", true)
	_state.set_flag(&"tutorial_done", true)
	assert_signal_emit_count(_state, "changed", 1)
	assert_true(_state.get_flag(&"tutorial_done"))


func test_no_scene_or_camera_or_input_calls_in_source() -> void:
	# AC: GameState contains NO change_scene_to_*, camera, or input calls.
	var src: String = FileAccess.get_file_as_string("res://game/autoload/game_state.gd")
	assert_false(src.contains("change_scene_to_"),
		"GameState must not call change_scene_to_*")
	assert_false(src.contains("CameraAuthority"),
		"GameState must not couple to CameraAuthority")
	assert_false(src.contains("InputFocus"),
		"GameState must not couple to InputFocus")
	assert_false(src.contains("get_viewport().set_input_as_handled"),
		"GameState must not touch input handling")
