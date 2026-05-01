## Tests CustomerStateIndicator state color updates and distance-based fade.
extends GutTest

const IndicatorScene: PackedScene = preload(
	"res://game/scenes/characters/customer_state_indicator.tscn"
)
const CustomerScene: PackedScene = preload(
	"res://game/scenes/characters/customer.tscn"
)

const STATE_BROWSING: int = 1
const STATE_INTERESTED: int = 2
const STATE_READY_TO_BUY: int = 3
const STATE_LEAVING: int = 5
const STATE_HAGGLING: int = 6
const STATE_DISSATISFIED: int = 7

var _indicator: Node3D
var _mock_customer: Node3D
var _camera: Camera3D


func before_each() -> void:
	_mock_customer = Node3D.new()
	add_child_autofree(_mock_customer)

	_indicator = IndicatorScene.instantiate()
	add_child_autofree(_indicator)
	_indicator.initialize(_mock_customer)

	_camera = Camera3D.new()
	_camera.current = true
	add_child_autofree(_camera)
	_indicator._active_camera = _camera


func test_initial_color_is_gray() -> void:
	var sprite: Sprite3D = _indicator.get_node("Sprite3D")
	assert_almost_eq(sprite.modulate.r, 0.6, 0.01)
	assert_almost_eq(sprite.modulate.g, 0.6, 0.01)
	assert_almost_eq(sprite.modulate.b, 0.6, 0.01)


func test_state_change_updates_color() -> void:
	var sprite: Sprite3D = _indicator.get_node("Sprite3D")
	EventBus.customer_state_changed.emit(_mock_customer, 2)
	assert_almost_eq(sprite.modulate.r, 1.0, 0.01, "yellow star r")
	assert_almost_eq(sprite.modulate.g, 0.85, 0.01, "yellow star g")
	assert_almost_eq(sprite.modulate.b, 0.0, 0.01, "yellow star b")


func test_ignores_other_customer_signals() -> void:
	var sprite: Sprite3D = _indicator.get_node("Sprite3D")
	var other: Node3D = Node3D.new()
	add_child_autofree(other)
	EventBus.customer_state_changed.emit(other, 3)
	assert_almost_eq(sprite.modulate.r, 0.6, 0.01)


func test_alpha_full_within_visible_distance() -> void:
	var sprite: Sprite3D = _indicator.get_node("Sprite3D")
	_camera.global_position = Vector3(15.0, 0.0, 0.0)
	_indicator.global_position = Vector3.ZERO
	_indicator._process(0.0)
	assert_almost_eq(sprite.modulate.a, 1.0, 0.01)


func test_alpha_zero_beyond_fade_distance() -> void:
	var sprite: Sprite3D = _indicator.get_node("Sprite3D")
	_camera.global_position = Vector3(24.0, 0.0, 0.0)
	_indicator.global_position = Vector3.ZERO
	_indicator._process(0.0)
	assert_almost_eq(sprite.modulate.a, 0.0, 0.01)


func test_alpha_fades_between_visible_and_fade_distance() -> void:
	var sprite: Sprite3D = _indicator.get_node("Sprite3D")
	_camera.global_position = Vector3(20.0, 0.0, 0.0)
	_indicator.global_position = Vector3.ZERO
	_indicator._process(0.0)
	assert_almost_eq(sprite.modulate.a, 0.5, 0.01)


func test_purchasing_state_shows_green() -> void:
	var sprite: Sprite3D = _indicator.get_node("Sprite3D")
	EventBus.customer_state_changed.emit(_mock_customer, 3)
	assert_almost_eq(sprite.modulate.r, 0.2, 0.01)
	assert_almost_eq(sprite.modulate.g, 0.8, 0.01)
	assert_almost_eq(sprite.modulate.b, 0.2, 0.01)


func test_issue_states_have_distinct_indicator_colors() -> void:
	var colors: Array[Color] = []
	for state: int in [
		STATE_BROWSING,
		STATE_INTERESTED,
		STATE_READY_TO_BUY,
		STATE_HAGGLING,
		STATE_DISSATISFIED,
		STATE_LEAVING,
	]:
		EventBus.customer_state_changed.emit(_mock_customer, state)
		colors.append(_indicator.get_node("Sprite3D").modulate)

	for i: int in colors.size():
		for j: int in range(i + 1, colors.size()):
			assert_false(
				_colors_match_rgb(colors[i], colors[j]),
				"indicator states should use distinct placeholder visuals"
			)


func test_customer_scene_contains_indicator_component() -> void:
	var customer: Node = CustomerScene.instantiate()
	add_child_autofree(customer)
	var indicator: Node = customer.get_node_or_null("CustomerStateIndicator")
	assert_not_null(indicator)
	assert_not_null(indicator.get_node_or_null("Sprite3D"))


func test_indicator_sprite_uses_billboard_mode() -> void:
	var sprite: Sprite3D = _indicator.get_node("Sprite3D")
	assert_eq(sprite.billboard, BaseMaterial3D.BILLBOARD_ENABLED)


func _colors_match_rgb(left: Color, right: Color) -> bool:
	return (
		is_equal_approx(left.r, right.r)
		and is_equal_approx(left.g, right.g)
		and is_equal_approx(left.b, right.b)
	)
