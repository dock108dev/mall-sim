## Base class for any object the player can interact with via raycast.
class_name Interactable
extends Area3D

signal interacted()
## ISSUE-017: parameterised variant — emits the actor that triggered the
## interaction. Kept separate from `interacted()` so existing parameterless
## listeners (storefront door, GUT tests) keep working.
signal interacted_by(by: Node)
signal focused()
signal unfocused()

enum InteractionType {
	SHELF_SLOT,
	REGISTER,
	ITEM,
	BACKROOM,
	CUSTOMER,
	STOREFRONT,
	RETURNS_BIN,
}

## Maps each interaction type to a default prompt verb.
const PROMPT_VERBS: Dictionary = {
	InteractionType.SHELF_SLOT: "Stock",
	InteractionType.REGISTER: "Use",
	InteractionType.ITEM: "Examine",
	InteractionType.BACKROOM: "View",
	InteractionType.CUSTOMER: "Talk to",
	InteractionType.STOREFRONT: "Enter",
	InteractionType.RETURNS_BIN: "Check",
}

## Collision layer used exclusively for interactables.
const INTERACTABLE_LAYER: int = 2
const INTERACTION_AREA_NAME: StringName = &"InteractionArea"
const INTERACTION_AREA_GROUP: StringName = &"interaction_area"
const INTERACTION_OWNER_META: StringName = &"interactable_owner"
const DEFAULT_COLLISION_SIZE := Vector3(0.5, 0.5, 0.5)

## Preloaded outline shader material applied as next_pass when hovered.
const _OUTLINE_MATERIAL: ShaderMaterial = preload(
	"res://game/assets/shaders/mat_outline_highlight.tres"
)

@export var interaction_type: InteractionType = InteractionType.ITEM
@export var display_name: String = "Item"
## ISSUE-017: action verb the StoreController/StoreReadyContract uses to
## prove the HUD objective text references a real interactable in the scene
## (e.g. objective "Interact with the shelf" requires action_verb=="Interact"
## on an interactable whose display_name contains "shelf").
@export var action_verb: String = "Interact"
@export var prompt_text: String = ""
@export var enabled: bool = true
@export var highlight_color: Color = Color(0.0, 0.737, 0.725, 1.0)
@export_range(0.001, 0.05, 0.001) var highlight_outline_width: float = 0.012
@export var interaction_prompt: String = "":
	get:
		return prompt_text
	set(value):
		prompt_text = value
@export var interaction_name: String = "":
	get:
		return display_name
	set(value):
		display_name = value

var _interaction_area: Area3D = null
var _original_materials: Array[Material] = []
var _highlight_active: bool = false


func _ready() -> void:
	if prompt_text.is_empty():
		prompt_text = PROMPT_VERBS.get(
			interaction_type, "Interact"
		)
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	input_ray_pickable = false
	add_to_group("interactable")
	# ISSUE-017: StoreReadyContract enumerates this group (plural) when
	# counting visible interactions. Kept alongside the legacy singular
	# group so existing systems keep filtering correctly.
	add_to_group(&"interactables")
	_interaction_area = _ensure_interaction_area()
	_register_interaction_area()


func _exit_tree() -> void:
	_unregister_interaction_area()


## Returns the Area3D used as the actual interaction hit target.
func get_interaction_area() -> Area3D:
	return _interaction_area


## Activates an outline highlight on the associated mesh via next_pass.
func highlight() -> void:
	if _highlight_active:
		return
	_highlight_active = true

	var mesh_node: MeshInstance3D = _find_mesh_instance()
	if not mesh_node:
		return

	_original_materials.clear()
	for i: int in range(mesh_node.get_surface_override_material_count()):
		var mat: Material = mesh_node.get_surface_override_material(i)
		if not mat and mesh_node.mesh:
			mat = mesh_node.mesh.surface_get_material(i)
		_original_materials.append(mat)

		var surface_mat: Material
		if mat:
			surface_mat = mat.duplicate()
		else:
			surface_mat = StandardMaterial3D.new()
		surface_mat.next_pass = _OUTLINE_MATERIAL.duplicate()
		var outline_mat := surface_mat.next_pass as ShaderMaterial
		outline_mat.set_shader_parameter("outline_color", highlight_color)
		outline_mat.set_shader_parameter("outline_width", highlight_outline_width)
		mesh_node.set_surface_override_material(i, surface_mat)


## Removes the outline highlight from the associated mesh.
func unhighlight() -> void:
	if not _highlight_active:
		return
	_highlight_active = false

	var mesh_node: MeshInstance3D = _find_mesh_instance()
	if not mesh_node:
		return

	for i: int in range(_original_materials.size()):
		mesh_node.set_surface_override_material(i, _original_materials[i])
	_original_materials.clear()


## Triggers the interaction, emitting both local and global signals.
## `by` (ISSUE-017) identifies the actor that triggered the interaction so
## listeners can attribute it; defaults to null for the legacy callsites.
func interact(by: Node = null) -> void:
	if not enabled:
		return
	interacted.emit()
	interacted_by.emit(by)
	EventBus.interactable_interacted.emit(self, interaction_type)


## Resolves an Interactable from a collider hit by the player's interaction ray.
static func from_collider(collider: Node) -> Interactable:
	if collider == null or not is_instance_valid(collider):
		return null
	if collider is Interactable:
		return collider as Interactable
	if collider.has_meta(String(INTERACTION_OWNER_META)):
		var meta_owner: Variant = collider.get_meta(String(INTERACTION_OWNER_META))
		if meta_owner is Interactable and is_instance_valid(meta_owner):
			return meta_owner as Interactable
	var current: Node = collider
	while current != null:
		if current is Interactable:
			return current as Interactable
		current = current.get_parent()
	return null


## Finds a MeshInstance3D in descendants or siblings for visual highlighting.
func _find_mesh_instance() -> MeshInstance3D:
	var result: MeshInstance3D = _find_mesh_recursive(self)
	if result:
		return result

	var parent_node: Node = get_parent()
	if not parent_node:
		return null
	for sibling: Node in parent_node.get_children():
		if sibling is MeshInstance3D:
			return sibling as MeshInstance3D

	return null


## Recursively searches descendants for the first MeshInstance3D.
func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
		var found: MeshInstance3D = _find_mesh_recursive(child)
		if found:
			return found
	return null


func _ensure_interaction_area() -> Area3D:
	var area: Area3D = get_node_or_null(
		String(INTERACTION_AREA_NAME)
	) as Area3D
	if area == null:
		area = Area3D.new()
		area.name = String(INTERACTION_AREA_NAME)
		add_child(area)
	area.owner = owner
	_move_collision_shapes_to_area(area)
	_ensure_collision_shape(area)
	return area


func _register_interaction_area() -> void:
	if not is_instance_valid(_interaction_area):
		return
	_interaction_area.collision_layer = INTERACTABLE_LAYER
	_interaction_area.collision_mask = 0
	_interaction_area.monitoring = true
	_interaction_area.monitorable = true
	_interaction_area.input_ray_pickable = true
	_interaction_area.set_meta(String(INTERACTION_OWNER_META), self)
	if not _interaction_area.is_in_group(String(INTERACTION_AREA_GROUP)):
		_interaction_area.add_to_group(String(INTERACTION_AREA_GROUP))


func _unregister_interaction_area() -> void:
	if not is_instance_valid(_interaction_area):
		return
	if _interaction_area.has_meta(String(INTERACTION_OWNER_META)):
		_interaction_area.remove_meta(String(INTERACTION_OWNER_META))
	if _interaction_area.is_in_group(String(INTERACTION_AREA_GROUP)):
		_interaction_area.remove_from_group(String(INTERACTION_AREA_GROUP))


func _move_collision_shapes_to_area(area: Area3D) -> void:
	var shapes: Array[CollisionShape3D] = []
	for child: Node in get_children():
		if child == area:
			continue
		if child is CollisionShape3D:
			shapes.append(child as CollisionShape3D)
	for shape: CollisionShape3D in shapes:
		shape.reparent(area, false)
		shape.owner = owner


func _ensure_collision_shape(area: Area3D) -> void:
	for child: Node in area.get_children():
		if child is CollisionShape3D:
			return
	var fallback_shape := CollisionShape3D.new()
	fallback_shape.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = DEFAULT_COLLISION_SIZE
	fallback_shape.shape = box_shape
	area.add_child(fallback_shape)
	fallback_shape.owner = owner
