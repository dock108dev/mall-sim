## Integration test — boot content loading populates ContentRegistry before gameplay.
extends GutTest

const STORE_IDS: Array[String] = [
	"sports_memorabilia",
	"retro_games",
	"video_rental",
	"pocket_creatures",
	"electronics",
]

const EXPECTED_STORE_RESOLUTIONS: Dictionary = {
	"sports_memorabilia": &"sports",
	"retro_games": &"retro_games",
	"video_rental": &"rentals",
	"pocket_creatures": &"pocket_creatures",
	"electronics": &"electronics",
}

const SAMPLE_ITEM_IDS: Array[String] = [
	"sports_duvall_hr_common",
	"sports_okoro_hoops_common",
	"retro_plumber_world_ss_loose",
	"retro_hedgehog_rush_md_loose",
	"rental_cosmic_battles_4_vhs",
	"rental_velociraptor_gardens_vhs",
	"pc_booster_base_set",
	"pc_single_blazedragon_holo",
	"elec_zunewave_128",
	"elec_portastation_console",
]


func before_all() -> void:
	ContentRegistry.clear_for_testing()
	DataLoaderSingleton.load_all()
	DifficultySystemSingleton._load_config()


func test_load_all_completes_without_push_errors() -> void:
	var load_errors: Array[String] = DataLoaderSingleton.get_load_errors()
	assert_eq(
		load_errors.size(), 0,
		"DataLoader should not record load errors: %s" % [load_errors]
	)


func test_all_store_ids_resolve_to_expected_canonical_ids() -> void:
	for store_id: String in STORE_IDS:
		var resolved: StringName = ContentRegistry.resolve(store_id)
		assert_eq(
			resolved,
			EXPECTED_STORE_RESOLUTIONS[store_id],
			"Store ID '%s' should resolve to the expected canonical ID"
			% store_id
		)


func test_each_store_entry_and_scene_path_exist() -> void:
	for store_id: String in STORE_IDS:
		var canonical: StringName = ContentRegistry.resolve(store_id)
		var entry: Dictionary = ContentRegistry.get_entry(canonical)
		assert_false(
			entry.is_empty(),
			"Store '%s' should have a non-empty registry entry" % store_id
		)
		var scene_path: String = ContentRegistry.get_scene_path(canonical)
		assert_false(
			scene_path.is_empty(),
			"Store '%s' should have a non-empty scene path" % store_id
		)


func test_at_least_ten_known_item_ids_are_registered() -> void:
	assert_gte(
		ContentRegistry.get_all_ids("item").size(), 10,
		"ContentRegistry should register at least 10 item IDs"
	)
	for item_id: String in SAMPLE_ITEM_IDS:
		assert_eq(
			ContentRegistry.resolve(item_id),
			StringName(item_id),
			"Item '%s' should resolve through ContentRegistry" % item_id
		)


func test_known_item_ids_are_accessible_from_data_loader() -> void:
	for item_id: String in SAMPLE_ITEM_IDS:
		assert_not_null(
			DataLoaderSingleton.get_item(item_id),
			"Item '%s' should be accessible after boot load" % item_id
		)


func test_all_customer_profile_ids_resolve() -> void:
	for customer_id: StringName in _load_ids_from_json(
		"res://game/content/customers/customer_profiles.json"
	):
		assert_eq(
			ContentRegistry.resolve(String(customer_id)),
			customer_id,
			"Customer profile '%s' should resolve through ContentRegistry"
			% customer_id
		)
		assert_not_null(
			DataLoaderSingleton.get_customer_type_definition(
				String(customer_id)
			),
			"Customer profile '%s' should be accessible after boot load"
			% customer_id
		)


func test_all_staff_definition_ids_resolve() -> void:
	for staff_id: StringName in _load_ids_from_json(
		"res://game/content/staff/staff_definitions.json"
	):
		assert_eq(
			ContentRegistry.resolve(String(staff_id)),
			staff_id,
			"Staff definition '%s' should resolve through ContentRegistry"
			% staff_id
		)
		assert_not_null(
			DataLoaderSingleton.get_staff_definition(String(staff_id)),
			"Staff definition '%s' should be accessible after boot load"
			% staff_id
		)


func test_unknown_id_returns_empty_and_emits_push_error() -> void:
	var registry_double: GDScript = partial_double(
		preload("res://game/autoload/content_registry.gd")
	)
	var registry: Node = registry_double.new()
	add_child_autofree(registry)
	var result: StringName = registry.resolve("nonexistent_item")
	assert_eq(
		result, &"",
		"Unknown IDs should resolve to an empty StringName"
	)
	assert_called(
		registry, "_emit_warning",
		[
			"ContentRegistry: unknown ID 'nonexistent_item' (normalized: 'nonexistent_item')"
		]
	)


func _load_ids_from_json(path: String) -> Array[StringName]:
	var data: Array = DataLoader.load_catalog_entries(path)
	assert_false(data.is_empty(), "%s should have entries" % path)
	var ids: Array[StringName] = []
	for entry: Variant in data:
		assert_true(entry is Dictionary, "%s entries should be dictionaries" % path)
		if entry is not Dictionary:
			continue
		var entry_dict: Dictionary = entry
		assert_true(entry_dict.has("id"), "%s entries should include id" % path)
		if not entry_dict.has("id"):
			continue
		ids.append(StringName(str(entry_dict["id"])))
	return ids
