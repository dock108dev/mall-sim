## Verifies the floor-level player position indicator wired into the retro
## games store: it must exist as a child of PlayerController, sit above the
## floor surface, track the pivot via parent transform inheritance, and toggle
## visibility based on the InputFocus context so it does not render in
## MALL_OVERVIEW or DAY_SUMMARY (anything other than `store_gameplay`).
extends GutTest

const RetroGamesScene: PackedScene = preload(
	"res://game/scenes/stores/retro_games.tscn"
)

# Floor StaticBody3D occupies Y∈[-0.05, 0.05]; the marker must clear that.
const _FLOOR_TOP_Y: float = 0.05
# Pivot extents exposed by the retro_games PlayerController override.
const _STORE_HALF_WIDTH: float = 4.5
const _STORE_HALF_DEPTH: float = 3.0

var _root: Node3D = null
var _controller: PlayerController = null
var _indicator: Node3D = null
var _focus: Node = null


func before_all() -> void:
	_root = RetroGamesScene.instantiate() as Node3D
	add_child(_root)
	_controller = _root.get_node_or_null("PlayerController") as PlayerController
	if _controller != null:
		_indicator = _controller.get_node_or_null("PlayerIndicator") as Node3D


func after_all() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null
	_controller = null
	_indicator = null


func before_each() -> void:
	_focus = get_tree().root.get_node_or_null("InputFocus")
	if _focus != null:
		_focus._reset_for_tests()


func after_each() -> void:
	if _focus != null and is_instance_valid(_focus):
		_focus._reset_for_tests()


func test_retro_games_scene_embeds_player_indicator() -> void:
	assert_not_null(
		_indicator,
		"retro_games.tscn must add a PlayerIndicator child under PlayerController"
	)


func test_player_indicator_is_mesh_instance() -> void:
	if _indicator == null:
		fail_test("PlayerIndicator missing")
		return
	assert_true(
		_indicator is MeshInstance3D,
		"PlayerIndicator must be a MeshInstance3D so it renders a floor disc"
	)


func test_player_indicator_sits_above_floor_surface() -> void:
	if _indicator == null:
		fail_test("PlayerIndicator missing")
		return
	# Local Y must clear the floor's top face (Y=0.05) to avoid z-fighting.
	assert_gt(
		_indicator.position.y, _FLOOR_TOP_Y,
		"PlayerIndicator local Y must clear the floor top to avoid z-fighting"
	)


func test_player_indicator_tracks_pivot_via_parent_transform() -> void:
	if _controller == null or _indicator == null:
		fail_test("PlayerController/PlayerIndicator missing")
		return
	# Snap the pivot to a known point inside the store; the indicator (child)
	# must inherit the same XZ via the controller's `global_position = _pivot`
	# update, with no script needing to re-position it each frame.
	var target: Vector3 = Vector3(2.0, 0.0, -1.5)
	_controller.set_pivot(target)
	assert_almost_eq(
		_indicator.global_position.x, target.x, 0.001,
		"PlayerIndicator must follow pivot X via parent transform inheritance"
	)
	assert_almost_eq(
		_indicator.global_position.z, target.z, 0.001,
		"PlayerIndicator must follow pivot Z via parent transform inheritance"
	)


func test_player_indicator_stays_within_store_bounds_at_extents() -> void:
	if _controller == null or _indicator == null:
		fail_test("PlayerController/PlayerIndicator missing")
		return
	# At the store boundary extents the indicator (≤0.5m radius) plus its
	# parent must still sit on the floor; the controller clamps the pivot to
	# the configured bounds, so a request beyond them snaps inside.
	_controller.set_pivot(Vector3(_STORE_HALF_WIDTH + 5.0, 0.0, 0.0))
	assert_lte(
		_indicator.global_position.x, _STORE_HALF_WIDTH + 0.001,
		"Indicator X must remain inside store_bounds_max.x at the +X extent"
	)
	_controller.set_pivot(Vector3(0.0, 0.0, -(_STORE_HALF_DEPTH + 5.0)))
	assert_gte(
		_indicator.global_position.z, -_STORE_HALF_DEPTH - 0.001,
		"Indicator Z must remain inside store_bounds_min.z at the -Z extent"
	)


func test_player_indicator_visible_in_store_gameplay_context() -> void:
	if _controller == null or _indicator == null or _focus == null:
		fail_test("Test prerequisites missing")
		return
	_focus.push_context(&"store_gameplay")
	_controller._update_player_indicator_visibility()
	assert_true(
		_indicator.visible,
		"PlayerIndicator must render while InputFocus context is store_gameplay"
	)
	_focus.pop_context()


func test_player_indicator_hidden_in_mall_hub_context() -> void:
	if _controller == null or _indicator == null or _focus == null:
		fail_test("Test prerequisites missing")
		return
	_focus.push_context(&"mall_hub")
	_controller._update_player_indicator_visibility()
	assert_false(
		_indicator.visible,
		"PlayerIndicator must hide when InputFocus context is mall_hub "
		+ "(maps to MALL_OVERVIEW state)"
	)
	_focus.pop_context()


func test_player_indicator_hidden_in_modal_context() -> void:
	# DAY_SUMMARY pushes a modal/menu context on top of store_gameplay; the
	# indicator must hide while the modal is active and reappear after pop.
	if _controller == null or _indicator == null or _focus == null:
		fail_test("Test prerequisites missing")
		return
	_focus.push_context(&"store_gameplay")
	_focus.push_context(&"modal")
	_controller._update_player_indicator_visibility()
	assert_false(
		_indicator.visible,
		"PlayerIndicator must hide when a modal sits above store_gameplay"
	)
	_focus.pop_context()
	_controller._update_player_indicator_visibility()
	assert_true(
		_indicator.visible,
		"PlayerIndicator must restore visibility once the modal pops"
	)
	_focus.pop_context()


func test_player_indicator_hidden_during_build_mode() -> void:
	if _controller == null or _indicator == null or _focus == null:
		fail_test("Test prerequisites missing")
		return
	_focus.push_context(&"store_gameplay")
	_controller.set_build_mode(true)
	_controller._update_player_indicator_visibility()
	assert_false(
		_indicator.visible,
		"PlayerIndicator must hide while build mode is active"
	)
	_controller.set_build_mode(false)
	_controller._update_player_indicator_visibility()
	assert_true(
		_indicator.visible,
		"PlayerIndicator must reappear once build mode exits"
	)
	_focus.pop_context()
