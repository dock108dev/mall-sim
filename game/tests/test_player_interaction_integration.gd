## Integration test: player camera ray triggers interactions and store entry.
extends GutTest

const PLAYER_SCENE: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)
const INTERACTION_RAY_SCRIPT: Script = preload(
	"res://game/scripts/player/interaction_ray.gd"
)
const STORE_ID: StringName = &"sports"
const VIEWPORT_SIZE := Vector2i(320, 240)


class MockInteractable extends Interactable:
	var interact_calls: int = 0

	func interact(by: Node = null) -> void:
		interact_calls += 1
		super(by)


var _viewport: SubViewport
var _player: PlayerController
var _interaction_ray: Node
var _store_entered_ids: Array[StringName] = []


func before_each() -> void:
	_store_entered_ids.clear()
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.own_world_3d = true
	_viewport.disable_3d = false
	add_child_autofree(_viewport)

	_player = PLAYER_SCENE.instantiate() as PlayerController
	_viewport.add_child(_player)
	_player.set_pivot(Vector3.ZERO)
	_player.set_camera_angles(0.0, 40.0)
	_player.set_zoom_distance(8.0)
	_player.get_camera().current = true

	_interaction_ray = INTERACTION_RAY_SCRIPT.new()
	_viewport.add_child(_interaction_ray)

	EventBus.store_entered.connect(_on_store_entered)

	await get_tree().process_frame
	_interaction_ray._apply_camera(_player.get_camera())
	await get_tree().physics_frame


func after_each() -> void:
	if EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.disconnect(_on_store_entered)


func test_interactable_within_range_calls_interact_after_input() -> void:
	var interactable := _add_mock_interactable(_point_on_camera_ray(8.0))

	await _refresh_interaction_ray(20.0)
	assert_same(
		_interaction_ray.get_hovered_target(),
		interactable,
		"InteractionRay should detect the interactable under the player camera"
	)

	_interaction_ray._unhandled_input(_make_interact_event())

	assert_eq(
		interactable.interact_calls,
		1,
		"Interact input should call interact() on the hovered target"
	)


func test_interactable_out_of_range_does_not_call_interact() -> void:
	var interactable := _add_mock_interactable(_point_on_camera_ray(8.0))

	await _refresh_interaction_ray(3.0)
	assert_null(
		_interaction_ray.get_hovered_target(),
		"InteractionRay should not hover a target beyond ray range"
	)

	_interaction_ray._unhandled_input(_make_interact_event())

	assert_eq(
		interactable.interact_calls,
		0,
		"Interact input should not call interact() when the target is out of range"
	)


func test_storefront_interaction_emits_store_entered_with_store_id() -> void:
	var storefront := _add_storefront(_point_on_camera_ray(8.0))
	storefront.door_interacted.connect(_on_storefront_door_interacted)

	await _refresh_interaction_ray(20.0)
	var hovered: Interactable = _interaction_ray.get_hovered_target()
	assert_not_null(hovered, "InteractionRay should detect the storefront door")
	if hovered == null:
		return
	assert_eq(
		hovered.interaction_type,
		Interactable.InteractionType.STOREFRONT,
		"Storefront door should be detected as a storefront interactable"
	)

	_interaction_ray._unhandled_input(_make_interact_event())

	assert_eq(
		_store_entered_ids,
		[STORE_ID],
		"Storefront interaction should emit store_entered with the correct store_id"
	)


func _add_mock_interactable(position: Vector3) -> MockInteractable:
	var interactable := MockInteractable.new()
	interactable.name = "MockInteractable"
	interactable.interaction_type = Interactable.InteractionType.ITEM
	interactable.display_name = "Mock Item"
	interactable.position = position
	interactable.add_child(_make_collision_shape(Vector3(1.0, 1.0, 1.0)))
	_viewport.add_child(interactable)
	return interactable


func _add_storefront(position: Vector3) -> Storefront:
	var storefront := Storefront.new()
	storefront.name = "MockStorefront"
	storefront.position = position
	_viewport.add_child(storefront)
	storefront.set_owned(String(STORE_ID), "Test Store")
	return storefront


func _make_collision_shape(size: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	return collision_shape


func _make_interact_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	return event


func _refresh_interaction_ray(ray_distance: float) -> void:
	_interaction_ray.ray_distance = ray_distance
	await get_tree().process_frame
	await get_tree().physics_frame
	_interaction_ray._update_raycast()


func _point_on_camera_ray(distance: float) -> Vector3:
	var camera := _player.get_camera()
	var mouse_position := _viewport.get_mouse_position()
	return (
		camera.project_ray_origin(mouse_position)
		+ camera.project_ray_normal(mouse_position) * distance
	)


func _on_storefront_door_interacted(storefront: Storefront) -> void:
	EventBus.store_entered.emit(StringName(storefront.store_id))


func _on_store_entered(store_id: StringName) -> void:
	_store_entered_ids.append(store_id)
