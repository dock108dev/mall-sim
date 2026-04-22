## A single slot on a shelf or display fixture that can hold one item.
class_name ShelfSlot
extends Interactable

signal slot_changed(slot: ShelfSlot)

const _CARD_PACK_SCENE: PackedScene = preload(
	"res://game/assets/models/props/placeholder_prop_card_pack.tscn"
)
const _SHELF_PRODUCT_SCENE: PackedScene = preload(
	"res://game/assets/models/props/placeholder_prop_shelf_product.tscn"
)
const _SPORTS_MEMORABILIA_SCENE: PackedScene = preload(
	"res://game/assets/models/props/placeholder_prop_sports_memorabilia.tscn"
)
const _GAME_CARTRIDGE_SCENE: PackedScene = preload(
	"res://game/assets/models/props/placeholder_prop_game_cartridge.tscn"
)
const _VHS_TAPE_SCENE: PackedScene = preload(
	"res://game/assets/models/props/placeholder_prop_vhs_tape.tscn"
)
const _ELECTRONICS_DEVICE_SCENE: PackedScene = preload(
	"res://game/assets/models/props/placeholder_prop_electronics_device.tscn"
)
const CATEGORY_SCENES: Dictionary = {
	"trading_cards": _CARD_PACK_SCENE,
	"sealed_packs": _CARD_PACK_SCENE,
	"sealed_product": _SHELF_PRODUCT_SCENE,
	"memorabilia": _SPORTS_MEMORABILIA_SCENE,
	"cartridge": _GAME_CARTRIDGE_SCENE,
	"console": _GAME_CARTRIDGE_SCENE,
	"accessory": _SHELF_PRODUCT_SCENE,
	"guide": _SHELF_PRODUCT_SCENE,
	"vhs_tapes": _VHS_TAPE_SCENE,
	"dvd_titles": _VHS_TAPE_SCENE,
	"snacks": _SHELF_PRODUCT_SCENE,
	"merchandise": _SHELF_PRODUCT_SCENE,
	"portable_audio": _ELECTRONICS_DEVICE_SCENE,
	"digital_camera": _ELECTRONICS_DEVICE_SCENE,
	"gadget": _ELECTRONICS_DEVICE_SCENE,
	"audio_equipment": _ELECTRONICS_DEVICE_SCENE,
	"portable_gaming": _ELECTRONICS_DEVICE_SCENE,
}
const DEFAULT_ITEM_SCENE: PackedScene = _SHELF_PRODUCT_SCENE

const HIGHLIGHT_EMPTY := Color(0.2, 0.8, 0.2)
const HIGHLIGHT_OCCUPIED := Color(0.9, 0.2, 0.2)

@export var slot_id: String = ""
@export var fixture_id: String = ""
@export var slot_size: String = "standard"

var _occupied: bool = false
var _held_item_id: String = ""
var _item_node: Node3D = null
var _placement_active: bool = false
var _info_label: Label3D = null
var _label_accent: Color = Color.WHITE

@onready var _empty_mesh: MeshInstance3D = _resolve_empty_mesh()


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


## Returns true if this slot can accept an item.
func is_available() -> bool:
	return not _occupied


## Returns the instance ID of the placed item, or empty string if empty.
func get_item_instance_id() -> String:
	if _occupied:
		return _held_item_id
	return ""


## Returns the instance ID of the held item, or empty StringName if empty.
func get_item_id() -> StringName:
	return StringName(get_item_instance_id())


## Returns the maximum number of items this slot can hold.
func get_capacity() -> int:
	return 1


## Returns the number of items currently occupying this slot (0 or 1).
func get_occupied() -> int:
	return 1 if _occupied else 0


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


## Assigns an item to this slot by canonical instance ID, returning true on success.
func assign_item(id: StringName) -> bool:
	return place_item(String(id))


## Removes the item from this slot and returns its instance ID.
func remove_item() -> String:
	if not _occupied:
		return ""
	var item_id: String = _held_item_id
	_held_item_id = ""
	_occupied = false
	_free_item_mesh()
	_update_empty_indicator()
	clear_display_data()
	slot_changed.emit(self)
	return item_id


## Removes the held item and restores availability.
func deassign() -> void:
	remove_item()


## Displays item name, condition, and price above this slot as a billboard label.
## Creates the Label3D on first call; subsequent calls update text in place.
func set_display_data(item_name: String, condition: String, price: float) -> void:
	if not _info_label:
		_info_label = Label3D.new()
		_info_label.pixel_size = 0.004
		_info_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_info_label.no_depth_test = true
		_info_label.font_size = 28
		_info_label.position = Vector3(0.0, 0.22, 0.0)
		_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_info_label.modulate = _label_accent
		add_child(_info_label)
	_info_label.text = "%s\n%s  $%.2f" % [item_name, condition.capitalize(), price]
	_info_label.visible = true


## Sets the accent color used for the info label text. Applies immediately if
## the label already exists.
func apply_accent(color: Color) -> void:
	_label_accent = color
	if _info_label:
		_info_label.modulate = color


## Hides the info label without destroying it.
func clear_display_data() -> void:
	if _info_label:
		_info_label.visible = false


## Shows or hides the translucent empty-slot indicator.
func _update_empty_indicator() -> void:
	if not is_node_ready() or _empty_mesh == null:
		return
	_empty_mesh.visible = not _occupied


## Spawns a placeholder scene representing the placed item.
func _spawn_item_mesh(category: String) -> void:
	_free_item_mesh()
	var scene: PackedScene = CATEGORY_SCENES.get(
		category, DEFAULT_ITEM_SCENE
	)
	var instance: Node3D = scene.instantiate()
	_item_node = instance
	add_child(instance)


## Frees the item node if it exists.
func _free_item_mesh() -> void:
	if _item_node and is_instance_valid(_item_node):
		_item_node.queue_free()
		_item_node = null


func _resolve_empty_mesh() -> MeshInstance3D:
	var placeholder: MeshInstance3D = get_node_or_null(
		"PlaceholderMesh"
	) as MeshInstance3D
	if placeholder:
		return placeholder
	return get_node_or_null("Marker") as MeshInstance3D


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
