## Tests StaffPanel static helpers and morale color thresholds.
extends GutTest


func test_skill_stars_level_1() -> void:
	var result: String = StaffPanel._format_skill_stars(1)
	assert_eq(result, "★☆☆")


func test_skill_stars_level_2() -> void:
	var result: String = StaffPanel._format_skill_stars(2)
	assert_eq(result, "★★☆")


func test_skill_stars_level_3() -> void:
	var result: String = StaffPanel._format_skill_stars(3)
	assert_eq(result, "★★★")


func test_morale_color_green_at_threshold() -> void:
	var color: Color = StaffPanel._get_morale_color(0.65)
	assert_eq(color, StaffPanel.MORALE_COLOR_GREEN)


func test_morale_color_green_above_threshold() -> void:
	var color: Color = StaffPanel._get_morale_color(0.9)
	assert_eq(color, StaffPanel.MORALE_COLOR_GREEN)


func test_morale_color_yellow_at_threshold() -> void:
	var color: Color = StaffPanel._get_morale_color(0.30)
	assert_eq(color, StaffPanel.MORALE_COLOR_YELLOW)


func test_morale_color_yellow_mid_range() -> void:
	var color: Color = StaffPanel._get_morale_color(0.50)
	assert_eq(color, StaffPanel.MORALE_COLOR_YELLOW)


func test_morale_color_red_below_threshold() -> void:
	var color: Color = StaffPanel._get_morale_color(0.29)
	assert_eq(color, StaffPanel.MORALE_COLOR_RED)


func test_morale_color_red_at_zero() -> void:
	var color: Color = StaffPanel._get_morale_color(0.0)
	assert_eq(color, StaffPanel.MORALE_COLOR_RED)


func test_get_role_name_cashier() -> void:
	var name: String = StaffPanel._get_role_name(
		StaffDefinition.StaffRole.CASHIER
	)
	assert_eq(name, "Cashier")


func test_get_role_name_stocker() -> void:
	var name: String = StaffPanel._get_role_name(
		StaffDefinition.StaffRole.STOCKER
	)
	assert_eq(name, "Stocker")


func test_get_role_name_greeter() -> void:
	var name: String = StaffPanel._get_role_name(
		StaffDefinition.StaffRole.GREETER
	)
	assert_eq(name, "Greeter")
