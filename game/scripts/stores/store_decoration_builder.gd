## Builds placeholder decorative props for each store type.
class_name StoreDecorationBuilder
extends RefCounted

const SMALL_STORE_HALF_W: float = 3.5
const SMALL_STORE_HALF_D: float = 2.5
const MEDIUM_STORE_HALF_W: float = 4.5
const MEDIUM_STORE_HALF_D: float = 3.0
const WALL_HEIGHT: float = 3.0

static var _poster_red: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_poster_red.tres"
)
static var _poster_blue: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_poster_blue.tres"
)
static var _poster_green: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_poster_green.tres"
)
static var _poster_yellow: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_poster_yellow.tres"
)
static var _poster_purple: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_poster_purple.tres"
)
static var _trash_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_trash_can.tres"
)
static var _plant_mat: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_plant_foliage.tres"
)
static var _wood_dark: StandardMaterial3D = preload(
	"res://game/assets/materials/mat_wood_dark.tres"
)


## Builds decorations for the given store type under a Decorations node.
static func build(parent: Node3D, store_type: String) -> Node3D:
	var decorations := Node3D.new()
	decorations.name = "Decorations"
	parent.add_child(decorations)

	match store_type:
		"sports", "sports_memorabilia":
			_build_sports(decorations)
		"retro_games":
			_build_retro(decorations)
		"video_rental":
			_build_video(decorations)
		"pocket_creatures":
			_build_pocket(decorations)
		"electronics", "consumer_electronics":
			_build_electronics(decorations)
		_:
			push_warning(
				"StoreDecorationBuilder: unknown store type '%s'"
				% store_type
			)

	return decorations


static func _build_sports(parent: Node3D) -> void:
	var hw: float = SMALL_STORE_HALF_W
	var hd: float = SMALL_STORE_HALF_D
	_add_store_sign(parent, hw, hd, _poster_red)
	_add_wall_poster(
		parent, "PosterBack1",
		Vector3(-2.0, 2.2, -hd + 0.06), Vector3(0.6, 0.4, 0.02),
		_poster_red
	)
	_add_wall_poster(
		parent, "PosterBack2",
		Vector3(1.0, 2.2, -hd + 0.06), Vector3(0.5, 0.35, 0.02),
		_poster_yellow
	)
	_add_wall_poster(
		parent, "PosterLeft",
		Vector3(-hw + 0.06, 2.0, -0.5), Vector3(0.02, 0.4, 0.5),
		_poster_blue
	)
	_add_trash_can(parent, Vector3(hw - 0.4, 0.0, hd - 0.6))


static func _build_retro(parent: Node3D) -> void:
	var hw: float = SMALL_STORE_HALF_W
	var hd: float = SMALL_STORE_HALF_D
	_add_store_sign(parent, hw, hd, _poster_purple)
	_add_wall_poster(
		parent, "PosterBack1",
		Vector3(-1.5, 2.2, -hd + 0.06), Vector3(0.5, 0.4, 0.02),
		_poster_purple
	)
	_add_wall_poster(
		parent, "PosterBack2",
		Vector3(1.5, 2.2, -hd + 0.06), Vector3(0.5, 0.35, 0.02),
		_poster_green
	)
	_add_wall_poster(
		parent, "PosterRight",
		Vector3(hw - 0.06, 2.0, -1.0), Vector3(0.02, 0.35, 0.45),
		_poster_blue
	)
	_add_small_plant(parent, Vector3(-hw + 0.4, 0.0, hd - 0.6))


static func _build_video(parent: Node3D) -> void:
	var hw: float = MEDIUM_STORE_HALF_W
	var hd: float = MEDIUM_STORE_HALF_D
	_add_store_sign(parent, hw, hd, _poster_blue)
	_add_wall_poster(
		parent, "PosterBack1",
		Vector3(-3.0, 2.2, -hd + 0.06), Vector3(0.6, 0.45, 0.02),
		_poster_red
	)
	_add_wall_poster(
		parent, "PosterBack2",
		Vector3(0.0, 2.2, -hd + 0.06), Vector3(0.5, 0.4, 0.02),
		_poster_blue
	)
	_add_wall_poster(
		parent, "PosterLeft",
		Vector3(-hw + 0.06, 2.0, 0.0), Vector3(0.02, 0.4, 0.5),
		_poster_yellow
	)
	_add_trash_can(parent, Vector3(hw - 0.4, 0.0, hd - 0.6))
	_add_small_plant(parent, Vector3(-hw + 0.4, 0.0, hd - 0.6))


static func _build_pocket(parent: Node3D) -> void:
	var hw: float = MEDIUM_STORE_HALF_W
	var hd: float = MEDIUM_STORE_HALF_D
	_add_store_sign(parent, hw, hd, _poster_yellow)
	_add_wall_poster(
		parent, "PosterBack1",
		Vector3(-2.5, 2.2, -hd + 0.06), Vector3(0.55, 0.4, 0.02),
		_poster_green
	)
	_add_wall_poster(
		parent, "PosterBack2",
		Vector3(2.0, 2.2, -hd + 0.06), Vector3(0.5, 0.35, 0.02),
		_poster_yellow
	)
	_add_wall_poster(
		parent, "PosterRight",
		Vector3(hw - 0.06, 2.0, -1.0), Vector3(0.02, 0.4, 0.5),
		_poster_purple
	)
	_add_trash_can(parent, Vector3(hw - 0.4, 0.0, hd - 0.6))


static func _build_electronics(parent: Node3D) -> void:
	var hw: float = MEDIUM_STORE_HALF_W
	var hd: float = MEDIUM_STORE_HALF_D
	_add_store_sign(parent, hw, hd, _poster_blue)
	_add_wall_poster(
		parent, "PosterBack1",
		Vector3(-3.0, 2.2, -hd + 0.06), Vector3(0.6, 0.4, 0.02),
		_poster_blue
	)
	_add_wall_poster(
		parent, "PosterBack2",
		Vector3(1.5, 2.2, -hd + 0.06), Vector3(0.5, 0.35, 0.02),
		_poster_green
	)
	_add_wall_poster(
		parent, "PosterLeft",
		Vector3(-hw + 0.06, 2.0, -0.8), Vector3(0.02, 0.35, 0.5),
		_poster_red
	)
	_add_small_plant(parent, Vector3(-hw + 0.4, 0.0, hd - 0.6))


## Adds the sign backing mesh above the store entrance. The exterior label
## itself is authored as a `SignName` Label3D inside each store's .tscn so
## that orientation and font are art-controlled per scene.
static func _add_store_sign(
	parent: Node3D,
	half_w: float, half_d: float,
	accent_mat: StandardMaterial3D
) -> void:
	var sign_w: float = half_w * 1.2
	var sign_backing := MeshInstance3D.new()
	sign_backing.name = "StoreSignBacking"
	sign_backing.mesh = BoxMesh.new()
	(sign_backing.mesh as BoxMesh).size = Vector3(sign_w, 0.5, 0.08)
	sign_backing.position = Vector3(0.0, 2.75, half_d + 0.1)
	sign_backing.set_surface_override_material(0, accent_mat)
	parent.add_child(sign_backing)


## Adds a flat wall poster (decorative plane flush against a wall).
static func _add_wall_poster(
	parent: Node3D, poster_name: String,
	pos: Vector3, size: Vector3,
	material: StandardMaterial3D
) -> void:
	var poster := MeshInstance3D.new()
	poster.name = poster_name
	poster.mesh = BoxMesh.new()
	(poster.mesh as BoxMesh).size = size
	poster.position = pos
	poster.set_surface_override_material(0, material)
	parent.add_child(poster)


## Adds a small cylindrical trash can on the floor near the entrance.
static func _add_trash_can(parent: Node3D, pos: Vector3) -> void:
	var can := MeshInstance3D.new()
	can.name = "TrashCan"
	can.mesh = CylinderMesh.new()
	(can.mesh as CylinderMesh).top_radius = 0.15
	(can.mesh as CylinderMesh).bottom_radius = 0.13
	(can.mesh as CylinderMesh).height = 0.5
	can.position = Vector3(pos.x, 0.25, pos.z)
	can.set_surface_override_material(0, _trash_mat)
	parent.add_child(can)


## Adds a small potted plant on the floor (planter box + foliage sphere).
static func _add_small_plant(parent: Node3D, pos: Vector3) -> void:
	var planter := MeshInstance3D.new()
	planter.name = "SmallPlanter"
	planter.mesh = BoxMesh.new()
	(planter.mesh as BoxMesh).size = Vector3(0.3, 0.35, 0.3)
	planter.position = Vector3(pos.x, 0.175, pos.z)
	planter.set_surface_override_material(0, _wood_dark)
	parent.add_child(planter)

	var foliage := MeshInstance3D.new()
	foliage.name = "SmallPlantFoliage"
	foliage.mesh = SphereMesh.new()
	(foliage.mesh as SphereMesh).radius = 0.2
	(foliage.mesh as SphereMesh).height = 0.4
	foliage.position = Vector3(pos.x, 0.55, pos.z)
	foliage.set_surface_override_material(0, _plant_mat)
	parent.add_child(foliage)
