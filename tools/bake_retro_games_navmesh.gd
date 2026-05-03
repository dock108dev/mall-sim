## One-shot tool: bake retro_games.tscn NavigationRegion3D and save the
## resulting NavigationMesh as an external resource. Run with:
##   bash scripts/godot_exec.sh --headless --script tools/bake_retro_games_navmesh.gd
extends SceneTree

const SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const OUTPUT_PATH: String = "res://game/navigation/retro_games_navmesh.tres"


func _initialize() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("bake_retro_games_navmesh: failed to load %s" % SCENE_PATH)
		quit(1)
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		push_error("bake_retro_games_navmesh: failed to instantiate scene")
		quit(1)
		return
	root.add_child(instance)
	# Let nodes finish entering tree (collision shapes register, etc).
	await process_frame
	await physics_frame

	var region: NavigationRegion3D = (
		instance.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	)
	if region == null:
		push_error("bake_retro_games_navmesh: NavigationRegion3D not found")
		quit(1)
		return

	var nav_mesh: NavigationMesh = region.navigation_mesh
	if nav_mesh == null:
		push_error("bake_retro_games_navmesh: NavigationRegion3D has no navigation_mesh")
		quit(1)
		return

	# Reset polygon data so the bake produces a fresh mesh rather than
	# concatenating to the existing single-quad stub.
	nav_mesh.clear_polygons()
	nav_mesh.vertices = PackedVector3Array()

	# Bake parameters per the issue spec.
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.1
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_max_climb = 0.2
	nav_mesh.agent_max_slope = 30.0
	# PARSED_GEOMETRY_BOTH so StaticBody3D fixture colliders are cut out.
	nav_mesh.geometry_parsed_geometry_type = (
		NavigationMesh.PARSED_GEOMETRY_BOTH
	)
	# Constrain bake to the playable bounds (matches the prior stub's footprint
	# in X/Z, with a Y range tight enough to exclude the ceiling slab).
	nav_mesh.filter_baking_aabb = AABB(
		Vector3(-7.7, -1.0, -9.7),
		Vector3(15.4, 2.5, 19.4)
	)

	# Drive the bake synchronously via NavigationServer3D so we can rely on
	# the polygon data being populated before saving. The Floor StaticBody
	# and fixture obstacle bodies are siblings of NavigationRegion3D, not
	# descendants, so the parse root must be the scene root.
	var source_geometry: NavigationMeshSourceGeometryData3D = (
		NavigationMeshSourceGeometryData3D.new()
	)
	NavigationServer3D.parse_source_geometry_data(
		nav_mesh, source_geometry, instance
	)
	NavigationServer3D.bake_from_source_geometry_data(
		nav_mesh, source_geometry
	)

	var poly_count: int = nav_mesh.get_polygon_count()
	if poly_count <= 0:
		push_error("bake_retro_games_navmesh: bake produced no polygons")
		quit(1)
		return
	if poly_count <= 1:
		push_warning(
			"bake_retro_games_navmesh: bake produced only %d polygon(s)"
			% poly_count
		)

	var save_err: int = ResourceSaver.save(nav_mesh, OUTPUT_PATH)
	if save_err != OK:
		push_error(
			"bake_retro_games_navmesh: ResourceSaver.save failed (%d)" % save_err
		)
		quit(1)
		return

	# ResourceSaver omits properties that match their compile-time defaults.
	# `cell_size` (default 0.25) and `geometry_parsed_geometry_type`
	# (default MESH_INSTANCES) are required by the runtime rebake guard
	# (NavMeshRebaker._has_valid_nav_region) and the SSOT tripwire that
	# greps for them in store nav meshes. Inject them explicitly so a
	# fresh load preserves the bake-ready configuration.
	_ensure_bake_ready_fields(OUTPUT_PATH)

	print(
		"bake_retro_games_navmesh: saved %s (%d polygons, %d vertices)"
		% [OUTPUT_PATH, poly_count, nav_mesh.vertices.size()]
	)
	quit(0)


func _ensure_bake_ready_fields(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error(
			"bake_retro_games_navmesh: cannot read %s for post-process" % path
		)
		return
	var injected: String = text
	if not injected.contains("cell_size = "):
		injected = injected.replace(
			"[resource]\n", "[resource]\ncell_size = 0.25\n"
		)
	if not injected.contains("geometry_parsed_geometry_type = "):
		injected = injected.replace(
			"[resource]\n",
			"[resource]\ngeometry_parsed_geometry_type = 2\n"
		)
	if injected == text:
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error(
			"bake_retro_games_navmesh: cannot write %s for post-process" % path
		)
		return
	f.store_string(injected)
	f.close()
