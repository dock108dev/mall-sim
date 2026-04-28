## Integration tests for InputFocus + PlayerController gating (ISSUE-011).
## Drives the InputFocus autoload directly; PlayerController's lookup
## `tree.root.get_node_or_null("InputFocus")` resolves to the same node, so
## context pushes here are observed by the controller.
extends GutTest

const PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)

var _focus: Node
var _player: PlayerController


func before_all() -> void:
	_player = PlayerControllerScene.instantiate() as PlayerController
	add_child(_player)


func after_all() -> void:
	if is_instance_valid(_player):
		_player.free()
	_player = null


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	assert_not_null(
		_focus, "InputFocus autoload must be present for integration tests"
	)
	if _focus != null:
		_focus._reset_for_tests()


func after_each() -> void:
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func test_modal_blocks_gameplay_input() -> void:
	_focus.push_context(&"store_gameplay")
	assert_true(_player._input_focus_allows_gameplay(),
		"store_gameplay context allows player input")
	_focus.push_context(&"modal")
	assert_false(_player._input_focus_allows_gameplay(),
		"modal context must block player input")


func test_closing_modal_restores_gameplay_input() -> void:
	_focus.push_context(&"store_gameplay")
	_focus.push_context(&"modal")
	assert_false(_player._input_focus_allows_gameplay())
	_focus.pop_context()
	assert_true(_player._input_focus_allows_gameplay(),
		"popping modal restores store_gameplay context and unblocks input")


func test_mall_hub_context_blocks_gameplay() -> void:
	_focus.push_context(&"mall_hub")
	assert_false(_player._input_focus_allows_gameplay(),
		"mall_hub is not store_gameplay; player input must be suppressed")


func test_main_menu_context_blocks_gameplay() -> void:
	_focus.push_context(&"main_menu")
	assert_false(_player._input_focus_allows_gameplay())


func test_empty_stack_treated_as_legacy_allowed() -> void:
	# Empty stack post-transition is a contract violation reported via
	# AuditLog/banner, but PlayerController itself stays permissive so the
	# violation surfaces visibly rather than as silent input death.
	_focus._reset_for_tests()
	assert_true(_player._input_focus_allows_gameplay())


func test_modal_push_pop_cycle_restores_store_gameplay() -> void:
	_focus.push_context(&"store_gameplay")
	assert_eq(_focus.current(), &"store_gameplay")
	_focus.push_context(&"modal")
	assert_eq(_focus.current(), &"modal")
	_focus.pop_context()
	assert_eq(
		_focus.current(),
		&"store_gameplay",
		"Closing modal must restore store_gameplay as the active InputFocus context"
	)
	_focus.pop_context()


func test_get_pivot_returns_vector3() -> void:
	assert_true(
		_player.get_pivot() is Vector3,
		"get_pivot() must return a Vector3"
	)


func test_get_pivot_initial_value_is_zero() -> void:
	assert_eq(
		_player.get_pivot(),
		Vector3.ZERO,
		"get_pivot() must return Vector3.ZERO before any movement is applied"
	)


func test_can_move_true_with_store_gameplay_context() -> void:
	_focus.push_context(&"store_gameplay")
	assert_true(
		_player.can_move(),
		"can_move() must return true when store_gameplay is the active InputFocus context"
	)
	_focus.pop_context()


func test_can_move_false_with_modal_context() -> void:
	_focus.push_context(&"modal")
	assert_false(
		_player.can_move(),
		"can_move() must return false when a modal is on top of the InputFocus stack"
	)
	_focus.pop_context()


func test_can_move_false_with_mall_hub_context() -> void:
	_focus._reset_for_tests()
	_focus.push_context(&"mall_hub")
	assert_false(
		_player.can_move(),
		"can_move() must return false when the mall_hub context is active"
	)


func test_player_controller_registers_in_group_on_ready() -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(&"player_controller")
	var found: bool = false
	for n: Node in nodes:
		if n == _player:
			found = true
			break
	assert_true(found, "PlayerController must add itself to the 'player_controller' group in _ready()")
