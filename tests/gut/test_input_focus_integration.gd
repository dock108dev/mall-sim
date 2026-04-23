## Integration tests for InputFocus + PlayerController gating (ISSUE-011).
## Mounts a stand-in InputFocus at /root/InputFocus so PlayerController's
## lookup `tree.root.get_node_or_null("InputFocus")` resolves to the stub,
## then verifies movement is blocked outside `&"store_gameplay"`.
extends GutTest

const InputFocusScript: GDScript = preload("res://game/autoload/input_focus.gd")
const PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)

var _focus: Node
var _player: PlayerController


func before_each() -> void:
	_focus = InputFocusScript.new()
	_focus.name = "InputFocus"
	get_tree().root.add_child(_focus)
	_focus._reset_for_tests()
	_player = PlayerControllerScene.instantiate() as PlayerController
	add_child_autofree(_player)


func after_each() -> void:
	if is_instance_valid(_focus):
		_focus.queue_free()


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
	assert_true(_player._input_focus_allows_gameplay())
