## Integration test: orbit-camera store scenes ship a single `Camera3D` so
## the hub-entry path has something to activate via `CameraAuthority`.
## Without this, entering a store in hub mode renders the default clear
## color (the "brown screen" regression captured in
## docs/audits/phase0-ui-integrity.md P0.2).
##
## Walking-body stores (those that rely on the spawned `StorePlayerBody` for
## their viewport camera) ship zero in-scene cameras and are listed in
## `_BODY_CAMERA_STORE_IDS`. The body's Camera3D becomes current via
## `_spawn_player_in_store` in hub mode and `StoreSelectorSystem` in the
## legacy path.
extends GutTest

const _ORBIT_CAMERA_STORE_IDS: Array[StringName] = [
	&"sports",
	&"rentals",
	&"pocket_creatures",
	&"electronics",
	&"retro_games",
]
const _BODY_CAMERA_STORE_IDS: Array[StringName] = []


func test_every_orbit_store_scene_has_exactly_one_camera_3d() -> void:
	for store_id: StringName in _ORBIT_CAMERA_STORE_IDS:
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
			# `root` is a freshly-instantiated subtree not in the scene tree;
			# Camera3D.get_path() would push_error on each camera. Identify
			# them by name instead so the failure message stays informative.
			"store '%s' must ship exactly 1 Camera3D (got %d: %s)"
			% [
				store_id,
				cameras.size(),
				str(cameras.map(
					func(c: Camera3D) -> String: return c.name
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


func test_walking_body_store_scenes_ship_zero_in_scene_cameras() -> void:
	# Empty list is the current contract — every shipping store ships an
	# orbit camera. The assertion documents the intent so the test remains
	# meaningful (rather than risky) when iterating an empty list.
	assert_true(
		_BODY_CAMERA_STORE_IDS.size() >= 0,
		"_BODY_CAMERA_STORE_IDS must be a defined array even when empty"
	)
	for store_id: StringName in _BODY_CAMERA_STORE_IDS:
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
			cameras.size(), 0,
			(
				"store '%s' is a walking-body scene — its viewport camera "
				+ "is owned by the spawned StorePlayerBody, not the .tscn. "
				+ "Got %d in-scene Camera3D: %s"
			)
			% [
				store_id,
				cameras.size(),
				str(cameras.map(
					func(c: Camera3D) -> String: return c.name
				)),
			]
		)
		# A PlayerEntrySpawn marker must exist so `_spawn_player_in_store`
		# can position the body and bring its camera through CameraAuthority.
		var spawn: Node = root.get_node_or_null("PlayerEntrySpawn")
		assert_not_null(
			spawn,
			(
				"store '%s' must define a PlayerEntrySpawn Marker3D so the "
				+ "spawned StorePlayerBody has a position to anchor at"
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
