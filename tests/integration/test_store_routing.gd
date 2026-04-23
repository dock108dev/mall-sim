## Integration test: ISSUE-001 — every active store exposes a complete routing
## payload via ContentRegistry.get_store_route() and the resolved scene_path
## loads a PackedScene wired with that category's own assets (no fallback to
## another store's scene).
extends GutTest

const _ACTIVE_STORE_IDS: Array[StringName] = [
	&"sports",
	&"retro_games",
	&"rentals",
	&"pocket_creatures",
	&"electronics",
]

const _REQUIRED_KEYS: Array[StringName] = [
	&"scene_path",
	&"inventory_type",
	&"interaction_set_id",
	&"tutorial_context_id",
]


func test_get_store_route_returns_all_fields_for_active_stores() -> void:
	for store_id: StringName in _ACTIVE_STORE_IDS:
		var route: Dictionary = ContentRegistry.get_store_route(store_id)
		assert_false(
			route.is_empty(),
			"get_store_route(%s) must not be empty" % store_id
		)
		for key: StringName in _REQUIRED_KEYS:
			assert_true(
				route.has(key),
				"route for %s missing key %s" % [store_id, key]
			)
			var value: Variant = route[key]
			assert_ne(
				str(value), "",
				"route for %s has empty %s" % [store_id, key]
			)


func test_unknown_store_id_returns_empty_route() -> void:
	var route: Dictionary = ContentRegistry.get_store_route(
		&"definitely_not_a_real_store"
	)
	assert_true(route.is_empty(), "unknown store_id must return empty route")


func test_sports_route_resolves_to_sports_scene_not_sneakers_fallback() -> void:
	var route: Dictionary = ContentRegistry.get_store_route(&"sports")
	assert_false(route.is_empty(), "sports route must resolve")
	var scene_path: String = String(route.get("scene_path", ""))
	assert_true(
		scene_path.ends_with("sports_memorabilia.tscn"),
		"sports scene_path must be sports_memorabilia, got %s" % scene_path
	)
	assert_eq(
		String(route.get("inventory_type", "")),
		"sports_memorabilia",
		"sports inventory_type must be sports_memorabilia"
	)
	assert_eq(
		String(route.get("interaction_set_id", "")),
		"sports_memorabilia",
		"sports interaction_set_id must be sports_memorabilia"
	)
	var scene: PackedScene = load(scene_path) as PackedScene
	assert_not_null(scene, "sports scene must load as PackedScene")


func test_active_store_scenes_exist_on_disk() -> void:
	for store_id: StringName in _ACTIVE_STORE_IDS:
		var route: Dictionary = ContentRegistry.get_store_route(store_id)
		var scene_path: String = String(route.get("scene_path", ""))
		assert_true(
			ResourceLoader.exists(scene_path),
			"%s scene missing on disk: %s" % [store_id, scene_path]
		)


func test_route_scene_paths_are_unique_per_store() -> void:
	var seen: Dictionary = {}
	for store_id: StringName in _ACTIVE_STORE_IDS:
		var route: Dictionary = ContentRegistry.get_store_route(store_id)
		var path: String = String(route.get("scene_path", ""))
		assert_false(
			seen.has(path),
			"scene_path %s reused by %s and %s"
				% [path, seen.get(path, &""), store_id]
		)
		seen[path] = store_id
