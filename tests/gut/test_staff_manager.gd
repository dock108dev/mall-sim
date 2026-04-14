## Tests StaffManager candidate pool, hiring, firing, quitting,
## capacity enforcement, and day-end rotation.
extends GutTest


var _manager: Node = null


func before_each() -> void:
	_manager = preload(
		"res://game/autoload/staff_manager.gd"
	).new()
	_manager._generate_initial_pool()


func after_each() -> void:
	if _manager:
		_manager.free()
		_manager = null


func test_initial_pool_has_8_candidates() -> void:
	var pool: Array = _manager.get_candidate_pool()
	assert_eq(pool.size(), 8)


func test_candidates_have_valid_ids() -> void:
	var pool: Array = _manager.get_candidate_pool()
	for candidate: StaffDefinition in pool:
		assert_true(
			candidate.staff_id.begins_with("staff_"),
			"ID should start with staff_"
		)


func test_candidates_have_display_names() -> void:
	var pool: Array = _manager.get_candidate_pool()
	for candidate: StaffDefinition in pool:
		assert_ne(candidate.display_name, "")


func test_candidates_have_valid_skill_levels() -> void:
	var pool: Array = _manager.get_candidate_pool()
	for candidate: StaffDefinition in pool:
		assert_true(
			candidate.skill_level >= 1 and candidate.skill_level <= 3,
			"Skill level should be 1-3"
		)


func test_candidates_have_default_morale() -> void:
	var pool: Array = _manager.get_candidate_pool()
	for candidate: StaffDefinition in pool:
		assert_almost_eq(
			candidate.morale,
			StaffDefinition.DEFAULT_MORALE,
			0.001,
		)


func test_hire_candidate_success() -> void:
	var pool: Array = _manager.get_candidate_pool()
	var candidate_id: String = (pool[0] as StaffDefinition).staff_id
	var result: bool = _manager.hire_candidate(
		candidate_id, "test_store"
	)
	assert_true(result)
	assert_eq(_manager.get_candidate_pool().size(), 7)
	assert_true(_manager.get_staff_registry().has(candidate_id))


func test_hire_candidate_assigns_store() -> void:
	var pool: Array = _manager.get_candidate_pool()
	var candidate_id: String = (pool[0] as StaffDefinition).staff_id
	_manager.hire_candidate(candidate_id, "test_store")
	var staff: Array[StaffDefinition] = _manager.get_staff_for_store(
		"test_store"
	)
	assert_eq(staff.size(), 1)
	assert_eq(staff[0].assigned_store_id, "test_store")


func test_hire_candidate_not_found_returns_false() -> void:
	var result: bool = _manager.hire_candidate(
		"nonexistent", "test_store"
	)
	assert_false(result)


func test_hire_at_capacity_returns_false() -> void:
	var pool: Array = _manager.get_candidate_pool()
	_manager.hire_candidate(
		(pool[0] as StaffDefinition).staff_id, "test_store"
	)
	_manager.hire_candidate(
		(pool[1] as StaffDefinition).staff_id, "test_store"
	)
	var third_id: String = (pool[2] as StaffDefinition).staff_id
	var result: bool = _manager.hire_candidate(
		third_id, "test_store"
	)
	assert_false(result)


func test_fire_staff_removes_from_registry() -> void:
	var pool: Array = _manager.get_candidate_pool()
	var candidate_id: String = (pool[0] as StaffDefinition).staff_id
	_manager.hire_candidate(candidate_id, "test_store")
	_manager.fire_staff(candidate_id)
	assert_false(_manager.get_staff_registry().has(candidate_id))
	assert_eq(_manager.get_staff_for_store("test_store").size(), 0)


func test_quit_staff_removes_from_registry() -> void:
	var pool: Array = _manager.get_candidate_pool()
	var candidate_id: String = (pool[0] as StaffDefinition).staff_id
	_manager.hire_candidate(candidate_id, "test_store")
	_manager.quit_staff(candidate_id)
	assert_false(_manager.get_staff_registry().has(candidate_id))


func test_get_staff_for_store_filters_by_store() -> void:
	var pool: Array = _manager.get_candidate_pool()
	_manager.hire_candidate(
		(pool[0] as StaffDefinition).staff_id, "store_a"
	)
	_manager.hire_candidate(
		(pool[1] as StaffDefinition).staff_id, "store_b"
	)
	assert_eq(_manager.get_staff_for_store("store_a").size(), 1)
	assert_eq(_manager.get_staff_for_store("store_b").size(), 1)
	assert_eq(
		_manager.get_staff_for_store("nonexistent").size(), 0
	)


func test_day_ended_increments_seniority() -> void:
	var pool: Array = _manager.get_candidate_pool()
	var candidate_id: String = (pool[0] as StaffDefinition).staff_id
	_manager.hire_candidate(candidate_id, "test_store")
	_manager._on_day_ended(1)
	var staff: StaffDefinition = _manager.get_staff_registry()[
		candidate_id
	]
	assert_eq(staff.seniority_days, 1)


func test_rotation_after_3_days() -> void:
	var original_ids: Array[String] = []
	for candidate: StaffDefinition in _manager.get_candidate_pool():
		original_ids.append(candidate.staff_id)
	_manager._on_day_ended(1)
	_manager._on_day_ended(2)
	assert_eq(_manager.get_candidate_pool().size(), 8)
	_manager._on_day_ended(3)
	assert_eq(_manager.get_candidate_pool().size(), 8)
	var new_ids: Array[String] = []
	for candidate: StaffDefinition in _manager.get_candidate_pool():
		new_ids.append(candidate.staff_id)
	var changed: Array = [0]
	for id: String in new_ids:
		if not original_ids.has(id):
			changed[0] += 1
	assert_eq(changed[0], 2, "2 new candidates after rotation")


func test_no_rotation_before_3_days() -> void:
	var original_ids: Array[String] = []
	for candidate: StaffDefinition in _manager.get_candidate_pool():
		original_ids.append(candidate.staff_id)
	_manager._on_day_ended(1)
	_manager._on_day_ended(2)
	var current_ids: Array[String] = []
	for candidate: StaffDefinition in _manager.get_candidate_pool():
		current_ids.append(candidate.staff_id)
	assert_eq(current_ids, original_ids)


func test_store_capacity_defaults_to_small() -> void:
	var max_staff: int = _manager.get_max_staff_for_store(
		"unknown_store"
	)
	assert_eq(max_staff, 2)


func test_save_and_load_round_trip() -> void:
	var pool: Array = _manager.get_candidate_pool()
	var candidate_id: String = (pool[0] as StaffDefinition).staff_id
	_manager.hire_candidate(candidate_id, "test_store")
	_manager._on_day_ended(1)
	var save_data: Dictionary = _manager.get_save_data()
	var new_manager: Node = preload(
		"res://game/autoload/staff_manager.gd"
	).new()
	new_manager.load_save_data(save_data)
	assert_true(
		new_manager.get_staff_registry().has(candidate_id)
	)
	var loaded_staff: StaffDefinition = (
		new_manager.get_staff_registry()[candidate_id]
	)
	assert_eq(loaded_staff.assigned_store_id, "test_store")
	assert_eq(loaded_staff.seniority_days, 1)
	assert_eq(new_manager.get_candidate_pool().size(), 7)
	new_manager.free()
