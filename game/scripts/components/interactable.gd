## Base class for any object the player can interact with via raycast.
class_name Interactable
extends Area3D

signal interacted(interactable: Interactable)
signal focused()
signal unfocused()

enum InteractionType {
	SHELF_SLOT,   ## 0
	REGISTER,     ## 1
	ITEM,         ## 2
	BACKROOM,     ## 3
	CUSTOMER,     ## 4
	STOREFRONT,   ## 5
	RETURNS_BIN,  ## 6
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

## Preloaded outline shader material applied as next_pass when hovered.
const _OUTLINE_MATERIAL: ShaderMaterial = preload(
	"res://game/assets/shaders/mat_outline_highlight.tres"
)

@export var interaction_type: InteractionType = InteractionType.ITEM
@export var display_name: String = "Item"
@export var interaction_prompt: String = ""
@export var enabled: bool = true

var _original_materials: Array[Material] = []
var _highlight_active: bool = false


func _ready() -> void:
	if interaction_prompt.is_empty():
		interaction_prompt = PROMPT_VERBS.get(
			interaction_type, "Interact"
		)
	collision_layer = INTERACTABLE_LAYER
	collision_mask = 0
	add_to_group("interactable")


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
func interact() -> void:
	if not enabled:
		return
	interacted.emit(self)
	EventBus.interactable_interacted.emit(self, interaction_type)


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
