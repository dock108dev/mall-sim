## Unit tests for StorePlayerBody (ISSUE-016).
## Verifies that `interact_pressed` is suppressed under a non-gameplay focus
## (e.g. modal) and fires once the store_gameplay context is restored.
extends GutTest

const StorePlayerScene: PackedScene = preload(
	"res://game/scenes/player/store_player_body.tscn"
)


class MockStoreRoot:
	extends Node3D
	func get_store_id() -> StringName:
		return &"unit_test_store"


class MockInteractable:
	extends Node


var _root: Node
var _player: StorePlayerBody
var _interactable: Node
var _received: Array[Node] = []


func before_each() -> void:
	InputFocus._reset_for_tests()
	_received.clear()

	_root = MockStoreRoot.new()
	add_child_autofree(_root)

	_player = StorePlayerScene.instantiate() as StorePlayerBody
	_root.add_child(_player)

	# Production: StoreController pushes CTX_STORE_GAMEPLAY on
	# EventBus.store_entered. The mock store root above does not extend
	# StoreController, so we simulate that push here so input gating tests
	# observe the same focus state as a live store.
	InputFocus.push_context(InputFocus.CTX_STORE_GAMEPLAY)

	_interactable = MockInteractable.new()
	add_child_autofree(_interactable)
	_player.current_interactable = _interactable

	_player.interact_pressed.connect(_on_interact)


func after_each() -> void:
	InputFocus._reset_for_tests()


func _on_interact(node: Node) -> void:
	_received.append(node)


func _make_interact_event() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"interact"
	ev.pressed = true
	return ev


func test_interact_fires_when_focus_is_store_gameplay() -> void:
	_player._unhandled_input(_make_interact_event())
	assert_eq(_received.size(), 1,
		"interact should fire when InputFocus.current == store_gameplay")
	assert_same(_received[0], _interactable)


func test_interact_suppressed_when_modal_on_top() -> void:
	InputFocus.push_context(&"modal")
	_player._unhandled_input(_make_interact_event())
	assert_eq(_received.size(), 0,
		"interact must NOT fire while a modal holds focus")


func test_interact_resumes_after_modal_pops() -> void:
	InputFocus.push_context(&"modal")
	_player._unhandled_input(_make_interact_event())
	assert_eq(_received.size(), 0, "blocked under modal")

	InputFocus.pop_context()
	_player._unhandled_input(_make_interact_event())
	assert_eq(_received.size(), 1,
		"interact should fire once gameplay focus is restored")


func test_interact_suppressed_when_no_interactable_hovered() -> void:
	_player.current_interactable = null
	_player._unhandled_input(_make_interact_event())
	assert_eq(_received.size(), 0,
		"interact must NOT fire when current_interactable is null")


# ── Store-footprint clamp (defense-in-depth fallback) ────────────────────────


func test_clamp_pulls_back_when_position_exceeds_max_z() -> void:
	# Simulate a wall-collision miss: teleport past the front bound, run a
	# physics step, and expect the post-clamp position to sit at the bound.
	_player.global_position = Vector3(0.0, 0.0, 5.0)
	_player._physics_process(0.016)
	assert_almost_eq(
		_player.global_position.z, _player.bounds_max.z, 0.0001,
		"forward overshoot must be clamped back to bounds_max.z"
	)


func test_clamp_pulls_back_when_position_exceeds_min_z() -> void:
	_player.global_position = Vector3(0.0, 0.0, -5.0)
	_player._physics_process(0.016)
	assert_almost_eq(
		_player.global_position.z, _player.bounds_min.z, 0.0001,
		"backward overshoot must be clamped to bounds_min.z"
	)


func test_clamp_pulls_back_when_position_exceeds_x_bounds() -> void:
	_player.global_position = Vector3(10.0, 0.0, 0.0)
	_player._physics_process(0.016)
	assert_almost_eq(
		_player.global_position.x, _player.bounds_max.x, 0.0001,
		"sideways overshoot must be clamped to bounds_max.x"
	)
	_player.global_position = Vector3(-10.0, 0.0, 0.0)
	_player._physics_process(0.016)
	assert_almost_eq(
		_player.global_position.x, _player.bounds_min.x, 0.0001,
		"sideways overshoot must be clamped to bounds_min.x"
	)


func test_clamp_leaves_in_bounds_position_untouched() -> void:
	# A position safely inside the footprint must not be moved by the clamp;
	# only the velocity-zeroing modal-focus path should affect it (and we are
	# under store_gameplay focus here).
	var before := Vector3(1.0, 0.0, 0.5)
	_player.global_position = before
	_player._physics_process(0.016)
	assert_almost_eq(_player.global_position.x, before.x, 0.0001,
		"in-bounds X must not be modified by the clamp")
	assert_almost_eq(_player.global_position.z, before.z, 0.0001,
		"in-bounds Z must not be modified by the clamp")


func test_clamp_bounds_match_retro_games_footprint() -> void:
	# The defaults must keep the body inside the 7×5 retro_games floor with a
	# safety margin from the wall surface (walls at ±3.5 X, ±2.5 Z). When
	# room geometry is resized the defaults must be updated alongside.
	assert_lte(_player.bounds_max.x, 3.5,
		"bounds_max.x must sit inside the right wall surface (3.5)")
	assert_gte(_player.bounds_min.x, -3.5,
		"bounds_min.x must sit inside the left wall surface (-3.5)")
	assert_lte(_player.bounds_max.z, 2.5,
		"bounds_max.z must sit inside the front wall surface (2.5)")
	assert_gte(_player.bounds_min.z, -2.5,
		"bounds_min.z must sit inside the back wall surface (-2.5)")
