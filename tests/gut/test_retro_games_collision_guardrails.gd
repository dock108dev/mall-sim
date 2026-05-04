## Verifies physics collision guardrails on retro_games.tscn so the FP body
## cannot walk through walls, shelves, the checkout counter, the refurb bench,
## or the glass entrance door, and the spawn marker faces inward.
extends GutTest

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"

## Names of fixtures expected to expose a `StaticBody3D` collider on the
## store_fixtures collision layer (bit 2). Walls live on layer 1 and are
## checked separately.
const _FIXTURES_WITH_STATIC_BODY: PackedStringArray = [
	"crt_demo_area",
	"CartRackLeft",
	"CartRackRight",
	"GlassCase",
	"ConsoleShelf",
	"AccessoriesBin",
	"Checkout",
	"BackroomDoor",
	"EntranceDoor",
	"refurb_bench",
]

## Names of wall-class colliders expected on the world_geometry collision
## layer (bit 1).
const _WALL_BODIES: PackedStringArray = [
	"Floor",
	"BackWallBody",
	"LeftWallBody",
	"RightWallBody",
	"FrontWallLeftBody",
	"FrontWallRightBody",
]

var _root: Node3D = null


func before_all() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	assert_not_null(scene, "Retro Games scene must load")
	if scene:
		_root = scene.instantiate() as Node3D
		add_child(_root)


func after_all() -> void:
	if is_instance_valid(_root):
		_root.free()
	_root = null


func test_walls_have_static_body_on_world_layer() -> void:
	for wall_name: String in _WALL_BODIES:
		var node: Node = _root.get_node_or_null(wall_name)
		assert_not_null(node, "%s must exist as a wall StaticBody3D" % wall_name)
		if node == null:
			continue
		assert_true(
			node is StaticBody3D,
			"%s must be a StaticBody3D so the FP CharacterBody3D collides with it"
				% wall_name
		)
		var body := node as StaticBody3D
		assert_eq(
			body.collision_layer & 1, 1,
			"%s must include the world_geometry layer (bit 1)" % wall_name
		)
		var shape: CollisionShape3D = (
			body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		)
		assert_not_null(
			shape, "%s must own a CollisionShape3D child" % wall_name
		)
		if shape:
			assert_not_null(
				shape.shape, "%s/CollisionShape3D.shape must be set" % wall_name
			)


func test_fixtures_have_static_body_on_fixture_layer() -> void:
	for fixture_name: String in _FIXTURES_WITH_STATIC_BODY:
		var fixture: Node = _root.get_node_or_null(fixture_name)
		assert_not_null(
			fixture, "%s must exist as an interior fixture" % fixture_name
		)
		if fixture == null:
			continue
		var body: StaticBody3D = (
			fixture.get_node_or_null("StaticBody3D") as StaticBody3D
		)
		assert_not_null(
			body,
			"%s must own a StaticBody3D child so the FP body cannot walk through it"
				% fixture_name
		)
		if body == null:
			continue
		assert_eq(
			body.collision_layer & 2, 2,
			"%s/StaticBody3D must include the store_fixtures layer (bit 2)"
				% fixture_name
		)
		var shape: CollisionShape3D = (
			body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		)
		assert_not_null(
			shape, "%s/StaticBody3D must own a CollisionShape3D" % fixture_name
		)
		if shape:
			assert_not_null(
				shape.shape,
				"%s/StaticBody3D/CollisionShape3D.shape must be set"
					% fixture_name
			)


func test_player_entry_spawn_orientation_faces_into_store() -> void:
	var marker: Marker3D = (
		_root.get_node_or_null("PlayerEntrySpawn") as Marker3D
	)
	assert_not_null(marker, "PlayerEntrySpawn Marker3D must exist")
	if marker == null:
		return
	# Godot's convention: a node's "forward" is the negative Z axis of its
	# basis. The marker sits near the front entrance (z>=8) so forward must
	# point toward the back wall (decreasing z) to face into the store.
	var forward: Vector3 = -marker.global_transform.basis.z
	assert_lt(
		forward.z, 0.0,
		"PlayerEntrySpawn forward (-basis.z) must point into the store (z < 0); got %.3f"
			% forward.z
	)


func test_player_entry_spawn_clears_walls_and_door() -> void:
	var marker: Marker3D = (
		_root.get_node_or_null("PlayerEntrySpawn") as Marker3D
	)
	assert_not_null(marker, "PlayerEntrySpawn Marker3D must exist")
	if marker == null:
		return
	var pos: Vector3 = marker.global_position
	# Capsule radius is 0.35 in store_player_body.tscn. The spawn must clear
	# every wall surface by at least the capsule radius so the body does not
	# spawn inside a collider. Wall surfaces: x=±8.0, z=-10.0, z=+10.05 (front
	# walls) — the entrance gap is at X∈[-1.5,+1.5] so the +z side check uses
	# the glass door collider front face at z=9.95.
	var capsule_radius: float = 0.35
	assert_gt(
		pos.x + 8.0, capsule_radius,
		"Spawn must clear left wall by capsule radius (got x=%.3f)" % pos.x
	)
	assert_gt(
		8.0 - pos.x, capsule_radius,
		"Spawn must clear right wall by capsule radius (got x=%.3f)" % pos.x
	)
	assert_gt(
		pos.z + 10.0, capsule_radius,
		"Spawn must clear back wall by capsule radius (got z=%.3f)" % pos.z
	)
	assert_gt(
		9.95 - pos.z, capsule_radius,
		"Spawn must clear glass door collider by capsule radius (got z=%.3f)"
			% pos.z
	)


func test_entrance_door_static_body_uses_fixture_layer() -> void:
	# The glass door collider must use the store_fixtures layer so the
	# player.collision_mask=3 stops here. A door dropped to layer 0 would let
	# the player walk into the void between front walls.
	var body: StaticBody3D = (
		_root.get_node_or_null("EntranceDoor/StaticBody3D") as StaticBody3D
	)
	assert_not_null(body, "EntranceDoor must own a StaticBody3D child")
	if body == null:
		return
	assert_eq(
		body.collision_layer & 2, 2,
		"EntranceDoor/StaticBody3D must include the store_fixtures layer (bit 2)"
	)


func test_entrance_door_interactable_trigger_stays_within_wall_height() -> void:
	# The Interactable trigger volume must not extend above the wall ceiling
	# — extending higher would let the player trigger an "Exit" prompt while
	# staring above the door surface and could overlap the front wall
	# colliders' Y-extent during scene authoring.
	#
	# Interactable._ready() reparents authored CollisionShape3D children
	# under a generated `InteractionArea` child, so descend the tree to find
	# the box shape rather than asserting an authoring path that the runtime
	# rewrites.
	var trigger: Area3D = (
		_root.get_node_or_null("EntranceDoor/Interactable") as Area3D
	)
	assert_not_null(trigger, "EntranceDoor/Interactable Area3D must exist")
	if trigger == null:
		return
	var shape: CollisionShape3D = (
		trigger.find_child("CollisionShape3D", true, false) as CollisionShape3D
	)
	assert_not_null(
		shape,
		"EntranceDoor/Interactable subtree must own a CollisionShape3D"
	)
	if shape == null or not (shape.shape is BoxShape3D):
		return
	var box := shape.shape as BoxShape3D
	# Trigger top in world space = trigger.y + box.size.y / 2.0.
	var trigger_top_y: float = trigger.global_position.y + box.size.y / 2.0
	assert_lte(
		trigger_top_y, 3.5 + 0.01,
		"Interactable trigger top must not exceed wall height (3.5 m); got %.3f"
			% trigger_top_y
	)
