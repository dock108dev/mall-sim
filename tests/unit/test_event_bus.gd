## Unit tests for EventBus Phase 1 signal inventory (ISSUE-022).
##
## Verifies each Phase 1 signal exists with the specified typed arguments and
## that the emit_* wrappers deliver the correct payload. The emitter-ownership
## rule (only conceptual owners may emit; see docs/architecture/ownership.md
## row 10) is enforced by code review and the per-owner tests, not here.
extends GutTest

const EventBusScript: GDScript = preload("res://game/autoload/event_bus.gd")

var _bus: Node


func before_each() -> void:
	_bus = EventBusScript.new()
	add_child_autofree(_bus)
	watch_signals(_bus)


func test_store_ready_emits_with_string_name() -> void:
	_bus.emit_store_ready(&"retro_games")
	assert_signal_emitted_with_parameters(_bus, "store_ready", [&"retro_games"])


func test_store_failed_emits_with_id_and_reason() -> void:
	_bus.emit_store_failed(&"retro_games", "player missing")
	assert_signal_emitted_with_parameters(
		_bus, "store_failed", [&"retro_games", "player missing"]
	)


func test_scene_ready_emits_with_scene_name() -> void:
	_bus.emit_scene_ready(&"mall_hub")
	assert_signal_emitted_with_parameters(_bus, "scene_ready", [&"mall_hub"])


func test_input_focus_changed_emits_with_owner() -> void:
	_bus.emit_input_focus_changed(&"store_gameplay")
	assert_signal_emitted_with_parameters(
		_bus, "input_focus_changed", [&"store_gameplay"]
	)


func test_camera_authority_changed_emits_with_node_path() -> void:
	var path: NodePath = NodePath("/root/Store/StoreCamera")
	_bus.emit_camera_authority_changed(path)
	assert_signal_emitted_with_parameters(
		_bus, "camera_authority_changed", [path]
	)


func test_run_state_changed_is_parameterless() -> void:
	# Phase 1 "game_state_changed()" intent is fulfilled by the parameterless
	# run_state_changed() signal (see ISSUE-020 / ownership.md row 6). The
	# legacy typed game_state_changed(old_state, new_state) remains for the
	# GameManager FSM and is asserted separately below.
	_bus.run_state_changed.emit()
	assert_signal_emitted(_bus, "run_state_changed")


func test_legacy_game_state_changed_is_typed() -> void:
	_bus.game_state_changed.emit(0, 1)
	assert_signal_emitted_with_parameters(_bus, "game_state_changed", [0, 1])


func test_phase1_signals_declared() -> void:
	for signal_name in [
		"store_ready",
		"store_failed",
		"scene_ready",
		"input_focus_changed",
		"camera_authority_changed",
		"run_state_changed",
	]:
		assert_true(
			_bus.has_signal(signal_name),
			"EventBus missing Phase 1 signal: %s" % signal_name,
		)
