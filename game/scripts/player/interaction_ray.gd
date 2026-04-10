## Casts a ray from the camera through the mouse cursor to detect interactables.
extends Node

## Maximum ray distance in meters.
@export var ray_distance: float = 100.0
## Collision mask for interactable detection (layer bits).
@export_flags_3d_physics var interaction_mask: int = 2

var _camera: Camera3D = null
var _hovered_target: Interactable = null
var _inventory_system: InventorySystem = null


func _ready() -> void:
	set_process(false)


## Call after the camera is available to begin raycasting.
func initialize(camera: Camera3D) -> void:
	_camera = camera
	set_process(true)


## Sets the InventorySystem reference for shelf item tooltip lookups.
func set_inventory_system(inv: InventorySystem) -> void:
	_inventory_system = inv


func _process(_delta: float) -> void:
	_update_raycast()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb_event := event as InputEventMouseButton
	if not mb_event.pressed:
		return
	if mb_event.button_index == MOUSE_BUTTON_LEFT:
		if _hovered_target:
			_hovered_target.interact()
			EventBus.player_interacted.emit(_hovered_target)
	elif mb_event.button_index == MOUSE_BUTTON_RIGHT:
		if _hovered_target:
			EventBus.interactable_right_clicked.emit(
				_hovered_target, _hovered_target.interaction_type
			)


## Returns the currently hovered interactable, or null.
func get_hovered_target() -> Interactable:
	return _hovered_target


func _update_raycast() -> void:
	if not _camera:
		return

	var viewport: Viewport = get_viewport()
	if not viewport:
		return

	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var ray_origin: Vector3 = _camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = _camera.project_ray_normal(mouse_pos)
	var ray_end: Vector3 = ray_origin + ray_dir * ray_distance

	var space_state: PhysicsDirectSpaceState3D = (
		viewport.find_world_3d().direct_space_state
	)
	var query: PhysicsRayQueryParameters3D = (
		PhysicsRayQueryParameters3D.create(
			ray_origin, ray_end, interaction_mask
		)
	)
	var result: Dictionary = space_state.intersect_ray(query)

	var new_target: Interactable = null
	if result.size() > 0:
		var collider: Node = result["collider"]
		if collider is Interactable:
			new_target = collider as Interactable

	if new_target != _hovered_target:
		_set_hovered_target(new_target)


func _set_hovered_target(new_target: Interactable) -> void:
	if _hovered_target:
		_hovered_target.unhighlight()

	_hovered_target = new_target

	if _hovered_target:
		_hovered_target.highlight()
		var prompt: String = "Click to %s %s" % [
			_hovered_target.interaction_prompt,
			_hovered_target.display_name,
		]
		EventBus.notification_requested.emit(prompt)
		_emit_tooltip_for_target(_hovered_target)
	else:
		EventBus.notification_requested.emit("")
		EventBus.item_tooltip_hidden.emit()


func _emit_tooltip_for_target(target: Interactable) -> void:
	if not target is ShelfSlot or not _inventory_system:
		EventBus.item_tooltip_hidden.emit()
		return
	var slot := target as ShelfSlot
	if not slot.is_occupied():
		EventBus.item_tooltip_hidden.emit()
		return
	var item: ItemInstance = _inventory_system.get_item(
		slot.get_item_instance_id()
	)
	if item:
		EventBus.item_tooltip_requested.emit(item)
	else:
		EventBus.item_tooltip_hidden.emit()
