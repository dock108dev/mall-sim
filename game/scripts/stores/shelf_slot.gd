## A single slot on a shelf or display fixture that can hold one item.
class_name ShelfSlot
extends Interactable

signal slot_changed(slot: ShelfSlot)

const CATEGORY_MATERIALS: Dictionary = {
	"trading_cards": preload(
		"res://game/assets/materials/mat_product_trading_cards.tres"
	),
	"sealed_packs": preload(
		"res://game/assets/materials/mat_product_sealed_packs.tres"
	),
	"sealed_product": preload(
		"res://game/assets/materials/mat_product_sealed_product.tres"
	),
	"memorabilia": preload(
		"res://game/assets/materials/mat_product_memorabilia.tres"
	),
	"cartridge": preload(
		"res://game/assets/materials/mat_product_cartridge.tres"
	),
	"console": preload(
		"res://game/assets/materials/mat_product_console.tres"
	),
	"accessory": preload(
		"res://game/assets/materials/mat_product_accessory.tres"
	),
	"guide": preload(
		"res://game/assets/materials/mat_product_guide.tres"
	),
	"vhs_tapes": preload(
		"res://game/assets/materials/mat_product_vhs_tapes.tres"
	),
	"dvd_titles": preload(
		"res://game/assets/materials/mat_product_dvd_titles.tres"
	),
	"snacks": preload(
		"res://game/assets/materials/mat_product_snacks.tres"
	),
	"merchandise": preload(
		"res://game/assets/materials/mat_product_merchandise.tres"
	),
	"portable_audio": preload(
		"res://game/assets/materials/mat_product_portable_audio.tres"
	),
	"digital_camera": preload(
		"res://game/assets/materials/mat_product_digital_camera.tres"
	),
	"gadget": preload(
		"res://game/assets/materials/mat_product_gadget.tres"
	),
	"audio_equipment": preload(
		"res://game/assets/materials/mat_product_audio_equipment.tres"
	),
	"portable_gaming": preload(
		"res://game/assets/materials/mat_product_portable_gaming.tres"
	),
}
const DEFAULT_ITEM_MATERIAL: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_product_default.tres"
)

const CATEGORY_SIZES: Dictionary = {
	"trading_cards": Vector3(0.15, 0.2, 0.08),
	"sealed_packs": Vector3(0.12, 0.18, 0.1),
	"sealed_product": Vector3(0.18, 0.22, 0.14),
	"memorabilia": Vector3(0.2, 0.22, 0.15),
	"cartridge": Vector3(0.12, 0.16, 0.08),
	"console": Vector3(0.25, 0.18, 0.2),
	"accessory": Vector3(0.14, 0.12, 0.1),
	"guide": Vector3(0.16, 0.22, 0.04),
	"vhs_tapes": Vector3(0.14, 0.2, 0.08),
	"dvd_titles": Vector3(0.14, 0.19, 0.02),
	"snacks": Vector3(0.1, 0.14, 0.1),
	"merchandise": Vector3(0.2, 0.25, 0.05),
	"portable_audio": Vector3(0.1, 0.14, 0.06),
	"digital_camera": Vector3(0.12, 0.1, 0.08),
	"gadget": Vector3(0.1, 0.15, 0.06),
	"audio_equipment": Vector3(0.16, 0.14, 0.12),
	"portable_gaming": Vector3(0.14, 0.08, 0.06),
}
const DEFAULT_ITEM_SIZE: Vector3 = Vector3(0.15, 0.18, 0.1)

const HIGHLIGHT_EMPTY := Color(0.2, 0.8, 0.2)
const HIGHLIGHT_OCCUPIED := Color(0.9, 0.2, 0.2)

@export var slot_id: String = ""
@export var fixture_id: String = ""
@export var slot_size: String = "standard"

var _occupied: bool = false
var _held_item_id: String = ""
var _item_mesh: MeshInstance3D = null
var _placement_active: bool = false

@onready var _empty_mesh: MeshInstance3D = $PlaceholderMesh


func _ready() -> void:
	interaction_type = InteractionType.SHELF_SLOT
	if display_name.is_empty():
		display_name = "Shelf Slot"
	add_to_group("shelf_slot")
	super._ready()
	_update_empty_indicator()
	EventBus.placement_mode_entered.connect(_on_placement_entered)
	EventBus.placement_mode_exited.connect(_on_placement_exited)


## Returns whether an item is currently placed in this slot.
func is_occupied() -> bool:
	return _occupied


## Returns the instance ID of the placed item, or empty string if empty.
func get_item_instance_id() -> String:
	if _occupied:
		return _held_item_id
	return ""


## Places an item into this slot, returning true on success.
func place_item(instance_id: String, category: String = "") -> bool:
	if _occupied:
		return false
	_held_item_id = instance_id
	_occupied = true
	_spawn_item_mesh(category)
	_update_empty_indicator()
	slot_changed.emit(self)
	return true


## Removes the item from this slot and returns its instance ID.
func remove_item() -> String:
	if not _occupied:
		return ""
	var item_id: String = _held_item_id
	_held_item_id = ""
	_occupied = false
	_free_item_mesh()
	_update_empty_indicator()
	slot_changed.emit(self)
	return item_id


## Shows or hides the translucent empty-slot indicator.
func _update_empty_indicator() -> void:
	if not is_node_ready() or _empty_mesh == null:
		return
	_empty_mesh.visible = not _occupied


## Spawns a colored BoxMesh representing the placed item.
func _spawn_item_mesh(category: String) -> void:
	_free_item_mesh()
	var mesh_size: Vector3 = CATEGORY_SIZES.get(
		category, DEFAULT_ITEM_SIZE
	)
	var mat: StandardMaterial3D = CATEGORY_MATERIALS.get(
		category, DEFAULT_ITEM_MATERIAL
	)
	var box: BoxMesh = BoxMesh.new()
	box.size = mesh_size
	_item_mesh = MeshInstance3D.new()
	_item_mesh.mesh = box
	_item_mesh.set_surface_override_material(0, mat)
	_item_mesh.position.y = mesh_size.y * 0.5
	add_child(_item_mesh)


## Frees the item mesh if it exists.
func _free_item_mesh() -> void:
	if _item_mesh and is_instance_valid(_item_mesh):
		_item_mesh.queue_free()
		_item_mesh = null


## Overrides base highlight to use green/red during placement mode.
func highlight() -> void:
	if _placement_active:
		_apply_placement_highlight()
		return
	super.highlight()


## Overrides base unhighlight to clear placement highlights too.
func unhighlight() -> void:
	super.unhighlight()


func _on_placement_entered() -> void:
	_placement_active = true


func _on_placement_exited() -> void:
	_placement_active = false
	if _highlight_active:
		unhighlight()


## Applies green (empty) or red (occupied) emission highlight.
func _apply_placement_highlight() -> void:
	if _highlight_active:
		return
	_highlight_active = true

	var mesh_node: MeshInstance3D = _find_mesh_instance()
	if not mesh_node:
		return

	var emission_color: Color
	if _occupied:
		emission_color = HIGHLIGHT_OCCUPIED
	else:
		emission_color = HIGHLIGHT_EMPTY

	_original_materials.clear()
	var surface_count: int = (
		mesh_node.get_surface_override_material_count()
	)
	for i: int in range(surface_count):
		var mat: Material = mesh_node.get_surface_override_material(i)
		if not mat and mesh_node.mesh:
			mat = mesh_node.mesh.surface_get_material(i)
		_original_materials.append(mat)

		var highlight_mat := StandardMaterial3D.new()
		if mat is StandardMaterial3D:
			highlight_mat = (mat as StandardMaterial3D).duplicate()
		highlight_mat.emission_enabled = true
		highlight_mat.emission = emission_color
		highlight_mat.emission_energy_multiplier = 0.8
		mesh_node.set_surface_override_material(i, highlight_mat)
