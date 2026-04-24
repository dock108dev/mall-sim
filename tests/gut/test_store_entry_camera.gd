## Integration test: every active store scene ships a single `Camera3D` so
## the hub-entry path has something to activate via `CameraAuthority`.
## Without this, entering a store in hub mode renders the default clear
## color (the "brown screen" regression captured in
## docs/audits/phase0-ui-integrity.md P0.2).
extends GutTest

const _ACTIVE_STORE_IDS: Array[StringName] = [
	&"sports",
	&"retro_games",
	&"rentals",
	&"pocket_creatures",
	&"electronics",
]


func test_every_store_scene_has_exactly_one_camera_3d() -> void:
	for store_id: StringName in _ACTIVE_STORE_IDS:
		var scene_path: String = ContentRegistry.get_scene_path(store_id)
		assert_false(
			scene_path.is_empty(),
			"store '%s' has no scene_path in ContentRegistry" % store_id
		)
		var packed: PackedScene = load(scene_path) as PackedScene
		assert_not_null(
			packed,
			"store '%s' scene '%s' failed to load" % [store_id, scene_path]
		)
		var root: Node = packed.instantiate()
		var cameras: Array[Camera3D] = _collect_cameras(root)
		assert_eq(
			cameras.size(), 1,
			"store '%s' must ship exactly 1 Camera3D (got %d at %s)"
			% [
				store_id,
				cameras.size(),
				str(cameras.map(
					func(c: Camera3D) -> String: return str(c.get_path())
				)),
			]
		)
		if cameras.size() == 1:
			assert_false(
				cameras[0].current,
				(
					"store '%s' Camera3D must ship with current=false so "
					+ "CameraAuthority owns activation"
				) % store_id
			)
		root.free()


func _collect_cameras(node: Node) -> Array[Camera3D]:
	var result: Array[Camera3D] = []
	if node is Camera3D:
		result.append(node as Camera3D)
	for child: Node in node.get_children():
		result.append_array(_collect_cameras(child))
	return result
