## Builds decorative props for the mall hallway environment.
class_name HallwayDecorationBuilder
extends RefCounted

static var _trash_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_trash_can.tres"
)
static var _directory_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_directory_sign.tres"
)
static var _sign_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_sign_backing.tres"
)
static var _planter_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_wood_dark.tres"
)
static var _plant_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_plant_foliage.tres"
)


## Builds all hallway decorations under a Decorations node.
static func build(
	parent: Node3D, hallway_width: float, hallway_height: float
) -> Node3D:
	var decorations := Node3D.new()
	decorations.name = "Decorations"
	parent.add_child(decorations)

	var center_z: float = hallway_width * 0.5
	var front_z: float = hallway_width - 0.3

	_build_directory_sign(decorations, front_z)
	_add_trash_can(decorations, Vector3(-10.0, 0.0, front_z))
	_add_trash_can(decorations, Vector3(10.0, 0.0, front_z))
	_add_planter(decorations, "PlanterLeft", Vector3(-8.0, 0.0, center_z))
	_add_planter(decorations, "PlanterRight", Vector3(8.0, 0.0, center_z))
	_build_overhead_banner(decorations, center_z, hallway_height)

	return decorations


static func _build_directory_sign(
	parent: Node3D, front_z: float
) -> void:
	var post := MeshInstance3D.new()
	post.name = "DirectoryPost"
	post.mesh = BoxMesh.new()
	(post.mesh as BoxMesh).size = Vector3(0.1, 2.2, 0.1)
	post.position = Vector3(0.0, 1.1, front_z)
	post.set_surface_override_material(0, _sign_mat)
	parent.add_child(post)

	var panel := MeshInstance3D.new()
	panel.name = "DirectoryPanel"
	panel.mesh = BoxMesh.new()
	(panel.mesh as BoxMesh).size = Vector3(1.2, 1.4, 0.06)
	panel.position = Vector3(0.0, 1.8, front_z)
	panel.set_surface_override_material(0, _directory_mat)
	parent.add_child(panel)

	var label := Label3D.new()
	label.name = "DirectoryLabel"
	label.text = "MALL DIRECTORY"
	label.font_size = 32
	label.pixel_size = 0.006
	label.position = Vector3(0.0, 2.2, front_z - 0.04)
	label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	parent.add_child(label)


static func _build_overhead_banner(
	parent: Node3D, center_z: float, hallway_height: float
) -> void:
	var banner := MeshInstance3D.new()
	banner.name = "OverheadBanner"
	banner.mesh = BoxMesh.new()
	(banner.mesh as BoxMesh).size = Vector3(3.0, 0.6, 0.03)
	banner.position = Vector3(0.0, hallway_height - 0.5, center_z)
	banner.set_surface_override_material(0, _sign_mat)
	parent.add_child(banner)

	var label := Label3D.new()
	label.name = "BannerLabel"
	label.text = "WELCOME TO THE MALL"
	label.font_size = 36
	label.pixel_size = 0.007
	label.position = Vector3(
		0.0, hallway_height - 0.5, center_z - 0.02
	)
	label.modulate = Color(1.0, 0.9, 0.7, 1.0)
	parent.add_child(label)


static func _add_trash_can(parent: Node3D, pos: Vector3) -> void:
	var can := MeshInstance3D.new()
	can.name = "TrashCan"
	can.mesh = CylinderMesh.new()
	(can.mesh as CylinderMesh).top_radius = 0.2
	(can.mesh as CylinderMesh).bottom_radius = 0.18
	(can.mesh as CylinderMesh).height = 0.6
	can.position = Vector3(pos.x, 0.3, pos.z)
	can.set_surface_override_material(0, _trash_mat)
	parent.add_child(can)


static func _add_planter(
	parent: Node3D, node_name: String, pos: Vector3
) -> void:
	var planter := MeshInstance3D.new()
	planter.name = node_name
	planter.mesh = BoxMesh.new()
	(planter.mesh as BoxMesh).size = Vector3(0.8, 0.6, 0.8)
	planter.position = Vector3(pos.x, 0.3, pos.z)
	planter.set_surface_override_material(0, _planter_mat)
	parent.add_child(planter)

	var foliage := MeshInstance3D.new()
	foliage.name = node_name + "Foliage"
	foliage.mesh = SphereMesh.new()
	(foliage.mesh as SphereMesh).radius = 0.4
	(foliage.mesh as SphereMesh).height = 0.8
	foliage.position = Vector3(pos.x, 0.9, pos.z)
	foliage.set_surface_override_material(0, _plant_mat)
	parent.add_child(foliage)
