## Floating billboard indicator that shows the customer's current state.
extends Node3D

enum IndicatorState {
	ENTERING = 0,
	BROWSING = 1,
	INTERESTED = 2,
	READY_TO_BUY = 3,
	WAITING_TO_BUY = 4,
	LEAVING = 5,
	HAGGLING = 6,
	DISSATISFIED = 7,
}

const VISIBLE_DISTANCE: float = 18.0
const FADE_DISTANCE: float = 22.0

const STATE_COLORS: Dictionary = {
	IndicatorState.ENTERING: Color(0.55, 0.55, 0.55, 1.0),
	IndicatorState.BROWSING: Color(0.6, 0.6, 0.6, 1.0),
	IndicatorState.INTERESTED: Color(1.0, 0.85, 0.0, 1.0),
	IndicatorState.READY_TO_BUY: Color(0.2, 0.8, 0.2, 1.0),
	IndicatorState.WAITING_TO_BUY: Color(0.1, 0.65, 0.95, 1.0),
	IndicatorState.LEAVING: Color(0.4, 0.45, 0.5, 1.0),
	IndicatorState.HAGGLING: Color(0.65, 0.45, 1.0, 1.0),
	IndicatorState.DISSATISFIED: Color(1.0, 0.15, 0.1, 1.0),
}

@export var customer_id: String = ""

var _customer: Node = null
var _active_camera: Camera3D = null

@onready var _sprite: Sprite3D = $Sprite3D


func _ready() -> void:
	EventBus.customer_state_changed.connect(_on_customer_state_changed)
	EventBus.active_camera_changed.connect(_on_active_camera_changed)
	var viewport: Viewport = get_viewport()
	if viewport:
		_active_camera = viewport.get_camera_3d()


func initialize(customer: Node) -> void:
	_customer = customer
	if customer_id.is_empty() and customer != null:
		customer_id = str(customer.get_instance_id())


func _process(_delta: float) -> void:
	if not _active_camera or not is_instance_valid(_active_camera):
		_sprite.modulate.a = 0.0
		return
	var dist: float = global_position.distance_to(
		_active_camera.global_position
	)
	if dist <= VISIBLE_DISTANCE:
		_sprite.modulate.a = 1.0
	elif dist >= FADE_DISTANCE:
		_sprite.modulate.a = 0.0
	else:
		var t: float = (dist - VISIBLE_DISTANCE) / (
			FADE_DISTANCE - VISIBLE_DISTANCE
		)
		_sprite.modulate.a = 1.0 - t


func _on_customer_state_changed(
	customer: Node, new_state: int
) -> void:
	if not _matches_customer(customer):
		return
	if STATE_COLORS.has(new_state):
		_sprite.modulate = Color(
			STATE_COLORS[new_state].r,
			STATE_COLORS[new_state].g,
			STATE_COLORS[new_state].b,
			_sprite.modulate.a,
		)


func _on_active_camera_changed(camera: Camera3D) -> void:
	_active_camera = camera


func _matches_customer(customer: Node) -> bool:
	if customer == _customer:
		return true
	if customer == null or customer_id.is_empty():
		return false
	return str(customer.get_instance_id()) == customer_id
