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


func test_player_ready_pushes_store_gameplay_context() -> void:
	assert_eq(
		InputFocus.current(),
		&"store_gameplay",
		"Player._ready must push store_gameplay onto InputFocus"
	)


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


func test_exit_tree_pops_gameplay_context() -> void:
	assert_eq(InputFocus.current(), &"store_gameplay")
	_player.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_ne(InputFocus.current(), &"store_gameplay",
		"Player._exit_tree must pop store_gameplay from InputFocus")
