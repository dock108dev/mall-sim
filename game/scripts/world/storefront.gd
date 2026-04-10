## Represents a single storefront slot in the mall hallway.
class_name Storefront
extends Node3D

signal door_interacted(storefront: Storefront)

const SIGN_OFFSET := Vector3(0.0, 3.2, -0.1)
const DOOR_SIZE := Vector3(1.6, 2.4, 0.3)
const WINDOW_SIZE := Vector3(2.5, 2.0, 0.1)

static var _facade_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_storefront_facade.tres"
)
static var _door_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_door_wood.tres"
)
static var _glass_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_storefront_glass.tres"
)

@export var slot_index: int = 0

var store_id: String = ""
var store_type: String = ""
var daily_rent: float = 0.0
var is_owned: bool = false

var _sign_label: Label3D
var _door_interactable: Interactable


func _ready() -> void:
	_build_visual()
	_update_sign()


## Sets this storefront as owned with the given store info.
func set_owned(p_store_id: String, p_store_type: String) -> void:
	store_id = p_store_id
	store_type = p_store_type
	is_owned = true
	_door_interactable.display_name = p_store_type
	_door_interactable.interaction_prompt = "Enter"
	_update_sign()


## Sets this storefront as permanently under renovation.
func set_renovation() -> void:
	is_owned = false
	store_id = "renovation"
	store_type = ""
	_door_interactable.display_name = "Under Renovation"
	_door_interactable.interaction_prompt = "Investigate"
	_door_interactable.interacted.disconnect(_on_door_interacted)
	_door_interactable.interacted.connect(
		_on_renovation_interacted
	)
	_update_sign()


## Sets this storefront as available for lease.
func set_available(p_daily_rent: float) -> void:
	daily_rent = p_daily_rent
	is_owned = false
	store_id = ""
	store_type = ""
	_door_interactable.display_name = "Storefront"
	_door_interactable.interaction_prompt = "Lease"
	_update_sign()


func _build_visual() -> void:
	_build_facade()
	_build_door()
	_build_windows()
	_build_sign()


func _build_facade() -> void:
	var left_mesh := MeshInstance3D.new()
	left_mesh.mesh = BoxMesh.new()
	(left_mesh.mesh as BoxMesh).size = Vector3(1.0, 3.5, 0.2)
	left_mesh.position = Vector3(-2.8, 1.75, 0.0)
	left_mesh.set_surface_override_material(0, _facade_mat)
	add_child(left_mesh)

	var right_mesh := MeshInstance3D.new()
	right_mesh.mesh = BoxMesh.new()
	(right_mesh.mesh as BoxMesh).size = Vector3(1.0, 3.5, 0.2)
	right_mesh.position = Vector3(2.8, 1.75, 0.0)
	right_mesh.set_surface_override_material(0, _facade_mat)
	add_child(right_mesh)

	var header_mesh := MeshInstance3D.new()
	header_mesh.mesh = BoxMesh.new()
	(header_mesh.mesh as BoxMesh).size = Vector3(6.6, 0.8, 0.2)
	header_mesh.position = Vector3(0.0, 3.1, 0.0)
	header_mesh.set_surface_override_material(0, _facade_mat)
	add_child(header_mesh)


func _build_door() -> void:
	var door_body := StaticBody3D.new()
	door_body.name = "DoorBody"
	door_body.position = Vector3(0.0, 1.2, 0.15)
	add_child(door_body)

	var door_mesh := _create_door_mesh()
	door_body.add_child(door_mesh)

	var door_col := CollisionShape3D.new()
	door_col.shape = BoxShape3D.new()
	(door_col.shape as BoxShape3D).size = DOOR_SIZE
	door_body.add_child(door_col)

	_door_interactable = _create_door_interactable(door_mesh)
	door_body.add_child(_door_interactable)


func _create_door_mesh() -> MeshInstance3D:
	var door_mesh := MeshInstance3D.new()
	door_mesh.name = "DoorMesh"
	door_mesh.mesh = BoxMesh.new()
	(door_mesh.mesh as BoxMesh).size = DOOR_SIZE
	door_mesh.set_surface_override_material(0, _door_mat)
	return door_mesh


func _create_door_interactable(
	door_mesh: MeshInstance3D
) -> Interactable:
	var interactable := Interactable.new()
	interactable.name = "DoorInteractable"
	interactable.interaction_type = (
		Interactable.InteractionType.STOREFRONT
	)
	interactable.display_name = "Storefront"
	interactable.interaction_prompt = "Lease"
	interactable.interacted.connect(_on_door_interacted)

	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	(col.shape as BoxShape3D).size = Vector3(2.0, 2.8, 1.0)
	interactable.add_child(col)
	interactable.add_child(door_mesh.duplicate())
	return interactable


func _build_windows() -> void:
	var left_win := MeshInstance3D.new()
	left_win.mesh = BoxMesh.new()
	(left_win.mesh as BoxMesh).size = WINDOW_SIZE
	left_win.position = Vector3(-1.7, 1.5, 0.05)
	left_win.set_surface_override_material(0, _glass_mat)
	add_child(left_win)

	var right_win := MeshInstance3D.new()
	right_win.mesh = BoxMesh.new()
	(right_win.mesh as BoxMesh).size = WINDOW_SIZE
	right_win.position = Vector3(1.7, 1.5, 0.05)
	right_win.set_surface_override_material(0, _glass_mat)
	add_child(right_win)


func _build_sign() -> void:
	_sign_label = Label3D.new()
	_sign_label.name = "SignLabel"
	_sign_label.position = SIGN_OFFSET
	_sign_label.pixel_size = 0.01
	_sign_label.font_size = 32
	_sign_label.outline_size = 4
	_sign_label.modulate = Color(1.0, 0.95, 0.8)
	_sign_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(_sign_label)


func _update_sign() -> void:
	if not _sign_label:
		return
	if store_id == "renovation":
		_sign_label.text = "Under Renovation"
		_sign_label.modulate = Color(0.9, 0.6, 0.2)
	elif is_owned:
		_sign_label.text = store_type
		_sign_label.modulate = Color(1.0, 0.95, 0.8)
	else:
		_sign_label.text = "For Lease — $%d/day" % int(daily_rent)
		_sign_label.modulate = Color(0.8, 0.8, 0.7)


func _on_door_interacted(_interactable: Interactable) -> void:
	door_interacted.emit(self)


func _on_renovation_interacted(
	_interactable: Interactable,
) -> void:
	EventBus.renovation_sounds_heard.emit()
	EventBus.notification_requested.emit(
		"The door is locked. A faded sign reads "
		+ "'Renovations in Progress.' You hear a "
		+ "faint hum from inside."
	)
