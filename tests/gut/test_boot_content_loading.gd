## Integration test — boot sequence content loading and ContentRegistry population.
extends GutTest


const STORE_IDS: Array[String] = [
	"sports_memorabilia",
	"retro_games",
	"video_rental",
	"pocket_creatures",
	"electronics",
]

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

const STAFF_IDS: Array[String] = [
	"cashier_skill_1",
	"cashier_skill_2",
	"cashier_skill_3",
	"stocker_skill_1",
	"stocker_skill_2",
	"stocker_skill_3",
	"greeter_skill_1",
	"greeter_skill_2",
	"greeter_skill_3",
]


func test_load_all_content_no_errors() -> void:
	var errors: Array[String] = DataLoaderSingleton.get_load_errors()
	assert_eq(
		errors.size(), 0,
		"DataLoader should have no load errors: %s" % [errors]
	)


func test_content_registry_ready() -> void:
	assert_true(
		ContentRegistry.is_ready(),
		"ContentRegistry should be ready after boot"
	)


func test_all_five_store_ids_resolve() -> void:
	for raw: String in STORE_IDS:
		var canonical: StringName = ContentRegistry.resolve(raw)
		assert_ne(
			canonical, &"",
			"Store ID '%s' should resolve to a canonical ID" % raw
		)


func test_store_entries_non_empty() -> void:
	for raw: String in STORE_IDS:
		var canonical: StringName = ContentRegistry.resolve(raw)
		if canonical.is_empty():
			fail_test("Cannot test entry — '%s' did not resolve" % raw)
			continue
		var entry: Dictionary = ContentRegistry.get_entry(canonical)
		assert_false(
			entry.is_empty(),
			"get_entry() for '%s' should return non-empty Dictionary"
			% canonical
		)


func test_store_scene_paths_non_empty() -> void:
	for raw: String in STORE_IDS:
		var canonical: StringName = ContentRegistry.resolve(raw)
		if canonical.is_empty():
			fail_test("Cannot test scene path — '%s' did not resolve" % raw)
			continue
		var path: String = ContentRegistry.get_scene_path(canonical)
		assert_false(
			path.is_empty(),
			"Scene path for '%s' should be non-empty" % canonical
		)


func test_at_least_ten_items_registered() -> void:
	var count: int = DataLoaderSingleton.get_item_count()
	assert_gte(
		count, 10,
		"Should have at least 10 items registered, found %d" % count
	)


func test_sample_item_ids_accessible() -> void:
	for item_id: String in SAMPLE_ITEM_IDS:
		var item: ItemDefinition = DataLoaderSingleton.get_item(item_id)
		assert_not_null(
			item,
			"Item '%s' should be loadable via DataLoader" % item_id
		)


func test_item_ids_in_registry() -> void:
	var ids: Array[StringName] = ContentRegistry.get_all_ids("item")
	assert_gte(
		ids.size(), 10,
		"ContentRegistry should have at least 10 item IDs, found %d"
		% ids.size()
	)


func test_customer_profiles_registered() -> void:
	var customers: Array[CustomerTypeDefinition] = (
		DataLoaderSingleton.get_all_customers()
	)
	assert_gt(
		customers.size(), 0,
		"Should have at least one customer profile loaded"
	)
	var ids: Array[StringName] = ContentRegistry.get_all_ids("customer")
	assert_eq(
		ids.size(), customers.size(),
		"Registry customer count (%d) should match DataLoader (%d)"
		% [ids.size(), customers.size()]
	)


func test_staff_definitions_registered() -> void:
	var staff: Array[StaffDefinition] = (
		DataLoaderSingleton.get_all_staff_definitions()
	)
	assert_eq(
		staff.size(), STAFF_IDS.size(),
		"Should have %d staff definitions, found %d"
		% [STAFF_IDS.size(), staff.size()]
	)


func test_staff_ids_accessible() -> void:
	for staff_id: String in STAFF_IDS:
		var def: StaffDefinition = (
			DataLoaderSingleton.get_staff_definition(staff_id)
		)
		assert_not_null(
			def,
			"Staff '%s' should be loadable via DataLoader" % staff_id
		)


func test_staff_ids_in_registry() -> void:
	var ids: Array[StringName] = ContentRegistry.get_all_ids("staff")
	for staff_id: String in STAFF_IDS:
		assert_has(
			ids, StringName(staff_id),
			"Staff '%s' should be in ContentRegistry" % staff_id
		)


func test_unknown_id_returns_empty() -> void:
	var result: StringName = ContentRegistry.resolve("nonexistent_item")
	assert_eq(
		result, &"",
		"Unknown ID should return empty StringName"
	)


func test_validate_all_references_clean() -> void:
	var errors: Array[String] = (
		ContentRegistry.validate_all_references()
	)
	assert_eq(
		errors.size(), 0,
		"Cross-reference validation should have no errors: %s"
		% [errors]
	)
