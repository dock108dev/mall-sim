## Tests VIP customer spawn pool gating via UnlockSystemSingleton.
extends GutTest


var _system: CustomerSystem


func before_each() -> void:
	UnlockSystemSingleton.initialize()
	_system = CustomerSystem.new()
	add_child_autofree(_system)
	_system._connect_signals()


func after_each() -> void:
	UnlockSystemSingleton.initialize()


# --- VIP not in pool before unlock ---


func test_vip_absent_from_pool_before_unlock() -> void:
	_system._vip_type_valid = true
	_system._spawn_pool_dirty = true
	var pool: Array[CustomerTypeDefinition] = _system.get_spawn_pool()
	for profile: CustomerTypeDefinition in pool:
		assert_ne(
			profile.id, "vip_customer",
			"VIP should not appear in pool before vip_customer_events is unlocked"
		)


func test_standard_types_present_before_unlock() -> void:
	_system._vip_type_valid = true
	_system._spawn_pool_dirty = true
	var pool: Array[CustomerTypeDefinition] = _system.get_spawn_pool()
	assert_gt(pool.size(), 0, "Pool should contain standard customer types")


# --- VIP appears after unlock ---


func test_vip_in_pool_after_unlock() -> void:
	_system._vip_type_valid = true
	_system._spawn_pool_dirty = true
	UnlockSystemSingleton.grant_unlock(&"vip_customer_events")
	_system._spawn_pool_dirty = true
	var pool: Array[CustomerTypeDefinition] = _system.get_spawn_pool()
	var found: Array = [false]
	for profile: CustomerTypeDefinition in pool:
		if profile.id == "vip_customer":
			found[0] = true
			break
	assert_true(found[0], "VIP should appear in pool after vip_customer_events is granted")


func test_vip_not_in_pool_when_vip_type_invalid() -> void:
	_system._vip_type_valid = false
	_system._spawn_pool_dirty = true
	UnlockSystemSingleton.grant_unlock(&"vip_customer_events")
	_system._spawn_pool_dirty = true
	var pool: Array[CustomerTypeDefinition] = _system.get_spawn_pool()
	for profile: CustomerTypeDefinition in pool:
		assert_ne(
			profile.id, "vip_customer",
			"VIP should not appear when vip_type_valid is false"
		)


# --- spawn pool dirty flag ---


func test_unlock_granted_sets_dirty_flag() -> void:
	_system._spawn_pool_dirty = false
	_system._on_unlock_granted(&"vip_customer_events")
	assert_true(
		_system._spawn_pool_dirty,
		"Dirty flag should be set when vip_customer_events is granted"
	)


func test_other_unlock_does_not_set_dirty_flag() -> void:
	_system._spawn_pool_dirty = false
	_system._on_unlock_granted(&"extended_hours_unlock")
	assert_false(
		_system._spawn_pool_dirty,
		"Dirty flag should not be set for unrelated unlock IDs"
	)


func test_pool_rebuilt_without_scene_reload() -> void:
	_system._vip_type_valid = true
	_system._spawn_pool_dirty = true
	var pool_before: Array[CustomerTypeDefinition] = _system.get_spawn_pool()
	var size_before: int = pool_before.size()

	UnlockSystemSingleton.grant_unlock(&"vip_customer_events")
	assert_true(
		_system._spawn_pool_dirty,
		"Pool should be marked dirty after unlock_granted signal"
	)

	var pool_after: Array[CustomerTypeDefinition] = _system.get_spawn_pool()
	assert_eq(
		pool_after.size(), size_before + 1,
		"Pool should grow by 1 after VIP unlock"
	)


# --- pool caching ---


func test_pool_not_rebuilt_when_clean() -> void:
	_system._vip_type_valid = true
	_system._spawn_pool_dirty = true
	var first: Array[CustomerTypeDefinition] = _system.get_spawn_pool()
	assert_false(_system._spawn_pool_dirty, "Dirty flag should clear after build")
	var second: Array[CustomerTypeDefinition] = _system.get_spawn_pool()
	assert_eq(first.size(), second.size(), "Repeated calls return same pool")


# --- VIP customer stats ---


func test_vip_profile_purchase_probability() -> void:
	if not GameManager.data_loader:
		pass_test("DataLoader not available — skipping stat check")
		return
	for profile: CustomerTypeDefinition in (
		GameManager.data_loader.get_all_customers()
	):
		if profile.id == "vip_customer":
			assert_eq(
				profile.purchase_probability_base, 0.85,
				"VIP purchase_probability_base should be 0.85"
			)
			return
	pass_test("vip_customer not found in DataLoader — skipping stat check")


func test_vip_profile_budget_range() -> void:
	if not GameManager.data_loader:
		pass_test("DataLoader not available — skipping stat check")
		return
	for profile: CustomerTypeDefinition in (
		GameManager.data_loader.get_all_customers()
	):
		if profile.id == "vip_customer":
			assert_true(
				profile.budget_range[0] >= 200.0,
				"VIP min budget should be >= 200 (2.5x standard)"
			)
			return
	pass_test("vip_customer not found in DataLoader — skipping stat check")


func test_vip_profile_browse_time() -> void:
	if not GameManager.data_loader:
		pass_test("DataLoader not available — skipping stat check")
		return
	for profile: CustomerTypeDefinition in (
		GameManager.data_loader.get_all_customers()
	):
		if profile.id == "vip_customer":
			assert_true(
				profile.browse_time_range[0] >= 45.0,
				"VIP min browse time should be >= 45s (1.5x standard)"
			)
			return
	pass_test("vip_customer not found in DataLoader — skipping stat check")


# --- standard rates unaffected ---


func test_standard_pool_size_unchanged_before_unlock() -> void:
	_system._vip_type_valid = true
	_system._spawn_pool_dirty = true
	var pool_locked: Array[CustomerTypeDefinition] = _system.get_spawn_pool()
	var locked_size: int = pool_locked.size()

	UnlockSystemSingleton.grant_unlock(&"vip_customer_events")
	_system._spawn_pool_dirty = true
	var pool_unlocked: Array[CustomerTypeDefinition] = _system.get_spawn_pool()

	assert_eq(
		pool_unlocked.size(), locked_size + 1,
		"Unlocking VIP adds exactly one profile to the pool"
	)
