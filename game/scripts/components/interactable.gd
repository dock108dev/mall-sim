## Base class for any object the player can interact with via raycast.
class_name Interactable
extends Area3D

signal interacted(interactable: Interactable)

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

## Color applied to mesh when hovered.
const HIGHLIGHT_COLOR := Color(1.3, 1.3, 1.0)

@export var interaction_type: InteractionType = InteractionType.ITEM
@export var display_name: String = "Item"
@export var interaction_prompt: String = ""

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


## Activates a visual highlight on the associated mesh.
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
		if not mat:
			mat = mesh_node.mesh.surface_get_material(i) if mesh_node.mesh else null
		_original_materials.append(mat)

		var highlight_mat: StandardMaterial3D = StandardMaterial3D.new()
		if mat is StandardMaterial3D:
			highlight_mat = (mat as StandardMaterial3D).duplicate()
		highlight_mat.emission_enabled = true
		highlight_mat.emission = Color(0.4, 0.4, 0.2)
		highlight_mat.emission_energy_multiplier = 0.5
		mesh_node.set_surface_override_material(i, highlight_mat)


## Removes the visual highlight from the associated mesh.
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
	interacted.emit(self)
	EventBus.interactable_interacted.emit(self, interaction_type)


## Finds a MeshInstance3D sibling or child for visual highlighting.
func _find_mesh_instance() -> MeshInstance3D:
	# Check children first
	for child: Node in get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D

	# Check siblings
	var parent_node: Node = get_parent()
	if not parent_node:
		return null
	for sibling: Node in parent_node.get_children():
		if sibling is MeshInstance3D:
			return sibling as MeshInstance3D

	return null
