## Tests CustomerStateIndicator state color updates and distance-based fade.
extends GutTest

const IndicatorScene: PackedScene = preload(
	"res://game/scenes/characters/customer_state_indicator.tscn"
)

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
	_camera.global_position = Vector3(5.0, 0.0, 0.0)
	_indicator.global_position = Vector3.ZERO
	_indicator._process(0.0)
	assert_almost_eq(sprite.modulate.a, 1.0, 0.01)


func test_alpha_zero_beyond_fade_distance() -> void:
	var sprite: Sprite3D = _indicator.get_node("Sprite3D")
	_camera.global_position = Vector3(12.0, 0.0, 0.0)
	_indicator.global_position = Vector3.ZERO
	_indicator._process(0.0)
	assert_almost_eq(sprite.modulate.a, 0.0, 0.01)


func test_alpha_fades_between_8_and_10_meters() -> void:
	var sprite: Sprite3D = _indicator.get_node("Sprite3D")
	_camera.global_position = Vector3(9.0, 0.0, 0.0)
	_indicator.global_position = Vector3.ZERO
	_indicator._process(0.0)
	assert_almost_eq(sprite.modulate.a, 0.5, 0.01)


func test_purchasing_state_shows_green() -> void:
	var sprite: Sprite3D = _indicator.get_node("Sprite3D")
	EventBus.customer_state_changed.emit(_mock_customer, 3)
	assert_almost_eq(sprite.modulate.r, 0.2, 0.01)
	assert_almost_eq(sprite.modulate.g, 0.8, 0.01)
	assert_almost_eq(sprite.modulate.b, 0.2, 0.01)
