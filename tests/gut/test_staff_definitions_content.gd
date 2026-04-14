## Validates staff_definitions.json: 9 templates, 3 roles x 3 skill levels,
## correct wages, skill bonuses, and morale values.
extends GutTest


const EXPECTED_COUNT: int = 9

const EXPECTED_IDS: Array[String] = [
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

const ROLE_COUNTS: Dictionary = {
	StaffDefinition.StaffRole.CASHIER: 3,
	StaffDefinition.StaffRole.STOCKER: 3,
	StaffDefinition.StaffRole.GREETER: 3,
}

const EXPECTED_WAGES: Dictionary = {
	"cashier_skill_1": {"hire": 15.0, "wage": 20.0},
	"cashier_skill_2": {"hire": 30.0, "wage": 35.0},
	"cashier_skill_3": {"hire": 60.0, "wage": 55.0},
	"stocker_skill_1": {"hire": 10.0, "wage": 18.0},
	"stocker_skill_2": {"hire": 25.0, "wage": 30.0},
	"stocker_skill_3": {"hire": 50.0, "wage": 48.0},
	"greeter_skill_1": {"hire": 20.0, "wage": 22.0},
	"greeter_skill_2": {"hire": 35.0, "wage": 38.0},
	"greeter_skill_3": {"hire": 65.0, "wage": 58.0},
}

const EXPECTED_SKILL_BONUS: Dictionary = {
	"cashier_skill_1": 1.0,
	"cashier_skill_2": 1.2,
	"cashier_skill_3": 1.5,
	"stocker_skill_1": 1.0,
	"stocker_skill_2": 2.0,
	"stocker_skill_3": 3.0,
	"greeter_skill_1": 0.0,
	"greeter_skill_2": 0.05,
	"greeter_skill_3": 0.12,
}


func test_exactly_nine_staff_definitions_loaded() -> void:
	var all: Array[StaffDefinition] = (
		DataLoader.get_all_staff_definitions()
	)
	assert_eq(
		all.size(), EXPECTED_COUNT,
		"Should have exactly %d staff definitions" % EXPECTED_COUNT
	)


func test_all_expected_ids_present() -> void:
	for staff_id: String in EXPECTED_IDS:
		var def: StaffDefinition = (
			DataLoader.get_staff_definition(staff_id)
		)
		assert_not_null(
			def,
			"Staff '%s' should be loadable" % staff_id
		)


func test_all_ids_registered_in_content_registry() -> void:
	var ids: Array[StringName] = (
		ContentRegistry.get_all_ids("staff")
	)
	for staff_id: String in EXPECTED_IDS:
		assert_has(
			ids, StringName(staff_id),
			"Staff '%s' should be in ContentRegistry" % staff_id
		)


func test_three_roles_with_three_skill_levels_each() -> void:
	var counts: Dictionary = {
		StaffDefinition.StaffRole.CASHIER: 0,
		StaffDefinition.StaffRole.STOCKER: 0,
		StaffDefinition.StaffRole.GREETER: 0,
	}
	for staff_id: String in EXPECTED_IDS:
		var def: StaffDefinition = (
			DataLoader.get_staff_definition(staff_id)
		)
		if def:
			counts[def.role] += 1
	for role_key: Variant in ROLE_COUNTS:
		assert_eq(
			counts[role_key], ROLE_COUNTS[role_key],
			"Role %s should have %d entries"
			% [role_key, ROLE_COUNTS[role_key]]
		)


func test_hire_cost_and_daily_wage_values() -> void:
	for staff_id: String in EXPECTED_WAGES:
		var def: StaffDefinition = (
			DataLoader.get_staff_definition(staff_id)
		)
		if not def:
			fail_test("Missing staff '%s'" % staff_id)
			continue
		var expected: Dictionary = EXPECTED_WAGES[staff_id]
		assert_almost_eq(
			def.hire_cost,
			expected["hire"] as float,
			0.01,
			"'%s' hire_cost" % staff_id
		)
		assert_almost_eq(
			def.daily_wage,
			expected["wage"] as float,
			0.01,
			"'%s' daily_wage" % staff_id
		)


func test_skill_bonus_values() -> void:
	for staff_id: String in EXPECTED_SKILL_BONUS:
		var def: StaffDefinition = (
			DataLoader.get_staff_definition(staff_id)
		)
		if not def:
			fail_test("Missing staff '%s'" % staff_id)
			continue
		assert_almost_eq(
			def.skill_bonus,
			EXPECTED_SKILL_BONUS[staff_id] as float,
			0.001,
			"'%s' skill_bonus" % staff_id
		)


func test_morale_start_is_065_on_all() -> void:
	for staff_id: String in EXPECTED_IDS:
		var def: StaffDefinition = (
			DataLoader.get_staff_definition(staff_id)
		)
		if not def:
			continue
		assert_almost_eq(
			def.morale, 0.65, 0.001,
			"'%s' morale_start should be 0.65" % staff_id
		)


func test_morale_decay_is_002_on_all() -> void:
	for staff_id: String in EXPECTED_IDS:
		var def: StaffDefinition = (
			DataLoader.get_staff_definition(staff_id)
		)
		if not def:
			continue
		assert_almost_eq(
			def.morale_decay_per_day, 0.02, 0.001,
			"'%s' morale_decay should be 0.02" % staff_id
		)


func test_all_entries_have_display_name() -> void:
	for staff_id: String in EXPECTED_IDS:
		var def: StaffDefinition = (
			DataLoader.get_staff_definition(staff_id)
		)
		if not def:
			continue
		assert_false(
			def.display_name.is_empty(),
			"'%s' should have a display_name" % staff_id
		)


func test_all_entries_have_description() -> void:
	for staff_id: String in EXPECTED_IDS:
		var def: StaffDefinition = (
			DataLoader.get_staff_definition(staff_id)
		)
		if not def:
			continue
		assert_false(
			def.description.is_empty(),
			"'%s' should have a description" % staff_id
		)


func test_skill_levels_match_id_pattern() -> void:
	for staff_id: String in EXPECTED_IDS:
		var def: StaffDefinition = (
			DataLoader.get_staff_definition(staff_id)
		)
		if not def:
			continue
		var expected_level: int = int(
			staff_id.get_slice("_", 2)
		)
		assert_eq(
			def.skill_level, expected_level,
			"'%s' skill_level should be %d" % [staff_id, expected_level]
		)


func test_no_real_brand_names_in_descriptions() -> void:
	var banned: PackedStringArray = [
		"Walmart", "Target", "Best Buy", "GameStop",
		"Blockbuster", "Amazon", "Costco", "Manpower",
		"Kelly Services", "Adecco",
	]
	for staff_id: String in EXPECTED_IDS:
		var def: StaffDefinition = (
			DataLoader.get_staff_definition(staff_id)
		)
		if not def:
			continue
		for brand: String in banned:
			assert_false(
				def.description.containsn(brand),
				"'%s' description contains banned brand '%s'"
				% [staff_id, brand]
			)
			assert_false(
				def.display_name.containsn(brand),
				"'%s' display_name contains banned brand '%s'"
				% [staff_id, brand]
			)
