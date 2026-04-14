## Tests StaffDefinition resource fields, defaults, enum, specialization,
## and performance multiplier formula.
extends GutTest


func test_default_values() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	assert_eq(staff.staff_id, "")
	assert_eq(staff.display_name, "")
	assert_eq(staff.role, StaffDefinition.StaffRole.CASHIER)
	assert_eq(staff.skill_level, 1)
	assert_almost_eq(staff.morale, 0.65, 0.001)
	assert_almost_eq(staff.daily_wage, 20.0, 0.01)
	assert_almost_eq(staff.hire_cost, 0.0, 0.01)
	assert_almost_eq(staff.skill_bonus, 0.0, 0.01)
	assert_almost_eq(
		staff.morale_decay_per_day, 0.02, 0.001
	)
	assert_eq(staff.description, "")
	assert_eq(staff.seniority_days, 0)
	assert_eq(staff.consecutive_low_morale_days, 0)
	assert_eq(staff.assigned_store_id, "")


func test_staff_role_enum() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.role = StaffDefinition.StaffRole.STOCKER
	assert_eq(staff.role, StaffDefinition.StaffRole.STOCKER)
	staff.role = StaffDefinition.StaffRole.GREETER
	assert_eq(staff.role, StaffDefinition.StaffRole.GREETER)
	staff.role = StaffDefinition.StaffRole.CASHIER
	assert_eq(staff.role, StaffDefinition.StaffRole.CASHIER)


func test_specialization_derived_from_role() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.role = StaffDefinition.StaffRole.CASHIER
	assert_eq(staff.specialization, "pricing")
	staff.role = StaffDefinition.StaffRole.STOCKER
	assert_eq(staff.specialization, "stocking")
	staff.role = StaffDefinition.StaffRole.GREETER
	assert_eq(staff.specialization, "customer_service")


func test_name_aliases_display_name() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.display_name = "Test Worker"
	assert_eq(staff.name, "Test Worker")


func test_skill_level_clamped_low() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.skill_level = 0
	assert_eq(staff.skill_level, 1)


func test_skill_level_clamped_high() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.skill_level = 5
	assert_eq(staff.skill_level, 3)


func test_morale_default() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	assert_almost_eq(staff.morale, 0.65, 0.001)


func test_morale_clamped_low() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.morale = -0.5
	assert_almost_eq(staff.morale, 0.0, 0.001)


func test_morale_clamped_high() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.morale = 1.5
	assert_almost_eq(staff.morale, 1.0, 0.001)


func test_performance_multiplier_default_morale() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	var expected: float = 0.6 + (0.65 * 0.4)
	assert_almost_eq(staff.performance_multiplier(), expected, 0.001)


func test_performance_multiplier_zero_morale() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.morale = 0.0
	assert_almost_eq(staff.performance_multiplier(), 0.6, 0.001)


func test_performance_multiplier_full_morale() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.morale = 1.0
	assert_almost_eq(staff.performance_multiplier(), 1.0, 0.001)


func test_performance_multiplier_mid_morale() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.morale = 0.5
	var expected: float = 0.6 + (0.5 * 0.4)
	assert_almost_eq(staff.performance_multiplier(), expected, 0.001)


func test_instantiation_with_fields() -> void:
	var staff: StaffDefinition = StaffDefinition.new()
	staff.staff_id = "abc-123"
	staff.display_name = "Test Worker"
	staff.role = StaffDefinition.StaffRole.STOCKER
	staff.skill_level = 2
	staff.daily_wage = 30.0
	staff.hire_cost = 25.0
	staff.skill_bonus = 2.0
	staff.morale = 0.8
	staff.seniority_days = 5
	staff.consecutive_low_morale_days = 2
	staff.assigned_store_id = "retro_games"
	assert_eq(staff.staff_id, "abc-123")
	assert_eq(staff.display_name, "Test Worker")
	assert_eq(staff.name, "Test Worker")
	assert_eq(staff.role, StaffDefinition.StaffRole.STOCKER)
	assert_eq(staff.specialization, "stocking")
	assert_eq(staff.skill_level, 2)
	assert_almost_eq(staff.morale, 0.8, 0.001)
	assert_almost_eq(staff.daily_wage, 30.0, 0.01)
	assert_almost_eq(staff.hire_cost, 25.0, 0.01)
	assert_almost_eq(staff.skill_bonus, 2.0, 0.01)
	assert_eq(staff.seniority_days, 5)
	assert_eq(staff.consecutive_low_morale_days, 2)
	assert_eq(staff.assigned_store_id, "retro_games")
