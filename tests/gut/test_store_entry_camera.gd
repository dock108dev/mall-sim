## Integration test: every store scene ships exactly one in-scene `Camera3D`
## (named `StoreCamera`) so the hub-entry path has something to activate via
## `CameraAuthority`. Without this, entering a store renders the default
## clear color (the "brown screen" regression captured in
## docs/audits/phase0-ui-integrity.md P0.2).
##
## Walking-body stores additionally author a `PlayerEntrySpawn` Marker3D so
## `_spawn_player_in_store` has a position to anchor the avatar at. Their
## viewport camera is still the in-scene `StoreCamera` (a fixed diorama
## angle), not a camera carried by the spawned body.
extends GutTest

const _IN_SCENE_CAMERA_STORE_IDS: Array[StringName] = [
	&"sports",
	&"rentals",
	&"pocket_creatures",
	&"electronics",
	&"retro_games",
]
const _WALKING_BODY_STORE_IDS: Array[StringName] = [
	&"retro_games",
]


func test_every_store_scene_ships_exactly_one_camera_3d() -> void:
	for store_id: StringName in _IN_SCENE_CAMERA_STORE_IDS:
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


func test_walking_body_store_scenes_have_player_entry_spawn() -> void:
	for store_id: StringName in _WALKING_BODY_STORE_IDS:
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
		# A PlayerEntrySpawn marker must exist so `_spawn_player_in_store`
		# can position the avatar; the in-scene `StoreCamera` is still
		# what CameraAuthority activates for the viewport.
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
