## Represents a single storefront slot in the mall hallway.
class_name Storefront
extends Node3D

signal door_interacted(storefront: Storefront)

const FACADE_SIZE := Vector3(6.6, 3.5, 0.2)
const SIGN_OFFSET := Vector3(0.0, 3.2, 0.16)
const STATUS_SIGN_OFFSET := Vector3(0.0, 2.55, 0.16)
const LEASE_MARKER_OFFSET := Vector3(0.0, 2.55, 0.08)
const LEASE_MARKER_SIZE := Vector3(2.0, 0.42, 0.04)
const DOOR_SIZE := Vector3(1.5, 2.35, 0.16)
const WINDOW_SIZE := Vector3(2.5, 2.0, 0.1)
const ENTRY_ZONE_SIZE := Vector3(2.0, 2.0, 1.0)
const ENTRY_ZONE_OFFSET := Vector3(0.0, 1.0, 0.7)
const LEASE_MARKER_STATE_LOCKED: StringName = &"locked"
const LEASE_MARKER_STATE_AVAILABLE: StringName = &"available"

static var _facade_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_storefront_facade.tres"
)
static var _door_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_door_wood.tres"
)
static var _glass_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_storefront_glass.tres"
)
static var _frame_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_metal_dark.tres"
)
static var _sign_backing_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_sign_backing.tres"
)
static var _threshold_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_floor_tile_cream.tres"
)

@export var slot_index: int = 0
@export var store_id: String = ""
@export var store_name: String = "":
	set(value):
		store_name = value
		_update_sign()

var store_type: String = ""
var daily_rent: float = 0.0
var is_owned: bool = false
var is_locked: bool = false

var _sign_label: Label3D
var _status_label: Label3D
var _door_interactable: Interactable
var _entry_zone: Area3D
var _lease_marker_mesh: MeshInstance3D
var _is_store_open: bool = false
static var _lease_marker_materials: Dictionary = {}


func _ready() -> void:
	_build_visual()
	_update_sign()
	_update_status_sign()
	EventBus.store_opened.connect(_on_store_opened)
	EventBus.store_closed.connect(_on_store_closed)
	EventBus.hour_changed.connect(_on_hour_changed)


## Sets this storefront as owned with the given store info.
func set_owned(p_store_id: String, p_store_type: String) -> void:
	store_id = p_store_id
	store_type = p_store_type
	store_name = p_store_type
	is_owned = true
	is_locked = false
	_door_interactable.display_name = p_store_type
	_door_interactable.interaction_prompt = "Enter"
	_update_sign()
	_update_status_sign()


## Sets this storefront as permanently under renovation.
func set_renovation() -> void:
	is_owned = false
	is_locked = false
	store_id = "renovation"
	store_type = ""
	store_name = "Under Renovation"
	_door_interactable.display_name = "Under Renovation"
	_door_interactable.interaction_prompt = "Investigate"
	_door_interactable.interacted.disconnect(_on_door_interacted)
	_door_interactable.interacted.connect(
		_on_renovation_interacted
	)
	_update_sign()
	_update_status_sign()


## Sets this storefront as locked (not yet eligible for lease).
func set_locked() -> void:
	is_locked = true
	is_owned = false
	store_id = ""
	store_type = ""
	store_name = ""
	daily_rent = 0.0
	_door_interactable.display_name = "Storefront"
	_door_interactable.interaction_prompt = "Locked"
	if _door_interactable.interacted.is_connected(_on_door_interacted):
		_door_interactable.interacted.disconnect(_on_door_interacted)
	if not _door_interactable.interacted.is_connected(_on_locked_interacted):
		_door_interactable.interacted.connect(_on_locked_interacted)
	_update_sign()
	_update_status_sign()


## Sets this storefront as available for lease.
func set_available(p_daily_rent: float) -> void:
	daily_rent = p_daily_rent
	is_owned = false
	is_locked = false
	store_id = ""
	store_type = ""
	store_name = ""
	if _door_interactable.interacted.is_connected(_on_locked_interacted):
		_door_interactable.interacted.disconnect(_on_locked_interacted)
	if not _door_interactable.interacted.is_connected(_on_door_interacted):
		_door_interactable.interacted.connect(_on_door_interacted)
	_door_interactable.display_name = "Storefront"
	_door_interactable.interaction_prompt = "Lease"
	_update_sign()
	_update_status_sign()


## Returns the lease marker material state for tests and hallway unlock checks.
func get_lease_marker_state() -> StringName:
	if _lease_marker_mesh == null:
		return &""
	var material: Material = _lease_marker_mesh.get_surface_override_material(0)
	if material == null:
		return &""
	return StringName(material.resource_name)


func _build_visual() -> void:
	_build_facade()
	_build_entry_architecture()
	_build_door()
	_build_windows()
	_build_sign()
	_build_lease_marker()
	_build_status_sign()
	_build_entry_zone()


func _build_facade() -> void:
	var facade_body := StaticBody3D.new()
	facade_body.name = "FacadeBody"
	add_child(facade_body)

	var left_mesh := MeshInstance3D.new()
	left_mesh.mesh = BoxMesh.new()
	(left_mesh.mesh as BoxMesh).size = Vector3(1.0, 3.5, 0.2)
	left_mesh.position = Vector3(-2.8, 1.75, 0.0)
	left_mesh.set_surface_override_material(0, _facade_mat)
	facade_body.add_child(left_mesh)

	var left_col := CollisionShape3D.new()
	left_col.shape = BoxShape3D.new()
	(left_col.shape as BoxShape3D).size = Vector3(1.0, 3.5, 0.2)
	left_col.position = Vector3(-2.8, 1.75, 0.0)
	facade_body.add_child(left_col)

	var right_mesh := MeshInstance3D.new()
	right_mesh.mesh = BoxMesh.new()
	(right_mesh.mesh as BoxMesh).size = Vector3(1.0, 3.5, 0.2)
	right_mesh.position = Vector3(2.8, 1.75, 0.0)
	right_mesh.set_surface_override_material(0, _facade_mat)
	facade_body.add_child(right_mesh)

	var right_col := CollisionShape3D.new()
	right_col.shape = BoxShape3D.new()
	(right_col.shape as BoxShape3D).size = Vector3(1.0, 3.5, 0.2)
	right_col.position = Vector3(2.8, 1.75, 0.0)
	facade_body.add_child(right_col)

	var header_mesh := MeshInstance3D.new()
	header_mesh.mesh = BoxMesh.new()
	(header_mesh.mesh as BoxMesh).size = Vector3(6.6, 0.8, 0.2)
	header_mesh.position = Vector3(0.0, 3.1, 0.0)
	header_mesh.set_surface_override_material(0, _facade_mat)
	facade_body.add_child(header_mesh)

	var header_col := CollisionShape3D.new()
	header_col.shape = BoxShape3D.new()
	(header_col.shape as BoxShape3D).size = Vector3(6.6, 0.8, 0.2)
	header_col.position = Vector3(0.0, 3.1, 0.0)
	facade_body.add_child(header_col)


func _build_entry_architecture() -> void:
	var left_jamb := MeshInstance3D.new()
	left_jamb.mesh = BoxMesh.new()
	(left_jamb.mesh as BoxMesh).size = Vector3(0.22, 2.45, 0.32)
	left_jamb.position = Vector3(-0.88, 1.23, 0.12)
	left_jamb.set_surface_override_material(0, _frame_mat)
	add_child(left_jamb)

	var right_jamb := MeshInstance3D.new()
	right_jamb.mesh = BoxMesh.new()
	(right_jamb.mesh as BoxMesh).size = Vector3(0.22, 2.45, 0.32)
	right_jamb.position = Vector3(0.88, 1.23, 0.12)
	right_jamb.set_surface_override_material(0, _frame_mat)
	add_child(right_jamb)

	var lintel := MeshInstance3D.new()
	lintel.mesh = BoxMesh.new()
	(lintel.mesh as BoxMesh).size = Vector3(1.98, 0.22, 0.32)
	lintel.position = Vector3(0.0, 2.45, 0.12)
	lintel.set_surface_override_material(0, _frame_mat)
	add_child(lintel)

	var recess := MeshInstance3D.new()
	recess.mesh = BoxMesh.new()
	(recess.mesh as BoxMesh).size = Vector3(1.66, 2.15, 0.26)
	recess.position = Vector3(0.0, 1.15, -0.05)
	recess.set_surface_override_material(0, _sign_backing_mat)
	add_child(recess)

	var threshold := MeshInstance3D.new()
	threshold.mesh = BoxMesh.new()
	(threshold.mesh as BoxMesh).size = Vector3(1.75, 0.08, 0.45)
	threshold.position = Vector3(0.0, 0.04, 0.22)
	threshold.set_surface_override_material(0, _threshold_mat)
	add_child(threshold)

	var sign_backing := MeshInstance3D.new()
	sign_backing.mesh = BoxMesh.new()
	(sign_backing.mesh as BoxMesh).size = Vector3(2.8, 0.48, 0.18)
	sign_backing.position = Vector3(0.0, 3.2, 0.03)
	sign_backing.set_surface_override_material(0, _sign_backing_mat)
	add_child(sign_backing)


func _build_door() -> void:
	var door_body := StaticBody3D.new()
	door_body.name = "DoorBody"
	door_body.position = Vector3(0.0, 1.18, 0.16)
	add_child(door_body)

	var door_col := CollisionShape3D.new()
	door_col.shape = BoxShape3D.new()
	(door_col.shape as BoxShape3D).size = DOOR_SIZE
	door_body.add_child(door_col)

	_door_interactable = _create_door_interactable()
	door_body.add_child(_door_interactable)


func _create_door_mesh() -> MeshInstance3D:
	var door_mesh := MeshInstance3D.new()
	door_mesh.name = "DoorMesh"
	door_mesh.mesh = BoxMesh.new()
	(door_mesh.mesh as BoxMesh).size = DOOR_SIZE
	door_mesh.set_surface_override_material(0, _door_mat)
	return door_mesh


func _create_door_interactable() -> Interactable:
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
	interactable.add_child(_create_door_mesh())
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

	var left_mullion := MeshInstance3D.new()
	left_mullion.mesh = BoxMesh.new()
	(left_mullion.mesh as BoxMesh).size = Vector3(0.08, 2.0, 0.14)
	left_mullion.position = Vector3(-1.7, 1.5, 0.09)
	left_mullion.set_surface_override_material(0, _frame_mat)
	add_child(left_mullion)

	var right_mullion := MeshInstance3D.new()
	right_mullion.mesh = BoxMesh.new()
	(right_mullion.mesh as BoxMesh).size = Vector3(0.08, 2.0, 0.14)
	right_mullion.position = Vector3(1.7, 1.5, 0.09)
	right_mullion.set_surface_override_material(0, _frame_mat)
	add_child(right_mullion)


func _build_sign() -> void:
	_sign_label = Label3D.new()
	_sign_label.name = "SignLabel"
	_sign_label.position = SIGN_OFFSET
	_sign_label.pixel_size = 0.01
	_sign_label.font_size = 32
	_sign_label.outline_size = 4
	_sign_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(_sign_label)


func _build_lease_marker() -> void:
	_lease_marker_mesh = MeshInstance3D.new()
	_lease_marker_mesh.name = "LeaseMarker"
	_lease_marker_mesh.mesh = BoxMesh.new()
	(_lease_marker_mesh.mesh as BoxMesh).size = LEASE_MARKER_SIZE
	_lease_marker_mesh.position = LEASE_MARKER_OFFSET
	_lease_marker_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lease_marker_mesh.set_surface_override_material(
		0,
		_get_lease_marker_material(LEASE_MARKER_STATE_LOCKED)
	)
	add_child(_lease_marker_mesh)


func _build_status_sign() -> void:
	_status_label = Label3D.new()
	_status_label.name = "StatusSign"
	_status_label.position = STATUS_SIGN_OFFSET
	_status_label.pixel_size = 0.008
	_status_label.font_size = 24
	_status_label.outline_size = 3
	_status_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(_status_label)


func _build_entry_zone() -> void:
	_entry_zone = Area3D.new()
	_entry_zone.name = "EntryZone"
	_entry_zone.position = ENTRY_ZONE_OFFSET
	# Collision layer 0 (default) so it doesn't interfere with interactables
	_entry_zone.collision_layer = 0
	_entry_zone.collision_mask = 1
	_entry_zone.monitoring = true
	_entry_zone.monitorable = false
	add_child(_entry_zone)

	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	(col.shape as BoxShape3D).size = ENTRY_ZONE_SIZE
	_entry_zone.add_child(col)

	_entry_zone.body_entered.connect(_on_entry_zone_body_entered)
	_entry_zone.body_exited.connect(_on_entry_zone_body_exited)


func _update_sign() -> void:
	if not _sign_label:
		return

	if store_id == "renovation":
		_sign_label.text = "Under Renovation"
		_sign_label.modulate = Color(0.9, 0.6, 0.2)
	elif is_owned:
		_sign_label.text = store_name if store_name != "" else store_type
		_sign_label.modulate = Color(1.0, 0.95, 0.8)
		_sign_label.outline_modulate = Color(0.2, 0.15, 0.05)
	elif is_locked:
		_sign_label.text = "Coming Soon"
		_sign_label.modulate = Color(0.35, 0.35, 0.35)
		_sign_label.outline_modulate = Color(0.1, 0.1, 0.1)
	else:
		_sign_label.text = "For Lease — $%d/day" % int(daily_rent)
		_sign_label.modulate = Color(0.5, 0.5, 0.45)
		_sign_label.outline_modulate = Color(0.15, 0.15, 0.1)


func _update_status_sign() -> void:
	if not _status_label or _lease_marker_mesh == null:
		return

	if store_id == "renovation":
		_lease_marker_mesh.visible = false
		_status_label.visible = false
		return

	if is_owned:
		_lease_marker_mesh.visible = false
	else:
		_lease_marker_mesh.visible = true
		var marker_state: StringName = (
			LEASE_MARKER_STATE_LOCKED
			if is_locked
			else LEASE_MARKER_STATE_AVAILABLE
		)
		_lease_marker_mesh.set_surface_override_material(
			0,
			_get_lease_marker_material(marker_state)
		)

	if is_locked:
		_status_label.visible = false
		return

	_status_label.visible = true

	if not is_owned:
		_status_label.text = "FOR LEASE"
		_status_label.modulate = Color(0.9, 0.85, 0.2)
		_status_label.outline_modulate = Color(0.3, 0.28, 0.05)
		return

	if _is_store_open:
		_status_label.text = "OPEN"
		_status_label.modulate = Color(0.2, 0.9, 0.3)
		_status_label.outline_modulate = Color(0.05, 0.3, 0.08)
	else:
		_status_label.text = "CLOSED"
		_status_label.modulate = Color(0.9, 0.2, 0.2)
		_status_label.outline_modulate = Color(0.3, 0.05, 0.05)


func _on_store_opened(opened_store_id: String) -> void:
	if opened_store_id != store_id:
		return
	_is_store_open = true
	_update_status_sign()


func _on_store_closed(closed_store_id: String) -> void:
	if closed_store_id != store_id:
		return
	_is_store_open = false
	_update_status_sign()


func _on_hour_changed(hour: int) -> void:
	if not is_owned:
		return
	var was_open: bool = _is_store_open
	_is_store_open = (
		hour >= Constants.STORE_OPEN_HOUR
		and hour < Constants.STORE_CLOSE_HOUR
	)
	if _is_store_open != was_open:
		_update_status_sign()


func _on_entry_zone_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if store_id.is_empty():
		return
	EventBus.storefront_zone_entered.emit(store_id)


func _on_entry_zone_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if store_id.is_empty():
		return
	EventBus.storefront_zone_exited.emit(store_id)


func _on_door_interacted(_interactable: Interactable) -> void:
	door_interacted.emit(self)


func _on_locked_interacted(
	_interactable: Interactable,
) -> void:
	EventBus.notification_requested.emit(
		"This storefront is not yet available. "
		+ "Build your reputation and earnings to unlock it."
	)


func _on_renovation_interacted(
	_interactable: Interactable,
) -> void:
	EventBus.renovation_sounds_heard.emit()
	EventBus.notification_requested.emit(
		"The door is locked. A faded sign reads "
		+ "'Renovations in Progress.' You hear a "
		+ "faint hum from inside."
	)


static func _get_lease_marker_material(
	state: StringName
) -> StandardMaterial3D:
	if _lease_marker_materials.has(state):
		return _lease_marker_materials[state] as StandardMaterial3D

	var material := StandardMaterial3D.new()
	material.resource_name = String(state)
	material.metallic = 0.0
	material.roughness = 0.85
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	match state:
		LEASE_MARKER_STATE_AVAILABLE:
			material.albedo_color = Color(0.95, 0.83, 0.22, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.42, 0.31, 0.04, 1.0)
			material.emission_energy_multiplier = 0.2
		_:
			material.albedo_color = Color(0.22, 0.22, 0.24, 1.0)
			material.emission_enabled = false
	_lease_marker_materials[state] = material
	return material
